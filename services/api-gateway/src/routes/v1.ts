import { randomUUID } from "node:crypto";
import { z } from "zod";
import type { FastifyInstance } from "fastify";
import type { AppStore } from "../domain/store.js";
import { ReasoningService } from "../reasoning/service.js";

const bboxSchema = z.object({ x: z.number(), y: z.number(), w: z.number(), h: z.number() });

export const registerV1Routes = (app: FastifyInstance, store: AppStore) => {
  const reasoning = new ReasoningService(store);

  app.post("/v1/sessions", async (request, reply) => {
    const schema = z.object({ device_id: z.string().min(1) });
    const body = schema.parse(request.body);
    const session = store.createSession(body.device_id);
    return reply.send({ session_id: session.id });
  });

  app.post("/v1/sessions/:sessionId/images::presign", async (request, reply) => {
    const params = z.object({ sessionId: z.string() }).parse(request.params);
    const schema = z.object({ filename: z.string(), content_type: z.string(), size: z.number().int().positive() });
    schema.parse(request.body);
    const session = store.getSession(params.sessionId);
    if (!session) return reply.notFound("session not found");

    const imageId = randomUUID();
    const objectKey = `${params.sessionId}/${imageId}`;
    store.addImage(params.sessionId, { id: imageId, objectKey });
    return reply.send({ image_id: imageId, upload_url: `https://mock-s3.local/upload/${objectKey}` });
  });

  app.post("/v1/sessions/:sessionId/images::commit", async (request, reply) => {
    const params = z.object({ sessionId: z.string() }).parse(request.params);
    const schema = z.object({
      image_ids: z.array(z.string()),
      meta: z
        .array(
          z.object({
            image_id: z.string(),
            width: z.number().int().positive(),
            height: z.number().int().positive(),
            sha256: z.string().min(32),
          }),
        )
        .default([]),
    });
    const body = schema.parse(request.body);

    const accepted: string[] = [];
    const rejected: string[] = [];

    for (const imageId of body.image_ids) {
      const exists = store.getImage(params.sessionId, imageId);
      if (!exists) {
        rejected.push(imageId);
        continue;
      }
      const meta = body.meta.find((item) => item.image_id === imageId);
      if (meta) {
        store.updateImageMeta(params.sessionId, imageId, {
          width: meta.width,
          height: meta.height,
          sha256: meta.sha256,
        });
      }
      accepted.push(imageId);
    }

    return reply.send({ accepted, rejected });
  });

  app.post("/v1/sessions/:sessionId/analysis", async (request, reply) => {
    const params = z.object({ sessionId: z.string() }).parse(request.params);
    const schema = z.object({ image_ids: z.array(z.string()).min(1) });
    const body = schema.parse(request.body);
    const session = store.getSession(params.sessionId);
    if (!session) return reply.notFound("session not found");

    const job = store.createAnalysisJob(params.sessionId, body.image_ids);
    store.updateJob(job.id, { status: "running", progress: 60, startedAt: new Date().toISOString() });

    const facts = body.image_ids.map((imageId, idx) => ({
      id: randomUUID(),
      sessionId: params.sessionId,
      imageId,
      sliceId: null,
      type: idx % 2 === 0 ? ("paragraph" as const) : ("entity" as const),
      text: idx % 2 === 0 ? `Screenshot ${idx + 1} extracted text block` : `Entity-${idx + 1}`,
      bbox: { x: 0.1, y: 0.1 + idx * 0.05, w: 0.8, h: 0.1 },
      confidence: 0.8,
      rawJson: { source: "mock-vision" },
    }));
    store.addFacts(params.sessionId, facts);
    store.updateJob(job.id, { status: "done", progress: 100, finishedAt: new Date().toISOString() });

    return reply.send({ job_id: job.id });
  });

  app.get("/v1/jobs/:jobId", async (request, reply) => {
    const params = z.object({ jobId: z.string() }).parse(request.params);
    const job = store.getJob(params.jobId);
    if (!job) return reply.notFound("job not found");
    return reply.send({ status: job.status, progress: job.progress });
  });

  app.get("/v1/sessions/:sessionId/summary", async (request, reply) => {
    const params = z.object({ sessionId: z.string() }).parse(request.params);
    const session = store.getSession(params.sessionId);
    if (!session) return reply.notFound("session not found");
    return reply.send(store.getSummary(params.sessionId));
  });

  app.post("/v1/sessions/:sessionId/chat", async (request, reply) => {
    const params = z.object({ sessionId: z.string() }).parse(request.params);
    const schema = z.object({
      message: z.string().min(1),
      context: z
        .object({
          image_ids: z.array(z.string()).optional(),
        })
        .optional(),
    });
    const body = schema.parse(request.body);
    const session = store.getSession(params.sessionId);
    if (!session) return reply.notFound("session not found");

    store.addMessage({
      id: randomUUID(),
      sessionId: params.sessionId,
      role: "user",
      content: body.message,
      createdAt: new Date().toISOString(),
    });

    const result = reasoning.answer(params.sessionId, body.message, body.context?.image_ids);
    store.storeAnswer(params.sessionId, result);

    return reply.send({
      answer: result.answer,
      citations: result.citations,
      followups: result.followups,
      confidence: result.confidence,
      is_speculative: result.isSpeculative,
    });
  });

  app.get("/v1/sessions/:sessionId/evidences/:evidenceId", async (request, reply) => {
    const params = z.object({ sessionId: z.string(), evidenceId: z.string() }).parse(request.params);
    const evidence = store.getEvidence(params.evidenceId);
    if (!evidence) return reply.notFound("evidence not found");
    bboxSchema.parse(evidence.bbox);
    return reply.send({
      image_id: evidence.imageId,
      bbox: evidence.bbox,
      excerpt: evidence.excerpt,
      fact_id: evidence.factId,
      confidence: evidence.confidence,
    });
  });

  app.delete("/v1/sessions/:sessionId", async (request, reply) => {
    const params = z.object({ sessionId: z.string() }).parse(request.params);
    const deleted = store.deleteSession(params.sessionId);
    if (!deleted) return reply.notFound("session not found");
    return reply.send({ ok: true, cleanup_queued: true });
  });
};

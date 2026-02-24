import { randomUUID } from "node:crypto";
import type { AppStore, ChatResponse, SummaryResponse } from "./store.js";
import type { AnalysisJob, ChatMessage, Evidence, Image, Session, StoredFact } from "./models.js";

const now = () => new Date().toISOString();

export class MemoryStore implements AppStore {
  private sessions = new Map<string, Session>();
  private images = new Map<string, Image>();
  private jobs = new Map<string, AnalysisJob>();
  private facts: StoredFact[] = [];
  private messages: ChatMessage[] = [];
  private evidences = new Map<string, Evidence>();

  createSession(deviceId: string): Session {
    const session: Session = { id: randomUUID(), deviceId, status: "active", createdAt: now(), updatedAt: now() };
    this.sessions.set(session.id, session);
    return session;
  }

  getSession(sessionId: string): Session | undefined {
    return this.sessions.get(sessionId);
  }

  listSessions(): Session[] {
    return [...this.sessions.values()];
  }

  deleteSession(sessionId: string): boolean {
    if (!this.sessions.has(sessionId)) {
      return false;
    }
    this.sessions.delete(sessionId);
    for (const [id, image] of this.images) {
      if (image.sessionId === sessionId) this.images.delete(id);
    }
    for (const [id, job] of this.jobs) {
      if (job.sessionId === sessionId) this.jobs.delete(id);
    }
    this.facts = this.facts.filter((fact) => fact.sessionId !== sessionId);
    this.messages = this.messages.filter((msg) => msg.sessionId !== sessionId);
    return true;
  }

  addImage(sessionId: string, image: Pick<Image, "id" | "objectKey">): Image {
    const record: Image = { id: image.id, sessionId, objectKey: image.objectKey, createdAt: now() };
    this.images.set(record.id, record);
    return record;
  }

  updateImageMeta(sessionId: string, imageId: string, meta: Partial<Image>): Image | undefined {
    const image = this.images.get(imageId);
    if (!image || image.sessionId !== sessionId) return undefined;
    const updated = { ...image, ...meta };
    this.images.set(imageId, updated);
    return updated;
  }

  getImage(sessionId: string, imageId: string): Image | undefined {
    const image = this.images.get(imageId);
    if (!image || image.sessionId !== sessionId) return undefined;
    return image;
  }

  createAnalysisJob(sessionId: string, imageIds: string[]): AnalysisJob {
    const job: AnalysisJob = { id: randomUUID(), sessionId, status: "pending", progress: 0, imageIds };
    this.jobs.set(job.id, job);
    return job;
  }

  getJob(jobId: string): AnalysisJob | undefined {
    return this.jobs.get(jobId);
  }

  updateJob(jobId: string, patch: Partial<AnalysisJob>): AnalysisJob | undefined {
    const current = this.jobs.get(jobId);
    if (!current) return undefined;
    const merged = { ...current, ...patch };
    this.jobs.set(jobId, merged);
    return merged;
  }

  addFacts(sessionId: string, facts: StoredFact[]): void {
    this.facts = this.facts.filter((item) => item.sessionId !== sessionId).concat(facts);
  }

  getFacts(sessionId: string, imageIds?: string[]): StoredFact[] {
    const inSession = this.facts.filter((fact) => fact.sessionId === sessionId);
    if (!imageIds || imageIds.length === 0) return inSession;
    const set = new Set(imageIds);
    return inSession.filter((fact) => set.has(fact.imageId));
  }

  addMessage(msg: ChatMessage): void {
    this.messages.push(msg);
  }

  getMessages(sessionId: string): ChatMessage[] {
    return this.messages.filter((msg) => msg.sessionId === sessionId);
  }

  addEvidence(ev: Evidence): void {
    this.evidences.set(ev.id, ev);
  }

  getEvidence(evidenceId: string): Evidence | undefined {
    return this.evidences.get(evidenceId);
  }

  getSummary(sessionId: string): SummaryResponse {
    const facts = this.getFacts(sessionId);
    const highlights = facts.slice(0, 3).map((fact) => fact.text);
    const entities = facts.filter((fact) => fact.type === "entity").map((fact) => fact.text).slice(0, 8);
    const timelines = facts.filter((fact) => fact.type === "time").map((fact) => fact.text).slice(0, 8);
    return {
      highlights,
      entities,
      timelines,
    };
  }

  storeAnswer(sessionId: string, content: ChatResponse): ChatMessage {
    const message: ChatMessage = {
      id: randomUUID(),
      sessionId,
      role: "assistant",
      content: content.answer,
      createdAt: now(),
    };
    this.addMessage(message);
    return message;
  }
}

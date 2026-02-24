import Fastify from "fastify";
import { MemoryStore } from "./domain/memory-store.js";
import { registerV1Routes } from "./routes/v1.js";

export const buildServer = () => {
  const app = Fastify({ logger: false });
  const store = new MemoryStore();

  app.get("/healthz", async () => ({ ok: true }));
  registerV1Routes(app, store);

  return app;
};

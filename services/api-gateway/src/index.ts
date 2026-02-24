import { buildServer } from "./server.js";

const parsePort = (raw: string | undefined): number => {
  if (!raw || raw.trim().length === 0) return 8080;
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0 || !Number.isInteger(n)) return 8080;
  return n;
};

const port = parsePort(process.env.PORT);
const host = process.env.HOST && process.env.HOST.trim().length > 0 ? process.env.HOST : "0.0.0.0";

console.log(`[api] booting host=${host} port=${port}`);
const app = buildServer();
console.log("[api] server object created");

app
  .listen({ port, host })
  .then(() => {
    console.log("[api] listen resolved");
    app.log.info(`api-gateway listening on ${host}:${port}`);
  })
  .catch((err) => {
    console.error("[api] listen failed", err);
    app.log.error(err);
    process.exit(1);
  });

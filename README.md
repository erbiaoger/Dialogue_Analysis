# ScreenshotIQ

Implementation scaffold for an iOS screenshot understanding + evidence-grounded chat app.

## Workspace Layout

- `services/api-gateway`: Fastify API implementing V1 endpoints.
- `services/analysis-worker`: BullMQ worker for long-image slicing and mock vision extraction.
- `services/reasoning-service`: Model-provider abstraction (OpenAI/Gemini routing).
- `packages/shared`: Shared API/domain types.
- `infra/prisma/schema.prisma`: PostgreSQL schema.
- `ios-app/ScreenshotIQ`: SwiftUI app skeleton (Home/Import/Analysis/Chat/Evidence/Settings).

## Implemented APIs

- `POST /v1/sessions`
- `POST /v1/sessions/{session_id}/images:presign`
- `POST /v1/sessions/{session_id}/images:commit`
- `POST /v1/sessions/{session_id}/analysis`
- `GET /v1/jobs/{job_id}`
- `GET /v1/sessions/{session_id}/summary`
- `POST /v1/sessions/{session_id}/chat`
- `GET /v1/sessions/{session_id}/evidences/{evidence_id}`
- `DELETE /v1/sessions/{session_id}`

## Run

```bash
npm install
npm run dev:api
```

## Docker (Local Deployment)

1. Prepare env:

```bash
cp .env.example .env.local
# edit .env.local and fill OPENAI_API_KEY
```

2. Start API in Docker:

```bash
docker compose up -d --build
```

3. Check health:

```bash
curl http://127.0.0.1:8080/healthz
```

4. Stop:

```bash
docker compose down
```

## iPhone Remote Access via Tailscale (Outside Home Network)

1. Install and login Tailscale on **Mac** and **iPhone** with the same tailnet account.
2. On Mac, verify tailnet IP:

```bash
tailscale ip -4
```

3. Keep Docker API running on Mac (`docker compose up -d`).
4. In iOS app `Settings -> API Base URL`, set:

```text
http://<your-mac-tailscale-ip>:8080
```

Example:

```text
http://100.101.102.103:8080
```

5. On iPhone Safari (while on cellular or external Wi-Fi), test:

```text
http://<your-mac-tailscale-ip>:8080/healthz
```

Expected result:

```json
{"ok":true}
```

If failed:
- Ensure Mac Tailscale status is `Connected`.
- Ensure iPhone Tailscale status is `Connected`.
- Ensure Docker container is healthy: `docker ps`.
- Ensure API URL in app has `http://` prefix and port `:8080`.

### Enable OpenAI (Real LLM)

Option A: use env file (recommended, auto-loaded by `simple-api.mjs`):

```bash
cp .env.example .env.local
# edit .env.local and fill OPENAI_API_KEY / OPENAI_MODEL / OPENAI_VISION_MODEL
npm run dev:api
```

Option B: export environment variables in shell:

```bash
export OPENAI_API_KEY="your_key_here"
export OPENAI_MODEL="gpt-4o-mini"
export OPENAI_VISION_MODEL="gpt-4o-mini"
npm run dev:api
```

If `OPENAI_API_KEY` is missing, `/v1/sessions/:id/chat` automatically falls back to local mock reasoning.

In another terminal:

```bash
npm run dev:worker
```

## Test

```bash
npm run typecheck
npm test
```

## Notes

- API currently uses an in-memory store for local development speed; Prisma schema is ready for Postgres-backed repository implementation.
- Reasoning path enforces evidence-first response and speculative fallback when no evidence is found.
- Analysis worker includes deterministic long-image slicing with 15% overlap.
- Current local runner for `dev:api` is `services/api-gateway/simple-api.mjs` for startup stability; it supports OpenAI + local fallback.

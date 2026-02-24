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

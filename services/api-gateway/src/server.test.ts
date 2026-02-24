import { describe, expect, it } from "vitest";
import { buildServer } from "./server.js";

describe("api-gateway", () => {
  it("creates a session and handles chat with citations", async () => {
    const app = buildServer();

    const createRes = await app.inject({
      method: "POST",
      url: "/v1/sessions",
      payload: { device_id: "device-1" },
    });
    expect(createRes.statusCode).toBe(200);
    const { session_id } = createRes.json();

    const presign = await app.inject({
      method: "POST",
      url: `/v1/sessions/${session_id}/images:presign`,
      payload: { filename: "a.png", content_type: "image/png", size: 10 },
    });
    const { image_id } = presign.json();

    await app.inject({
      method: "POST",
      url: `/v1/sessions/${session_id}/images:commit`,
      payload: {
        image_ids: [image_id],
        meta: [{ image_id, width: 100, height: 200, sha256: "a".repeat(64) }],
      },
    });

    await app.inject({
      method: "POST",
      url: `/v1/sessions/${session_id}/analysis`,
      payload: { image_ids: [image_id] },
    });

    const chat = await app.inject({
      method: "POST",
      url: `/v1/sessions/${session_id}/chat`,
      payload: { message: "总结一下这张图" },
    });

    expect(chat.statusCode).toBe(200);
    const body = chat.json();
    expect(body.answer).toBeTypeOf("string");
    expect(Array.isArray(body.citations)).toBe(true);
    expect(body.citations.length).toBeGreaterThan(0);
  });
});

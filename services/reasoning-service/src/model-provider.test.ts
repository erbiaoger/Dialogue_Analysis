import { describe, expect, it } from "vitest";
import { routeModel } from "./model-provider.js";

describe("routeModel", () => {
  it("routes complex reasoning to openai", () => {
    expect(routeModel("complex_reasoning").name).toBe("openai");
  });

  it("routes simple qa to gemini", () => {
    expect(routeModel("simple_qa").name).toBe("gemini");
  });
});

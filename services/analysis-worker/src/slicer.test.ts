import { describe, expect, it } from "vitest";
import { sliceLongImage } from "./slicer.js";

describe("sliceLongImage", () => {
  it("returns one slice for small image", () => {
    const out = sliceLongImage(1000, 1200);
    expect(out).toHaveLength(1);
  });

  it("splits long image with overlap", () => {
    const out = sliceLongImage(1000, 12000, 2000, 0.15);
    expect(out.length).toBeGreaterThan(1);
    expect(out[0].h).toBe(2000);
    expect(out.at(-1)?.y).toBeLessThan(12000);
  });
});

import { randomUUID } from "node:crypto";
import type { VisualFact } from "@screenshot-iq/shared";
import type { SliceRect } from "./slicer.js";

export const mockVisionExtract = (sessionId: string, imageId: string, slices: SliceRect[]): VisualFact[] => {
  return slices.map((slice, idx) => ({
    id: randomUUID(),
    sessionId,
    imageId,
    sliceId: `slice-${idx}`,
    type: idx % 3 === 0 ? "time" : idx % 2 === 0 ? "entity" : "paragraph",
    text: idx % 3 === 0 ? `2026-02-${(idx % 28) + 1}` : `Extracted content from slice ${idx + 1}`,
    bbox: {
      x: 0.08,
      y: 0.1,
      w: 0.84,
      h: 0.12,
    },
    confidence: 0.78,
    rawJson: {
      model: "mock-vision-v1",
      slice,
    },
  }));
};

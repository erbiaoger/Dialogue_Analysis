import type { StoredFact } from "../domain/models.js";

export const searchFacts = (facts: StoredFact[], query: string): StoredFact[] => {
  const lower = query.toLowerCase();
  const ranked = facts
    .map((fact) => ({ fact, score: similarity(lower, fact.text.toLowerCase()) }))
    .filter((item) => item.score > 0.15)
    .sort((a, b) => b.score - a.score)
    .slice(0, 12)
    .map((item) => item.fact);
  if (ranked.length > 0) {
    return ranked;
  }
  return facts
    .slice()
    .sort((a, b) => b.confidence - a.confidence)
    .slice(0, 5);
};

export const locateEvidence = (facts: StoredFact[]) => {
  return facts.map((fact) => ({
    factId: fact.id,
    imageId: fact.imageId,
    bbox: fact.bbox,
    excerpt: fact.text,
    confidence: fact.confidence,
  }));
};

export const crossImageEntityLink = (facts: StoredFact[]): string[] => {
  const byText = new Map<string, number>();
  for (const fact of facts) {
    const key = fact.text.trim();
    if (key.length < 2) continue;
    byText.set(key, (byText.get(key) ?? 0) + 1);
  }
  return [...byText.entries()].filter(([, count]) => count > 1).map(([text]) => text);
};

export const timelineReconstruct = (facts: StoredFact[]): string[] => {
  return facts
    .filter((fact) => fact.type === "time")
    .map((fact) => fact.text)
    .sort((a, b) => a.localeCompare(b));
};

const similarity = (a: string, b: string): number => {
  if (!a || !b) return 0;
  const aSet = new Set(a.split(/\s+/));
  const bSet = new Set(b.split(/\s+/));
  const intersect = [...aSet].filter((item) => bSet.has(item)).length;
  const union = new Set([...aSet, ...bSet]).size;
  if (union === 0) return 0;
  return intersect / union;
};

import { randomUUID } from "node:crypto";
import type { AppStore } from "../domain/store.js";
import type { ChatResponse } from "../domain/store.js";
import { buildPlan } from "./planner.js";
import { crossImageEntityLink, locateEvidence, searchFacts, timelineReconstruct } from "./tools.js";

export class ReasoningService {
  constructor(private readonly store: AppStore) {}

  answer(sessionId: string, message: string, imageIds?: string[]): ChatResponse {
    const plan = buildPlan(message);
    const facts = this.store.getFacts(sessionId, imageIds);
    const relevantFacts = searchFacts(facts, message);
    const evidenceRows = locateEvidence(relevantFacts);
    const linkedEntities = crossImageEntityLink(facts);
    const timeline = timelineReconstruct(facts);

    const citations = evidenceRows.slice(0, 5).map((row) => {
      const id = randomUUID();
      this.store.addEvidence({
        id,
        imageId: row.imageId,
        factId: row.factId,
        bbox: row.bbox,
        excerpt: row.excerpt,
        confidence: row.confidence,
      });
      return {
        id,
        evidenceId: id,
        factId: row.factId,
        reasoningRole: "support" as const,
        score: row.confidence,
      };
    });

    const hasEvidence = citations.length > 0;
    const confidence = hasEvidence ? Math.min(0.95, 0.55 + citations.length * 0.07) : 0.28;

    const answer = hasEvidence
      ? [
          "基于截图证据，我先给出结论：",
          relevantFacts.slice(0, 3).map((fact, idx) => `${idx + 1}. ${fact.text}`).join("\n"),
          linkedEntities.length > 0 ? `\n跨图重复实体：${linkedEntities.slice(0, 5).join("、")}` : "",
          timeline.length > 0 ? `\n时间线线索：${timeline.slice(0, 5).join(" -> ")}` : "",
        ].join("\n")
      : "当前截图里没有足够证据支持确定结论。建议补充更清晰或更多上下文截图。";

    const followups = hasEvidence
      ? ["要我按重要性排序这些证据吗？", "要我指出潜在冲突信息吗？", "要我基于这些证据给你一个行动建议吗？"]
      : ["你希望我先关注哪张图？", "可以补一张包含关键信息区域的截图吗？"];

    const speculative = !hasEvidence;
    void plan;

    return {
      answer,
      citations,
      followups,
      confidence,
      isSpeculative: speculative,
    };
  }
}

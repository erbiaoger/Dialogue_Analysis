import type { AnalysisJob, ChatMessage, Evidence, Image, Session, StoredFact } from "./models.js";

export type ChatResponse = {
  answer: string;
  citations: Array<{
    id: string;
    evidenceId: string;
    factId: string;
    reasoningRole: "support" | "contrast";
    score: number;
  }>;
  followups: string[];
  confidence: number;
  isSpeculative: boolean;
};

export type SummaryResponse = {
  highlights: string[];
  entities: string[];
  timelines: string[];
};

export interface AppStore {
  createSession(deviceId: string): Session;
  getSession(sessionId: string): Session | undefined;
  listSessions(): Session[];
  deleteSession(sessionId: string): boolean;
  addImage(sessionId: string, image: Pick<Image, "id" | "objectKey">): Image;
  updateImageMeta(sessionId: string, imageId: string, meta: Partial<Image>): Image | undefined;
  getImage(sessionId: string, imageId: string): Image | undefined;
  createAnalysisJob(sessionId: string, imageIds: string[]): AnalysisJob;
  getJob(jobId: string): AnalysisJob | undefined;
  updateJob(jobId: string, patch: Partial<AnalysisJob>): AnalysisJob | undefined;
  addFacts(sessionId: string, facts: StoredFact[]): void;
  getFacts(sessionId: string, imageIds?: string[]): StoredFact[];
  addMessage(msg: ChatMessage): void;
  getMessages(sessionId: string): ChatMessage[];
  addEvidence(ev: Evidence): void;
  getEvidence(evidenceId: string): Evidence | undefined;
  getSummary(sessionId: string): SummaryResponse;
  storeAnswer(sessionId: string, content: ChatResponse): ChatMessage;
}

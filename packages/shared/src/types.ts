export type JobStatus = "pending" | "running" | "done" | "failed";

export type BoundingBox = {
  x: number;
  y: number;
  w: number;
  h: number;
};

export type VisualFactType =
  | "title"
  | "paragraph"
  | "button"
  | "price"
  | "time"
  | "entity"
  | "table_cell";

export type VisualFact = {
  id: string;
  sessionId: string;
  imageId: string;
  sliceId: string | null;
  type: VisualFactType;
  text: string;
  bbox: BoundingBox;
  confidence: number;
  rawJson: Record<string, unknown>;
};

export type Citation = {
  id: string;
  evidenceId: string;
  factId: string;
  reasoningRole: "support" | "contrast";
  score: number;
};

export type ChatRequest = {
  message: string;
  context?: {
    imageIds?: string[];
  };
};

export type ChatResponse = {
  answer: string;
  citations: Citation[];
  followups: string[];
  confidence: number;
  isSpeculative: boolean;
};

export type PlannerSubtask = {
  id: string;
  intent: string;
  requiredEvidence: string[];
};

export type PlannerOutput = {
  subtasks: PlannerSubtask[];
};

export type SummaryResponse = {
  highlights: string[];
  entities: string[];
  timelines: string[];
};

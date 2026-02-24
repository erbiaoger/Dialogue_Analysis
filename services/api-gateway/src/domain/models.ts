export type BoundingBox = {
  x: number;
  y: number;
  w: number;
  h: number;
};

export type VisualFactType = "title" | "paragraph" | "button" | "price" | "time" | "entity" | "table_cell";

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

export type Session = {
  id: string;
  deviceId: string;
  status: string;
  createdAt: string;
  updatedAt: string;
};

export type Image = {
  id: string;
  sessionId: string;
  sha256?: string;
  width?: number;
  height?: number;
  objectKey?: string;
  createdAt: string;
};

export type AnalysisJob = {
  id: string;
  sessionId: string;
  status: "pending" | "running" | "done" | "failed";
  errorCode?: string;
  progress: number;
  startedAt?: string;
  finishedAt?: string;
  imageIds: string[];
};

export type ChatMessage = {
  id: string;
  sessionId: string;
  role: "user" | "assistant" | "system";
  content: string;
  createdAt: string;
};

export type Evidence = {
  id: string;
  imageId: string;
  factId: string;
  bbox: BoundingBox;
  excerpt: string;
  confidence: number;
};

export type StoredFact = VisualFact;

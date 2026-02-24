type PlannerOutput = {
  subtasks: Array<{
    id: string;
    intent: string;
    requiredEvidence: string[];
  }>;
};

export const buildPlan = (message: string): PlannerOutput => {
  const subtasks = [
    {
      id: "s1",
      intent: "Extract direct evidence relevant to user question",
      requiredEvidence: ["text", "layout", "entities"],
    },
    {
      id: "s2",
      intent: "Cross-check evidence consistency across images",
      requiredEvidence: ["cross-image-links", "timeline"],
    },
    {
      id: "s3",
      intent: `Compose final answer with confidence for question: ${message}`,
      requiredEvidence: ["citations"],
    },
  ];
  return { subtasks };
};

export type ModelTask = "simple_qa" | "complex_reasoning";

export interface ModelProvider {
  name: string;
  complete(prompt: string): Promise<string>;
}

export class OpenAIProvider implements ModelProvider {
  name = "openai";

  async complete(prompt: string): Promise<string> {
    return `OPENAI_MOCK_RESPONSE: ${prompt.slice(0, 80)}`;
  }
}

export class GeminiProvider implements ModelProvider {
  name = "gemini";

  async complete(prompt: string): Promise<string> {
    return `GEMINI_MOCK_RESPONSE: ${prompt.slice(0, 80)}`;
  }
}

export const routeModel = (task: ModelTask): ModelProvider => {
  if (task === "complex_reasoning") {
    return new OpenAIProvider();
  }
  return new GeminiProvider();
};

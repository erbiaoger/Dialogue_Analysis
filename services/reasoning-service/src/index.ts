import { routeModel } from "./model-provider.js";

export const runReasoning = async (prompt: string, complex = false): Promise<string> => {
  const provider = routeModel(complex ? "complex_reasoning" : "simple_qa");
  return provider.complete(prompt);
};

if (process.env.NODE_ENV !== "test") {
  runReasoning("health-check", false).then((res) => {
    console.log(`[reasoning-service] ${res}`);
  });
}

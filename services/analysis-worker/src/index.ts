import { Queue, Worker } from "bullmq";
import { mockVisionExtract } from "./vision.js";
import { sliceLongImage } from "./slicer.js";

type AnalyzePayload = {
  sessionId: string;
  imageId: string;
  width: number;
  height: number;
};

const redisHost = process.env.REDIS_HOST ?? "127.0.0.1";
const redisPort = Number(process.env.REDIS_PORT ?? 6379);

const connection = { host: redisHost, port: redisPort };
const queueName = "analysis-jobs";

export const analysisQueue = new Queue<AnalyzePayload>(queueName, { connection });

const worker = new Worker<AnalyzePayload>(
  queueName,
  async (job) => {
    const { sessionId, imageId, width, height } = job.data;
    const slices = sliceLongImage(width, height);
    const facts = mockVisionExtract(sessionId, imageId, slices);

    console.log(`Processed ${imageId} with ${slices.length} slices and ${facts.length} facts`);
    return { factsCount: facts.length, slicesCount: slices.length };
  },
  { connection },
);

worker.on("completed", (job) => {
  console.log(`analysis job completed: ${job.id}`);
});

worker.on("failed", (job, err) => {
  console.error(`analysis job failed: ${job?.id}`, err);
});

console.log(`analysis-worker listening on queue ${queueName}`);

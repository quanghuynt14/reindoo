/* eslint-disable no-console */
import type { Job } from 'bullmq';
import type { BullConfig } from './config.ts';
import type { JobData, JobName } from './queue/queue.types.ts';
import type { TaskService } from './taskService.ts';
import { Worker } from 'bullmq';
import { QUEUE_NAMES } from './queue/queue.types.ts';
import { createRedisConnection } from './queue/redis.connection.ts';

export type ProcessorFunction = (job: Job<any>) => Promise<any>;
export type ProcessorMap = Record<string, ProcessorFunction>;

export interface WorkerConfig {
  taskService: TaskService;
  redisConfig: BullConfig;
  concurrency?: number;
  rateLimit?: {
    max: number;
    duration: number;
  };
}

/**
 * Creates a worker instance to process background tasks
 * @param config - Worker configuration with taskService and options
 * @returns BullMQ Worker instance
 */
export function createWorker(config: WorkerConfig): Worker<JobData, unknown, JobName> {
  const redisConnection = createRedisConnection(config.redisConfig);
  const handlers = config.taskService._getHandlers();

  const workerOptions: any = {
    connection: redisConnection,
    concurrency: config.concurrency || 5,
  };

  if (config.rateLimit) {
    workerOptions.limiter = {
      max: config.rateLimit.max,
      duration: config.rateLimit.duration,
    };
  }

  const worker = new Worker<JobData, unknown, JobName>(
    QUEUE_NAMES.MAIN,
    async (job) => {
      console.log(`Processing job: ${job.name} (${job.id})`);

      const handler = handlers.get(job.name);

      if (!handler) {
        throw new Error(`No handler found for task: ${job.name}`);
      }

      return await handler({ data: job.data, job });
    },
    workerOptions,
  );

  // Worker event handlers
  worker.on('completed', (job) => {
    console.log(`Job ${job.id} (${job.name}) completed successfully`);
  });

  worker.on('failed', (job, err) => {
    console.error(`Job ${job?.id} (${job?.name}) failed:`, err);
  });

  worker.on('error', (err) => {
    console.error('Worker error:', err);
  });

  return worker;
}

// Keep old name for backward compatibility
export const createWorkerRunner = createWorker;

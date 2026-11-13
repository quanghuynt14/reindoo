// Configuration
export type { BullConfig, Config } from './config.ts';
// Fastify Plugin
export { taskServicePlugin } from './plugins/taskService.plugin.ts';

// Job Types (for task processors)
export * from './queue/queue.types.ts';

// Main API - Task Service
export { createTaskService, type TaskHandler, type TaskService } from './taskService.ts';

export type { FindTasksOptions, ScheduleOptions, TaskInfo } from './taskService.ts';

// Worker API
export { createWorker, createWorkerRunner, type ProcessorMap, type WorkerConfig } from './worker.ts';

// BullMQ types for repeat options
export type { RepeatOptions } from 'bullmq';

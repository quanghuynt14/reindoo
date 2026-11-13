import type { Job, JobsOptions, RepeatOptions } from 'bullmq';
import type { Config } from './config.ts';
import type { JobName, JobPayloadMap } from './queue/queue.types.ts';
import { createQueueManager } from './queue/queue.manager.ts';

export interface ScheduleOptions {
  delay?: number; // Delay in milliseconds
  priority?: number; // Lower number = higher priority
  attempts?: number; // Override default retry attempts
  taskId?: string; // Custom task ID (for idempotency)
  scheduledTime?: Date; // Schedule for specific time
  repeat?: RepeatOptions; // Repeatable job options (cron pattern, etc.)
}

export interface FindTasksOptions {
  userId?: string;
  taskName?: JobName;
  limit?: number;
  offset?: number;
}

export interface TaskInfo {
  id: string;
  name: string;
  state: string;
  data: any;
  timestamp?: number;
  finishedOn?: number;
  failedReason?: string;
  attemptsMade: number;
  progress?: number | object | string | boolean;
}

export type TaskHandler<T extends JobName> = (context: {
  data: JobPayloadMap[T];
  job: Job;
}) => Promise<any>;

/**
 * Creates a task service instance with a clean, simple API
 * Uses BullMQ with Redis for queue storage
 */
// eslint-disable-next-line ts/explicit-function-return-type
export function createTaskService(config: Config) {
  const queueManager = createQueueManager(config.redis);
  const queue = queueManager.getQueue();

  // Initialize queue events for monitoring
  queueManager.getQueueEvents();

  // Store task handlers
  const handlers = new Map<string, TaskHandler<any>>();

  return {
    /**
     * Define a task handler
     */
    define<T extends JobName>({
      taskName,
      handler,
    }: {
      taskName: T;
      handler: TaskHandler<T>;
    }) {
      handlers.set(taskName, handler);
    },
    /**
     * Schedule a task to be processed
     * @param taskName - Name of the task to schedule
     * @param data - Task-specific data
     * @param options - Scheduling options (delay, priority, repeat, etc.)
     */
    async schedule<T extends JobName>(
      taskName: T,
      data: JobPayloadMap[T],
      options?: ScheduleOptions,
    ): Promise<{ id: string; name: string }> {
      const jobOptions: JobsOptions = {};

      if (options?.scheduledTime) {
        const delay = options.scheduledTime.getTime() - Date.now();
        if (delay < 0) {
          throw new Error('Scheduled time must be in the future');
        }
        jobOptions.delay = delay;
      } else if (options?.delay !== undefined) {
        jobOptions.delay = options.delay;
      }

      if (options?.priority !== undefined) {
        jobOptions.priority = options.priority;
      }
      if (options?.attempts !== undefined) {
        jobOptions.attempts = options.attempts;
      }
      if (options?.taskId !== undefined) {
        jobOptions.jobId = options.taskId;
      }
      if (options?.repeat !== undefined) {
        jobOptions.repeat = options.repeat;
      }

      const job = await queue.add(taskName, data as any, jobOptions);

      return {
        id: job.id!,
        name: job.name,
      };
    },

    /**
     * Cancel a scheduled or running task
     * @param taskId - ID of the task to cancel
     * @returns true if cancelled, false if task not found
     */
    async cancel(taskId: string): Promise<boolean> {
      const job = await queue.getJob(taskId);

      if (!job) {
        return false;
      }

      await job.remove();
      return true;
    },

    /**
     * Find tasks by criteria
     * @param options - Search criteria (userId, taskName, etc.)
     * @returns Array of matching tasks
     */
    async find(options: FindTasksOptions = {}): Promise<TaskInfo[]> {
      const { userId, taskName, limit = 100, offset = 0 } = options;

      // Get jobs from different states
      const states = ['waiting', 'active', 'completed', 'failed', 'delayed'] as const;
      const allTasks: TaskInfo[] = [];

      for (const state of states) {
        const jobs = await queue.getJobs([state], offset, offset + limit);

        for (const job of jobs) {
          // Filter by criteria
          if (taskName && job.name !== taskName) {
            continue;
          }
          if (userId && job.data?.userId !== userId) {
            continue;
          }

          const jobState = await job.getState();
          allTasks.push({
            id: job.id!,
            name: job.name,
            state: jobState,
            data: job.data,
            ...(job.timestamp !== undefined && { timestamp: job.timestamp }),
            ...(job.finishedOn !== undefined && { finishedOn: job.finishedOn }),
            ...(job.failedReason !== undefined && { failedReason: job.failedReason }),
            attemptsMade: job.attemptsMade,
            ...(job.progress !== undefined && { progress: job.progress }),
          });
        }
      }

      return allTasks.slice(0, limit);
    },

    /**
     * Get detailed information about a specific task
     * @param taskId - ID of the task
     * @returns Task information or null if not found
     */
    async getTask(taskId: string): Promise<TaskInfo | null> {
      const job = await queue.getJob(taskId);

      if (!job) {
        return null;
      }

      const state = await job.getState();

      return {
        id: job.id!,
        name: job.name,
        state,
        data: job.data,
        ...(job.timestamp !== undefined && { timestamp: job.timestamp }),
        ...(job.finishedOn !== undefined && { finishedOn: job.finishedOn }),
        ...(job.failedReason !== undefined && { failedReason: job.failedReason }),
        attemptsMade: job.attemptsMade,
        ...(job.progress !== undefined && { progress: job.progress }),
      };
    },

    /**
     * Get queue statistics
     */
    async getStats() {
      const counts = await queue.getJobCounts(
        'waiting',
        'active',
        'completed',
        'failed',
        'delayed',
      );

      return {
        name: queue.name,
        counts,
      };
    },

    /**
     * Internal: Get registered handlers (used by worker)
     * @internal
     */
    _getHandlers(): Map<string, TaskHandler<any>> {
      return handlers;
    },

    /**
     * Internal: Close queue connections (used by plugin cleanup)
     * @internal
     */
    async _closeConnections(): Promise<void> {
      await queueManager.closeConnections();
    },
  };
}

export type TaskService = ReturnType<typeof createTaskService>;

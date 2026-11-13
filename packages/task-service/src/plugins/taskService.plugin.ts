import type { Config } from '../config.ts';
import fp from 'fastify-plugin';
import { createTaskService } from '../taskService.ts';

type FastifyInstance = any;

export interface TaskServicePluginOptions {
  config: Config;
}

/**
 * Task Service Plugin for Fastify
 *
 * Provides task scheduling and management capabilities to Fastify applications.
 * Decorates the Fastify instance with a taskService that provides:
 * - schedule(): Schedule tasks with optional delay/priority
 * - cancel(): Cancel scheduled tasks
 * - find(): Find tasks by userId, taskName
 * - getJob(): Get detailed job information
 * - getStats(): Get queue statistics
 */
export const taskServicePlugin = fp(
  async (instance: FastifyInstance, options: TaskServicePluginOptions) => {
    const { config } = options;

    if (!config) {
      throw new Error('Config is required for taskServicePlugin');
    }

    const taskService = createTaskService(config);

    instance.decorate('taskService', taskService);

    // Cleanup on server shutdown
    instance.addHook('onClose', async () => {
      instance.log.info('Closing task service connections');
      await taskService._closeConnections();
    });

    instance.log.info('Task service plugin registered');
  },
  {
    name: 'taskService',
    dependencies: [], // Task service has no dependencies on other plugins
  },
);

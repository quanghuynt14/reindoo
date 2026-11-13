/* eslint-disable no-console */
import type { TaskService } from '@practice/task-service';

/**
 * Register good-morning task that runs daily at 9am
 */
export function registerGoodMorningTask(taskService: TaskService) {
  // Define the task handler
  taskService.define({
    taskName: 'good-morning',
    handler: async ({ data }) => {
      const message = data.message || 'Good morning!';
      console.log(`[${new Date().toISOString()}] ${message}`);
      return { success: true, message };
    },
  });
}

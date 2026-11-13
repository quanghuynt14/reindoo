/* eslint-disable no-console */
import process from 'node:process';
import { createTaskService, createWorker } from '@practice/task-service';
import closeWithGrace from 'close-with-grace';
import { MongoClient } from 'mongodb';
import { registerGoodMorningTask } from '../modules/common/goodMorning.task.ts';

export async function startWorker() {
  console.log('Starting worker...');

  // Connect to MongoDB (same connection as API server)
  // eslint-disable-next-line dot-notation
  const mongoUrl = process.env['MONGODB_URL'];
  if (!mongoUrl) {
    throw new Error('MONGODB_URL environment variable is required');
  }
  const mongoClient = new MongoClient(mongoUrl, {
    serverSelectionTimeoutMS: 8000,
  });

  await mongoClient.connect();
  console.log('Connected to MongoDB');

  // Redis configuration (shared between TaskService and Worker)
  const redisConfig = {
    // eslint-disable-next-line dot-notation
    host: process.env['REDIS_HOST'] || 'localhost',
    // eslint-disable-next-line dot-notation
    port: Number(process.env['REDIS_PORT']) || 6379,
    // eslint-disable-next-line dot-notation
    password: process.env['REDIS_PASSWORD'] || '',
  };

  // Create task service
  const taskService = createTaskService({ redis: redisConfig });

  // Register task handlers
  registerGoodMorningTask(taskService);

  // Schedule the good morning task to run every day
  await taskService.schedule(
    'good-morning',
    { message: 'Good morning!' },
    {
      repeat: {
        pattern: '0 8 * * *', // Cron pattern for 8am daily
        key: 'good-morning-daily', // Unique key for this recurring job
      },
    },
  );
  console.log('Scheduled good morning task to run at 8am every day');

  // Task handlers will be registered by the application using task-service
  const handlersCount = taskService._getHandlers().size;
  console.log(`Registered ${handlersCount} task handlers`);

  // Create worker using task-service infrastructure
  const worker = createWorker({
    taskService,
    redisConfig,
    // eslint-disable-next-line dot-notation
    concurrency: Number(process.env['QUEUE_CONCURRENCY']) || 5,
    rateLimit: {
      // eslint-disable-next-line dot-notation
      max: Number(process.env['QUEUE_RATE_LIMIT_MAX']) || 10,
      // eslint-disable-next-line dot-notation
      duration: Number(process.env['QUEUE_RATE_LIMIT_DURATION']) || 1000,
    },
  });

  console.log('Worker started and listening for jobs...');

  // Graceful shutdown
  const closeListener = closeWithGrace(async ({ err, signal }) => {
    if (err) {
      console.error('Worker closing with error:', err);
    } else {
      console.log(`${signal} signal received, worker closing...`);
    }

    console.log('Closing worker...');
    await worker.close();

    console.log('Closing MongoDB connection...');
    await mongoClient.close();

    console.log('Worker shutdown complete');
  });

  // Handle worker errors
  worker.on('error', (err) => {
    console.error('Critical worker error:', err);
    closeListener.close();
  });
}

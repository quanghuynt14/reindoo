/* eslint-disable no-console */
import type { BullConfig } from '../config.ts';
import process from 'node:process';
import { Queue, QueueEvents } from 'bullmq';
import { QUEUE_NAMES } from './queue.types.ts';
import { createRedisConnection } from './redis.connection.ts';

let queueInstance: Queue<any, any, any> | null = null;
let queueEventsInstance: QueueEvents | null = null;
let redisConnection: ReturnType<typeof createRedisConnection> | null = null;

// eslint-disable-next-line ts/explicit-function-return-type
export function createQueueManager(redisConfig: BullConfig) {
  return {
    getQueue(): Queue<any, any, any> {
      if (!queueInstance) {
        redisConnection = createRedisConnection(redisConfig);

        queueInstance = new Queue(
          QUEUE_NAMES.MAIN,
          {
            connection: redisConnection as any,
            defaultJobOptions: {
              attempts:
                // eslint-disable-next-line dot-notation
                Number(process.env['QUEUE_DEFAULT_RETRY_LIMIT']) || 3,
              backoff: {
                type: 'exponential',
                delay:
                  // eslint-disable-next-line dot-notation
                  Number(process.env['QUEUE_DEFAULT_BACKOFF_DELAY']) || 3000,
              },
              removeOnComplete: {
                age: 86400, // Keep completed jobs for 24 hours
                count: 1000, // Keep last 1000 completed jobs
              },
              removeOnFail: {
                age: 604800, // Keep failed jobs for 7 days
              },
            },
          },
        );

        console.log('Queue instance created');
      }

      return queueInstance;
    },

    getQueueEvents(): QueueEvents {
      if (!queueEventsInstance) {
        if (!redisConnection) {
          redisConnection = createRedisConnection(redisConfig);
        }

        queueEventsInstance = new QueueEvents(QUEUE_NAMES.MAIN, {
          connection: redisConnection.duplicate() as any,
        });

        queueEventsInstance.on('completed', ({ jobId }) => {
          console.log(`Job ${jobId} completed`);
        });

        queueEventsInstance.on('failed', ({ jobId, failedReason }) => {
          console.error(`Job ${jobId} failed: ${failedReason}`);
        });

        console.log('Queue events listener created');
      }

      return queueEventsInstance;
    },

    async closeConnections(): Promise<void> {
      console.log('Closing queue connections...');

      if (queueInstance) {
        await queueInstance.close();
        queueInstance = null;
      }

      if (queueEventsInstance) {
        await queueEventsInstance.close();
        queueEventsInstance = null;
      }

      if (redisConnection) {
        redisConnection.disconnect();
        redisConnection = null;
      }

      console.log('Queue connections closed');
    },
  };
}

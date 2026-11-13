/* eslint-disable no-console */
import type { BullConfig } from '../config.ts';
import { Redis } from 'ioredis';

export function createRedisConnection(config: BullConfig): Redis {
  const redisUrl = `redis://${config.host}:${config.port}`;
  const redisDb = config.db ?? 0;

  const options: any = {
    db: redisDb,
    maxRetriesPerRequest: null, // Required for BullMQ
    enableReadyCheck: false, // Required for BullMQ
    retryStrategy: (times: number) => {
      const delay = Math.min(times * 50, 2000);
      return delay;
    },
  };

  if (config.password) {
    options.password = config.password;
  }

  const connection = new Redis(redisUrl, options);

  connection.on('error', (err: Error) => {
    console.error('Redis connection error:', err);
  });

  connection.on('connect', () => {
    console.log('Redis connected successfully');
  });

  return connection;
}

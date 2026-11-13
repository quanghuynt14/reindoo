import process from 'node:process';
import fastifyCors from '@fastify/cors';
import fp from 'fastify-plugin';
import { authPlugin } from './auth/auth.plugin.ts';
// import { taskServicePlugin } from "@practice/task-service";
import { dbPlugin } from './db/db.plugin.ts';
import { turnstilePlugin } from './turnstile/turnstile.plugin.ts';

export const plugins = fp(async (instance) => {
  
  // Register CORS to allow requests from TanStack Start client
  instance.register(fastifyCors, {
    // eslint-disable-next-line dot-notation
    origin: process.env['CLIENT_URL'] || '',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'X-Requested-With',
      'User-Agent',
      'x-turnstile-token',
    ],
    credentials: true, // Important for cookies
    maxAge: 86400,
  });

  // Register task service plugin with config
  // instance.register(taskServicePlugin, {
  //   config: {
  //     redis: {
  //       host: process.env["REDIS_HOST"] || "localhost",
  //       port: Number(process.env["REDIS_PORT"]) || 6379,
  //       password: process.env["REDIS_PASSWORD"] || '',
  //     },
  //     runJobs: false, // API server doesn't process jobs, only schedules them
  //   },
  // });

  instance.register(dbPlugin);
  instance.register(authPlugin); // Auth depends on db, so it loads after
  instance.register(turnstilePlugin);
});

import type { FastifyInstance } from 'fastify';
import { apiRoutes } from './api/api.routes.ts';

export async function routes(instance: FastifyInstance) {
  instance.register((instance) => instance.route({
    method: 'GET',
    url: '/health',
    handler: async () => {
      return { now: new Date() };
    },
  }));

  instance.register(apiRoutes, { prefix: '/api' });
}

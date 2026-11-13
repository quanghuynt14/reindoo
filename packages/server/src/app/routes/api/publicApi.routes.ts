import type { FastifyInstance } from 'fastify';
import { authRoutes } from './auth.routes.ts';

export async function publicApiRoutes(instance: FastifyInstance) {
  instance.register(authRoutes);

  instance.register((instance) => instance.route({
    method: 'GET',
    url: '/health',
    handler: async () => {
      return { date: 'djkl' };
    },
  }));
};

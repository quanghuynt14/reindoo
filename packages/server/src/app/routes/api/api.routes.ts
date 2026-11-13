import type { FastifyInstance } from 'fastify';
import { privateApiRoutes } from './privateApi.routes.ts';
import { publicApiRoutes } from './publicApi.routes.ts';

export async function apiRoutes(instance: FastifyInstance) {
  instance.register(publicApiRoutes);
  instance.register(privateApiRoutes);
};

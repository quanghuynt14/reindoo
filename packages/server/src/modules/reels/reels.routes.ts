import type { FastifyInstance } from 'fastify';
import { registerGetReelsRoute } from './routes/getReels/getReels.route.ts';

export async function reelsPrivateRoutes(instance: FastifyInstance) {
  registerGetReelsRoute(instance);
}

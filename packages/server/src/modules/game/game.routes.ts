import type { FastifyInstance } from 'fastify';
import { registerGetGameStatsRoute } from './routes/getGameStats/getGameStats.route.ts';
import { registerStartGameRoute } from './routes/startGame/startGame.route.ts';
import { registerSubmitAnswerRoute } from './routes/submitAnswer/submitAnswer.route.ts';

export async function gamePrivateRoutes(instance: FastifyInstance) {
  registerStartGameRoute(instance);
  registerSubmitAnswerRoute(instance);
  registerGetGameStatsRoute(instance);
}

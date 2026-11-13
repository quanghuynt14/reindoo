import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { gameProvider } from '../../game.provider.ts';
import { getGameStatsResponseSchema } from './getGameStats.route-schema.ts';

export function registerGetGameStatsRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/stats',
    schema: {
      response: {
        200: getGameStatsResponseSchema,
      },
    },
    handler: async (request) => {
      const userId = request.user!.id;

      const { gameStatsRepository } = gameProvider({ db: instance.db });

      // Get stats
      let stats = await gameStatsRepository.getStats({ userId });

      // If no stats exist, initialize them
      if (!stats) {
        stats = await gameStatsRepository.initializeStats({ userId });
      }

      // Format the response to match the schema
      return {
        userId: stats.userId,
        totalGamesPlayed: stats.totalGamesPlayed,
        totalQuestionsAnswered: stats.totalQuestionsAnswered,
        correctAnswers: stats.correctAnswers,
        byCategory: stats.byCategory,
        ...(stats.lastPlayedAt && { lastPlayedAt: stats.lastPlayedAt.toISOString() }),
      };
    },
  });
}

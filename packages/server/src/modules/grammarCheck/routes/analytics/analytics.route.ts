import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { grammarCheckProvider } from '../../grammarCheck.provider.ts';
import { analyticsResponseSchema } from './analytics.route-schema.ts';

export function registerAnalyticsRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/analytics',
    schema: {
      response: {
        200: analyticsResponseSchema,
      },
    },
    handler: async (request, reply) => {
      const { getAnalytics } = grammarCheckProvider({ db: instance.db });

      try {
        const analytics = await getAnalytics({
          userId: request.user!.id,
        });

        return reply.send({
          ...analytics,
          recentChecks: analytics.recentChecks.map((check) => ({
            ...check,
            createdAt: check.createdAt.toISOString(),
          })),
        });
      } catch (error) {
        instance.log.error(error);
        throw error;
      }
    },
  });
}

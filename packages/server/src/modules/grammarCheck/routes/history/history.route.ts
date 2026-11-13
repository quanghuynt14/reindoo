import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { grammarCheckProvider } from '../../grammarCheck.provider.ts';
import { historyQuerySchema, historyResponseSchema } from './history.route-schema.ts';

export function registerHistoryRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/history',
    schema: {
      querystring: historyQuerySchema,
      response: {
        200: historyResponseSchema,
      },
    },
    handler: async (request, reply) => {
      const { page, limit, sortBy, sortOrder, search } = request.query as {
        page?: number;
        limit?: number;
        sortBy?: string;
        sortOrder?: 'asc' | 'desc';
        search?: string;
      };

      const { getHistory } = grammarCheckProvider({ db: instance.db });

      try {
        const history = await getHistory({
          userId: request.user!.id,
          page: page || 1,
          limit: limit || 10,
          sortBy: sortBy || 'createdAt',
          sortOrder: sortOrder || 'desc',
          search,
        });

        return reply.send({
          ...history,
          results: history.results.map((check) => ({
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

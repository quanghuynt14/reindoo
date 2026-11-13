import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { translateCheckProvider } from '../../translateCheck.provider.ts';
import { historyQuerySchema, historyResponseSchema } from './history.route-schema.ts';

// Default values for history query parameters (must match schema defaults)
const DEFAULT_PAGE = 1;
const DEFAULT_LIMIT = 10;
const DEFAULT_SORT_BY = 'createdAt';
const DEFAULT_SORT_ORDER = 'desc' as const;

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

      const { getHistory } = translateCheckProvider({ db: instance.db });

      try {
        const history = await getHistory({
          userId: request.user!.id,
          page: page || DEFAULT_PAGE,
          limit: limit || DEFAULT_LIMIT,
          sortBy: sortBy || DEFAULT_SORT_BY,
          sortOrder: sortOrder || DEFAULT_SORT_ORDER,
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

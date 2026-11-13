import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { dictionaryProvider } from '../../dictionary.provider.ts';
import { getUserSearchHistoryResponseSchema } from './getUserSearchHistory.route-schema.ts';

export function registerGetUserSearchHistoryRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/history',
    schema: {
      response: {
        200: getUserSearchHistoryResponseSchema,
      },
      querystring: {
        type: 'object',
        properties: {
          page: { type: 'number', minimum: 1, default: 1 },
          limit: { type: 'number', minimum: 1, maximum: 100, default: 20 },
        },
      },
    },
    handler: async (request) => {
      const userId = request.user!.id;
      const { page = 1, limit = 20 } = request.query as { page?: number; limit?: number };

      const skip = (page - 1) * limit;

      const { getUserSearchHistory } = dictionaryProvider({ db: instance.db });

      // Fetch one extra item to determine if there are more pages
      const searchHistory = await getUserSearchHistory({ userId, skip, limit: limit + 1 });

      const hasMore = searchHistory.length > limit;
      const items = hasMore ? searchHistory.slice(0, limit) : searchHistory;

      return {
        searchHistory: items.map((item) => ({
          ...item,
          searchedAt: item.searchedAt.toISOString(),
        })),
        hasMore,
      };
    },
  });
}

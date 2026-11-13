import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { dictionaryProvider } from '../../dictionary.provider.ts';
import { getStarredWordsResponseSchema } from './getStarredWords.route-schema.ts';

export function registerGetStarredWordsRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/starred',
    schema: {
      response: {
        200: getStarredWordsResponseSchema,
      },
    },
    handler: async (request) => {
      const userId = request.user!.id;

      const { getStarredWords } = dictionaryProvider({ db: instance.db });

      const starredWords = await getStarredWords({ userId });

      return {
        starredWords: starredWords.map((item) => ({
          ...item,
          starredAt: item.starredAt.toISOString(),
        })),
      };
    },
  });
}

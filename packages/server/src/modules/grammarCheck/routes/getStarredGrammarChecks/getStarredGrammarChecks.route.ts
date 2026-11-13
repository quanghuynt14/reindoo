import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { grammarCheckProvider } from '../../grammarCheck.provider.ts';
import { getStarredGrammarChecksResponseSchema } from './getStarredGrammarChecks.route-schema.ts';

export function registerGetStarredGrammarChecksRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/starred',
    schema: {
      response: {
        200: getStarredGrammarChecksResponseSchema,
      },
    },
    handler: async (request) => {
      const userId = request.user!.id;

      const { getStarredGrammarChecks } = grammarCheckProvider({ db: instance.db });

      const starredGrammarChecks = await getStarredGrammarChecks({ userId });

      return {
        starredGrammarChecks: starredGrammarChecks.map((item) => ({
          ...item,
          starredAt: item.starredAt.toISOString(),
          grammarCheck: {
            ...item.grammarCheck,
            createdAt: item.grammarCheck.createdAt.toISOString(),
          },
        })),
      };
    },
  });
}

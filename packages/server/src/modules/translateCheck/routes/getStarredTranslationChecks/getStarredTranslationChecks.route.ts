import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { translateCheckProvider } from '../../translateCheck.provider.ts';
import { getStarredTranslationChecksResponseSchema } from './getStarredTranslationChecks.route-schema.ts';

export function registerGetStarredTranslationChecksRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/starred',
    schema: {
      response: {
        200: getStarredTranslationChecksResponseSchema,
      },
    },
    handler: async (request) => {
      const userId = request.user!.id;

      const { getStarredTranslationChecks } = translateCheckProvider({ db: instance.db });

      const starredTranslationChecks = await getStarredTranslationChecks({ userId });

      return {
        starredTranslationChecks: starredTranslationChecks.map((item) => ({
          ...item,
          starredAt: item.starredAt.toISOString(),
          translationCheck: {
            ...item.translationCheck,
            createdAt: item.translationCheck.createdAt.toISOString(),
          },
        })),
      };
    },
  });
}

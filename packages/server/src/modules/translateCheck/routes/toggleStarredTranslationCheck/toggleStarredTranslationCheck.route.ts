import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { translateCheckProvider } from '../../translateCheck.provider.ts';
import { toggleStarredTranslationCheckRequestSchema, toggleStarredTranslationCheckResponseSchema } from './toggleStarredTranslationCheck.route-schema.ts';

export function registerToggleStarredTranslationCheckRoute(instance: ServerInstance) {
  instance.route({
    method: 'POST',
    url: '/starred/toggle',
    schema: {
      body: toggleStarredTranslationCheckRequestSchema,
      response: {
        200: toggleStarredTranslationCheckResponseSchema,
      },
    },
    handler: async (request) => {
      const userId = request.user!.id;
      const { translationCheckId } = request.body;

      const { toggleStarredTranslationCheck } = translateCheckProvider({ db: instance.db });

      const result = await toggleStarredTranslationCheck({ userId, translationCheckId });

      return result;
    },
  });
}

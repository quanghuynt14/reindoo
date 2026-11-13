import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { translateCheckProvider } from '../../translateCheck.provider.ts';
import { checkTranslationCheckStarredRequestSchema, checkTranslationCheckStarredResponseSchema } from './checkTranslationCheckStarred.route-schema.ts';

export function registerCheckTranslationCheckStarredRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/starred/check',
    schema: {
      querystring: checkTranslationCheckStarredRequestSchema,
      response: {
        200: checkTranslationCheckStarredResponseSchema,
      },
    },
    handler: async (request) => {
      const userId = request.user!.id;
      const { translationCheckId } = request.query;

      const { checkTranslationCheckStarred } = translateCheckProvider({ db: instance.db });

      const result = await checkTranslationCheckStarred({ userId, translationCheckId });

      return result;
    },
  });
}

import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { translateCheckProvider } from '../../translateCheck.provider.ts';
import {
  checkTranslationBodySchema,
  checkTranslationResponseSchema,
} from './checkTranslation.route-schema.ts';

export function registerCheckTranslationRoute(instance: ServerInstance) {
  instance.route({
    method: 'POST',
    url: '/',
    schema: {
      body: checkTranslationBodySchema,
      response: {
        200: checkTranslationResponseSchema,
      },
    },
    handler: async (request, reply) => {
      const { originalText, translatedText } = request.body;

      const { checkTranslation } = translateCheckProvider({ db: instance.db });

      try {
        const result = await checkTranslation({
          userId: request.user!.id,
          originalText,
          translatedText,
        });

        return reply.send({
          ...result,
          createdAt: result.createdAt.toISOString(),
        });
      } catch (error) {
        instance.log.error(error);
        throw error;
      }
    },
  });
}

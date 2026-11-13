import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { reelsProvider } from '../../reels.provider.ts';
import { reelsQuerySchema, reelsResponseSchema } from './getReels.route-schema.ts';

export function registerGetReelsRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/',
    schema: {
      querystring: reelsQuerySchema,
      response: {
        200: reelsResponseSchema,
      },
    },
    handler: async (request, reply) => {
      const { page, limit, sourceLanguage, targetLanguage, sort } = request.query as {
        page?: number;
        limit?: number;
        sourceLanguage?: string;
        targetLanguage?: string;
        sort?: 'newest' | 'oldest' | 'random';
      };

      const { getReels } = reelsProvider({ db: instance.db });

      try {
        const result = await getReels({
          userId: request.user!.id,
          page: page || 1,
          limit: limit || 10,
          ...(sourceLanguage && { sourceLanguage }),
          ...(targetLanguage && { targetLanguage }),
          ...(sort && { sort }),
        });

        return reply.send(result);
      } catch (error) {
        instance.log.error(error);
        throw error;
      }
    },
  });
}

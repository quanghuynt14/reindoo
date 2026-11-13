import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { dictionaryProvider } from '../../dictionary.provider.ts';
import { checkWordStarredQuerySchema, checkWordStarredResponseSchema } from './checkWordStarred.route-schema.ts';

export function registerCheckWordStarredRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/starred/check',
    schema: {
      querystring: checkWordStarredQuerySchema,
      response: {
        200: checkWordStarredResponseSchema,
      },
    },
    handler: async (request) => {
      const { wordId } = request.query;
      const userId = request.user!.id;

      const { checkWordStarred } = dictionaryProvider({ db: instance.db });

      return await checkWordStarred({
        userId,
        wordId,
      });
    },
  });
}

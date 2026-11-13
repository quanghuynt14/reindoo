import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { dictionaryProvider } from '../../dictionary.provider.ts';
import { toggleStarredWordBodySchema, toggleStarredWordResponseSchema } from './toggleStarredWord.route-schema.ts';

export function registerToggleStarredWordRoute(instance: ServerInstance) {
  instance.route({
    method: 'POST',
    url: '/starred/toggle',
    schema: {
      body: toggleStarredWordBodySchema,
      response: {
        200: toggleStarredWordResponseSchema,
      },
    },
    handler: async (request) => {
      const { wordId } = request.body;
      const userId = request.user!.id;

      const { toggleStarredWord } = dictionaryProvider({ db: instance.db });

      return await toggleStarredWord({
        userId,
        wordId,
      });
    },
  });
}

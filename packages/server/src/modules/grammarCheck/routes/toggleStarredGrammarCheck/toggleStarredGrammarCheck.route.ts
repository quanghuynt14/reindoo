import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { grammarCheckProvider } from '../../grammarCheck.provider.ts';
import { toggleStarredGrammarCheckRequestSchema, toggleStarredGrammarCheckResponseSchema } from './toggleStarredGrammarCheck.route-schema.ts';

export function registerToggleStarredGrammarCheckRoute(instance: ServerInstance) {
  instance.route({
    method: 'POST',
    url: '/starred/toggle',
    schema: {
      body: toggleStarredGrammarCheckRequestSchema,
      response: {
        200: toggleStarredGrammarCheckResponseSchema,
      },
    },
    handler: async (request) => {
      const userId = request.user!.id;
      const { grammarCheckId } = request.body;

      const { toggleStarredGrammarCheck } = grammarCheckProvider({ db: instance.db });

      const result = await toggleStarredGrammarCheck({ userId, grammarCheckId });

      return result;
    },
  });
}

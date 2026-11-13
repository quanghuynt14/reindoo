import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { grammarCheckProvider } from '../../grammarCheck.provider.ts';
import { checkGrammarCheckStarredRequestSchema, checkGrammarCheckStarredResponseSchema } from './checkGrammarCheckStarred.route-schema.ts';

export function registerCheckGrammarCheckStarredRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/starred/check',
    schema: {
      querystring: checkGrammarCheckStarredRequestSchema,
      response: {
        200: checkGrammarCheckStarredResponseSchema,
      },
    },
    handler: async (request) => {
      const userId = request.user!.id;
      const { grammarCheckId } = request.query;

      const { checkGrammarCheckStarred } = grammarCheckProvider({ db: instance.db });

      const result = await checkGrammarCheckStarred({ userId, grammarCheckId });

      return result;
    },
  });
}

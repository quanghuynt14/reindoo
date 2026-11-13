import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { grammarCheckProvider } from '../../grammarCheck.provider.ts';
import {
  checkGrammarBodySchema,
  checkGrammarResponseSchema,
} from './checkGrammar.route-schema.ts';

export function registerCheckGrammarRoute(instance: ServerInstance) {
  instance.route({
    method: 'POST',
    url: '/',
    schema: {
      body: checkGrammarBodySchema,
      response: {
        200: checkGrammarResponseSchema,
      },
    },
    handler: async (request, reply) => {
      const { text } = request.body;

      const { checkGrammar } = grammarCheckProvider({ db: instance.db });

      try {
        const result = await checkGrammar({
          userId: request.user!.id,
          text,
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

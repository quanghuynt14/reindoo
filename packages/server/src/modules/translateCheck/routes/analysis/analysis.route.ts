import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { translateCheckProvider } from '../../translateCheck.provider.ts';
import { analysisResponseSchema } from './analysis.route-schema.ts';

export function registerAnalysisRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/analysis',
    schema: {
      response: {
        200: analysisResponseSchema,
      },
    },
    handler: async (request, reply) => {
      const { getAnalysis } = translateCheckProvider({ db: instance.db });

      try {
        const analysis = await getAnalysis({
          userId: request.user!.id,
        });

        return reply.send(analysis);
      } catch (error) {
        instance.log.error(error);
        throw error;
      }
    },
  });
}

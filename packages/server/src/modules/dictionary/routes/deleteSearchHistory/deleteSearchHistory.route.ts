import type { FastifyReply, FastifyRequest } from 'fastify';
import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { dictionaryProvider } from '../../dictionary.provider.ts';
import { deleteSearchHistoryParamsSchema, deleteSearchHistoryResponseSchema } from './deleteSearchHistory.route-schema.ts';

export function registerDeleteSearchHistoryRoute(instance: ServerInstance) {
  instance.route({
    method: 'DELETE',
    url: '/history/:id',
    schema: {
      params: deleteSearchHistoryParamsSchema,
      response: {
        200: deleteSearchHistoryResponseSchema,
      },
    },
    handler: (async (request: FastifyRequest, reply: FastifyReply) => {
      const { id } = request.params as { id: string };
      const userId = request.user!.id;

      const { deleteSearchHistory } = dictionaryProvider({ db: instance.db });

      const result = await deleteSearchHistory({ id, userId });

      if (result.notFound) {
        reply.code(404);
        return {
          statusCode: 404,
          error: 'Not Found',
          message: 'Không tìm thấy mục lịch sử này.',
        };
      }

      if (result.unauthorized) {
        reply.code(403);
        return {
          statusCode: 403,
          error: 'Forbidden',
          message: 'Bạn không có quyền xoá mục này.',
        };
      }

      if (!result.success) {
        reply.code(500);
        return {
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Không xoá được mục lịch sử. Vui lòng thử lại.',
        };
      }

      return { success: true };
    }) as any,
  });
}

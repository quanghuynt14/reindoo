import type { FastifyInstance } from 'fastify';
import { dictionaryPrivateRoutes } from '../../../modules/dictionary/dictionary.routes.ts';
import { gamePrivateRoutes } from '../../../modules/game/game.routes.ts';
import { grammarCheckPrivateRoutes } from '../../../modules/grammarCheck/grammarCheck.routes.ts';
import { reelsPrivateRoutes } from '../../../modules/reels/reels.routes.ts';
import { translateCheckPrivateRoutes } from '../../../modules/translateCheck/translateCheck.routes.ts';

export async function privateApiRoutes(instance: FastifyInstance) {
  // Add authentication hook to protect all private routes
  instance.addHook('onRequest', async (request, reply) => {
    const session = await instance.auth.api.getSession({
      headers: request.headers as HeadersInit,
    });

    if (!session) {
      return reply.status(401).send({
        error: 'Unauthorized',
        message: 'Bạn cần đăng nhập để dùng chức năng này.',
      });
    }

    // Attach user info to request for use in route handlers
    request.user = session.user;
  });

  instance.register(dictionaryPrivateRoutes, { prefix: '/dictionary' });
  instance.register(grammarCheckPrivateRoutes, { prefix: '/grammar-check' });
  instance.register(translateCheckPrivateRoutes, { prefix: '/translate-check' });
  instance.register(gamePrivateRoutes, { prefix: '/game' });
  instance.register(reelsPrivateRoutes, { prefix: '/reels' });
};

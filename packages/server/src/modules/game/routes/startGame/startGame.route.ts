import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { gameProvider } from '../../game.provider.ts';
import { startGameBodySchema, startGameResponseSchema } from './startGame.route-schema.ts';

export function registerStartGameRoute(instance: ServerInstance) {
  instance.route({
    method: 'POST',
    url: '/start',
    schema: {
      body: startGameBodySchema,
      response: {
        200: startGameResponseSchema,
      },
    },
    handler: async (request) => {
      const { categories, questionCount } = request.body;
      const userId = request.user!.id;

      const { generateQuestions, gameSessionRepository } = gameProvider({ db: instance.db });

      // Generate questions
      const questions = await generateQuestions({
        userId,
        categories,
        questionCount,
      });

      if (questions.length === 0) {
        throw new Error('Chưa đủ dữ liệu để ra đề. Hãy tra từ, kiểm tra ngữ pháp hoặc đối chiếu bản dịch thêm một chút, rồi quay lại.');
      }

      // Create game session
      const session = await gameSessionRepository.create({
        userId,
        categories,
        questions,
      });

      return {
        sessionId: session.id,
        questions: session.questions,
      };
    },
  });
}

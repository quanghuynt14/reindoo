import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { gameProvider } from '../../game.provider.ts';
import { submitAnswerBodySchema, submitAnswerResponseSchema } from './submitAnswer.route-schema.ts';

export function registerSubmitAnswerRoute(instance: ServerInstance) {
  instance.route({
    method: 'POST',
    url: '/answer',
    schema: {
      body: submitAnswerBodySchema,
      response: {
        200: submitAnswerResponseSchema,
      },
    },
    handler: async (request) => {
      const { sessionId, questionId, selectedAnswerIndex } = request.body;
      const userId = request.user!.id;

      const { gameSessionRepository, updateGameStats } = gameProvider({ db: instance.db });

      // Find session
      const session = await gameSessionRepository.findById({ id: sessionId });

      if (!session) {
        throw new Error('Phiên chơi này không tồn tại.');
      }

      if (session.userId !== userId) {
        throw new Error('Bạn không có quyền vào phiên chơi này.');
      }

      // Find question
      const question = session.questions.find((q: { id: string }) => q.id === questionId);

      if (!question) {
        throw new Error('Câu hỏi này không thuộc phiên chơi hiện tại.');
      }

      // Check if already answered
      const existingAnswer = session.answers.find((a: { questionId: string }) => a.questionId === questionId);
      if (existingAnswer) {
        throw new Error('Câu hỏi này đã được trả lời rồi.');
      }

      // Check if correct
      const correct = selectedAnswerIndex === question.correctAnswerIndex;

      // Submit answer
      await gameSessionRepository.submitAnswer({
        sessionId,
        questionId,
        selectedIndex: selectedAnswerIndex,
        correct,
      });

      // Check if all questions are answered
      const updatedSession = await gameSessionRepository.findById({ id: sessionId });
      if (updatedSession) {
        if (updatedSession.answers.length === updatedSession.totalQuestions) {
          // Complete session and update stats
          await gameSessionRepository.completeSession({ sessionId });
          await updateGameStats({ session: updatedSession });
        }
      }

      return {
        correct,
        correctAnswerIndex: question.correctAnswerIndex,
        ...(question.hint && { explanation: question.hint }),
      };
    },
  });
}

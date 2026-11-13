import type { GameCategory, GameSession } from '@practice/shared';

type GameAnswer = {
  questionId: string;
  selectedIndex: number;
  correct: boolean;
  answeredAt: Date;
};

type GameStatsRepository = {
  updateStats: (params: {
    userId: string;
    correctCount: number;
    totalCount: number;
    categoryStats: Record<GameCategory, { total: number; correct: number }>;
  }) => Promise<void>;
};

export function createUpdateGameStatsUsecase({
  gameStatsRepository,
}: {
  gameStatsRepository: GameStatsRepository;
}) {
  return async function updateGameStats({
    session,
  }: {
    session: GameSession;
  }): Promise<void> {
    const correctCount = session.score;
    const totalCount = session.totalQuestions;

    // Calculate stats by category
    const categoryStats: Record<GameCategory, { total: number; correct: number }> = {
      dictionary: { total: 0, correct: 0 },
      grammar: { total: 0, correct: 0 },
      translation: { total: 0, correct: 0 },
    };

    for (const question of session.questions) {
      const answer = session.answers.find((a: GameAnswer) => a.questionId === question.id);
      if (answer) {
        const category = question.category;
        if (categoryStats[category]) {
          categoryStats[category].total++;
          if (answer.correct) {
            categoryStats[category].correct++;
          }
        }
      }
    }

    await gameStatsRepository.updateStats({
      userId: session.userId,
      correctCount,
      totalCount,
      categoryStats,
    });
  };
}

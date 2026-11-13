import type { GameCategory, GameStats } from '@practice/shared';
import type { Db } from 'mongodb';
import { getGameStatsCollection } from './gameStats.collection.ts';

type GameStatsDocument = {
  userId: string;
  totalGamesPlayed: number;
  totalQuestionsAnswered: number;
  correctAnswers: number;
  byCategory: {
    dictionary: { total: number; correct: number };
    grammar: { total: number; correct: number };
    translation: { total: number; correct: number };
  };
  lastPlayedAt?: Date;
};

export function createGameStatsRepository({ db }: { db: Db }) {
  const collection = getGameStatsCollection({ db });

  return {
    async getStats({ userId }: { userId: string }): Promise<GameStats | null> {
      const doc = await collection.findOne<GameStatsDocument>({ userId });

      if (!doc) {
        return null;
      }

      const result: GameStats = {
        userId: doc.userId,
        totalGamesPlayed: doc.totalGamesPlayed,
        totalQuestionsAnswered: doc.totalQuestionsAnswered,
        correctAnswers: doc.correctAnswers,
        byCategory: doc.byCategory,
      };

      if (doc.lastPlayedAt) {
        result.lastPlayedAt = doc.lastPlayedAt;
      }

      return result;
    },

    async updateStats({
      userId,
      correctCount,
      totalCount,
      categoryStats,
    }: {
      userId: string;
      correctCount: number;
      totalCount: number;
      categoryStats: Record<GameCategory, { total: number; correct: number }>;
    }): Promise<void> {
      const now = new Date();

      // Build the category update object
      const categoryUpdates: Record<string, number> = {};
      for (const [category, stats] of Object.entries(categoryStats)) {
        categoryUpdates[`byCategory.${category}.total`] = stats.total;
        categoryUpdates[`byCategory.${category}.correct`] = stats.correct;
      }

      await collection.updateOne(
        { userId },
        {
          $inc: {
            totalGamesPlayed: 1,
            totalQuestionsAnswered: totalCount,
            correctAnswers: correctCount,
            ...categoryUpdates,
          },
          $set: {
            lastPlayedAt: now,
          },
        },
        { upsert: true },
      );
    },

    async initializeStats({ userId }: { userId: string }): Promise<GameStats> {
      const doc: GameStatsDocument = {
        userId,
        totalGamesPlayed: 0,
        totalQuestionsAnswered: 0,
        correctAnswers: 0,
        byCategory: {
          dictionary: { total: 0, correct: 0 },
          grammar: { total: 0, correct: 0 },
          translation: { total: 0, correct: 0 },
        },
      };

      await collection.insertOne(doc);

      return {
        userId: doc.userId,
        totalGamesPlayed: doc.totalGamesPlayed,
        totalQuestionsAnswered: doc.totalQuestionsAnswered,
        correctAnswers: doc.correctAnswers,
        byCategory: doc.byCategory,
      };
    },
  };
}

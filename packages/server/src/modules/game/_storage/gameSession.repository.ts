import type { GameCategory, GameQuestion, GameSession } from '@practice/shared';
import type { Db } from 'mongodb';
import { ObjectId } from 'mongodb';
import { getGameSessionCollection } from './gameSession.collection.ts';

type GameSessionDocument = {
  userId: string;
  categories: GameCategory[];
  questions: GameQuestion[];
  answers: Array<{
    questionId: string;
    selectedIndex: number;
    correct: boolean;
    answeredAt: Date;
  }>;
  score: number;
  totalQuestions: number;
  startedAt: Date;
  completedAt?: Date;
};

export function createGameSessionRepository({ db }: { db: Db }) {
  const collection = getGameSessionCollection({ db });

  return {
    async create({
      userId,
      categories,
      questions,
    }: {
      userId: string;
      categories: GameCategory[];
      questions: GameQuestion[];
    }): Promise<GameSession> {
      const now = new Date();
      const document: GameSessionDocument = {
        userId,
        categories,
        questions,
        answers: [],
        score: 0,
        totalQuestions: questions.length,
        startedAt: now,
      };

      const result = await collection.insertOne(document);

      return {
        id: result.insertedId.toString(),
        ...document,
      };
    },

    async findById({ id }: { id: string }): Promise<GameSession | null> {
      const doc = await collection.findOne<GameSessionDocument>({ _id: new ObjectId(id) });

      if (!doc) {
        return null;
      }

      const result: GameSession = {
        id: (doc as any)._id.toString(),
        userId: doc.userId,
        categories: doc.categories,
        questions: doc.questions,
        answers: doc.answers,
        score: doc.score,
        totalQuestions: doc.totalQuestions,
        startedAt: doc.startedAt,
      };

      if (doc.completedAt) {
        result.completedAt = doc.completedAt;
      }

      return result;
    },

    async submitAnswer({
      sessionId,
      questionId,
      selectedIndex,
      correct,
    }: {
      sessionId: string;
      questionId: string;
      selectedIndex: number;
      correct: boolean;
    }): Promise<void> {
      await collection.updateOne(
        { _id: new ObjectId(sessionId) },
        {
          $push: {
            answers: {
              questionId,
              selectedIndex,
              correct,
              answeredAt: new Date(),
            },
          } as any,
          $inc: {
            score: correct ? 1 : 0,
          },
        },
      );
    },

    async completeSession({ sessionId }: { sessionId: string }): Promise<void> {
      await collection.updateOne(
        { _id: new ObjectId(sessionId) },
        {
          $set: {
            completedAt: new Date(),
          },
        },
      );
    },

    async getUserSessions({
      userId,
      limit = 10,
    }: {
      userId: string;
      limit?: number;
    }): Promise<GameSession[]> {
      const docs = await collection
        .find({ userId })
        .sort({ startedAt: -1 })
        .limit(limit)
        .toArray();

      return docs.map((doc: any): GameSession => {
        const result: GameSession = {
          id: doc._id.toString(),
          userId: doc.userId,
          categories: doc.categories,
          questions: doc.questions,
          answers: doc.answers,
          score: doc.score,
          totalQuestions: doc.totalQuestions,
          startedAt: doc.startedAt,
        };

        if (doc.completedAt) {
          result.completedAt = doc.completedAt;
        }

        return result;
      });
    },
  };
}

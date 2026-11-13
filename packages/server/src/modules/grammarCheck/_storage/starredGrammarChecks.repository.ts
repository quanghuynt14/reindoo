import type { Db } from 'mongodb';
import type { StarredGrammarCheck } from './starredGrammarChecks.repository.model.ts';
import { ObjectId } from 'mongodb';
import { getStarredGrammarChecksCollection } from './starredGrammarChecks.collection.ts';
import { formatDocumentToModel } from './starredGrammarChecks.repository.model.ts';

export function createStarredGrammarChecksRepository({ db }: { db: Db }) {
  const collection = getStarredGrammarChecksCollection({ db });

  return {
    async addStarredGrammarCheck({
      userId,
      grammarCheckId,
    }: {
      userId: string;
      grammarCheckId: string;
    }) {
      const document = await collection.insertOne({
        userId,
        grammarCheckId: new ObjectId(grammarCheckId),
        starredAt: new Date(),
      });

      if (!document.insertedId) {
        throw new Error('Failed to add starred grammar check');
      }

      const insertedDocument = await collection.findOne({ _id: document.insertedId });

      if (!insertedDocument) {
        throw new Error('Failed to retrieve inserted starred grammar check');
      }

      return formatDocumentToModel({ document: insertedDocument });
    },

    async removeStarredGrammarCheck({
      userId,
      grammarCheckId,
    }: {
      userId: string;
      grammarCheckId: string;
    }) {
      const result = await collection.deleteOne({
        userId,
        grammarCheckId: new ObjectId(grammarCheckId),
      });

      return result.deletedCount > 0;
    },

    async isGrammarCheckStarred({
      userId,
      grammarCheckId,
    }: {
      userId: string;
      grammarCheckId: string;
    }): Promise<boolean> {
      const document = await collection.findOne({
        userId,
        grammarCheckId: new ObjectId(grammarCheckId),
      });

      return document !== null;
    },

    async getUserStarredGrammarChecks({
      userId,
    }: {
      userId: string;
    }): Promise<StarredGrammarCheck[]> {
      const documents = await collection
        .find({ userId })
        .sort({ starredAt: -1 })
        .toArray();

      return documents.map((document) => formatDocumentToModel({ document }));
    },
  };
};

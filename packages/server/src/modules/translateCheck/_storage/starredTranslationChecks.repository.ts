import type { Db } from 'mongodb';
import type { StarredTranslationCheck } from './starredTranslationChecks.repository.model.ts';
import { ObjectId } from 'mongodb';
import { getStarredTranslationChecksCollection } from './starredTranslationChecks.collection.ts';
import { formatDocumentToModel } from './starredTranslationChecks.repository.model.ts';

export function createStarredTranslationChecksRepository({ db }: { db: Db }) {
  const collection = getStarredTranslationChecksCollection({ db });

  return {
    async addStarredTranslationCheck({
      userId,
      translationCheckId,
    }: {
      userId: string;
      translationCheckId: string;
    }) {
      const document = await collection.insertOne({
        userId,
        translationCheckId: new ObjectId(translationCheckId),
        starredAt: new Date(),
      });

      if (!document.insertedId) {
        throw new Error('Failed to add starred translation check');
      }

      const insertedDocument = await collection.findOne({ _id: document.insertedId });

      if (!insertedDocument) {
        throw new Error('Failed to retrieve inserted starred translation check');
      }

      return formatDocumentToModel({ document: insertedDocument });
    },

    async removeStarredTranslationCheck({
      userId,
      translationCheckId,
    }: {
      userId: string;
      translationCheckId: string;
    }) {
      const result = await collection.deleteOne({
        userId,
        translationCheckId: new ObjectId(translationCheckId),
      });

      return result.deletedCount > 0;
    },

    async isTranslationCheckStarred({
      userId,
      translationCheckId,
    }: {
      userId: string;
      translationCheckId: string;
    }): Promise<boolean> {
      const document = await collection.findOne({
        userId,
        translationCheckId: new ObjectId(translationCheckId),
      });

      return document !== null;
    },

    async getUserStarredTranslationChecks({
      userId,
    }: {
      userId: string;
    }): Promise<StarredTranslationCheck[]> {
      const documents = await collection
        .find({ userId })
        .sort({ starredAt: -1 })
        .toArray();

      return documents.map((document) => formatDocumentToModel({ document }));
    },
  };
};

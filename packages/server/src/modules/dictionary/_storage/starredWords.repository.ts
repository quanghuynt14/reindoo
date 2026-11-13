import type { Db } from 'mongodb';
import type { StarredWord } from '../dictionary.types.ts';
import { ObjectId } from 'mongodb';
import { getStarredWordsCollection } from './starredWords.collection.ts';
import { formatDocumentToModel } from './starredWords.repository.model.ts';

export function createStarredWordsRepository({ db }: { db: Db }) {
  const collection = getStarredWordsCollection({ db });

  return {
    async addStarredWord({
      userId,
      wordId,
    }: {
      userId: string;
      wordId: string;
    }) {
      const document = await collection.insertOne({
        userId,
        wordId: new ObjectId(wordId),
        starredAt: new Date(),
      });

      if (!document.insertedId) {
        throw new Error('Failed to add starred word');
      }

      const insertedDocument = await collection.findOne({ _id: document.insertedId });

      if (!insertedDocument) {
        throw new Error('Failed to retrieve inserted starred word');
      }

      return formatDocumentToModel({ document: insertedDocument });
    },

    async removeStarredWord({
      userId,
      wordId,
    }: {
      userId: string;
      wordId: string;
    }) {
      const result = await collection.deleteOne({
        userId,
        wordId: new ObjectId(wordId),
      });

      return result.deletedCount > 0;
    },

    async isWordStarred({
      userId,
      wordId,
    }: {
      userId: string;
      wordId: string;
    }): Promise<boolean> {
      const document = await collection.findOne({
        userId,
        wordId: new ObjectId(wordId),
      });

      return document !== null;
    },

    async getUserStarredWords({
      userId,
    }: {
      userId: string;
    }): Promise<StarredWord[]> {
      const documents = await collection
        .find({ userId })
        .sort({ starredAt: -1 })
        .toArray();

      return documents.map((document) => formatDocumentToModel({ document }));
    },
  };
};

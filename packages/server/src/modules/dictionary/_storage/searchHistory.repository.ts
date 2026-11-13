import type { Db } from 'mongodb';
import type { SearchHistory } from '../dictionary.types.ts';
import { ObjectId } from 'mongodb';
import { getSearchHistoryCollection } from './searchHistory.collection.ts';
import { formatDocumentToModel } from './searchHistory.repository.model.ts';

export function createSearchHistoryRepository({ db }: { db: Db }) {
  const collection = getSearchHistoryCollection({ db });

  return {
    async addSearchHistory({
      userId,
      wordId,
    }: {
      userId: string;
      wordId: string;
    }) {
      const document = await collection.insertOne({
        userId,
        wordId: new ObjectId(wordId),
        searchedAt: new Date(),
      });

      if (!document.insertedId) {
        throw new Error('Failed to add search history');
      }

      const insertedDocument = await collection.findOne({ _id: document.insertedId });

      if (!insertedDocument) {
        throw new Error('Failed to retrieve inserted search history');
      }

      return formatDocumentToModel({ document: insertedDocument });
    },

    async getUserSearchHistory({
      userId,
      skip = 0,
      limit,
    }: {
      userId: string;
      skip?: number;
      limit?: number;
    }): Promise<SearchHistory[]> {
      let query = collection
        .find({ userId })
        .sort({ searchedAt: -1 })
        .skip(skip);

      if (limit !== undefined) {
        query = query.limit(limit);
      }

      const documents = await query.toArray();

      return documents.map((document) => formatDocumentToModel({ document }));
    },

    async deleteSearchHistory({
      id,
      userId,
    }: {
      id: string;
      userId: string;
    }): Promise<{ success: boolean; notFound?: boolean; unauthorized?: boolean }> {
      // First check if the item exists
      const existingItem = await collection.findOne({
        _id: new ObjectId(id),
      });

      if (!existingItem) {
        return { success: false, notFound: true };
      }

      // Check if the user owns this item
      // eslint-disable-next-line dot-notation
      if (existingItem['userId'] !== userId) {
        return { success: false, unauthorized: true };
      }

      // Delete the item
      const result = await collection.deleteOne({
        _id: new ObjectId(id),
        userId,
      });

      return { success: result.deletedCount === 1 };
    },
  };
};

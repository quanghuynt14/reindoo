import type { TranslateCheckResult, TranslationError } from '@practice/shared';
import type { Db, WithId } from 'mongodb';
import type { TranslateCheckResultDocument } from './translateCheck.repository.model.ts';
import { ObjectId } from 'mongodb';
import { getTranslateCheckCollection } from './translateCheck.collection.ts';
import { formatDocumentToModel } from './translateCheck.repository.model.ts';

// Escape special regex characters to prevent regex injection in MongoDB queries
function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Whitelist of allowed sort fields to prevent NoSQL injection
const ALLOWED_SORT_FIELDS = ['createdAt', 'detectedOriginalLanguage', 'detectedTranslatedLanguage'] as const;
type AllowedSortField = typeof ALLOWED_SORT_FIELDS[number];

function isAllowedSortField(field: string): field is AllowedSortField {
  return ALLOWED_SORT_FIELDS.includes(field as AllowedSortField);
}

export function createTranslateCheckRepository({ db }: { db: Db }) {
  const collection = getTranslateCheckCollection({ db });

  return {
    async saveResult({
      userId,
      originalText,
      translatedText,
      detectedOriginalLanguage,
      detectedTranslatedLanguage,
      translationErrors,
      correctedTranslation,
    }: {
      userId: string;
      originalText: string;
      translatedText: string;
      detectedOriginalLanguage: string;
      detectedTranslatedLanguage: string;
      translationErrors: TranslationError[];
      correctedTranslation: string;
    }): Promise<TranslateCheckResult> {
      const now = new Date();
      const document: TranslateCheckResultDocument = {
        userId,
        originalText,
        translatedText,
        detectedOriginalLanguage,
        detectedTranslatedLanguage,
        translationErrors,
        correctedTranslation,
        createdAt: now,
      };

      const result = await collection.insertOne(document);

      return {
        id: result.insertedId.toString(),
        userId,
        originalText,
        translatedText,
        detectedOriginalLanguage,
        detectedTranslatedLanguage,
        translationErrors,
        correctedTranslation,
        createdAt: now,
      };
    },

    async findByUserId({
      userId,
      limit = 10,
    }: {
      userId: string;
      limit?: number;
    }): Promise<TranslateCheckResult[]> {
      const results = await collection
        .find({ userId })
        .sort({ createdAt: -1 })
        .limit(limit)
        .toArray();

      return results.map((doc) => formatDocumentToModel({ document: doc as WithId<TranslateCheckResultDocument> }));
    },

    async findById({ id }: { id: string }): Promise<TranslateCheckResult | null> {
      const doc = await collection.findOne({ _id: new ObjectId(id) });

      if (!doc) {
        return null;
      }

      return formatDocumentToModel({ document: doc as WithId<TranslateCheckResultDocument> });
    },

    async getHistory({
      userId,
      page = 1,
      limit = 10,
      sortBy = 'createdAt',
      sortOrder = 'desc',
      search,
    }: {
      userId: string;
      page?: number | undefined;
      limit?: number | undefined;
      sortBy?: string | undefined;
      sortOrder?: 'asc' | 'desc' | undefined;
      search?: string | undefined;
    }): Promise<{ results: TranslateCheckResult[]; total: number; page: number; totalPages: number }> {
      const skip = (page - 1) * limit;
      const sortDirection = sortOrder === 'asc' ? 1 : -1;

      // Validate and default sortBy to prevent NoSQL injection
      const validatedSortBy = isAllowedSortField(sortBy) ? sortBy : 'createdAt';

      // Build query
      type QueryType = {
        userId: string;
        $or?: Array<{
          originalText?: { $regex: string; $options: string };
          translatedText?: { $regex: string; $options: string };
          detectedOriginalLanguage?: { $regex: string; $options: string };
          detectedTranslatedLanguage?: { $regex: string; $options: string };
        }>;
      };

      const query: QueryType = { userId };
      if (search) {
        const escapedSearch = escapeRegex(search);
        query.$or = [
          { originalText: { $regex: escapedSearch, $options: 'i' } },
          { translatedText: { $regex: escapedSearch, $options: 'i' } },
          { detectedOriginalLanguage: { $regex: escapedSearch, $options: 'i' } },
          { detectedTranslatedLanguage: { $regex: escapedSearch, $options: 'i' } },
        ];
      }

      const [results, total] = await Promise.all([
        collection
          .find(query)
          .sort({ [validatedSortBy]: sortDirection })
          .skip(skip)
          .limit(limit)
          .toArray(),
        collection.countDocuments(query),
      ]);

      return {
        results: results.map((doc) => formatDocumentToModel({ document: doc as WithId<TranslateCheckResultDocument> })),
        total,
        page,
        totalPages: Math.ceil(total / limit),
      };
    },

    async deleteById({
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
}

import type { GrammarCheckResult, GrammarError } from '@practice/shared';
import type { Db, WithId } from 'mongodb';
import type { GrammarCheckResultDocument } from './grammarCheck.repository.model.ts';
import { ObjectId } from 'mongodb';
import { getGrammarCheckCollection } from './grammarCheck.collection.ts';
import { formatDocumentToModel } from './grammarCheck.repository.model.ts';

// Escape special regex characters to prevent regex injection
function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Whitelist of allowed sort fields to prevent NoSQL injection
const ALLOWED_SORT_FIELDS = ['createdAt', 'detectedLanguage'] as const;
type AllowedSortField = typeof ALLOWED_SORT_FIELDS[number];

function isAllowedSortField(field: string): field is AllowedSortField {
  return ALLOWED_SORT_FIELDS.includes(field as AllowedSortField);
}

export function createGrammarCheckRepository({ db }: { db: Db }) {
  const collection = getGrammarCheckCollection({ db });

  return {
    async saveResult({
      userId,
      originalText,
      correctedText,
      detectedLanguage,
      grammarErrors,
    }: {
      userId: string;
      originalText: string;
      correctedText: string;
      detectedLanguage: string;
      grammarErrors: GrammarError[];
    }): Promise<GrammarCheckResult> {
      const now = new Date();
      const document: GrammarCheckResultDocument = {
        userId,
        originalText,
        correctedText,
        detectedLanguage,
        grammarErrors,
        createdAt: now,
      };

      const result = await collection.insertOne(document);

      return {
        id: result.insertedId.toString(),
        userId,
        originalText,
        correctedText,
        detectedLanguage,
        grammarErrors,
        createdAt: now,
      };
    },

    async findByUserId({
      userId,
      limit = 10,
    }: {
      userId: string;
      limit?: number;
    }): Promise<GrammarCheckResult[]> {
      const results = await collection
        .find({ userId })
        .sort({ createdAt: -1 })
        .limit(limit)
        .toArray();

      return results.map((doc) => formatDocumentToModel({ document: doc as WithId<GrammarCheckResultDocument> }));
    },

    async findById({ id }: { id: string }): Promise<GrammarCheckResult | null> {
      const doc = await collection.findOne({ _id: new ObjectId(id) });

      if (!doc) {
        return null;
      }

      return formatDocumentToModel({ document: doc as WithId<GrammarCheckResultDocument> });
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
    }): Promise<{ results: GrammarCheckResult[]; total: number; page: number; totalPages: number }> {
      const skip = (page - 1) * limit;
      const sortDirection = sortOrder === 'asc' ? 1 : -1;

      // Validate and default sortBy to prevent NoSQL injection
      const validatedSortBy = isAllowedSortField(sortBy) ? sortBy : 'createdAt';

      // Build query
      type QueryType = {
        userId: string;
        $or?: Array<{
          originalText?: { $regex: string; $options: string };
          detectedLanguage?: { $regex: string; $options: string };
        }>;
      };

      const query: QueryType = { userId };
      if (search) {
        const escapedSearch = escapeRegex(search);
        query.$or = [
          { originalText: { $regex: escapedSearch, $options: 'i' } },
          { detectedLanguage: { $regex: escapedSearch, $options: 'i' } },
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
        results: results.map((doc) => formatDocumentToModel({ document: doc as WithId<GrammarCheckResultDocument> })),
        total,
        page,
        totalPages: Math.ceil(total / limit),
      };
    },

    async getAnalytics({ userId }: { userId: string }): Promise<{
      totalChecks: number;
      totalErrors: number;
      errorsByCategory: Record<string, number>;
      errorTrends: Array<{ date: string; count: number }>;
      mostCommonErrors: Array<{ message: string; count: number }>;
      languageDistribution: Record<string, number>;
      recentChecks: GrammarCheckResult[];
    }> {
      // Define types for aggregation results
      type ErrorCategoryResult = { category: string; count: number };
      type ErrorMessageResult = { message: string; count: number };
      type LanguageDistributionResult = { language: string; count: number };
      type ErrorTrendResult = { _id: string; count: number };

      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      const [
        totalChecks,
        totalErrorsResult,
        errorsByCategory,
        mostCommonErrors,
        languageDistribution,
        errorTrendsResult,
        recentChecks,
      ] = await Promise.all([
        collection.countDocuments({ userId }),
        // Calculate total errors using aggregation
        collection.aggregate([
          { $match: { userId } },
          { $project: { errorCount: { $size: { $ifNull: ['$grammarErrors', []] } } } },
          { $group: { _id: null, total: { $sum: '$errorCount' } } },
        ]).toArray(),
        // Error categories
        collection.aggregate([
          { $match: { userId } },
          { $unwind: '$grammarErrors' },
          { $group: { _id: '$grammarErrors.category', count: { $sum: 1 } } },
          { $project: { category: '$_id', count: 1, _id: 0 } },
        ]).toArray(),
        // Most common errors
        collection.aggregate([
          { $match: { userId } },
          { $unwind: '$grammarErrors' },
          { $group: { _id: '$grammarErrors.message', count: { $sum: 1 } } },
          { $sort: { count: -1 } },
          { $limit: 10 },
          { $project: { message: '$_id', count: 1, _id: 0 } },
        ]).toArray(),
        // Language distribution
        collection.aggregate([
          { $match: { userId } },
          { $group: { _id: '$detectedLanguage', count: { $sum: 1 } } },
          { $project: { language: '$_id', count: 1, _id: 0 } },
        ]).toArray(),
        // Error trends (last 7 days) using aggregation
        collection.aggregate([
          { $match: { userId, createdAt: { $gte: sevenDaysAgo } } },
          {
            $project: {
              date: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
              errorCount: { $size: { $ifNull: ['$grammarErrors', []] } },
            },
          },
          { $group: { _id: '$date', count: { $sum: '$errorCount' } } },
          { $sort: { _id: 1 } },
        ]).toArray(),
        // Recent checks
        collection
          .find({ userId })
          .sort({ createdAt: -1 })
          .limit(5)
          .toArray(),
      ]);

      // Extract total errors from aggregation result
      const totalErrors = totalErrorsResult.length > 0 ? (totalErrorsResult[0] as { total: number }).total : 0;

      // Format error trends
      const errorTrends = (errorTrendsResult as ErrorTrendResult[]).map(({ _id, count }) => ({
        date: _id,
        count,
      }));

      // Format error categories
      const errorsByCategoryMap: Record<string, number> = {};
      (errorsByCategory as ErrorCategoryResult[]).forEach((item) => {
        errorsByCategoryMap[item.category] = item.count;
      });

      // Format language distribution
      const languageDistributionMap: Record<string, number> = {};
      (languageDistribution as LanguageDistributionResult[]).forEach((item) => {
        languageDistributionMap[item.language] = item.count;
      });

      return {
        totalChecks,
        totalErrors,
        errorsByCategory: errorsByCategoryMap,
        errorTrends,
        mostCommonErrors: mostCommonErrors as ErrorMessageResult[],
        languageDistribution: languageDistributionMap,
        recentChecks: recentChecks.map((doc) => formatDocumentToModel({ document: doc as WithId<GrammarCheckResultDocument> })),
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

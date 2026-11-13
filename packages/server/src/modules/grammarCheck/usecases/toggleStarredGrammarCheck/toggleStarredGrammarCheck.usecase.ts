import type { createStarredGrammarChecksRepository } from '../../_storage/starredGrammarChecks.repository.ts';

export function createToggleStarredGrammarCheckUsecase({
  starredGrammarChecksRepository,
}: {
  starredGrammarChecksRepository: ReturnType<typeof createStarredGrammarChecksRepository>;
}) {
  return async ({
    userId,
    grammarCheckId,
  }: {
    userId: string;
    grammarCheckId: string;
  }) => {
    const isStarred = await starredGrammarChecksRepository.isGrammarCheckStarred({
      userId,
      grammarCheckId,
    });

    if (isStarred) {
      await starredGrammarChecksRepository.removeStarredGrammarCheck({
        userId,
        grammarCheckId,
      });
      return { starred: false };
    } else {
      try {
        await starredGrammarChecksRepository.addStarredGrammarCheck({
          userId,
          grammarCheckId,
        });
        return { starred: true };
      } catch (error: unknown) {
        // Handle potential race condition where another concurrent request
        // has already added the same (userId, grammarCheckId) pair
        const err = error as { code?: number };
        if (err.code === 11000) {
          // MongoDB duplicate key error - item already starred
          return { starred: true };
        }
        throw error;
      }
    }
  };
}

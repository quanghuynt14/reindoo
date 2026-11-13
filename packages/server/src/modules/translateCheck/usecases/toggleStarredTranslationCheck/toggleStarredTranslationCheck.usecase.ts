import type { createStarredTranslationChecksRepository } from '../../_storage/starredTranslationChecks.repository.ts';

export function createToggleStarredTranslationCheckUsecase({
  starredTranslationChecksRepository,
}: {
  starredTranslationChecksRepository: ReturnType<typeof createStarredTranslationChecksRepository>;
}) {
  return async ({
    userId,
    translationCheckId,
  }: {
    userId: string;
    translationCheckId: string;
  }) => {
    const isStarred = await starredTranslationChecksRepository.isTranslationCheckStarred({
      userId,
      translationCheckId,
    });

    if (isStarred) {
      await starredTranslationChecksRepository.removeStarredTranslationCheck({
        userId,
        translationCheckId,
      });
      return { starred: false };
    } else {
      try {
        await starredTranslationChecksRepository.addStarredTranslationCheck({
          userId,
          translationCheckId,
        });
        return { starred: true };
      } catch (error: unknown) {
        // Handle potential race condition where another concurrent request
        // has already added the same (userId, translationCheckId) pair
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

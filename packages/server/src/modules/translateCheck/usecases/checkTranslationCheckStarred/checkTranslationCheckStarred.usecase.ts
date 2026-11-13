import type { createStarredTranslationChecksRepository } from '../../_storage/starredTranslationChecks.repository.ts';

export function createCheckTranslationCheckStarredUsecase({
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
  }): Promise<{ starred: boolean }> => {
    const isStarred = await starredTranslationChecksRepository.isTranslationCheckStarred({
      userId,
      translationCheckId,
    });

    return { starred: isStarred };
  };
}

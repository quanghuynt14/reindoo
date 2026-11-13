import type { TranslateCheckResult } from '@practice/shared';
import type { createStarredTranslationChecksRepository } from '../../_storage/starredTranslationChecks.repository.ts';
import type { createTranslateCheckRepository } from '../../_storage/translateCheck.repository.ts';

export type StarredTranslationCheckWithDetails = {
  userId: string;
  translationCheck: TranslateCheckResult;
  starredAt: Date;
};

export function createGetStarredTranslationChecksUsecase({
  starredTranslationChecksRepository,
  translateCheckRepository,
}: {
  starredTranslationChecksRepository: ReturnType<typeof createStarredTranslationChecksRepository>;
  translateCheckRepository: ReturnType<typeof createTranslateCheckRepository>;
}) {
  return async ({
    userId,
  }: {
    userId: string;
  }): Promise<StarredTranslationCheckWithDetails[]> => {
    const starredTranslationChecks = await starredTranslationChecksRepository.getUserStarredTranslationChecks({
      userId,
    });

    // Populate translation check details for each starred item in parallel
    const starredTranslationChecksWithDetails = await Promise.all(
      starredTranslationChecks.map(async (starredTranslationCheck) => {
        const translationCheck = await translateCheckRepository.findById({
          id: starredTranslationCheck.translationCheckId,
        });

        if (!translationCheck) {
          throw new Error(`Translation check with id ${starredTranslationCheck.translationCheckId} not found`);
        }

        return {
          userId: starredTranslationCheck.userId,
          translationCheck,
          starredAt: starredTranslationCheck.starredAt,
        } as StarredTranslationCheckWithDetails;
      }),
    );

    return starredTranslationChecksWithDetails;
  };
}

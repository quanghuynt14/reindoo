import type { GrammarCheckResult } from '@practice/shared';
import type { createGrammarCheckRepository } from '../../_storage/grammarCheck.repository.ts';
import type { createStarredGrammarChecksRepository } from '../../_storage/starredGrammarChecks.repository.ts';

export type StarredGrammarCheckWithDetails = {
  userId: string;
  grammarCheck: GrammarCheckResult;
  starredAt: Date;
};

export function createGetStarredGrammarChecksUsecase({
  starredGrammarChecksRepository,
  grammarCheckRepository,
}: {
  starredGrammarChecksRepository: ReturnType<typeof createStarredGrammarChecksRepository>;
  grammarCheckRepository: ReturnType<typeof createGrammarCheckRepository>;
}) {
  return async ({
    userId,
  }: {
    userId: string;
  }): Promise<StarredGrammarCheckWithDetails[]> => {
    const starredGrammarChecks = await starredGrammarChecksRepository.getUserStarredGrammarChecks({
      userId,
    });

    // Populate grammar check details for each starred item in parallel
    const starredGrammarChecksWithDetails = await Promise.all(
      starredGrammarChecks.map(async (starredGrammarCheck) => {
        const grammarCheck = await grammarCheckRepository.findById({
          id: starredGrammarCheck.grammarCheckId,
        });

        if (!grammarCheck) {
          throw new Error(`Grammar check with id ${starredGrammarCheck.grammarCheckId} not found`);
        }

        return {
          userId: starredGrammarCheck.userId,
          grammarCheck,
          starredAt: starredGrammarCheck.starredAt,
        } as StarredGrammarCheckWithDetails;
      }),
    );

    return starredGrammarChecksWithDetails;
  };
}

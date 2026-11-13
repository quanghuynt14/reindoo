import type { createStarredGrammarChecksRepository } from '../../_storage/starredGrammarChecks.repository.ts';

export function createCheckGrammarCheckStarredUsecase({
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
  }): Promise<{ starred: boolean }> => {
    const isStarred = await starredGrammarChecksRepository.isGrammarCheckStarred({
      userId,
      grammarCheckId,
    });

    return { starred: isStarred };
  };
}

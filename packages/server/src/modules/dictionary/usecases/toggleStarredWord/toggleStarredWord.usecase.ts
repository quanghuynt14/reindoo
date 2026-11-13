import type { createStarredWordsRepository } from '../../_storage/starredWords.repository.ts';

export function createToggleStarredWordUsecase({
  starredWordsRepository,
}: {
  starredWordsRepository: ReturnType<typeof createStarredWordsRepository>;
}) {
  return async ({
    userId,
    wordId,
  }: {
    userId: string;
    wordId: string;
  }) => {
    const isStarred = await starredWordsRepository.isWordStarred({
      userId,
      wordId,
    });

    if (isStarred) {
      await starredWordsRepository.removeStarredWord({
        userId,
        wordId,
      });
      return { starred: false };
    } else {
      await starredWordsRepository.addStarredWord({
        userId,
        wordId,
      });
      return { starred: true };
    }
  };
}

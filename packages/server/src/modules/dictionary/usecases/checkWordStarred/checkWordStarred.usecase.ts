import type { createStarredWordsRepository } from '../../_storage/starredWords.repository.ts';

export function createCheckWordStarredUsecase({
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

    return { starred: isStarred };
  };
}

import type { createDictionaryRepository } from '../../_storage/dictionary.repository.ts';
import type { createStarredWordsRepository } from '../../_storage/starredWords.repository.ts';
import type { StarredWordWithDetails } from '../../dictionary.types.ts';

export function createGetStarredWordsUsecase({
  starredWordsRepository,
  dictionaryRepository,
}: {
  starredWordsRepository: ReturnType<typeof createStarredWordsRepository>;
  dictionaryRepository: ReturnType<typeof createDictionaryRepository>;
}) {
  return async ({
    userId,
  }: {
    userId: string;
  }): Promise<StarredWordWithDetails[]> => {
    const starredWords = await starredWordsRepository.getUserStarredWords({ userId });

    // Populate word details for each starred word
    const starredWordsWithDetails = await Promise.all(
      starredWords.map(async (starredWord) => {
        const word = await dictionaryRepository.getWordById({ wordId: starredWord.wordId });

        // Une référence qui ne résout plus n'est pas une panne du serveur.
        // Recharger le lexique réattribue les `_id` de `dictionary`, et
        // l'historique garde les anciens : au premier rechargement, cette
        // ligne renvoyait 500 et emportait la page entière — des centaines
        // d'entrées valides invisibles à cause d'une seule morte.
        //
        // On saute. `repairReferences.ts` les compte et les enlève.
        if (!word) {
          return null;
        }

        return {
          userId: starredWord.userId,
          word,
          starredAt: starredWord.starredAt,
        } as StarredWordWithDetails;
      }),
    );

    return starredWordsWithDetails.filter((item) => item !== null);
  };
}

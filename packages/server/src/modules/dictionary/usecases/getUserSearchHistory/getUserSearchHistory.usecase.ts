import type { createDictionaryRepository } from '../../_storage/dictionary.repository.ts';
import type { createSearchHistoryRepository } from '../../_storage/searchHistory.repository.ts';
import type { SearchHistoryWithDetails } from '../../dictionary.types.ts';

export function createGetUserSearchHistoryUsecase({
  searchHistoryRepository,
  dictionaryRepository,
}: {
  searchHistoryRepository: ReturnType<typeof createSearchHistoryRepository>;
  dictionaryRepository: ReturnType<typeof createDictionaryRepository>;
}) {
  return async ({
    userId,
    skip,
    limit,
  }: {
    userId: string;
    skip?: number;
    limit?: number;
  }): Promise<SearchHistoryWithDetails[]> => {
    const searchHistory = await searchHistoryRepository.getUserSearchHistory({
      userId,
      ...(skip !== undefined && { skip }),
      ...(limit !== undefined && { limit }),
    });

    // Populate word details for each search history item
    const searchHistoryWithDetails = await Promise.all(
      searchHistory.map(async (history) => {
        const word = await dictionaryRepository.getWordById({ wordId: history.wordId });

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
          id: history.id,
          userId: history.userId,
          word,
          searchedAt: history.searchedAt,
        } as SearchHistoryWithDetails;
      }),
    );

    return searchHistoryWithDetails.filter((item) => item !== null);
  };
}

import type { Db } from 'mongodb';
import type { SearchHistoryWithDetails } from '../dictionary/dictionary.types.ts';
import { createDictionaryRepository } from '../dictionary/_storage/dictionary.repository.ts';
import { createSearchHistoryRepository } from '../dictionary/_storage/searchHistory.repository.ts';

export function reelsProvider({ db }: { db: Db }) {
  const searchHistoryRepository = createSearchHistoryRepository({ db });
  const dictionaryRepository = createDictionaryRepository({ db });
  type ReelSort = 'newest' | 'oldest' | 'random';

  return {
    async getReels({
      userId,
      page = 1,
      limit = 10,
      sourceLanguage,
      targetLanguage,
      sort = 'random',
    }: {
      userId: string;
      page?: number;
      limit?: number;
      sourceLanguage?: string;
      targetLanguage?: string;
      sort?: ReelSort;
    }) {
      // Calculate skip for pagination
      const skip = (page - 1) * limit;

      // Fetch dictionary search history
      const dictionaryHistory = await searchHistoryRepository.getUserSearchHistory({ userId });

      // Populate word details for dictionary history using a bulk fetch to avoid N+1 queries
      const wordIds = dictionaryHistory.map((history) => history.wordId);
      const uniqueWordIds = Array.from(new Set(wordIds));

      const words = await dictionaryRepository.getWordsByIds({ wordIds: uniqueWordIds });
      const wordById = new Map<string, NonNullable<typeof words[number]>>();
      for (let i = 0; i < words.length; i++) {
        const word = words[i];
        const wordId = uniqueWordIds[i];
        if (word && wordId) {
          wordById.set(wordId, word);
        }
      }

      const dictionaryHistoryWithDetails: SearchHistoryWithDetails[] = dictionaryHistory.flatMap((history) => {
        const word = wordById.get(history.wordId);

        // Une référence qui ne résout plus n'est pas une panne du serveur.
        // Recharger le lexique réattribue les `_id` de `dictionary`, et
        // l'historique garde les anciens : au premier rechargement, cette
        // ligne renvoyait 500 et emportait la page entière — des centaines
        // d'entrées valides invisibles à cause d'une seule morte.
        //
        // On saute. `repairReferences.ts` les compte et les enlève.
        if (!word) {
          return [];
        }

        return {
          id: history.id,
          userId: history.userId,
          word,
          searchedAt: history.searchedAt,
        } as SearchHistoryWithDetails;
      });

      // Filter by language if specified
      // When both filters are set to the SAME language, use OR logic (match either position)
      // When both filters are set to DIFFERENT languages, use AND logic (exact pair match)
      let filteredHistory = dictionaryHistoryWithDetails;
      if (sourceLanguage || targetLanguage) {
        filteredHistory = dictionaryHistoryWithDetails.filter((item) => {
          if (sourceLanguage && targetLanguage) {
            // Both filters set: use OR if same language, AND if different
            if (sourceLanguage === targetLanguage) {
              // Same language in both filters: match if language appears in either position
              return item.word.sourceLanguage === sourceLanguage || item.word.targetLanguage === targetLanguage;
            } else {
              // Different languages: exact pair match (source AND target must match)
              return item.word.sourceLanguage === sourceLanguage && item.word.targetLanguage === targetLanguage;
            }
          } else if (sourceLanguage) {
            // Only source filter set
            return item.word.sourceLanguage === sourceLanguage;
          } else {
            // Only target filter set
            return item.word.targetLanguage === targetLanguage;
          }
        });
      }

      // Transform into reel items (dictionary only)
      const reelItems = filteredHistory.map((item: SearchHistoryWithDetails) => ({
        type: 'dictionary' as const,
        data: {
          ...item,
          searchedAt: item.searchedAt instanceof Date ? item.searchedAt.toISOString() : item.searchedAt,
        },
        createdAt: item.searchedAt,
      }));

      if (sort === 'newest') {
        reelItems.sort(
          (a, b) => new Date(b.data.searchedAt).getTime() - new Date(a.data.searchedAt).getTime(),
        );
      } else if (sort === 'oldest') {
        reelItems.sort(
          (a, b) => new Date(a.data.searchedAt).getTime() - new Date(b.data.searchedAt).getTime(),
        );
      } else {
        // Fisher-Yates shuffle algorithm for unbiased randomization.
        for (let i = reelItems.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          const temp = reelItems[i];
          reelItems[i] = reelItems[j]!;
          reelItems[j] = temp!;
        }
      }

      if (sort === 'random') {
        // Infinite scrolling for random mode by cycling through the shuffled items.
        const paginatedItems: typeof reelItems = [];

        if (reelItems.length > 0) {
          for (let i = 0; i < limit; i++) {
            const index = (skip + i) % reelItems.length;
            if (reelItems[index]) {
              paginatedItems.push(reelItems[index]!);
            }
          }
        }

        const hasMore = reelItems.length > 0;
        const nextPage = hasMore ? page + 1 : null;

        return {
          items: paginatedItems,
          nextPage,
          hasMore,
        };
      }

      const paginatedItems = reelItems.slice(skip, skip + limit);
      const hasMore = skip + limit < reelItems.length;
      const nextPage = hasMore ? page + 1 : null;

      return {
        items: paginatedItems,
        nextPage,
        hasMore,
      };
    },
  };
}

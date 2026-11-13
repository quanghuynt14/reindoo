import type { Db } from 'mongodb';
import { createDictionaryRepository } from './_storage/dictionary.repository.ts';
import { createSearchHistoryRepository } from './_storage/searchHistory.repository.ts';
import { createStarredWordsRepository } from './_storage/starredWords.repository.ts';
import { createCheckWordStarredUsecase } from './usecases/checkWordStarred/checkWordStarred.usecase.ts';
import { createGetStarredWordsUsecase } from './usecases/getStarredWords/getStarredWords.usecase.ts';
import { createGetUserSearchHistoryUsecase } from './usecases/getUserSearchHistory/getUserSearchHistory.usecase.ts';
import { createSearchWordUsecase } from './usecases/searchWord/searchWord.usecase.ts';
import { createToggleStarredWordUsecase } from './usecases/toggleStarredWord/toggleStarredWord.usecase.ts';

export function dictionaryProvider({ db }: { db: Db }) {
  const dictionaryRepository = createDictionaryRepository({ db });
  const searchHistoryRepository = createSearchHistoryRepository({ db });
  const starredWordsRepository = createStarredWordsRepository({ db });

  const searchWord = createSearchWordUsecase({
    dictionaryRepository,
    searchHistoryRepository,
  });

  const getUserSearchHistory = createGetUserSearchHistoryUsecase({
    searchHistoryRepository,
    dictionaryRepository,
  });

  const toggleStarredWord = createToggleStarredWordUsecase({
    starredWordsRepository,
  });

  const getStarredWords = createGetStarredWordsUsecase({
    starredWordsRepository,
    dictionaryRepository,
  });

  const checkWordStarred = createCheckWordStarredUsecase({
    starredWordsRepository,
  });

  const deleteSearchHistory = async ({
    id,
    userId,
  }: {
    id: string;
    userId: string;
  }) => {
    return searchHistoryRepository.deleteSearchHistory({ id, userId });
  };

  return {
    searchWord,
    getUserSearchHistory,
    toggleStarredWord,
    getStarredWords,
    checkWordStarred,
    deleteSearchHistory,
  };
}

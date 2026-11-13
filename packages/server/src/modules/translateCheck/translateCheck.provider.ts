import type { Db } from 'mongodb';
import { createStarredTranslationChecksRepository } from './_storage/starredTranslationChecks.repository.ts';
import { createTranslateCheckRepository } from './_storage/translateCheck.repository.ts';
import { createCheckTranslationUsecase } from './usecases/checkTranslation/checkTranslation.usecase.ts';
import { createCheckTranslationCheckStarredUsecase } from './usecases/checkTranslationCheckStarred/checkTranslationCheckStarred.usecase.ts';
import { createGetAnalysisUsecase } from './usecases/getAnalysis/getAnalysis.usecase.ts';
import { createGetStarredTranslationChecksUsecase } from './usecases/getStarredTranslationChecks/getStarredTranslationChecks.usecase.ts';
import { createToggleStarredTranslationCheckUsecase } from './usecases/toggleStarredTranslationCheck/toggleStarredTranslationCheck.usecase.ts';

export function translateCheckProvider({ db }: { db: Db }) {
  const translateCheckRepository = createTranslateCheckRepository({ db });
  const starredTranslationChecksRepository = createStarredTranslationChecksRepository({ db });

  const toggleStarredTranslationCheck = createToggleStarredTranslationCheckUsecase({
    starredTranslationChecksRepository,
  });

  const getStarredTranslationChecks = createGetStarredTranslationChecksUsecase({
    starredTranslationChecksRepository,
    translateCheckRepository,
  });

  const checkTranslationCheckStarred = createCheckTranslationCheckStarredUsecase({
    starredTranslationChecksRepository,
  });

  return {
    checkTranslation: createCheckTranslationUsecase({ translateCheckRepository }),
    toggleStarredTranslationCheck,
    getStarredTranslationChecks,
    checkTranslationCheckStarred,
    getHistory: async ({
      userId,
      page,
      limit,
      sortBy,
      sortOrder,
      search,
    }: {
      userId: string;
      page?: number | undefined;
      limit?: number | undefined;
      sortBy?: string | undefined;
      sortOrder?: 'asc' | 'desc' | undefined;
      search?: string | undefined;
    }) => {
      return translateCheckRepository.getHistory({ userId, page, limit, sortBy, sortOrder, search });
    },
    getAnalysis: createGetAnalysisUsecase({ translateCheckRepository }),
    deleteHistory: async ({
      id,
      userId,
    }: {
      id: string;
      userId: string;
    }) => {
      return translateCheckRepository.deleteById({ id, userId });
    },
  };
}

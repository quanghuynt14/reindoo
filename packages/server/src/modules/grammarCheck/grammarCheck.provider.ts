import type { Db } from 'mongodb';
import { createGrammarCheckRepository } from './_storage/grammarCheck.repository.ts';
import { createStarredGrammarChecksRepository } from './_storage/starredGrammarChecks.repository.ts';
import { createCheckGrammarUsecase } from './usecases/checkGrammar/checkGrammar.usecase.ts';
import { createCheckGrammarCheckStarredUsecase } from './usecases/checkGrammarCheckStarred/checkGrammarCheckStarred.usecase.ts';
import { createGetAnalysisUsecase } from './usecases/getAnalysis/getAnalysis.usecase.ts';
import { createGetStarredGrammarChecksUsecase } from './usecases/getStarredGrammarChecks/getStarredGrammarChecks.usecase.ts';
import { createToggleStarredGrammarCheckUsecase } from './usecases/toggleStarredGrammarCheck/toggleStarredGrammarCheck.usecase.ts';

export function grammarCheckProvider({ db }: { db: Db }) {
  const grammarCheckRepository = createGrammarCheckRepository({ db });
  const starredGrammarChecksRepository = createStarredGrammarChecksRepository({ db });

  const toggleStarredGrammarCheck = createToggleStarredGrammarCheckUsecase({
    starredGrammarChecksRepository,
  });

  const getStarredGrammarChecks = createGetStarredGrammarChecksUsecase({
    starredGrammarChecksRepository,
    grammarCheckRepository,
  });

  const checkGrammarCheckStarred = createCheckGrammarCheckStarredUsecase({
    starredGrammarChecksRepository,
  });

  return {
    checkGrammar: createCheckGrammarUsecase({ grammarCheckRepository }),
    toggleStarredGrammarCheck,
    getStarredGrammarChecks,
    checkGrammarCheckStarred,
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
      return grammarCheckRepository.getHistory({ userId, page, limit, sortBy, sortOrder, search });
    },
    getAnalytics: async ({ userId }: { userId: string }) => {
      return grammarCheckRepository.getAnalytics({ userId });
    },
    getAnalysis: createGetAnalysisUsecase({ grammarCheckRepository }),
    deleteHistory: async ({
      id,
      userId,
    }: {
      id: string;
      userId: string;
    }) => {
      return grammarCheckRepository.deleteById({ id, userId });
    },
  };
}

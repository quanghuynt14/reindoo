import type { Db } from 'mongodb';
import { createDictionaryRepository } from '../dictionary/_storage/dictionary.repository.ts';
import { createSearchHistoryRepository } from '../dictionary/_storage/searchHistory.repository.ts';
import { createGrammarCheckRepository } from '../grammarCheck/_storage/grammarCheck.repository.ts';
import { createTranslateCheckRepository } from '../translateCheck/_storage/translateCheck.repository.ts';
import { createGameSessionRepository } from './_storage/gameSession.repository.ts';
import { createGameStatsRepository } from './_storage/gameStats.repository.ts';
import { createGenerateDictionaryQuestionsUsecase } from './usecases/generateDictionaryQuestions.usecase.ts';
import { createGenerateGrammarQuestionsUsecase } from './usecases/generateGrammarQuestions.usecase.ts';
import { createGenerateQuestionsUsecase } from './usecases/generateQuestions.usecase.ts';
import { createGenerateTranslationQuestionsUsecase } from './usecases/generateTranslationQuestions.usecase.ts';
import { createUpdateGameStatsUsecase } from './usecases/updateGameStats.usecase.ts';

export function gameProvider({ db }: { db: Db }) {
  const gameSessionRepository = createGameSessionRepository({ db });
  const gameStatsRepository = createGameStatsRepository({ db });
  const dictionaryRepository = createDictionaryRepository({ db });
  const searchHistoryRepository = createSearchHistoryRepository({ db });
  const grammarCheckRepository = createGrammarCheckRepository({ db });
  const translateCheckRepository = createTranslateCheckRepository({ db });

  const generateDictionaryQuestions = createGenerateDictionaryQuestionsUsecase({
    dictionaryRepository,
    searchHistoryRepository,
  });

  const generateGrammarQuestions = createGenerateGrammarQuestionsUsecase({
    grammarCheckRepository,
  });

  const generateTranslationQuestions = createGenerateTranslationQuestionsUsecase({
    translateCheckRepository,
  });

  const generateQuestions = createGenerateQuestionsUsecase({
    generateDictionaryQuestions,
    generateGrammarQuestions,
    generateTranslationQuestions,
  });

  const updateGameStats = createUpdateGameStatsUsecase({
    gameStatsRepository,
  });

  return {
    gameSessionRepository,
    gameStatsRepository,
    generateQuestions,
    updateGameStats,
  };
}

import type { DICTIONARY_SOURCE_LANGUAGES, LANGUAGE } from './constants.ts';

export type Language = typeof LANGUAGE[keyof typeof LANGUAGE];

export type DictionarySourceLanguage = typeof DICTIONARY_SOURCE_LANGUAGES[number];

export type Word = {
  id: string;
  word: string;
  sourceLanguage: Language;
  targetLanguage: Language;
  translated: string;
  explains: {
    explain: string;
    synonyms: string[];
    antonyms: string[];
    exampleSentences: {
      sourceSentence: string;
      targetTranslation: string;
    }[];
  }[];

  // Ce que le lexique compilé apporte, et que la génération n'avait pas.
  // Tous optionnels : les documents écrits avant la bascule ne les portent pas,
  // et l'historique en garde.
  ipa?: string[];
  audio?: string;
  /** L'article du Wiktionnaire d'où sort l'entrée — pour vérifier une glose. */
  wiki?: string;
  derived?: string[];
  /** La forme tapée, quand elle n'est pas la vedette : « allions » pour aller. */
  matchedForm?: string;
  /** Les autres vedettes que cette forme atteint : « allions » est aussi allier. */
  alsoFrom?: string[];
};

export type GrammarError = {
  message: string;
  category: string;
  position: {
    start: number;
    end: number;
  };
  suggestion: string;
};

export type GrammarCheckResult = {
  id: string;
  userId: string;
  originalText: string;
  correctedText: string;
  detectedLanguage: string;
  grammarErrors: GrammarError[];
  createdAt: Date;
};

export type TranslationError = {
  message: string;
  positions: {
    // Arrays of character indices where the error occurs in each text
    // Can be empty arrays if error doesn't apply to that text
    // Example: [15, 20] for a character range, or [15] for a single position
    original: number[];
    translated: number[];
  };
};

export type TranslateCheckResult = {
  id: string;
  userId: string;
  originalText: string;
  translatedText: string;
  detectedOriginalLanguage: string;
  detectedTranslatedLanguage: string;
  translationErrors: TranslationError[];
  correctedTranslation: string;
  createdAt: Date;
};

// Game Types
export type GameCategory = 'dictionary' | 'grammar' | 'translation';

export type GameQuestionType
  // Dictionary
  = | 'word-to-translation'
    | 'translation-to-word'
    | 'synonym-match'
    | 'antonym-match'
    | 'fill-blank'
    | 'definition-match'
  // Grammar
    | 'true-false'
    | 'correct-sentence'
    | 'error-category'
    | 'suggest-correction'
    | 'count-errors'
  // Translation
    | 'choose-correct-translation'
    | 'translation-true-false'
    | 'detect-original-language'
    | 'detect-translated-language'
    | 'count-translation-errors'
    | 'match-translation';

export type GameQuestion = {
  id: string;
  category: GameCategory;
  type: GameQuestionType;
  sourceId: string;
  question: string;
  context?: string;
  hint?: string;
  options: string[];
  correctAnswerIndex: number;
};

export type GameSession = {
  id: string;
  userId: string;
  categories: GameCategory[];
  questions: GameQuestion[];
  answers: {
    questionId: string;
    selectedIndex: number;
    correct: boolean;
    answeredAt: Date;
  }[];
  score: number;
  totalQuestions: number;
  startedAt: Date;
  completedAt?: Date;
};

export type GameStats = {
  userId: string;
  totalGamesPlayed: number;
  totalQuestionsAnswered: number;
  correctAnswers: number;
  byCategory: {
    dictionary: { total: number; correct: number };
    grammar: { total: number; correct: number };
    translation: { total: number; correct: number };
  };
  lastPlayedAt?: Date;
};

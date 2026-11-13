import type { GameQuestion, GameQuestionType, Word } from '@practice/shared';
import { MIN_ITEMS_FOR_QUESTIONS, WRONG_OPTIONS_COUNT } from '../game.constants.ts';
import { generateId, shuffleArray } from '../game.utils.ts';

type DictionaryRepository = {
  getWordById: ({ wordId }: { wordId: string }) => Promise<Word | undefined>;
};

type SearchHistoryRepository = {
  getUserSearchHistory: ({ userId }: { userId: string }) => Promise<Array<{ wordId: string; searchedAt: Date }>>;
};

export function createGenerateDictionaryQuestionsUsecase({
  dictionaryRepository,
  searchHistoryRepository,
}: {
  dictionaryRepository: DictionaryRepository;
  searchHistoryRepository: SearchHistoryRepository;
}) {
  return async function generateDictionaryQuestions({
    userId,
    count,
  }: {
    userId: string;
    count: number;
  }): Promise<GameQuestion[]> {
    // Fetch user's search history
    const history = await searchHistoryRepository.getUserSearchHistory({ userId });

    if (history.length < MIN_ITEMS_FOR_QUESTIONS) {
      return []; // Need at least MIN_ITEMS_FOR_QUESTIONS items for multiple choice
    }

    // Fetch all words from history
    const words = await Promise.all(
      history.map(async (h) => {
        const word = await dictionaryRepository.getWordById({ wordId: h.wordId });
        return word;
      }),
    );

    // Filter out null and undefined values
    const validWords = words.filter((w): w is Word => w !== null && w !== undefined);

    if (validWords.length < MIN_ITEMS_FOR_QUESTIONS) {
      return [];
    }

    const questions: GameQuestion[] = [];
    // Question types available for dictionary questions
    // NOTE: This array must be kept in sync with GameQuestionType union type
    const questionTypes: GameQuestionType[] = [
      'word-to-translation',
      'translation-to-word',
      'synonym-match',
      'antonym-match',
      'fill-blank',
      'definition-match',
    ];

    // Shuffle question types and words
    const shuffledTypes = shuffleArray(questionTypes);
    const shuffledWords = shuffleArray(validWords);

    let questionCount = 0;
    let typeIndex = 0;
    let wordIndex = 0;

    while (questionCount < count && wordIndex < shuffledWords.length) {
      const word = shuffledWords[wordIndex];

      if (word) {
        const questionType = shuffledTypes[typeIndex % shuffledTypes.length];
        if (questionType) {
          const question = generateQuestionForType(questionType, word, validWords);

          if (question) {
            questions.push(question);
            questionCount++;
          }
        }
      }

      wordIndex++;
      typeIndex++;
    }

    return questions;
  };
}

function generateQuestionForType(
  type: GameQuestionType,
  word: Word,
  allWords: Word[],
): GameQuestion | null {
  const otherWords = allWords.filter((w) => w.id !== word.id);

  switch (type) {
    case 'word-to-translation': {
      const wrongOptions = shuffleArray(otherWords)
        .filter((w) => w.targetLanguage === word.targetLanguage)
        .slice(0, WRONG_OPTIONS_COUNT)
        .map((w) => w.translated);

      if (wrongOptions.length < WRONG_OPTIONS_COUNT) {
        return null;
      }

      const options = shuffleArray([word.translated, ...wrongOptions]);
      return {
        id: generateId(),
        category: 'dictionary',
        type,
        sourceId: word.id,
        question: `"${word.word}" nghĩa là gì?`,
        options,
        correctAnswerIndex: options.indexOf(word.translated),
      };
    }

    case 'translation-to-word': {
      const wrongOptions = shuffleArray(otherWords)
        .filter((w) => w.sourceLanguage === word.sourceLanguage)
        .slice(0, WRONG_OPTIONS_COUNT)
        .map((w) => w.word);

      if (wrongOptions.length < WRONG_OPTIONS_COUNT) {
        return null;
      }

      const options = shuffleArray([word.word, ...wrongOptions]);
      return {
        id: generateId(),
        category: 'dictionary',
        type,
        sourceId: word.id,
        question: `Từ nào có nghĩa là "${word.translated}"?`,
        options,
        correctAnswerIndex: options.indexOf(word.word),
      };
    }

    case 'synonym-match': {
      const allSynonyms = word.explains.flatMap((e) => e.synonyms);
      if (allSynonyms.length === 0) {
        return null;
      }

      const correctSynonym = shuffleArray(allSynonyms)[0];
      if (!correctSynonym) {
        return null;
      }

      const wrongOptions = shuffleArray(otherWords)
        .slice(0, WRONG_OPTIONS_COUNT)
        .map((w) => w.word);

      if (wrongOptions.length < WRONG_OPTIONS_COUNT) {
        return null;
      }

      const options = shuffleArray([correctSynonym, ...wrongOptions]);
      return {
        id: generateId(),
        category: 'dictionary',
        type,
        sourceId: word.id,
        question: `Từ nào đồng nghĩa với "${word.word}"?`,
        options,
        correctAnswerIndex: options.indexOf(correctSynonym),
      };
    }

    case 'antonym-match': {
      const allAntonyms = word.explains.flatMap((e) => e.antonyms);
      if (allAntonyms.length === 0) {
        return null;
      }

      const correctAntonym = shuffleArray(allAntonyms)[0];
      if (!correctAntonym) {
        return null;
      }

      const wrongOptions = shuffleArray(otherWords)
        .slice(0, WRONG_OPTIONS_COUNT)
        .map((w) => w.word);

      if (wrongOptions.length < WRONG_OPTIONS_COUNT) {
        return null;
      }

      const options = shuffleArray([correctAntonym, ...wrongOptions]);
      return {
        id: generateId(),
        category: 'dictionary',
        type,
        sourceId: word.id,
        question: `Từ nào trái nghĩa với "${word.word}"?`,
        options,
        correctAnswerIndex: options.indexOf(correctAntonym),
      };
    }

    case 'fill-blank': {
      const exampleSentences = word.explains.flatMap((e) => e.exampleSentences);
      if (exampleSentences.length === 0) {
        return null;
      }

      const example = shuffleArray(exampleSentences)[0];
      if (!example) {
        return null;
      }

      const sentenceWithBlank = example.sourceSentence.replace(
        // Use a more flexible pattern that works with non-ASCII characters
        new RegExp(word.word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi'),
        '____',
      );

      if (sentenceWithBlank === example.sourceSentence) {
        return null;
      }

      const wrongOptions = shuffleArray(otherWords)
        .slice(0, WRONG_OPTIONS_COUNT)
        .map((w) => w.word);

      if (wrongOptions.length < WRONG_OPTIONS_COUNT) {
        return null;
      }

      const options = shuffleArray([word.word, ...wrongOptions]);
      return {
        id: generateId(),
        category: 'dictionary',
        type,
        sourceId: word.id,
        question: `Điền vào chỗ trống: ${sentenceWithBlank}`,
        options,
        correctAnswerIndex: options.indexOf(word.word),
      };
    }

    case 'definition-match': {
      if (word.explains.length === 0) {
        return null;
      }

      const firstExplain = word.explains[0];
      if (!firstExplain) {
        return null;
      }

      const correctDefinition = firstExplain.explain;
      const wrongOptions = shuffleArray(otherWords)
        .filter((w) => w.explains.length > 0)
        .slice(0, WRONG_OPTIONS_COUNT)
        .map((w) => w.explains[0]?.explain)
        .filter((e): e is string => e !== undefined);

      if (wrongOptions.length < WRONG_OPTIONS_COUNT) {
        return null;
      }

      const options = shuffleArray([correctDefinition, ...wrongOptions]);
      return {
        id: generateId(),
        category: 'dictionary',
        type,
        sourceId: word.id,
        question: `"${word.word}" được định nghĩa thế nào?`,
        options,
        correctAnswerIndex: options.indexOf(correctDefinition),
      };
    }

    default:
      return null;
  }
}

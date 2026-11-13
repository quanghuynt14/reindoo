import type { GameQuestion, GameQuestionType, TranslateCheckResult } from '@practice/shared';
import { MAX_HISTORY_LIMIT, MIN_ITEMS_FOR_QUESTIONS, WRONG_OPTIONS_COUNT } from '../game.constants.ts';
import { formatLanguage, generateId, shuffleArray } from '../game.utils.ts';

type TranslateCheckRepository = {
  findByUserId: ({ userId, limit }: { userId: string; limit?: number }) => Promise<TranslateCheckResult[]>;
};

export function createGenerateTranslationQuestionsUsecase({
  translateCheckRepository,
}: {
  translateCheckRepository: TranslateCheckRepository;
}) {
  return async function generateTranslationQuestions({
    userId,
    count,
  }: {
    userId: string;
    count: number;
  }): Promise<GameQuestion[]> {
    // Fetch user's translation check history
    const history = await translateCheckRepository.findByUserId({ userId, limit: MAX_HISTORY_LIMIT });

    if (history.length < MIN_ITEMS_FOR_QUESTIONS) {
      return []; // Need at least MIN_ITEMS_FOR_QUESTIONS items for multiple choice
    }

    const questions: GameQuestion[] = [];
    // Question types available for translation questions
    // NOTE: This array must be kept in sync with GameQuestionType union type
    const questionTypes: GameQuestionType[] = [
      'choose-correct-translation',
      'translation-true-false',
      'detect-original-language',
      'detect-translated-language',
      'count-translation-errors',
      'match-translation',
    ];

    // Shuffle question types and history
    const shuffledTypes = shuffleArray(questionTypes);
    const shuffledHistory = shuffleArray(history);

    let questionCount = 0;
    let typeIndex = 0;
    let historyIndex = 0;

    while (questionCount < count && historyIndex < shuffledHistory.length) {
      const item = shuffledHistory[historyIndex];

      if (item) {
        const questionType = shuffledTypes[typeIndex % shuffledTypes.length];
        if (questionType) {
          const question = generateQuestionForType(questionType, item, history);

          if (question) {
            questions.push(question);
            questionCount++;
          }
        }
      }

      historyIndex++;
      typeIndex++;
    }

    return questions;
  };
}

function generateQuestionForType(
  type: GameQuestionType,
  item: TranslateCheckResult,
  allItems: TranslateCheckResult[],
): GameQuestion | null {
  const otherItems = allItems.filter((i) => i.id !== item.id);

  switch (type) {
    case 'choose-correct-translation': {
      const hasErrors = item.translationErrors.length > 0;
      const correctTranslation = hasErrors ? item.correctedTranslation : item.translatedText;

      const wrongOptions = shuffleArray(otherItems)
        .slice(0, WRONG_OPTIONS_COUNT)
        .map((i) => i.translatedText);

      if (wrongOptions.length < WRONG_OPTIONS_COUNT) {
        return null;
      }

      const options = shuffleArray([correctTranslation, ...wrongOptions]);
      return {
        id: generateId(),
        category: 'translation',
        type,
        sourceId: item.id,
        question: 'Bản dịch nào sát nhất?',
        context: item.originalText,
        options,
        correctAnswerIndex: options.indexOf(correctTranslation),
      };
    }

    case 'translation-true-false': {
      const isAccurate = item.translationErrors.length === 0;
      const options = shuffleArray(['Có', 'Không']);
      const correctAnswer = isAccurate ? 'Có' : 'Không';

      return {
        id: generateId(),
        category: 'translation',
        type,
        sourceId: item.id,
        question: 'Bản dịch này có chuẩn không?',
        context: `Original: ${item.originalText}\nTranslation: ${item.translatedText}`,
        options,
        correctAnswerIndex: options.indexOf(correctAnswer),
      };
    }

    case 'detect-original-language': {
      const correctLanguage = formatLanguage(item.detectedOriginalLanguage);

      // Get unique languages from other items
      const otherLanguages = Array.from(
        new Set(
          otherItems
            .map((i) => formatLanguage(i.detectedOriginalLanguage))
            .filter((l) => l !== correctLanguage),
        ),
      );

      if (otherLanguages.length < WRONG_OPTIONS_COUNT) {
        // Add common languages
        const commonLanguages = ['English', 'Vietnamese', 'French', 'Spanish', 'German'];
        otherLanguages.push(
          ...commonLanguages.filter((l) => l !== correctLanguage && !otherLanguages.includes(l)),
        );
      }

      const wrongOptions = shuffleArray(otherLanguages).slice(0, WRONG_OPTIONS_COUNT);
      const options = shuffleArray([correctLanguage, ...wrongOptions]);

      return {
        id: generateId(),
        category: 'translation',
        type,
        sourceId: item.id,
        question: 'Văn bản này viết bằng ngôn ngữ nào?',
        context: item.originalText,
        options,
        correctAnswerIndex: options.indexOf(correctLanguage),
      };
    }

    case 'detect-translated-language': {
      const correctLanguage = formatLanguage(item.detectedTranslatedLanguage);

      // Get unique languages from other items
      const otherLanguages = Array.from(
        new Set(
          otherItems
            .map((i) => formatLanguage(i.detectedTranslatedLanguage))
            .filter((l) => l !== correctLanguage),
        ),
      );

      if (otherLanguages.length < WRONG_OPTIONS_COUNT) {
        // Add common languages
        const commonLanguages = ['English', 'Vietnamese', 'French', 'Spanish', 'German'];
        otherLanguages.push(
          ...commonLanguages.filter((l) => l !== correctLanguage && !otherLanguages.includes(l)),
        );
      }

      const wrongOptions = shuffleArray(otherLanguages).slice(0, WRONG_OPTIONS_COUNT);
      const options = shuffleArray([correctLanguage, ...wrongOptions]);

      return {
        id: generateId(),
        category: 'translation',
        type,
        sourceId: item.id,
        question: 'Bản dịch này là ngôn ngữ nào?',
        context: item.translatedText,
        options,
        correctAnswerIndex: options.indexOf(correctLanguage),
      };
    }

    case 'count-translation-errors': {
      const correctCount = item.translationErrors.length.toString();

      // Generate wrong options around the correct count
      const correctNum = item.translationErrors.length;
      const wrongOptions = [
        Math.max(0, correctNum - 1).toString(),
        (correctNum + 1).toString(),
        (correctNum + 2).toString(),
      ].filter((o) => o !== correctCount);

      const options = shuffleArray([correctCount, ...wrongOptions.slice(0, WRONG_OPTIONS_COUNT)]);

      return {
        id: generateId(),
        category: 'translation',
        type,
        sourceId: item.id,
        question: 'Bản dịch này có bao nhiêu lỗi?',
        context: `Original: ${item.originalText}\nTranslation: ${item.translatedText}`,
        options,
        correctAnswerIndex: options.indexOf(correctCount),
      };
    }

    case 'match-translation': {
      const correctTranslation = item.translatedText;

      const wrongOptions = shuffleArray(otherItems)
        .slice(0, WRONG_OPTIONS_COUNT)
        .map((i) => i.translatedText);

      if (wrongOptions.length < WRONG_OPTIONS_COUNT) {
        return null;
      }

      const options = shuffleArray([correctTranslation, ...wrongOptions]);

      return {
        id: generateId(),
        category: 'translation',
        type,
        sourceId: item.id,
        question: 'Bản dịch nào khớp với văn bản này?',
        context: item.originalText,
        options,
        correctAnswerIndex: options.indexOf(correctTranslation),
      };
    }

    default:
      return null;
  }
}

import type { GameQuestion, GameQuestionType, GrammarCheckResult } from '@practice/shared';
import { MAX_HISTORY_LIMIT, MIN_ITEMS_FOR_QUESTIONS, WRONG_OPTIONS_COUNT } from '../game.constants.ts';
import { formatErrorCategory, generateId, shuffleArray } from '../game.utils.ts';

type GrammarCheckRepository = {
  findByUserId: ({ userId, limit }: { userId: string; limit?: number }) => Promise<GrammarCheckResult[]>;
};

export function createGenerateGrammarQuestionsUsecase({
  grammarCheckRepository,
}: {
  grammarCheckRepository: GrammarCheckRepository;
}) {
  return async function generateGrammarQuestions({
    userId,
    count,
  }: {
    userId: string;
    count: number;
  }): Promise<GameQuestion[]> {
    // Fetch user's grammar check history
    const history = await grammarCheckRepository.findByUserId({ userId, limit: MAX_HISTORY_LIMIT });

    if (history.length < MIN_ITEMS_FOR_QUESTIONS) {
      return []; // Need at least MIN_ITEMS_FOR_QUESTIONS items for multiple choice
    }

    const questions: GameQuestion[] = [];
    // Question types available for grammar questions
    // NOTE: This array must be kept in sync with GameQuestionType union type
    const questionTypes: GameQuestionType[] = [
      'true-false',
      'correct-sentence',
      'error-category',
      'suggest-correction',
      'count-errors',
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
  item: GrammarCheckResult,
  allItems: GrammarCheckResult[],
): GameQuestion | null {
  const otherItems = allItems.filter((i) => i.id !== item.id);

  switch (type) {
    case 'true-false': {
      const hasErrors = item.grammarErrors.length > 0;
      const options = shuffleArray(['Đúng', 'Sai']);
      const correctAnswer = hasErrors ? 'Sai' : 'Đúng';

      return {
        id: generateId(),
        category: 'grammar',
        type,
        sourceId: item.id,
        question: 'Câu này có đúng ngữ pháp không?',
        context: item.originalText,
        options,
        correctAnswerIndex: options.indexOf(correctAnswer),
      };
    }

    case 'correct-sentence': {
      if (item.grammarErrors.length === 0) {
        return null;
      }

      const wrongOptions = shuffleArray(otherItems)
        .filter((i) => i.grammarErrors.length > 0)
        .slice(0, 2)
        .map((i) => i.originalText);

      if (wrongOptions.length < 2) {
        return null;
      }

      // Add a variation of the original text
      wrongOptions.push(item.originalText);

      const options = shuffleArray([item.correctedText, ...wrongOptions]);
      return {
        id: generateId(),
        category: 'grammar',
        type,
        sourceId: item.id,
        question: 'Câu nào mới đúng ngữ pháp?',
        options,
        correctAnswerIndex: options.indexOf(item.correctedText),
      };
    }

    case 'error-category': {
      if (item.grammarErrors.length === 0) {
        return null;
      }

      const error = shuffleArray(item.grammarErrors)[0];
      if (!error) {
        return null;
      }

      const correctCategory = formatErrorCategory(error.category);

      // Generate some common error categories
      const commonCategories = [
        'Chính tả',
        'Ngữ pháp',
        'Dấu câu',
        'Văn phong',
        'Dùng từ',
        'Cấu trúc câu',
      ];

      const wrongOptions = shuffleArray(
        commonCategories.filter((c) => c !== correctCategory),
      ).slice(0, WRONG_OPTIONS_COUNT);

      if (wrongOptions.length < WRONG_OPTIONS_COUNT) {
        wrongOptions.push('Lỗi khác', 'Lỗi cú pháp', 'Trình bày');
        wrongOptions.length = WRONG_OPTIONS_COUNT;
      }

      const options = shuffleArray([correctCategory, ...wrongOptions.slice(0, WRONG_OPTIONS_COUNT)]);

      // Extract the problematic text
      const { start, end } = error.position;
      const errorText = item.originalText.substring(start, end);

      return {
        id: generateId(),
        category: 'grammar',
        type,
        sourceId: item.id,
        question: `"${errorText}" là lỗi thuộc loại nào?`,
        context: item.originalText,
        hint: error.message,
        options,
        correctAnswerIndex: options.indexOf(correctCategory),
      };
    }

    case 'suggest-correction': {
      if (item.grammarErrors.length === 0) {
        return null;
      }

      const error = shuffleArray(item.grammarErrors)[0];
      if (!error) {
        return null;
      }

      const correctSuggestion = error.suggestion;

      const wrongOptions = shuffleArray(otherItems)
        .flatMap((i) => i.grammarErrors.map((e) => e.suggestion))
        .filter((s) => s !== correctSuggestion)
        .slice(0, WRONG_OPTIONS_COUNT);

      if (wrongOptions.length < WRONG_OPTIONS_COUNT) {
        return null;
      }

      const options = shuffleArray([correctSuggestion, ...wrongOptions]);

      const { start, end } = error.position;
      const errorText = item.originalText.substring(start, end);

      return {
        id: generateId(),
        category: 'grammar',
        type,
        sourceId: item.id,
        question: `Phải thay "${errorText}" bằng gì?`,
        context: item.originalText,
        options,
        correctAnswerIndex: options.indexOf(correctSuggestion),
      };
    }

    case 'count-errors': {
      const correctCount = item.grammarErrors.length.toString();

      // Generate wrong options around the correct count
      const correctNum = item.grammarErrors.length;
      const wrongOptions = [
        Math.max(0, correctNum - 1).toString(),
        (correctNum + 1).toString(),
        (correctNum + 2).toString(),
      ].filter((o) => o !== correctCount);

      const options = shuffleArray([correctCount, ...wrongOptions.slice(0, WRONG_OPTIONS_COUNT)]);

      return {
        id: generateId(),
        category: 'grammar',
        type,
        sourceId: item.id,
        question: 'Câu này có bao nhiêu lỗi ngữ pháp?',
        context: item.originalText,
        options,
        correctAnswerIndex: options.indexOf(correctCount),
      };
    }

    default:
      return null;
  }
}

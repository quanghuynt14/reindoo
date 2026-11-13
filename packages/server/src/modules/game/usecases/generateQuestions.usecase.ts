import type { GameCategory, GameQuestion } from '@practice/shared';
import { shuffleArray } from '../game.utils.ts';

type GenerateDictionaryQuestions = (params: { userId: string; count: number }) => Promise<GameQuestion[]>;
type GenerateGrammarQuestions = (params: { userId: string; count: number }) => Promise<GameQuestion[]>;
type GenerateTranslationQuestions = (params: { userId: string; count: number }) => Promise<GameQuestion[]>;

export function createGenerateQuestionsUsecase({
  generateDictionaryQuestions,
  generateGrammarQuestions,
  generateTranslationQuestions,
}: {
  generateDictionaryQuestions: GenerateDictionaryQuestions;
  generateGrammarQuestions: GenerateGrammarQuestions;
  generateTranslationQuestions: GenerateTranslationQuestions;
}) {
  return async function generateQuestions({
    userId,
    categories,
    questionCount,
  }: {
    userId: string;
    categories: GameCategory[];
    questionCount: number;
  }): Promise<GameQuestion[]> {
    const questionsPerCategory = Math.ceil(questionCount / categories.length);
    const allQuestions: GameQuestion[] = [];

    // Generate questions for each category
    for (const category of categories) {
      let categoryQuestions: GameQuestion[] = [];

      switch (category) {
        case 'dictionary':
          categoryQuestions = await generateDictionaryQuestions({
            userId,
            count: questionsPerCategory,
          });
          break;
        case 'grammar':
          categoryQuestions = await generateGrammarQuestions({
            userId,
            count: questionsPerCategory,
          });
          break;
        case 'translation':
          categoryQuestions = await generateTranslationQuestions({
            userId,
            count: questionsPerCategory,
          });
          break;
        default:
          throw new Error(`Unsupported game category: ${String(category)}`);
      }

      allQuestions.push(...categoryQuestions);
    }

    // Shuffle and limit to requested count
    const shuffledQuestions = shuffleArray(allQuestions);
    return shuffledQuestions.slice(0, questionCount);
  };
}

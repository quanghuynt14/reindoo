import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { dictionaryProvider } from '../../dictionary.provider.ts';
import { WordNotFoundError } from '../../usecases/searchWord/searchWord.usecase.ts';
import {
  searchWordBodySchema,
  searchWordNotFoundSchema,
  searchWordResponseSchema,
} from './searchWord.route-schema.ts';

export function registerSearchWordRoute(instance: ServerInstance) {
  instance.route({
    method: 'POST',
    url: '/',
    schema: {
      body: searchWordBodySchema,
      response: {
        200: searchWordResponseSchema,
        404: searchWordNotFoundSchema,
      },
    },
    handler: async (request, reply) => {
      const { searchingWord, sourceLanguage, targetLanguage, saveToHistory = true } = request.body;

      const { searchWord } = dictionaryProvider({ db: instance.db });

      try {
        return await searchWord({
          userId: request.user!.id,
          searchingWord,
          sourceLanguage,
          targetLanguage,
          saveToHistory,
        });
      }
      catch (error) {
        // Un mot absent n'est pas une panne : c'est la réponse du dictionnaire.
        // 404 plutôt que 500, et les propositions dans le corps.
        if (error instanceof WordNotFoundError) {
          return reply.code(404).send({
            error: error.message,
            searchingWord: error.searchingWord,
            suggestions: error.suggestions,
          });
        }
        throw error;
      }
    },
  });
}

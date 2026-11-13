import type { FastifyInstance } from 'fastify';
import { registerCheckWordStarredRoute } from './routes/checkWordStarred/checkWordStarred.route.ts';
import { registerDeleteSearchHistoryRoute } from './routes/deleteSearchHistory/deleteSearchHistory.route.ts';
import { registerGetStarredWordsRoute } from './routes/getStarredWords/getStarredWords.route.ts';
import { registerGetUserSearchHistoryRoute } from './routes/getUserSearchHistory/getUserSearchHistory.route.ts';
import { registerSearchWordRoute } from './routes/searchWord/searchWord.route.ts';
import { registerToggleStarredWordRoute } from './routes/toggleStarredWord/toggleStarredWord.route.ts';

export async function dictionaryPrivateRoutes(instance: FastifyInstance) {
  registerSearchWordRoute(instance);
  registerGetUserSearchHistoryRoute(instance);
  registerToggleStarredWordRoute(instance);
  registerGetStarredWordsRoute(instance);
  registerCheckWordStarredRoute(instance);
  registerDeleteSearchHistoryRoute(instance);
}

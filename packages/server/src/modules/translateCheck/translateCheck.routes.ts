import type { FastifyInstance } from 'fastify';
import { registerAnalysisRoute } from './routes/analysis/analysis.route.ts';
import { registerCheckTranslationRoute } from './routes/checkTranslation/checkTranslation.route.ts';
import { registerCheckTranslationCheckStarredRoute } from './routes/checkTranslationCheckStarred/checkTranslationCheckStarred.route.ts';
import { registerDeleteTranslateCheckHistoryRoute } from './routes/deleteHistory/deleteHistory.route.ts';
import { registerGetStarredTranslationChecksRoute } from './routes/getStarredTranslationChecks/getStarredTranslationChecks.route.ts';
import { registerHistoryRoute } from './routes/history/history.route.ts';
import { registerToggleStarredTranslationCheckRoute } from './routes/toggleStarredTranslationCheck/toggleStarredTranslationCheck.route.ts';

export async function translateCheckPrivateRoutes(instance: FastifyInstance) {
  registerCheckTranslationRoute(instance);
  registerHistoryRoute(instance);
  registerAnalysisRoute(instance);
  registerToggleStarredTranslationCheckRoute(instance);
  registerGetStarredTranslationChecksRoute(instance);
  registerCheckTranslationCheckStarredRoute(instance);
  registerDeleteTranslateCheckHistoryRoute(instance);
}

import type { FastifyInstance } from 'fastify';
import { registerAnalysisRoute } from './routes/analysis/analysis.route.ts';
import { registerAnalyticsRoute } from './routes/analytics/analytics.route.ts';
import { registerCheckGrammarRoute } from './routes/checkGrammar/checkGrammar.route.ts';
import { registerCheckGrammarCheckStarredRoute } from './routes/checkGrammarCheckStarred/checkGrammarCheckStarred.route.ts';
import { registerDeleteGrammarCheckHistoryRoute } from './routes/deleteHistory/deleteHistory.route.ts';
import { registerExportRoute } from './routes/export/export.route.ts';
import { registerGetStarredGrammarChecksRoute } from './routes/getStarredGrammarChecks/getStarredGrammarChecks.route.ts';
import { registerHistoryRoute } from './routes/history/history.route.ts';
import { registerToggleStarredGrammarCheckRoute } from './routes/toggleStarredGrammarCheck/toggleStarredGrammarCheck.route.ts';

export async function grammarCheckPrivateRoutes(instance: FastifyInstance) {
  registerCheckGrammarRoute(instance);
  registerAnalyticsRoute(instance);
  registerAnalysisRoute(instance);
  registerHistoryRoute(instance);
  registerExportRoute(instance);
  registerToggleStarredGrammarCheckRoute(instance);
  registerGetStarredGrammarChecksRoute(instance);
  registerCheckGrammarCheckStarredRoute(instance);
  registerDeleteGrammarCheckHistoryRoute(instance);
}

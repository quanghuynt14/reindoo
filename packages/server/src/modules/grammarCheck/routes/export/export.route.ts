import type { ServerInstance } from '../../../../app/types/fastify.types.ts';
import { grammarCheckProvider } from '../../grammarCheck.provider.ts';
import { exportQuerySchema } from './export.route-schema.ts';

const TEXT_WIDTH = 80;

export function registerExportRoute(instance: ServerInstance) {
  instance.route({
    method: 'GET',
    url: '/export',
    schema: {
      querystring: exportQuerySchema,
    },
    handler: async (request, reply) => {
      const { format } = request.query as { format?: 'csv' | 'txt' };
      const exportFormat = format || 'csv';

      const { getHistory } = grammarCheckProvider({ db: instance.db });

      try {
        // Get all history for export (limited to 10000 records for performance)
        // For larger datasets, consider implementing streaming or batch exports
        const history = await getHistory({
          userId: request.user!.id,
          page: 1,
          limit: 10000,
          sortBy: 'createdAt',
          sortOrder: 'desc',
        });

        if (exportFormat === 'csv') {
          // Generate CSV
          const headers = ['Date', 'Detected Language', 'Error Count', 'Original Text', 'Corrected Text'];
          const rows = history.results.map((check) => [
            new Date(check.createdAt).toLocaleString(),
            check.detectedLanguage,
            check.grammarErrors.length.toString(),
            `"${check.originalText.replace(/"/g, '""')}"`,
            `"${check.correctedText.replace(/"/g, '""')}"`,
          ]);

          const csv = [headers.join(','), ...rows.map((row) => row.join(','))].join('\n');

          reply.header('Content-Type', 'text/csv');
          reply.header('Content-Disposition', 'attachment; filename="grammar-check-history.csv"');
          return reply.send(csv);
        } else {
          // Generate text format report
          const content = [
            'Grammar Check History Report',
            '='.repeat(TEXT_WIDTH),
            '',
            `Generated: ${new Date().toLocaleString()}`,
            `Total Checks: ${history.total}`,
            '',
            '='.repeat(TEXT_WIDTH),
            '',
            ...history.results.flatMap((check, index) => [
              `Check #${index + 1}`,
              '-'.repeat(TEXT_WIDTH),
              `Date: ${new Date(check.createdAt).toLocaleString()}`,
              `Language: ${check.detectedLanguage}`,
              `Errors: ${check.grammarErrors.length}`,
              '',
              'Original Text:',
              check.originalText,
              '',
              'Corrected Text:',
              check.correctedText,
              '',
              'Errors:',
              ...check.grammarErrors.map((error, i) =>
                `  ${i + 1}. [${error.category}] ${error.message} - Suggestion: ${error.suggestion}`,
              ),
              '',
              '',
            ]),
          ].join('\n');

          reply.header('Content-Type', 'text/plain');
          reply.header('Content-Disposition', 'attachment; filename="grammar-check-history.txt"');
          return reply.send(content);
        }
      } catch (error) {
        instance.log.error(error);
        throw error;
      }
    },
  });
}

export const analysisResponseSchema = {
  type: 'object',
  properties: {
    errorPatterns: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          category: { type: 'string' },
          count: { type: 'number' },
          percentage: { type: 'number' },
          examples: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                message: { type: 'string' },
                suggestion: { type: 'string' },
                textSnippet: { type: 'string' },
              },
              required: ['message', 'suggestion', 'textSnippet'],
            },
          },
          trend: { type: 'string', enum: ['improving', 'stable', 'worsening'] },
        },
        required: ['category', 'count', 'percentage', 'examples', 'trend'],
      },
    },
    improvementAreas: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          category: { type: 'string' },
          errorCount: { type: 'number' },
          priority: { type: 'string', enum: ['high', 'medium', 'low'] },
          recommendation: { type: 'string' },
          resources: {
            type: 'array',
            items: { type: 'string' },
          },
        },
        required: ['category', 'errorCount', 'priority', 'recommendation', 'resources'],
      },
    },
    progressMetrics: {
      type: 'object',
      properties: {
        totalChecks: { type: 'number' },
        totalErrors: { type: 'number' },
        averageErrorsPerCheck: { type: 'number' },
        improvementRate: { type: 'number' },
        recentTrend: { type: 'string', enum: ['improving', 'stable', 'worsening'] },
      },
      required: ['totalChecks', 'totalErrors', 'averageErrorsPerCheck', 'improvementRate', 'recentTrend'],
    },
    categoryBreakdown: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          category: { type: 'string' },
          count: { type: 'number' },
          percentage: { type: 'number' },
        },
        required: ['category', 'count', 'percentage'],
      },
    },
    timeBasedAnalysis: {
      type: 'object',
      properties: {
        last7Days: {
          type: 'object',
          properties: {
            checks: { type: 'number' },
            errors: { type: 'number' },
            avgErrors: { type: 'number' },
          },
          required: ['checks', 'errors', 'avgErrors'],
        },
        previous7Days: {
          type: 'object',
          properties: {
            checks: { type: 'number' },
            errors: { type: 'number' },
            avgErrors: { type: 'number' },
          },
          required: ['checks', 'errors', 'avgErrors'],
        },
        improvement: { type: 'number' },
      },
      required: ['last7Days', 'previous7Days', 'improvement'],
    },
  },
  required: ['errorPatterns', 'improvementAreas', 'progressMetrics', 'categoryBreakdown', 'timeBasedAnalysis'],
} as const;

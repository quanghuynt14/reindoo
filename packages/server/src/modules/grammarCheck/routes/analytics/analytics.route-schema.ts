export const analyticsResponseSchema = {
  type: 'object',
  properties: {
    totalChecks: { type: 'number' },
    totalErrors: { type: 'number' },
    errorsByCategory: {
      type: 'object',
      additionalProperties: { type: 'number' },
    },
    errorTrends: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          date: { type: 'string' },
          count: { type: 'number' },
        },
        required: ['date', 'count'],
      },
    },
    mostCommonErrors: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          message: { type: 'string' },
          count: { type: 'number' },
        },
        required: ['message', 'count'],
      },
    },
    languageDistribution: {
      type: 'object',
      additionalProperties: { type: 'number' },
    },
    recentChecks: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          userId: { type: 'string' },
          originalText: { type: 'string' },
          correctedText: { type: 'string' },
          detectedLanguage: { type: 'string' },
          grammarErrors: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                message: { type: 'string' },
                category: { type: 'string' },
                position: {
                  type: 'object',
                  properties: {
                    start: { type: 'number' },
                    end: { type: 'number' },
                  },
                  required: ['start', 'end'],
                },
                suggestion: { type: 'string' },
              },
              required: ['message', 'category', 'position', 'suggestion'],
            },
          },
          createdAt: { type: 'string' },
        },
        required: [
          'id',
          'userId',
          'originalText',
          'correctedText',
          'detectedLanguage',
          'grammarErrors',
          'createdAt',
        ],
      },
    },
  },
  required: [
    'totalChecks',
    'totalErrors',
    'errorsByCategory',
    'errorTrends',
    'mostCommonErrors',
    'languageDistribution',
    'recentChecks',
  ],
} as const;

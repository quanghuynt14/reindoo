export const historyQuerySchema = {
  type: 'object',
  properties: {
    page: { type: 'number', minimum: 1, default: 1 },
    limit: { type: 'number', minimum: 1, maximum: 100, default: 10 },
    sortBy: { type: 'string', default: 'createdAt' },
    sortOrder: { type: 'string', enum: ['asc', 'desc'], default: 'desc' },
    search: { type: 'string' },
  },
  additionalProperties: false,
} as const;

export const historyResponseSchema = {
  type: 'object',
  properties: {
    results: {
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
    total: { type: 'number' },
    page: { type: 'number' },
    totalPages: { type: 'number' },
  },
  required: ['results', 'total', 'page', 'totalPages'],
} as const;

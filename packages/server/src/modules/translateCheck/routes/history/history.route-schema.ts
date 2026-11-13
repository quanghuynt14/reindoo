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
          translatedText: { type: 'string' },
          detectedOriginalLanguage: { type: 'string' },
          detectedTranslatedLanguage: { type: 'string' },
          translationErrors: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                message: { type: 'string' },
                positions: {
                  type: 'object',
                  properties: {
                    original: {
                      type: 'array',
                      items: { type: 'number' },
                    },
                    translated: {
                      type: 'array',
                      items: { type: 'number' },
                    },
                  },
                  required: ['original', 'translated'],
                },
              },
              required: ['message', 'positions'],
            },
          },
          correctedTranslation: { type: 'string' },
          createdAt: { type: 'string' },
        },
        required: [
          'id',
          'userId',
          'originalText',
          'translatedText',
          'detectedOriginalLanguage',
          'detectedTranslatedLanguage',
          'translationErrors',
          'correctedTranslation',
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

export const checkTranslationBodySchema = {
  type: 'object',
  properties: {
    originalText: {
      type: 'string',
      minLength: 1,
      maxLength: 5000,
    },
    translatedText: {
      type: 'string',
      minLength: 1,
      maxLength: 5000,
    },
  },
  required: ['originalText', 'translatedText'],
  additionalProperties: false,
} as const;

export const checkTranslationResponseSchema = {
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
} as const;

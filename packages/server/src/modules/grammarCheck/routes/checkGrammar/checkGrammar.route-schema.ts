export const checkGrammarBodySchema = {
  type: 'object',
  properties: {
    text: {
      type: 'string',
      minLength: 1,
      maxLength: 5000,
    },
  },
  required: ['text'],
  additionalProperties: false,
} as const;

export const checkGrammarResponseSchema = {
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
} as const;

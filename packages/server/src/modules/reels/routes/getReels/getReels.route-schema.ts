export const reelsQuerySchema = {
  type: 'object',
  properties: {
    page: { type: 'number', minimum: 1, default: 1 },
    limit: { type: 'number', minimum: 1, maximum: 50, default: 10 },
    sourceLanguage: { type: 'string' },
    targetLanguage: { type: 'string' },
    sort: { type: 'string', enum: ['newest', 'oldest', 'random'], default: 'random' },
  },
  additionalProperties: false,
} as const;

export const reelsResponseSchema = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      // NOTE: Item structure is intentionally not validated here.
      // Items are heterogeneous (dictionary/grammar/translation) and
      // validated at the application layer via TypeScript discriminated unions.
    },
    nextPage: {
      oneOf: [
        { type: 'number' },
        { type: 'null' },
      ],
    },
    hasMore: { type: 'boolean' },
  },
  required: ['items', 'nextPage', 'hasMore'],
} as const;

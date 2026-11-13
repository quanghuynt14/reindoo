export const exportQuerySchema = {
  type: 'object',
  properties: {
    format: { type: 'string', enum: ['csv', 'txt'], default: 'csv' },
  },
  additionalProperties: false,
} as const;

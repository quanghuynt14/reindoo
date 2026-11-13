import type { JSONSchema } from 'json-schema-to-ts';

export const startGameBodySchema = {
  type: 'object',
  required: ['categories', 'questionCount'],
  additionalProperties: false,
  properties: {
    categories: {
      type: 'array',
      items: {
        type: 'string',
        enum: ['dictionary', 'grammar', 'translation'],
      },
      minItems: 1,
    },
    questionCount: {
      type: 'number',
      minimum: 5,
      maximum: 20,
    },
  },
} as const satisfies JSONSchema;

export const startGameResponseSchema = {
  type: 'object',
  required: ['sessionId', 'questions'],
  additionalProperties: false,
  properties: {
    sessionId: { type: 'string' },
    questions: {
      type: 'array',
      items: {
        type: 'object',
        required: ['id', 'category', 'type', 'sourceId', 'question', 'options', 'correctAnswerIndex'],
        additionalProperties: false,
        properties: {
          id: { type: 'string' },
          category: {
            type: 'string',
            enum: ['dictionary', 'grammar', 'translation'],
          },
          type: { type: 'string' },
          sourceId: { type: 'string' },
          question: { type: 'string' },
          context: { type: 'string' },
          hint: { type: 'string' },
          options: {
            type: 'array',
            items: { type: 'string' },
          },
          correctAnswerIndex: { type: 'number' },
        },
      },
    },
  },
} as const satisfies JSONSchema;

import type { FromSchema } from 'json-schema-to-ts';

const grammarErrorSchema = {
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
      additionalProperties: false,
    },
    suggestion: { type: 'string' },
  },
  required: ['message', 'category', 'position', 'suggestion'],
  additionalProperties: false,
} as const;

const grammarCheckResultSchema = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    userId: { type: 'string' },
    originalText: { type: 'string' },
    correctedText: { type: 'string' },
    detectedLanguage: { type: 'string' },
    grammarErrors: {
      type: 'array',
      items: grammarErrorSchema,
    },
    createdAt: { type: 'string', format: 'date-time' },
  },
  required: ['id', 'userId', 'originalText', 'correctedText', 'detectedLanguage', 'grammarErrors', 'createdAt'],
  additionalProperties: false,
} as const;

const starredGrammarCheckSchema = {
  type: 'object',
  properties: {
    userId: { type: 'string' },
    grammarCheck: grammarCheckResultSchema,
    starredAt: { type: 'string', format: 'date-time' },
  },
  required: ['userId', 'grammarCheck', 'starredAt'],
  additionalProperties: false,
} as const;

export const getStarredGrammarChecksResponseSchema = {
  type: 'object',
  properties: {
    starredGrammarChecks: {
      type: 'array',
      items: starredGrammarCheckSchema,
    },
  },
  required: ['starredGrammarChecks'],
  additionalProperties: false,
} as const;

export type GetStarredGrammarChecksResponse = FromSchema<typeof getStarredGrammarChecksResponseSchema>;

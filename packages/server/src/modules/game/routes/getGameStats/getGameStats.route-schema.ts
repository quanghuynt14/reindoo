import type { JSONSchema } from 'json-schema-to-ts';

export const getGameStatsResponseSchema = {
  type: 'object',
  required: ['userId', 'totalGamesPlayed', 'totalQuestionsAnswered', 'correctAnswers', 'byCategory'],
  additionalProperties: false,
  properties: {
    userId: { type: 'string' },
    totalGamesPlayed: { type: 'number' },
    totalQuestionsAnswered: { type: 'number' },
    correctAnswers: { type: 'number' },
    byCategory: {
      type: 'object',
      required: ['dictionary', 'grammar', 'translation'],
      additionalProperties: false,
      properties: {
        dictionary: {
          type: 'object',
          required: ['total', 'correct'],
          additionalProperties: false,
          properties: {
            total: { type: 'number' },
            correct: { type: 'number' },
          },
        },
        grammar: {
          type: 'object',
          required: ['total', 'correct'],
          additionalProperties: false,
          properties: {
            total: { type: 'number' },
            correct: { type: 'number' },
          },
        },
        translation: {
          type: 'object',
          required: ['total', 'correct'],
          additionalProperties: false,
          properties: {
            total: { type: 'number' },
            correct: { type: 'number' },
          },
        },
      },
    },
    lastPlayedAt: { type: 'string', format: 'date-time' },
  },
} as const satisfies JSONSchema;

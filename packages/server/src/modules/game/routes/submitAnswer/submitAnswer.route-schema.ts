import type { JSONSchema } from 'json-schema-to-ts';

export const submitAnswerBodySchema = {
  type: 'object',
  required: ['sessionId', 'questionId', 'selectedAnswerIndex'],
  additionalProperties: false,
  properties: {
    sessionId: { type: 'string' },
    questionId: { type: 'string' },
    selectedAnswerIndex: { type: 'number' },
  },
} as const satisfies JSONSchema;

export const submitAnswerResponseSchema = {
  type: 'object',
  required: ['correct', 'correctAnswerIndex'],
  additionalProperties: false,
  properties: {
    correct: { type: 'boolean' },
    correctAnswerIndex: { type: 'number' },
    explanation: { type: 'string' },
  },
} as const satisfies JSONSchema;

import type { FromSchema } from 'json-schema-to-ts';

export const deleteGrammarCheckHistoryParamsSchema = {
  type: 'object',
  properties: {
    id: { type: 'string' },
  },
  required: ['id'],
  additionalProperties: false,
} as const;

export const deleteGrammarCheckHistoryResponseSchema = {
  type: 'object',
  properties: {
    success: { type: 'boolean' },
  },
  required: ['success'],
  additionalProperties: false,
} as const;

export type DeleteGrammarCheckHistoryResponse = FromSchema<
  typeof deleteGrammarCheckHistoryResponseSchema
>;

import type { FromSchema } from 'json-schema-to-ts';

export const deleteTranslateCheckHistoryParamsSchema = {
  type: 'object',
  properties: {
    id: { type: 'string' },
  },
  required: ['id'],
  additionalProperties: false,
} as const;

export const deleteTranslateCheckHistoryResponseSchema = {
  type: 'object',
  properties: {
    success: { type: 'boolean' },
  },
  required: ['success'],
  additionalProperties: false,
} as const;

export type DeleteTranslateCheckHistoryResponse = FromSchema<
  typeof deleteTranslateCheckHistoryResponseSchema
>;

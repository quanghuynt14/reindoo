import type { FromSchema } from 'json-schema-to-ts';

export const deleteSearchHistoryParamsSchema = {
  type: 'object',
  properties: {
    id: { type: 'string' },
  },
  required: ['id'],
  additionalProperties: false,
} as const;

export const deleteSearchHistoryResponseSchema = {
  type: 'object',
  properties: {
    success: { type: 'boolean' },
  },
  required: ['success'],
  additionalProperties: false,
} as const;

export type DeleteSearchHistoryResponse = FromSchema<
  typeof deleteSearchHistoryResponseSchema
>;

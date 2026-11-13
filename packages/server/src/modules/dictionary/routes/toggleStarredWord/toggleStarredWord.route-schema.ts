import type { FromSchema } from 'json-schema-to-ts';

export const toggleStarredWordBodySchema = {
  type: 'object',
  properties: {
    wordId: { type: 'string' },
  },
  required: ['wordId'],
  additionalProperties: false,
} as const;

export const toggleStarredWordResponseSchema = {
  type: 'object',
  properties: {
    starred: { type: 'boolean' },
  },
  required: ['starred'],
  additionalProperties: false,
} as const;

export type ToggleStarredWordResponse = FromSchema<
  typeof toggleStarredWordResponseSchema
>;

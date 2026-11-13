import type { FromSchema } from 'json-schema-to-ts';

export const checkWordStarredQuerySchema = {
  type: 'object',
  properties: {
    wordId: { type: 'string' },
  },
  required: ['wordId'],
  additionalProperties: false,
} as const;

export const checkWordStarredResponseSchema = {
  type: 'object',
  properties: {
    starred: { type: 'boolean' },
  },
  required: ['starred'],
  additionalProperties: false,
} as const;

export type CheckWordStarredResponse = FromSchema<
  typeof checkWordStarredResponseSchema
>;

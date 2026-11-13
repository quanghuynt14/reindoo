import type { FromSchema } from 'json-schema-to-ts';

export const checkTranslationCheckStarredRequestSchema = {
  type: 'object',
  properties: {
    translationCheckId: { type: 'string' },
  },
  required: ['translationCheckId'],
  additionalProperties: false,
} as const;

export const checkTranslationCheckStarredResponseSchema = {
  type: 'object',
  properties: {
    starred: { type: 'boolean' },
  },
  required: ['starred'],
  additionalProperties: false,
} as const;

export type CheckTranslationCheckStarredRequest = FromSchema<typeof checkTranslationCheckStarredRequestSchema>;
export type CheckTranslationCheckStarredResponse = FromSchema<typeof checkTranslationCheckStarredResponseSchema>;

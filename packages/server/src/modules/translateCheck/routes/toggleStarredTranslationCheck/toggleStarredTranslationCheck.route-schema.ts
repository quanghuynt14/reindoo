import type { FromSchema } from 'json-schema-to-ts';

export const toggleStarredTranslationCheckRequestSchema = {
  type: 'object',
  properties: {
    translationCheckId: { type: 'string' },
  },
  required: ['translationCheckId'],
  additionalProperties: false,
} as const;

export const toggleStarredTranslationCheckResponseSchema = {
  type: 'object',
  properties: {
    starred: { type: 'boolean' },
  },
  required: ['starred'],
  additionalProperties: false,
} as const;

export type ToggleStarredTranslationCheckRequest = FromSchema<typeof toggleStarredTranslationCheckRequestSchema>;
export type ToggleStarredTranslationCheckResponse = FromSchema<typeof toggleStarredTranslationCheckResponseSchema>;

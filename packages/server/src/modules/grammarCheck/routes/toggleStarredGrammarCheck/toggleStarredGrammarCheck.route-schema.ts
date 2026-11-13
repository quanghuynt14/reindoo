import type { FromSchema } from 'json-schema-to-ts';

export const toggleStarredGrammarCheckRequestSchema = {
  type: 'object',
  properties: {
    grammarCheckId: { type: 'string' },
  },
  required: ['grammarCheckId'],
  additionalProperties: false,
} as const;

export const toggleStarredGrammarCheckResponseSchema = {
  type: 'object',
  properties: {
    starred: { type: 'boolean' },
  },
  required: ['starred'],
  additionalProperties: false,
} as const;

export type ToggleStarredGrammarCheckRequest = FromSchema<typeof toggleStarredGrammarCheckRequestSchema>;
export type ToggleStarredGrammarCheckResponse = FromSchema<typeof toggleStarredGrammarCheckResponseSchema>;

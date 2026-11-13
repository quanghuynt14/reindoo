import type { FromSchema } from 'json-schema-to-ts';

export const checkGrammarCheckStarredRequestSchema = {
  type: 'object',
  properties: {
    grammarCheckId: { type: 'string' },
  },
  required: ['grammarCheckId'],
  additionalProperties: false,
} as const;

export const checkGrammarCheckStarredResponseSchema = {
  type: 'object',
  properties: {
    starred: { type: 'boolean' },
  },
  required: ['starred'],
  additionalProperties: false,
} as const;

export type CheckGrammarCheckStarredRequest = FromSchema<typeof checkGrammarCheckStarredRequestSchema>;
export type CheckGrammarCheckStarredResponse = FromSchema<typeof checkGrammarCheckStarredResponseSchema>;

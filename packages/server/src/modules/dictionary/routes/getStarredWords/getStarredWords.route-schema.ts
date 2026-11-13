import type { FromSchema } from 'json-schema-to-ts';

export const getStarredWordsResponseSchema = {
  type: 'object',
  properties: {
    starredWords: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          userId: { type: 'string' },
          word: {
            type: 'object',
            required: ['id', 'word', 'sourceLanguage', 'targetLanguage', 'translated', 'explains'],
            additionalProperties: false,
            properties: {
              id: { type: 'string' },
              word: { type: 'string' },
              sourceLanguage: { type: 'string' },
              targetLanguage: { type: 'string' },
              translated: { type: 'string' },
              explains: {
                type: 'array',
                items: {
                  type: 'object',
                  required: ['explain', 'synonyms', 'antonyms', 'exampleSentences'],
                  additionalProperties: false,
                  properties: {
                    explain: { type: 'string' },
                    synonyms: {
                      type: 'array',
                      items: { type: 'string' },
                    },
                    antonyms: {
                      type: 'array',
                      items: { type: 'string' },
                    },
                    exampleSentences: {
                      type: 'array',
                      items: {
                        type: 'object',
                        required: ['sourceSentence', 'targetTranslation'],
                        additionalProperties: false,
                        properties: {
                          sourceSentence: { type: 'string' },
                          targetTranslation: { type: 'string' },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
          starredAt: { type: 'string', format: 'date-time' },
        },
        required: ['userId', 'word', 'starredAt'],
        additionalProperties: false,
      },
    },
  },
  required: ['starredWords'],
  additionalProperties: false,
} as const;

export type GetStarredWordsResponse = FromSchema<
  typeof getStarredWordsResponseSchema
>;

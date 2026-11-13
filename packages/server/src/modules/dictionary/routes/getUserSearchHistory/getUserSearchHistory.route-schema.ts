import type { JSONSchema } from 'json-schema-to-ts';

export const getUserSearchHistoryResponseSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['searchHistory', 'hasMore'],
  properties: {
    searchHistory: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'userId', 'word', 'searchedAt'],
        properties: {
          id: { type: 'string' },
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
          searchedAt: { type: 'string', format: 'date-time' },
        },
      },
    },
    hasMore: { type: 'boolean' },
  },
} as const satisfies JSONSchema;

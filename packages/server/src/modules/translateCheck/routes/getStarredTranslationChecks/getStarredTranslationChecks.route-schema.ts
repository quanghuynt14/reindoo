import type { FromSchema } from 'json-schema-to-ts';

const translationErrorSchema = {
  type: 'object',
  properties: {
    message: { type: 'string' },
    positions: {
      type: 'object',
      properties: {
        original: {
          type: 'array',
          items: { type: 'number' },
        },
        translated: {
          type: 'array',
          items: { type: 'number' },
        },
      },
      required: ['original', 'translated'],
      additionalProperties: false,
    },
  },
  required: ['message', 'positions'],
  additionalProperties: false,
} as const;

const translateCheckResultSchema = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    userId: { type: 'string' },
    originalText: { type: 'string' },
    translatedText: { type: 'string' },
    detectedOriginalLanguage: { type: 'string' },
    detectedTranslatedLanguage: { type: 'string' },
    translationErrors: {
      type: 'array',
      items: translationErrorSchema,
    },
    correctedTranslation: { type: 'string' },
    createdAt: { type: 'string', format: 'date-time' },
  },
  required: ['id', 'userId', 'originalText', 'translatedText', 'detectedOriginalLanguage', 'detectedTranslatedLanguage', 'translationErrors', 'correctedTranslation', 'createdAt'],
  additionalProperties: false,
} as const;

const starredTranslationCheckSchema = {
  type: 'object',
  properties: {
    userId: { type: 'string' },
    translationCheck: translateCheckResultSchema,
    starredAt: { type: 'string', format: 'date-time' },
  },
  required: ['userId', 'translationCheck', 'starredAt'],
  additionalProperties: false,
} as const;

export const getStarredTranslationChecksResponseSchema = {
  type: 'object',
  properties: {
    starredTranslationChecks: {
      type: 'array',
      items: starredTranslationCheckSchema,
    },
  },
  required: ['starredTranslationChecks'],
  additionalProperties: false,
} as const;

export type GetStarredTranslationChecksResponse = FromSchema<typeof getStarredTranslationChecksResponseSchema>;

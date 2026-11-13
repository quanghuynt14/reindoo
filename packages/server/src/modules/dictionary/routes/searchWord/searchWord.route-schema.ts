import type { JSONSchema } from 'json-schema-to-ts';
import { DICTIONARY_SOURCE_LANGUAGES, DICTIONARY_TARGET_LANGUAGE, LANGUAGE } from '@practice/shared';

export const searchWordBodySchema = {
  type: 'object',
  required: ['searchingWord', 'sourceLanguage', 'targetLanguage'],
  additionalProperties: false,
  properties: {
    searchingWord: {
      type: 'string',
    },
    // Seuls les couples qui ont un lexique derrière eux. Avant, l'énumération
    // acceptait les cinq langues et le modèle répondait sur n'importe laquelle ;
    // maintenant elle mentirait, puisque la recherche ne pourrait que renvoyer
    // « introuvable ». Un 400 dit la vérité plus tôt.
    sourceLanguage: {
      type: 'string',
      enum: [...DICTIONARY_SOURCE_LANGUAGES],
    },
    targetLanguage: {
      type: 'string',
      enum: [DICTIONARY_TARGET_LANGUAGE],
    },
    saveToHistory: {
      type: 'boolean',
      default: true,
    },
  },
} as const satisfies JSONSchema;

export const searchWordResponseSchema = {
  type: 'object',
  required: ['id', 'word', 'sourceLanguage', 'targetLanguage', 'translated', 'explains'],
  additionalProperties: false,
  properties: {
    id: { type: 'string' },
    word: { type: 'string' },
    sourceLanguage: {
      type: 'string',
      enum: Object.values(LANGUAGE),
    },
    targetLanguage: {
      type: 'string',
      enum: Object.values(LANGUAGE),
    },
    translated: { type: 'string' },
    // Facultatifs, et il faut qu'ils le restent : l'historique contient des
    // entrées écrites avant le passage au lexique compilé, qui ne les ont pas.
    ipa: { type: 'array', items: { type: 'string' } },
    audio: { type: 'string' },
    wiki: { type: 'string' },
    derived: { type: 'array', items: { type: 'string' } },
    matchedForm: { type: 'string' },
    alsoFrom: { type: 'array', items: { type: 'string' } },
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
} as const satisfies JSONSchema;

/**
 * Un mot absent est maintenant une réponse à part entière.
 *
 * Avec le modèle de langue, la recherche répondait toujours quelque chose —
 * quitte à l'inventer. Le lexique est fini : « introuvable » est un résultat
 * juste, et les propositions sont ce qui le rend utilisable.
 */
export const searchWordNotFoundSchema = {
  type: 'object',
  required: ['error', 'searchingWord', 'suggestions'],
  additionalProperties: false,
  properties: {
    error: { type: 'string' },
    searchingWord: { type: 'string' },
    suggestions: {
      type: 'array',
      items: { type: 'string' },
    },
  },
} as const satisfies JSONSchema;

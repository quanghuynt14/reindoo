import type { Word } from '@practice/shared'

export type DictionaryHistoryItem = {
  id: string
  userId: string
  word: Word
  searchedAt: string
}

export type GrammarCheckResult = {
  id: string
  userId: string
  originalText: string
  correctedText: string
  detectedLanguage: string
  grammarErrors: Array<{
    message: string
    category: string
    position: { start: number; end: number }
    suggestion: string
  }>
  createdAt: string
}

export type TranslateCheckResult = {
  id: string
  userId: string
  originalText: string
  translatedText: string
  detectedOriginalLanguage: string
  detectedTranslatedLanguage: string
  translationErrors: Array<{
    message: string
    positions: {
      original: Array<number>
      translated: Array<number>
    }
  }>
  correctedTranslation: string
  createdAt: string
}

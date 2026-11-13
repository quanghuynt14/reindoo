import type { TranslateCheckResult, TranslationError } from '@practice/shared';
import type { WithId } from 'mongodb';

export type TranslateCheckResultDocument = {
  userId: string;
  originalText: string;
  translatedText: string;
  detectedOriginalLanguage: string;
  detectedTranslatedLanguage: string;
  translationErrors: TranslationError[];
  correctedTranslation: string;
  createdAt: Date;
};

export function formatDocumentToModel({ document }: { document: WithId<TranslateCheckResultDocument> }): TranslateCheckResult {
  return {
    id: document._id.toString(),
    userId: document.userId,
    originalText: document.originalText,
    translatedText: document.translatedText,
    detectedOriginalLanguage: document.detectedOriginalLanguage,
    detectedTranslatedLanguage: document.detectedTranslatedLanguage,
    translationErrors: document.translationErrors,
    correctedTranslation: document.correctedTranslation,
    createdAt: document.createdAt,
  };
}

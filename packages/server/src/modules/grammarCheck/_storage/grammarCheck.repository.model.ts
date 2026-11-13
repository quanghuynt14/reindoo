import type { GrammarCheckResult, GrammarError } from '@practice/shared';
import type { WithId } from 'mongodb';

export type GrammarCheckResultDocument = {
  userId: string;
  originalText: string;
  correctedText: string;
  detectedLanguage: string;
  grammarErrors: GrammarError[];
  createdAt: Date;
};

export function formatDocumentToModel({ document }: { document: WithId<GrammarCheckResultDocument> }): GrammarCheckResult {
  return {
    id: document._id.toString(),
    userId: document.userId,
    originalText: document.originalText,
    correctedText: document.correctedText,
    detectedLanguage: document.detectedLanguage,
    grammarErrors: document.grammarErrors,
    createdAt: document.createdAt,
  };
}

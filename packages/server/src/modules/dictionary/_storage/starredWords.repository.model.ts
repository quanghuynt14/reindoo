import type { StarredWord } from '../dictionary.types.ts';

export function formatDocumentToModel({ document }: { document: any }): StarredWord {
  return {
    userId: document.userId,
    wordId: document.wordId.toString(),
    starredAt: document.starredAt,
  };
}

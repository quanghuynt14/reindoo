import type { SearchHistory } from '../dictionary.types.ts';

export function formatDocumentToModel({ document }: { document: any }): SearchHistory {
  return {
    id: document._id.toString(),
    userId: document.userId,
    wordId: document.wordId.toString(),
    searchedAt: document.searchedAt,
  };
}

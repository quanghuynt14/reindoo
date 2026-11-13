export type SearchHistory = {
  id: string;
  userId: string;
  wordId: string;
  searchedAt: Date;
};

export type SearchHistoryWithDetails = {
  id: string;
  userId: string;
  word: import('@practice/shared').Word;
  searchedAt: Date;
};

export type StarredWord = {
  userId: string;
  wordId: string;
  starredAt: Date;
};

export type StarredWordWithDetails = {
  userId: string;
  word: import('@practice/shared').Word;
  starredAt: Date;
};

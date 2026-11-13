import type { Db } from 'mongodb';

export function getSearchHistoryCollection({ db }: { db: Db }) {
  return db.collection('searchHistory');
}

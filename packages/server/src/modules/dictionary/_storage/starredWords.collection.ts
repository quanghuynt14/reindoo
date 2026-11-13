import type { Db } from 'mongodb';

export function getStarredWordsCollection({ db }: { db: Db }) {
  return db.collection('starredWords');
}

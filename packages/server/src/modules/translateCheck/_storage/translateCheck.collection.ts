import type { Db } from 'mongodb';

export function getTranslateCheckCollection({ db }: { db: Db }) {
  return db.collection('translateCheck');
}

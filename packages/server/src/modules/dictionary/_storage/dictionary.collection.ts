import type { Db } from 'mongodb';

export function getDictionaryCollection({ db }: { db: Db }) {
  return db.collection('dictionary');
}

import type { Db } from 'mongodb';

export function getStarredTranslationChecksCollection({ db }: { db: Db }) {
  return db.collection('starredTranslationChecks');
}

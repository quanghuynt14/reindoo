import type { Db } from 'mongodb';

export function getStarredGrammarChecksCollection({ db }: { db: Db }) {
  return db.collection('starredGrammarChecks');
}

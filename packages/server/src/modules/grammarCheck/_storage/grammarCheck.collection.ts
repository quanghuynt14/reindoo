import type { Db } from 'mongodb';

export function getGrammarCheckCollection({ db }: { db: Db }) {
  return db.collection('grammarCheck');
}

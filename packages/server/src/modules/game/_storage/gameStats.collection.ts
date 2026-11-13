import type { Db } from 'mongodb';

export function getGameStatsCollection({ db }: { db: Db }) {
  return db.collection('gameStats');
}

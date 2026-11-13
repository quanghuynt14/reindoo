import type { Db } from 'mongodb';

export function getGameSessionCollection({ db }: { db: Db }) {
  return db.collection('gameSession');
}

import process from 'node:process';
import fp from 'fastify-plugin';
import { MongoClient } from 'mongodb';

export const dbPlugin = fp(async (instance) => {
  // eslint-disable-next-line dot-notation
  const mongoUrl = process.env['MONGODB_URL'];
  if (!mongoUrl) {
    throw new Error('MONGODB_URL environment variable is required');
  }

  const mongoClient = new MongoClient(mongoUrl, {
    // set to be < fastify.pluginTimeout which is 10s by default
    // this way, connection errors are correctly reported at server startup
    serverSelectionTimeoutMS: 8000,
  });

  // eslint-disable-next-line dot-notation
  const dbName = process.env['MONGODB_DB_NAME'] || 'practice';
  const db = mongoClient.db(dbName);

  instance.addHook('onClose', async (instance) => {
    instance.log.info('Closing db connection');
    await mongoClient.close();
  });

  instance.decorate('db', db);

  instance.log.info('Connected to db');
}, { name: 'db' });

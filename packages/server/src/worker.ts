import process from 'node:process';
import { startWorker } from './app/startWorker.ts';

startWorker().catch((err) => {
  console.error('Failed to start worker:', err);
  process.exit(1);
});

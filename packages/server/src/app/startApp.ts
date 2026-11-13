import process from 'node:process';
import closeWithGrace from 'close-with-grace';
import { createApp } from './createApp.ts';

export async function startApp() {
  const app = await createApp();

  const closeListener = closeWithGrace(async ({ err, signal, manual }) => {
    if (err) {
      app.log.error({ err }, 'Server closing with error');
    } else {
      app.log.error(
        { err: new Error('Signal Received') },
        `${signal} signal received, server closing, close manual received: ${manual}`,
      );
    }

    try {
      await app.close();
    } catch (closeErr) {
      app.log.error({ err: closeErr }, 'Failed to close app');
      throw closeErr;
    }
  });

  app.addHook('onClose', async () => {
    closeListener.uninstall();
  });

  app.listen({ port: 3210, host: '0.0.0.0' }, (err) => {
    if (err) {
      app.log.error({ err }, 'Uncaught error in app, exit(1)');
      process.exit(1);
    }
  });
}

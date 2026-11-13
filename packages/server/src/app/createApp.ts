import fastify from 'fastify';
import { plugins } from './plugins/plugins.ts';
import { routes } from './routes/routes.ts';

export async function createApp() {
  const app = fastify({ logger: true });

  app.register(plugins);
  app.register(routes);

  return app;
}

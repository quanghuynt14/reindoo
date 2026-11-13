import process from 'node:process';
import { betterAuth } from 'better-auth';
import { mongodbAdapter } from 'better-auth/adapters/mongodb';
import { tanstackStartCookies } from 'better-auth/tanstack-start';
import fp from 'fastify-plugin';

export const authPlugin = fp(
  async (instance) => {
    // Ensure db is ready
    if (!instance.db) {
      throw new Error('Database not initialized');
    }

    const auth = betterAuth({
      database: mongodbAdapter(instance.db as any), // Get the Db instance from Connection
      basePath: '/api/auth', // Better Auth default base path
      emailAndPassword: {
        enabled: true,
        requireEmailVerification: false, // Set to true in production
      },
      trustedOrigins: [process.env['CLIENT_URL'] || ''],
      plugins: [tanstackStartCookies()],
      // eslint-disable-next-line dot-notation
      secret: process.env['BETTER_AUTH_SECRET'],
      session: {
        cookieCache: {
          enabled: true,
          maxAge: 60 * 60 * 24 * 7, // 7 days
        },
      },
      advanced: {
        // eslint-disable-next-line dot-notation
        crossSubDomainCookies: process.env['NODE_ENV'] === 'production'
          ? {
              enabled: true,
              domain: 'reindoo.com',
            }
          : undefined,
        useSecureCookies: true,
      },
    });

    // Decorate Fastify instance with auth
    instance.decorate('auth', auth);

    instance.log.info('Auth plugin registered');
  },
  {
    name: 'auth',
    dependencies: ['db'], // Ensures db plugin is loaded first
  },
);

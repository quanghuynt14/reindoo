import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

export async function authRoutes(fastify: FastifyInstance) {
  fastify.log.info('Registering Better Auth routes');

  // Single catch-all route for Better Auth as per Fastify integration guide
  fastify.route({
    method: ['GET', 'POST'],
    url: '/auth/*',
    preHandler: async (request, reply) => {
      // Only validate POST requests to sign-in/sign-up endpoints
      if (request.method !== 'POST') return;

      const url = request.url || '';
      if (!url.includes('/sign-in') && !url.includes('/sign-up')) return;

      const token = request.headers['x-turnstile-token'];
      if (!token || typeof token !== 'string') {
        return reply.status(403).send({ error: 'Captcha token required' });
      }

      const isValid = await fastify.verifyTurnstileToken(token);
      if (!isValid) {
        return reply.status(403).send({ error: 'Captcha verification failed' });
      }
    },
    async handler(request: FastifyRequest, reply: FastifyReply) {
      try {
        fastify.log.info({
          url: request.url,
          method: request.method,
          body: request.body,
          cookies: request.headers.cookie,
          headers: request.headers,
        }, 'Handling auth request');

        // Construct the full URL from the request
        const protocol = request.headers['x-forwarded-proto'] || 'http';
        const host = request.headers.host || 'localhost:3210';
        const url = `${protocol}://${host}${request.url}`;

        fastify.log.info({ fullUrl: url, protocol, host }, 'Request URL');

        // Convert Fastify headers to standard Headers object
        const headers = new Headers();
        Object.entries(request.headers).forEach(([key, value]) => {
          if (value) {
            const headerValue = Array.isArray(value) ? value.join(', ') : String(value);
            headers.append(key, headerValue);
          }
        });

        // Prepare request body
        let body: string | null = null;
        if (request.body && request.method !== 'GET' && request.method !== 'HEAD') {
          body = typeof request.body === 'string' ? request.body : JSON.stringify(request.body);
          fastify.log.info({ bodyType: typeof request.body, bodyContent: body }, 'Request body');
        }

        const webRequest = new Request(url, {
          method: request.method,
          headers,
          body,
        });

        const response = await fastify.auth.handler(webRequest);

        fastify.log.info({ status: response.status, headers: Object.fromEntries(response.headers.entries()) }, 'Auth response');

        // Send the response back through Fastify
        reply.status(response.status);
        response.headers.forEach((value: string, key: string) => {
          reply.header(key, value);
        });

        const responseBody = await response.text();
        fastify.log.info({ responseBody }, 'Response body');
        return reply.send(responseBody || null);
      } catch (error) {
        fastify.log.error({ error }, 'Authentication Error:');
        reply.status(500).send({
          error: 'Internal authentication error',
          code: 'AUTH_FAILURE',
        });
      }
    },
  });

  fastify.log.info('Better Auth routes registered');
}

import process from 'node:process';
import fp from 'fastify-plugin';

export const turnstilePlugin = fp(async (instance) => {
  async function verifyTurnstileToken(token: string): Promise<boolean> {
    const secretKey = process.env['TURNSTILE_SECRET_KEY'];

    if (!secretKey) {
      instance.log.warn('TURNSTILE_SECRET_KEY not set, skipping Turnstile verification');
      return true;
    }

    try {
      const response = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          secret: secretKey,
          response: token,
        }),
      });

      const data = (await response.json()) as { success: boolean; 'error-codes'?: string[] };

      if (!data.success) {
        instance.log.warn(
          { errorCodes: data['error-codes'] },
          'Turnstile token verification failed',
        );
      }

      return data.success;
    } catch (error) {
      instance.log.error({ error }, 'Failed to verify Turnstile token');
      return false;
    }
  }

  instance.decorate('verifyTurnstileToken', verifyTurnstileToken);
}, {
  name: 'turnstile',
});

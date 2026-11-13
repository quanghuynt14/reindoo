import type { JsonSchemaToTsProvider } from '@fastify/type-provider-json-schema-to-ts';
import type { TaskService } from '@practice/task-service';
import type { Auth } from 'better-auth';
import type {
  FastifyBaseLogger,
  FastifyInstance,
  RawReplyDefaultExpression,
  RawRequestDefaultExpression,
  RawServerDefault,
} from 'fastify';
import type { Db } from 'mongodb';

declare module 'fastify' {
  interface FastifyInstance {
    db: Db;
    auth: Auth;
    taskService: TaskService;
    verifyTurnstileToken: (token: string) => Promise<boolean>;
  }

  interface FastifyRequest {
    user?: {
      id: string;
      email: string;
      name: string;
      [key: string]: any;
    };
  }
}

export type ServerInstance = FastifyInstance<
  RawServerDefault,
  RawRequestDefaultExpression<RawServerDefault>,
  RawReplyDefaultExpression<RawServerDefault>,
  FastifyBaseLogger,
  JsonSchemaToTsProvider
>;

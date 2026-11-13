# Task Service Architecture Documentation

## Overview

The `task-service` package is a **task scheduling and management service** built on **BullMQ** and **Redis**. It provides a clean, type-safe interface for defining, scheduling, and executing asynchronous tasks.

**Technology Stack:**
- **BullMQ**: High-performance queue system
- **Redis**: Job storage and queue backend
- **TypeScript**: Full type safety

## Core Design Principles

### 1. Clean API
The service provides a simple, intuitive API that abstracts away BullMQ complexity:
- Easy task definition and scheduling
- Type-safe job payloads
- Comprehensive task management capabilities

### 2. Separation of Concerns
- **TaskService**: Public API for scheduling and managing tasks
- **Queue Manager**: Redis connection and BullMQ queue lifecycle
- **Worker**: Separate process for task execution
- **Config**: Redis configuration and service options

### 3. Type Safety
Full TypeScript support with well-defined interfaces ensures compile-time safety and better developer experience. Job types are centrally defined to ensure consistency between task producers and consumers.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Application Layer                      │
│              (API Server, Worker Process)                   │
└─────────────┬───────────────────────────────────┬───────────┘
              │                                   │
              │ schedules tasks                   │ processes tasks
              ▼                                   ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│      TaskService API        │   │         Worker              │
│  ┌──────────────────────┐   │   │  ┌──────────────────────┐   │
│  │ - define()           │   │   │  │ - Fetches jobs       │   │
│  │ - schedule()         │   │   │  │ - Executes handlers  │   │
│  │ - cancel()           │   │   │  │ - Reports results    │   │
│  │ - find()             │   │   │  │ - Handles retries    │   │
│  │ - getTask()          │   │   │  └──────────────────────┘   │
│  │ - getStats()         │   │   └──────────────┬──────────────┘
│  └──────────────────────┘   │                  │
└──────────────┬──────────────┘                  │
               │                                 │
               │ uses Queue Manager              │
               ▼                                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    Queue Manager                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  - Creates and manages BullMQ Queue instance         │   │
│  │  - Manages Redis connections                         │   │
│  │  - Handles queue events and monitoring               │   │
│  │  - Singleton pattern for shared connections          │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ persists to
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                         Redis                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  - Job storage and queuing                           │   │
│  │  - Job state management                              │   │
│  │  - Delayed/scheduled jobs                            │   │
│  │  - Job retry and failure tracking                    │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. Configuration (`src/config.ts`)

Simple configuration for Redis connection and service options:

```typescript
// Redis configuration
export type BullConfig = {
  host: string;
  port: number;
  db?: number;
  password?: string;
};

// Task service configuration
export type Config = {
  redis: BullConfig;
  runJobs?: boolean;
  workerType?: {
    enableFilter: boolean;
    type?: string;
  };
  maxConcurrency?: number;
};
```

**Example Usage:**
```typescript
const config: Config = {
  redis: {
    host: 'localhost',
    port: 6379,
    db: 0,
  },
  runJobs: true,
  maxConcurrency: 10,
};
```

### 2. TaskService API (`src/taskService.ts`)

The main service interface that applications interact with:

```typescript
export type TaskService = {
  // Define a task handler
  define<T extends JobName>({
    taskName,
    handler,
  }: {
    taskName: T;
    handler: TaskHandler<T>;
  }): void;

  // Schedule a one-time task
  schedule<T extends JobName>(
    taskName: T,
    data: JobPayloadMap[T],
    options?: ScheduleOptions
  ): Promise<{ id: string; name: string }>;

  // Cancel a scheduled task
  cancel(taskId: string): Promise<boolean>;

  // Find tasks by criteria
  find(options?: FindTasksOptions): Promise<TaskInfo[]>;

  // Get specific task
  getTask(taskId: string): Promise<TaskInfo | null>;

  // Get queue statistics
  getStats(): Promise<{ name: string; counts: object }>;
};
```

**Creating a TaskService Instance:**
```typescript
import { createTaskService } from '@practice/task-service';

const taskService = createTaskService(config);
```

### 3. Queue Manager (`src/queue/queue.manager.ts`)

Manages the BullMQ Queue lifecycle and Redis connections using a singleton pattern:

- **Singleton Pattern**: Ensures only one queue instance exists
- **Connection Management**: Creates and reuses Redis connections
- **Event Monitoring**: Sets up queue event listeners
- **Graceful Cleanup**: Provides methods to close connections

**Key Features:**
- Default retry configuration (3 attempts, exponential backoff)
- Automatic job cleanup (completed: 24h, failed: 7 days)
- Event logging for completed/failed jobs

### 4. Job Types (`src/queue/queue.types.ts`)

Central definition of all job types for type safety:

```typescript
export enum JobName {
  GRAMMAR_CHECK = 'grammar-check',
  TRANSLATE_CHECK = 'translate-check',
}

export type JobPayloadMap = {
  [JobName.GRAMMAR_CHECK]: {
    userId: string;
    text: string;
    language: string;
  };
  [JobName.TRANSLATE_CHECK]: {
    userId: string;
    text: string;
    sourceLang: string;
    targetLang: string;
  };
};
```

**Benefits:**
- Type-safe task scheduling
- Autocomplete for job names and payloads
- Compile-time validation
- Consistent types across producers and consumers

### 5. Worker (`src/worker.ts`)

Separate process that executes background tasks:

```typescript
export interface WorkerConfig {
  taskService: TaskService;
  redisConfig: BullConfig;
  concurrency?: number;
  rateLimit?: {
    max: number;
    duration: number;
  };
}

export function createWorker(config: WorkerConfig): Worker;
```

**Worker Features:**
- Concurrent job processing (configurable)
- Rate limiting support
- Automatic retries on failure
- Event handlers for job lifecycle

---

## Usage Examples

### Basic Task Definition and Scheduling

```typescript
import { createTaskService, JobName } from '@practice/task-service';

const taskService = createTaskService({
  redis: {
    host: 'localhost',
    port: 6379,
  },
});

// Define task handler
taskService.define({
  taskName: JobName.GRAMMAR_CHECK,
  handler: async ({ data, job }) => {
    console.log('Processing grammar check:', data);
    // Perform grammar check...
    return { corrections: [] };
  },
});

// Schedule a task
const task = await taskService.schedule(
  JobName.GRAMMAR_CHECK,
  {
    userId: 'user-123',
    text: 'Hello world',
    language: 'en',
  },
  {
    delay: 5000, // 5 second delay
    priority: 1, // High priority
    attempts: 5, // Override default retry
  }
);

console.log('Task scheduled:', task.id);
```

### Worker Process

```typescript
import { createTaskService, createWorker, JobName } from '@practice/task-service';

const config = {
  redis: {
    host: 'localhost',
    port: 6379,
  },
};

const taskService = createTaskService(config);

// Define handlers
taskService.define({
  taskName: JobName.GRAMMAR_CHECK,
  handler: async ({ data }) => {
    // Process task...
    return { success: true };
  },
});

// Create worker
const worker = createWorker({
  taskService,
  redisConfig: config.redis,
  concurrency: 5,
  rateLimit: {
    max: 10,
    duration: 1000, // 10 jobs per second
  },
});

// Worker automatically starts processing
```

### Fastify Plugin Integration

```typescript
import Fastify from 'fastify';
import { taskServicePlugin } from '@practice/task-service';

const app = Fastify();

await app.register(taskServicePlugin, {
  config: {
    redis: {
      host: 'localhost',
      port: 6379,
    },
  },
});

// Use in routes
app.post('/grammar-check', async (request, reply) => {
  const task = await app.taskService.schedule(
    JobName.GRAMMAR_CHECK,
    request.body
  );
  return { taskId: task.id };
});
```

### Task Management

```typescript
// Find tasks
const tasks = await taskService.find({
  userId: 'user-123',
  taskName: JobName.GRAMMAR_CHECK,
  limit: 10,
});

// Get specific task
const task = await taskService.getTask('job-id-123');

// Cancel task
await taskService.cancel('job-id-123');

// Get queue statistics
const stats = await taskService.getStats();
console.log('Queue stats:', stats);
```

---

## Data Flow

### Task Scheduling Flow

```
1. Application calls taskService.schedule()
   ↓
2. TaskService creates BullMQ job with data
   ↓
3. Job is serialized and stored in Redis
   ↓
4. BullMQ schedules job (immediately or delayed)
   ↓
5. Returns job ID to application
```

### Task Execution Flow

```
1. Worker fetches next job from Redis
   ↓
2. Worker finds registered handler for job name
   ↓
3. Handler is executed with job data
   ↓
4. On success:
   - Result is stored
   - Job marked as completed
   - 'completed' event fired
   
5. On failure:
   - Error is logged
   - Job is retried (if attempts remaining)
   - Job marked as failed (after all attempts)
   - 'failed' event fired
```

---

## Key Features

### 1. Type-Safe Job Definitions

All job types are centrally defined in `queue.types.ts`, ensuring:
- No typos in job names
- Correct payload structure
- Compile-time validation

### 2. Automatic Retries

Failed jobs are automatically retried with:
- Configurable retry attempts (default: 3)
- Exponential backoff (default: 3s)
- Per-job override options

### 3. Job Scheduling

Schedule jobs for:
- Immediate execution
- Delayed execution (delay in ms)
- Specific time (scheduledTime option)
- With priority (lower number = higher priority)

### 4. Job Management

Comprehensive job management:
- Query jobs by user, name, status
- Cancel pending jobs
- Get detailed job information
- Monitor queue statistics

### 5. Graceful Shutdown

Proper cleanup on application shutdown:
- Closes queue connections
- Waits for in-flight jobs
- Releases Redis connections

---

## Configuration Best Practices

### Development Environment

```typescript
const config: Config = {
  redis: {
    host: 'localhost',
    port: 6379,
    db: 0, // Use separate DB for dev
  },
  maxConcurrency: 2,
};
```

### Production Environment

```typescript
const config: Config = {
  redis: {
    host: process.env.REDIS_HOST,
    port: parseInt(process.env.REDIS_PORT || '6379'),
    password: process.env.REDIS_PASSWORD,
    db: 0,
  },
  maxConcurrency: 10,
};
```

### Testing Environment

For testing, use a separate Redis database:

```typescript
const config: Config = {
  redis: {
    host: 'localhost',
    port: 6379,
    db: 15, // Separate DB for tests
  },
};
```

---

## Deployment Architecture

### Recommended Setup

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   API Server    │     │   API Server    │     │   API Server    │
│  (Task Producer)│     │  (Task Producer)│     │  (Task Producer)│
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
                                 │
                                 │ Schedule Tasks
                                 ▼
                         ┌───────────────┐
                         │     Redis     │
                         │    (Queue)    │
                         └───────┬───────┘
                                 │
                                 │ Fetch Tasks
                                 ▼
         ┌───────────────────────┬───────────────────────┐
         │                       │                       │
┌────────▼────────┐     ┌────────▼────────┐     ┌────────▼────────┐
│ Worker Process  │     │ Worker Process  │     │ Worker Process  │
│ (Task Consumer) │     │ (Task Consumer) │     │ (Task Consumer) │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

**Key Points:**
- Multiple API servers can schedule tasks
- Multiple workers can process tasks in parallel
- Single Redis instance acts as central queue
- Workers can be scaled independently of API servers

### Process Separation

**API Server (Task Producer):**
- Only schedules tasks
- Never processes tasks
- Fast response times

**Worker Process (Task Consumer):**
- Only processes tasks
- Runs task handlers
- Can be resource-intensive

**Benefits:**
- Independent scaling
- Resource isolation
- Better reliability
- Easier monitoring

---

## Monitoring and Observability

### Queue Statistics

```typescript
const stats = await taskService.getStats();
// Returns: { name: 'taskService', counts: { waiting: 5, active: 2, completed: 100, failed: 3 } }
```

### Event Monitoring

The Queue Manager automatically logs:
- Job completion: `Job {jobId} completed`
- Job failure: `Job {jobId} failed: {reason}`
- Redis connection status

### Production Monitoring

For production, consider:
- BullBoard UI for queue visualization
- Custom metrics exporters (Prometheus)
- Alert on high failure rates
- Monitor Redis memory usage

---

## Error Handling

### Retry Strategy

Jobs automatically retry on failure:
```typescript
{
  attempts: 3, // Total attempts
  backoff: {
    type: 'exponential',
    delay: 3000, // 3s, 6s, 12s
  }
}
```

### Custom Retry Logic

Override per job:
```typescript
await taskService.schedule(JobName.GRAMMAR_CHECK, data, {
  attempts: 5,
  priority: 1,
});
```

### Failed Job Handling

Failed jobs are:
- Kept in Redis for 7 days
- Queryable via `find()` method
- Include failure reason and stack trace

---

## Performance Considerations

### Concurrency

Adjust worker concurrency based on:
- Available CPU cores
- Task resource requirements
- Redis connection limits

```typescript
createWorker({
  concurrency: 5, // Process 5 jobs simultaneously
});
```

### Rate Limiting

Prevent overwhelming external services:
```typescript
createWorker({
  rateLimit: {
    max: 10,
    duration: 1000, // 10 jobs per second
  },
});
```

### Job Cleanup

Automatic cleanup prevents Redis bloat:
- Completed jobs: 24 hours or 1000 jobs
- Failed jobs: 7 days

Adjust in `queue.manager.ts` if needed.

---

## Testing

### Unit Testing

Mock the TaskService for unit tests:
```typescript
const mockTaskService = {
  schedule: jest.fn(),
  cancel: jest.fn(),
  // ...
};
```

### Integration Testing

Use a test Redis instance:
```typescript
const testConfig = {
  redis: {
    host: 'localhost',
    port: 6379,
    db: 15, // Test database
  },
};

// Clean up after tests
afterAll(async () => {
  await taskService._closeConnections();
});
```

---

## Migration Notes

### From Previous Version

The simplified architecture removes:
- Backend abstraction layer (unused)
- Agenda/Test backend adapters (unused)
- job.service.ts (duplicate implementation)

**Breaking Changes:**
1. Config structure changed:
   ```typescript
   // Old
   { backend: 'bull', host: '...', ... }
   
   // New
   { redis: { host: '...', ... } }
   ```

2. Worker requires redisConfig:
   ```typescript
   // Old
   createWorker({ taskService })
   
   // New
   createWorker({ taskService, redisConfig })
   ```

3. Removed exports:
   - `AgendaConfig`
   - `TestConfig`

---

## Future Enhancements

Potential improvements:
- Recurring/cron jobs support
- Job prioritization queues
- Dead letter queue for permanently failed jobs
- Enhanced monitoring and metrics
- Job result persistence
- Transaction support

---

## Summary

The task-service package provides a clean, production-ready task queue built on BullMQ and Redis. It offers:

✅ **Type Safety**: Full TypeScript support with centralized job types  
✅ **Simple API**: Clean interface abstracting BullMQ complexity  
✅ **Reliability**: Automatic retries, error handling, graceful shutdown  
✅ **Scalability**: Multiple workers, rate limiting, concurrency control  
✅ **Observability**: Event monitoring, statistics, logging  
✅ **Production Ready**: Battle-tested BullMQ with Redis backend  

The architecture is straightforward, maintainable, and suitable for production workloads.

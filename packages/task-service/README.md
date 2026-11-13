# Task Service API

Simplified task scheduling and management for your application.

## Installation

```bash
pnpm add @practice/task-service
```

## Usage

### For API Server (with Fastify)

```typescript
import { taskServicePlugin } from '@practice/task-service';

app.register(taskServicePlugin);

// In your routes
app.post('/grammar/check', async (request, reply) => {
  // Schedule a task
  const task = await request.server.taskService.schedule('grammar-check', {
    text: request.body.text,
    userId: request.user.id,
  });

  return { taskId: task.id };
});

// Find tasks for a user
app.get('/tasks', async (request, reply) => {
  const tasks = await request.server.taskService.find({
    userId: request.user.id,
    limit: 10,
  });

  return { tasks };
});

// Cancel a task
app.delete('/tasks/:id', async (request, reply) => {
  const cancelled = await request.server.taskService.cancel(request.params.id);
  return { cancelled };
});
```

### For Worker Process

```typescript
import { createWorker } from '@practice/task-service';

const worker = createWorker({
  processors: {
    'grammar-check': async (job) => {
      // Process the job
      const { text, userId } = job.data;
      // ... your processing logic
      return result;
    },
  },
  concurrency: 5,
});
```

### Standalone Usage (without Fastify)

```typescript
import { createTaskService } from '@practice/task-service';

const taskService = createTaskService();

// Schedule a task
await taskService.schedule('grammar-check', { text: 'Hello', userId: '123' });

// Find tasks
const tasks = await taskService.find({ userId: '123', taskName: 'grammar-check' });

// Cancel a task
await taskService.cancel(taskId);
```

## API

### `taskService.schedule(taskName, data, options?)`

Schedule a task to be processed.

**Parameters:**
- `taskName` - Name of the task
- `data` - Task-specific data
- `options` - Optional scheduling options
  - `delay` - Delay in milliseconds
  - `priority` - Priority (lower = higher priority)
  - `scheduledTime` - Schedule for specific time (Date)
  - `attempts` - Number of retry attempts
  - `taskId` - Custom task ID for idempotency

**Returns:** `{ id: string, name: string }`

### `taskService.cancel(taskId)`

Cancel a scheduled or running task.

**Parameters:**
- `taskId` - ID of the task to cancel

**Returns:** `boolean` - true if cancelled, false if not found

### `taskService.find(options)`

Find tasks by criteria.

**Parameters:**
- `options.userId` - Filter by user ID
- `options.taskName` - Filter by task name
- `options.limit` - Max results (default: 100)
- `options.offset` - Offset for pagination

**Returns:** Array of `TaskInfo` objects

### `taskService.getTask(taskId)`

Get detailed information about a specific task.

**Parameters:**
- `taskId` - ID of the task

**Returns:** `TaskInfo | null`

### `taskService.getStats()`

Get queue statistics.

**Returns:** Object with queue name and job counts

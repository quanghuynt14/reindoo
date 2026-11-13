# Good Morning Task

A scheduled recurring task that prints "Good morning!" at 9am every day.

## Implementation

### Task Handler
Located in [goodMorning.task.ts](goodMorning.task.ts), this task:
- Runs daily at 9:00 AM (configured with cron pattern `0 9 * * *`)
- Prints "Good morning!" to the console with a timestamp
- Returns a success response

### Registration
The task is registered in the worker process ([worker.ts](../../worker.ts)):
1. The handler is registered with `registerGoodMorningTask(taskService)`
2. The recurring schedule is set up using BullMQ's repeat options with a cron pattern

### Cron Pattern
- Pattern: `0 9 * * *`
- Meaning: At 09:00 AM every day
- Format: `minute hour day-of-month month day-of-week`

### Job Type
The task is defined in the task-service queue types:
- Job name: `"good-morning"`
- Job data type: `GoodMorningJobData` with optional `message` field

## Testing

To test the task immediately without waiting for 9am, you can modify the cron pattern in [worker.ts](../../worker.ts):
- Every minute: `* * * * *`
- Every 5 minutes: `*/5 * * * *`
- Every hour: `0 * * * *`

## Modifying the Message

To customize the message, update the data passed when scheduling the task in [worker.ts](../../worker.ts):
```typescript
await taskService.schedule(
  "good-morning",
  { message: "Your custom message here!" },
  {
    repeat: {
      pattern: "0 9 * * *",
      key: "good-morning-daily",
    },
  }
);
```

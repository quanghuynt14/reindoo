// Redis/BullMQ configuration
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

// Define all job names as union type for type safety
export type JobName
  = | 'grammar-check'
    | 'grammar-store-result'
    | 'translate-check'
    | 'translate-store-result'
    | 'dictionary-search'
    | 'game-generate-question'
    | 'send-email'
    | 'send-notification'
    | 'process-analytics'
    | 'cleanup-old-data'
    | 'good-morning';

// Define job data types for each job
export type GrammarCheckJobData = {
  text: string;
  userId: string;
  language?: string;
};

export type GrammarStoreResultJobData = {
  userId: string;
  result: any;
  timestamp: Date;
};

export type TranslateCheckJobData = {
  text: string;
  userId: string;
  fromLanguage?: string;
  toLanguage?: string;
};

export type TranslateStoreResultJobData = {
  userId: string;
  result: any;
  timestamp: Date;
};

export type DictionarySearchJobData = {
  word: string;
  userId: string;
};

export type GameGenerateQuestionJobData = {
  userId: string;
  type: 'dictionary' | 'grammar' | 'translation';
  difficulty?: string;
};

export type SendEmailJobData = {
  to: string;
  subject: string;
  body: string;
  userId: string;
};

export type SendNotificationJobData = {
  userId: string;
  title: string;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
};

export type ProcessAnalyticsJobData = {
  userId: string;
  eventType: string;
  metadata: Record<string, any>;
};

export type CleanupOldDataJobData = {
  olderThanDays: number;
};

export type GoodMorningJobData = {
  message?: string;
};

// Union of all job data types
export type JobData
  = | GrammarCheckJobData
    | GrammarStoreResultJobData
    | TranslateCheckJobData
    | TranslateStoreResultJobData
    | DictionarySearchJobData
    | GameGenerateQuestionJobData
    | SendEmailJobData
    | SendNotificationJobData
    | ProcessAnalyticsJobData
    | CleanupOldDataJobData
    | GoodMorningJobData;

// Type-safe job payload mapping
export type JobPayloadMap = {
  'grammar-check': GrammarCheckJobData;
  'grammar-store-result': GrammarStoreResultJobData;
  'translate-check': TranslateCheckJobData;
  'translate-store-result': TranslateStoreResultJobData;
  'dictionary-search': DictionarySearchJobData;
  'game-generate-question': GameGenerateQuestionJobData;
  'send-email': SendEmailJobData;
  'send-notification': SendNotificationJobData;
  'process-analytics': ProcessAnalyticsJobData;
  'cleanup-old-data': CleanupOldDataJobData;
  'good-morning': GoodMorningJobData;
};

// Queue configuration
export const QUEUE_NAMES = {
  MAIN: 'practice-queue',
} as const;

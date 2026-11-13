// Game configuration constants

// Minimum number of items required in user history to generate questions
// This ensures we have enough items to create meaningful multiple-choice options
export const MIN_ITEMS_FOR_QUESTIONS = 4;

// Number of wrong answer options for multiple choice questions
// All questions use 4 total options (1 correct + 3 wrong)
export const WRONG_OPTIONS_COUNT = 3;

// Maximum number of history items to fetch for question generation
// This limits memory usage while providing enough variety for questions
export const MAX_HISTORY_LIMIT = 100;

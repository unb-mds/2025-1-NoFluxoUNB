// Setup file for Jest tests
process.env.NODE_ENV = 'test';

// Mock environment variables
process.env.SUPABASE_URL = 'https://test.supabase.co';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'test-key';
process.env.ML_PUSH_API_KEY = 'test-ml-push-api-key';

// Global test timeout
jest.setTimeout(10000); 
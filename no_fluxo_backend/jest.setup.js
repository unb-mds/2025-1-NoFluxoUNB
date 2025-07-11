// Setup file for Jest tests
process.env.NODE_ENV = 'test';

// Mock environment variables
process.env.SUPABASE_URL = 'https://test.supabase.co';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'test-key';

// Global test timeout
jest.setTimeout(10000); 
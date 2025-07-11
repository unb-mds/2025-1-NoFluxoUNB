module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: [
    '<rootDir>/tests-ts/**/*.test.ts',
    '<rootDir>/no_fluxo_backend/tests/**/*.test.ts'
  ],
  moduleFileExtensions: ['ts', 'js', 'json', 'node'],
  roots: ['<rootDir>/no_fluxo_backend/src', '<rootDir>/tests-ts'],
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  setupFilesAfterEnv: ['<rootDir>/no_fluxo_backend/jest.setup.js'],
  collectCoverageFrom: [
    'no_fluxo_backend/src/**/*.ts',
    '!no_fluxo_backend/src/**/*.d.ts'
  ],
  coverageDirectory: 'coverage',
  coverageReporters: [
    'text',
    'lcov',
    'html'
  ],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/no_fluxo_backend/src/$1'
  }
}; 
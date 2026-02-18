# 13 - Testing Strategy: Flutter to SvelteKit Migration

> **NoFluxo UNB** - Comprehensive Testing Guide for SvelteKit

This document outlines the complete testing strategy for the migrated SvelteKit application, including unit tests, component tests, integration tests, and end-to-end tests.

---

## Table of Contents

1. [Testing Stack Overview](#1-testing-stack-overview)
2. [Vitest Configuration](#2-vitest-configuration)
3. [Unit Tests](#3-unit-tests)
4. [Component Tests](#4-component-tests)
5. [Integration Tests](#5-integration-tests)
6. [E2E Tests with Playwright](#6-e2e-tests-with-playwright)
7. [Testing Patterns](#7-testing-patterns)
8. [CI/CD Integration](#8-cicd-integration)
9. [Coverage Reports](#9-coverage-reports)
10. [Testing Best Practices](#10-testing-best-practices)

---

## Current State Analysis

### Flutter Test Coverage

The existing Flutter app has minimal test coverage:

```dart
// test/widget_test.dart - Only a basic counter smoke test
testWidgets('Counter increments smoke test', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  expect(find.text('0'), findsOneWidget);
});
```

### Migration Opportunity

This migration presents an opportunity to establish a robust testing foundation from the start, ensuring long-term maintainability and reliability.

---

## 1. Testing Stack Overview

### Tools and Libraries

| Tool | Purpose | Version |
|------|---------|---------|
| **Vitest** | Unit & component testing | ^2.0.0 |
| **@testing-library/svelte** | Component testing utilities | ^5.0.0 |
| **Playwright** | End-to-end testing | ^1.40.0 |
| **MSW** (Mock Service Worker) | API mocking | ^2.0.0 |
| **@vitest/coverage-v8** | Code coverage | ^2.0.0 |
| **@faker-js/faker** | Test data generation | ^8.0.0 |

### Testing Pyramid

```
         ╱╲
        ╱  ╲
       ╱ E2E╲        (10%) Critical user flows
      ╱──────╲
     ╱        ╲
    ╱Integration╲    (20%) API & auth flows
   ╱────────────╲
  ╱              ╲
 ╱   Component    ╲  (30%) UI components
╱──────────────────╲
╱                    ╲
╱       Unit Tests     ╲ (40%) Stores, utils, helpers
╱──────────────────────────╲
```

### Installation

```bash
# Install testing dependencies
pnpm add -D vitest @vitest/coverage-v8 @testing-library/svelte @testing-library/jest-dom
pnpm add -D jsdom @types/testing-library__jest-dom
pnpm add -D msw @faker-js/faker

# Playwright (should be installed during project init)
pnpm add -D @playwright/test
npx playwright install
```

---

## 2. Vitest Configuration

### File: `vite.config.ts`

```typescript
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [sveltekit()],
  test: {
    // Enable globals (describe, it, expect)
    globals: true,
    
    // DOM environment for component tests
    environment: 'jsdom',
    
    // Setup files
    setupFiles: ['./src/tests/setup.ts'],
    
    // Include patterns
    include: ['src/**/*.{test,spec}.{js,ts}'],
    
    // Exclude patterns
    exclude: [
      'node_modules',
      'dist',
      '.svelte-kit',
      'e2e/**/*'
    ],
    
    // Coverage configuration
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      reportsDirectory: './coverage',
      include: ['src/**/*.{ts,svelte}'],
      exclude: [
        'src/**/*.test.ts',
        'src/**/*.spec.ts',
        'src/tests/**/*',
        'src/**/*.d.ts'
      ],
      thresholds: {
        lines: 80,
        branches: 75,
        functions: 80,
        statements: 80
      }
    },
    
    // Alias configuration
    alias: {
      $lib: '/src/lib',
      $app: '/src/app'
    },
    
    // Mock dependencies
    deps: {
      inline: [/svelte/]
    }
  }
});
```

### File: `src/tests/setup.ts`

```typescript
import '@testing-library/jest-dom/vitest';
import { vi } from 'vitest';

// Mock localStorage
const localStorageMock = {
  getItem: vi.fn(),
  setItem: vi.fn(),
  removeItem: vi.fn(),
  clear: vi.fn(),
  length: 0,
  key: vi.fn()
};
Object.defineProperty(window, 'localStorage', {
  value: localStorageMock
});

// Mock matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn()
  }))
});

// Mock IntersectionObserver
class MockIntersectionObserver {
  observe = vi.fn();
  disconnect = vi.fn();
  unobserve = vi.fn();
}
Object.defineProperty(window, 'IntersectionObserver', {
  writable: true,
  value: MockIntersectionObserver
});

// Mock ResizeObserver
class MockResizeObserver {
  observe = vi.fn();
  disconnect = vi.fn();
  unobserve = vi.fn();
}
Object.defineProperty(window, 'ResizeObserver', {
  writable: true,
  value: MockResizeObserver
});

// Reset all mocks before each test
beforeEach(() => {
  vi.clearAllMocks();
  localStorageMock.getItem.mockReturnValue(null);
});

// Clean up after each test
afterEach(() => {
  vi.restoreAllMocks();
});
```

### File: `vitest.config.ts` (Alternative Standalone Config)

```typescript
import { defineConfig } from 'vitest/config';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  plugins: [svelte({ hot: !process.env.VITEST })],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/tests/setup.ts'],
    include: ['src/**/*.{test,spec}.{js,ts}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov']
    }
  }
});
```

---

## 3. Unit Tests

### 3.1 Store Tests

#### File: `src/lib/stores/auth.test.ts`

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import { user, isAnonymous, isLoading, authActions } from './auth';

describe('Auth Store', () => {
  beforeEach(() => {
    // Reset stores to initial state
    user.set(null);
    isAnonymous.set(false);
    isLoading.set(false);
    vi.clearAllMocks();
  });

  describe('user store', () => {
    it('should have null as initial value', () => {
      expect(get(user)).toBeNull();
    });

    it('should update when setUser is called', () => {
      const mockUser = {
        id: '123',
        email: 'test@example.com',
        name: 'Test User'
      };
      
      authActions.setUser(mockUser);
      
      expect(get(user)).toEqual(mockUser);
    });

    it('should persist user to localStorage', () => {
      const mockUser = {
        id: '123',
        email: 'test@example.com'
      };
      
      authActions.setUser(mockUser);
      
      expect(localStorage.setItem).toHaveBeenCalledWith(
        'user',
        JSON.stringify(mockUser)
      );
    });

    it('should remove from localStorage when set to null', () => {
      authActions.setUser(null);
      
      expect(localStorage.removeItem).toHaveBeenCalledWith('user');
    });
  });

  describe('isAnonymous store', () => {
    it('should have false as initial value', () => {
      expect(get(isAnonymous)).toBe(false);
    });

    it('should update when setAnonymous is called', () => {
      authActions.setAnonymous(true);
      
      expect(get(isAnonymous)).toBe(true);
    });

    it('should persist to localStorage', () => {
      authActions.setAnonymous(true);
      
      expect(localStorage.setItem).toHaveBeenCalledWith(
        'isAnonymous',
        'true'
      );
    });
  });

  describe('isLoading store', () => {
    it('should have false as initial value', () => {
      expect(get(isLoading)).toBe(false);
    });

    it('should update when setLoading is called', () => {
      authActions.setLoading(true);
      
      expect(get(isLoading)).toBe(true);
    });
  });

  describe('logout action', () => {
    it('should clear all auth state', () => {
      // Setup: logged in user
      authActions.setUser({ id: '123', email: 'test@example.com' });
      authActions.setAnonymous(false);
      
      // Action
      authActions.logout();
      
      // Assert
      expect(get(user)).toBeNull();
      expect(get(isAnonymous)).toBe(false);
      expect(localStorage.removeItem).toHaveBeenCalledWith('user');
      expect(localStorage.removeItem).toHaveBeenCalledWith('isAnonymous');
    });
  });

  describe('initialize action', () => {
    it('should restore user from localStorage', () => {
      const savedUser = { id: '123', email: 'test@example.com' };
      vi.mocked(localStorage.getItem).mockImplementation((key) => {
        if (key === 'user') return JSON.stringify(savedUser);
        return null;
      });
      
      authActions.initialize();
      
      expect(get(user)).toEqual(savedUser);
    });

    it('should handle invalid JSON gracefully', () => {
      vi.mocked(localStorage.getItem).mockReturnValue('invalid-json');
      
      expect(() => authActions.initialize()).not.toThrow();
      expect(get(user)).toBeNull();
      expect(localStorage.removeItem).toHaveBeenCalledWith('user');
    });
  });
});
```

#### File: `src/lib/stores/fluxogram.test.ts`

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import {
  subjects,
  selectedSubject,
  completedSubjects,
  fluxogramActions
} from './fluxogram';
import type { Subject } from '$lib/types';

const mockSubjects: Subject[] = [
  {
    id: '1',
    code: 'FGA0001',
    name: 'Introdução à Engenharia',
    credits: 4,
    semester: 1,
    prerequisites: []
  },
  {
    id: '2',
    code: 'FGA0002',
    name: 'Cálculo 1',
    credits: 6,
    semester: 1,
    prerequisites: []
  },
  {
    id: '3',
    code: 'FGA0003',
    name: 'Cálculo 2',
    credits: 6,
    semester: 2,
    prerequisites: ['FGA0002']
  }
];

describe('Fluxogram Store', () => {
  beforeEach(() => {
    subjects.set([]);
    selectedSubject.set(null);
    completedSubjects.set(new Set());
  });

  describe('subjects', () => {
    it('should initialize as empty array', () => {
      expect(get(subjects)).toEqual([]);
    });

    it('should update when setSubjects is called', () => {
      fluxogramActions.setSubjects(mockSubjects);
      
      expect(get(subjects)).toEqual(mockSubjects);
    });
  });

  describe('selectedSubject', () => {
    it('should select a subject', () => {
      fluxogramActions.setSubjects(mockSubjects);
      fluxogramActions.selectSubject(mockSubjects[0]);
      
      expect(get(selectedSubject)).toEqual(mockSubjects[0]);
    });

    it('should deselect when called with same subject', () => {
      fluxogramActions.selectSubject(mockSubjects[0]);
      fluxogramActions.selectSubject(mockSubjects[0]);
      
      expect(get(selectedSubject)).toBeNull();
    });
  });

  describe('completedSubjects', () => {
    it('should toggle completion status', () => {
      fluxogramActions.toggleCompleted('FGA0001');
      
      expect(get(completedSubjects).has('FGA0001')).toBe(true);
      
      fluxogramActions.toggleCompleted('FGA0001');
      
      expect(get(completedSubjects).has('FGA0001')).toBe(false);
    });

    it('should mark multiple subjects as complete', () => {
      fluxogramActions.markAsCompleted(['FGA0001', 'FGA0002']);
      
      const completed = get(completedSubjects);
      expect(completed.has('FGA0001')).toBe(true);
      expect(completed.has('FGA0002')).toBe(true);
    });
  });

  describe('prerequisite checking', () => {
    it('should identify available subjects', () => {
      fluxogramActions.setSubjects(mockSubjects);
      fluxogramActions.markAsCompleted(['FGA0002']);
      
      const isAvailable = fluxogramActions.isSubjectAvailable('FGA0003');
      
      expect(isAvailable).toBe(true);
    });

    it('should identify unavailable subjects', () => {
      fluxogramActions.setSubjects(mockSubjects);
      // FGA0002 not completed, so FGA0003 should be unavailable
      
      const isAvailable = fluxogramActions.isSubjectAvailable('FGA0003');
      
      expect(isAvailable).toBe(false);
    });
  });
});
```

### 3.2 Utility Function Tests

#### File: `src/lib/utils/validation.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
import {
  isValidEmail,
  isValidPassword,
  formatCourseCode,
  calculateProgress
} from './validation';

describe('Validation Utils', () => {
  describe('isValidEmail', () => {
    it('should return true for valid email', () => {
      expect(isValidEmail('test@example.com')).toBe(true);
      expect(isValidEmail('user.name@domain.org')).toBe(true);
    });

    it('should return false for invalid email', () => {
      expect(isValidEmail('')).toBe(false);
      expect(isValidEmail('invalid')).toBe(false);
      expect(isValidEmail('no@domain')).toBe(false);
      expect(isValidEmail('@nodomain.com')).toBe(false);
    });

    it('should handle edge cases', () => {
      expect(isValidEmail('  ')).toBe(false);
      expect(isValidEmail(null as any)).toBe(false);
      expect(isValidEmail(undefined as any)).toBe(false);
    });
  });

  describe('isValidPassword', () => {
    it('should return true for valid password', () => {
      expect(isValidPassword('Password123!')).toBe(true);
      expect(isValidPassword('SecureP@ss1')).toBe(true);
    });

    it('should return false for weak password', () => {
      expect(isValidPassword('short')).toBe(false);      // too short
      expect(isValidPassword('nouppercase1!')).toBe(false);
      expect(isValidPassword('NOLOWERCASE1!')).toBe(false);
      expect(isValidPassword('NoNumbers!')).toBe(false);
    });
  });

  describe('formatCourseCode', () => {
    it('should format course codes correctly', () => {
      expect(formatCourseCode('fga0001')).toBe('FGA0001');
      expect(formatCourseCode('CIC1234')).toBe('CIC1234');
    });

    it('should trim whitespace', () => {
      expect(formatCourseCode('  FGA0001  ')).toBe('FGA0001');
    });
  });

  describe('calculateProgress', () => {
    it('should calculate percentage correctly', () => {
      expect(calculateProgress(5, 10)).toBe(50);
      expect(calculateProgress(3, 4)).toBe(75);
      expect(calculateProgress(0, 10)).toBe(0);
    });

    it('should handle edge cases', () => {
      expect(calculateProgress(0, 0)).toBe(0);
      expect(calculateProgress(5, 0)).toBe(0);
      expect(calculateProgress(10, 10)).toBe(100);
    });

    it('should cap at 100%', () => {
      expect(calculateProgress(15, 10)).toBe(100);
    });
  });
});
```

### 3.3 Type Guard Tests

#### File: `src/lib/types/guards.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
import {
  isUser,
  isSubject,
  isApiError,
  isCourse
} from './guards';

describe('Type Guards', () => {
  describe('isUser', () => {
    it('should return true for valid user object', () => {
      const validUser = {
        id: '123',
        email: 'test@example.com'
      };
      expect(isUser(validUser)).toBe(true);
    });

    it('should return true for user with optional fields', () => {
      const validUser = {
        id: '123',
        email: 'test@example.com',
        name: 'Test User',
        dadosFluxograma: { curso: 'engenharia' }
      };
      expect(isUser(validUser)).toBe(true);
    });

    it('should return false for invalid objects', () => {
      expect(isUser(null)).toBe(false);
      expect(isUser(undefined)).toBe(false);
      expect(isUser({})).toBe(false);
      expect(isUser({ id: '123' })).toBe(false);
      expect(isUser({ email: 'test@example.com' })).toBe(false);
    });

    it('should return false for wrong types', () => {
      expect(isUser({ id: 123, email: 'test@example.com' })).toBe(false);
      expect(isUser({ id: '123', email: 123 })).toBe(false);
    });
  });

  describe('isSubject', () => {
    it('should return true for valid subject', () => {
      const validSubject = {
        id: '1',
        code: 'FGA0001',
        name: 'Intro',
        credits: 4,
        semester: 1,
        prerequisites: []
      };
      expect(isSubject(validSubject)).toBe(true);
    });

    it('should return false for missing required fields', () => {
      expect(isSubject({ id: '1', code: 'FGA0001' })).toBe(false);
    });
  });

  describe('isApiError', () => {
    it('should identify API error responses', () => {
      const apiError = {
        error: true,
        message: 'Not found',
        status: 404
      };
      expect(isApiError(apiError)).toBe(true);
    });

    it('should return false for success responses', () => {
      const successResponse = {
        data: { id: '123' },
        status: 200
      };
      expect(isApiError(successResponse)).toBe(false);
    });
  });
});
```

---

## 4. Component Tests

### 4.1 Testing Library Setup

#### File: `src/tests/component-helpers.ts`

```typescript
import { render, type RenderResult } from '@testing-library/svelte';
import { writable, type Writable } from 'svelte/store';
import type { User } from '$lib/types';

// Helper to render with mock stores
export function renderWithStores<T extends Record<string, unknown>>(
  component: any,
  options: {
    props?: Record<string, unknown>;
    stores?: Partial<T>;
  } = {}
): RenderResult {
  return render(component, {
    props: options.props
  });
}

// Create mock auth store context
export function createMockAuthContext(overrides: Partial<User> = {}) {
  const defaultUser: User = {
    id: 'test-user-id',
    email: 'test@example.com',
    name: 'Test User',
    ...overrides
  };

  return {
    user: writable<User | null>(defaultUser),
    isAnonymous: writable(false),
    isLoading: writable(false)
  };
}

// Helper for waiting
export async function tick(): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

// Custom matchers for common assertions
export function getByTestIdSafe(
  container: HTMLElement,
  testId: string
): HTMLElement | null {
  return container.querySelector(`[data-testid="${testId}"]`);
}
```

### 4.2 Example Component Tests

#### File: `src/lib/components/ui/GradientCTAButton.test.ts`

```typescript
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import GradientCTAButton from './GradientCTAButton.svelte';

describe('GradientCTAButton', () => {
  it('should render button with text', () => {
    render(GradientCTAButton, {
      props: { text: 'Click Me' }
    });

    expect(screen.getByRole('button')).toHaveTextContent('Click Me');
  });

  it('should apply custom styles', () => {
    render(GradientCTAButton, {
      props: {
        text: 'Styled Button',
        fontSize: 24,
        borderRadius: 20,
        minWidth: '300px'
      }
    });

    const button = screen.getByRole('button');
    expect(button).toHaveStyle('--border-radius: 20px');
  });

  it('should dispatch click event when clicked', async () => {
    const handleClick = vi.fn();
    const { component } = render(GradientCTAButton, {
      props: { text: 'Click Me' }
    });

    component.$on('click', handleClick);
    await fireEvent.click(screen.getByRole('button'));

    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('should not dispatch click when disabled', async () => {
    const handleClick = vi.fn();
    const { component } = render(GradientCTAButton, {
      props: { text: 'Disabled', disabled: true }
    });

    component.$on('click', handleClick);
    await fireEvent.click(screen.getByRole('button'));

    expect(handleClick).not.toHaveBeenCalled();
  });

  it('should have disabled styles when disabled', () => {
    render(GradientCTAButton, {
      props: { text: 'Disabled', disabled: true }
    });

    const button = screen.getByRole('button');
    expect(button).toBeDisabled();
  });

  it('should apply gradient colors', () => {
    render(GradientCTAButton, {
      props: {
        text: 'Gradient',
        gradientColors: ['#ff0000', '#0000ff']
      }
    });

    const button = screen.getByRole('button');
    expect(button).toHaveStyle('--gradient-start: #ff0000');
    expect(button).toHaveStyle('--gradient-end: #0000ff');
  });
});
```

#### File: `src/lib/components/ui/GlassContainer.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import GlassContainer from './GlassContainer.svelte';

// Test wrapper component for slot content
import { tick } from 'svelte';

describe('GlassContainer', () => {
  it('should render with default props', async () => {
    const { container } = render(GlassContainer);
    
    const glassDiv = container.querySelector('.glass-container');
    expect(glassDiv).toBeInTheDocument();
  });

  it('should apply custom padding', () => {
    const { container } = render(GlassContainer, {
      props: { padding: '32px' }
    });

    const glassDiv = container.querySelector('.glass-container');
    expect(glassDiv).toHaveStyle('padding: 32px');
  });

  it('should apply custom border radius', () => {
    const { container } = render(GlassContainer, {
      props: { borderRadius: 24 }
    });

    const glassDiv = container.querySelector('.glass-container');
    expect(glassDiv).toHaveStyle('--border-radius: 24px');
  });

  it('should apply backdrop filter on mount', async () => {
    const { container } = render(GlassContainer, {
      props: { blurAmount: 15 }
    });

    await tick();

    const glassDiv = container.querySelector('.glass-container');
    expect(glassDiv).toHaveStyle('backdrop-filter: blur(15px)');
  });

  it('should render slot content', () => {
    // Using a test wrapper to test slot content
    const { container } = render(GlassContainer, {
      props: {},
      slots: {
        default: '<p data-testid="slot-content">Hello World</p>'
      }
    });

    // Note: Slot testing may require a wrapper component
    const glassDiv = container.querySelector('.glass-container');
    expect(glassDiv).toBeInTheDocument();
  });
});
```

#### File: `src/lib/components/ui/AppLogo.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import AppLogo from './AppLogo.svelte';

describe('AppLogo', () => {
  it('should render logo text', () => {
    render(AppLogo);
    
    expect(screen.getByText('NO')).toBeInTheDocument();
    expect(screen.getByText('FLUXO')).toBeInTheDocument();
  });

  it('should show icon by default', () => {
    const { container } = render(AppLogo);
    
    const icon = container.querySelector('.logo-icon');
    expect(icon).toBeInTheDocument();
    expect(icon).toHaveTextContent('N');
  });

  it('should hide icon when showIcon is false', () => {
    const { container } = render(AppLogo, {
      props: { showIcon: false }
    });
    
    const icon = container.querySelector('.logo-icon');
    expect(icon).not.toBeInTheDocument();
  });

  it('should apply custom font size', () => {
    const { container } = render(AppLogo, {
      props: { fontSize: 48 }
    });
    
    const logo = container.querySelector('.app-logo');
    expect(logo).toHaveStyle('--font-size: 48px');
  });

  it('should apply custom color', () => {
    const { container } = render(AppLogo, {
      props: { color: 'red' }
    });
    
    const logo = container.querySelector('.app-logo');
    expect(logo).toHaveStyle('--color: red');
  });
});
```

### 4.3 Mocking Stores in Component Tests

#### File: `src/tests/store-mocks.ts`

```typescript
import { vi } from 'vitest';
import { writable, readable, type Writable, type Readable } from 'svelte/store';
import type { User, Subject } from '$lib/types';

// Mock user store
export function createMockUserStore(initialValue: User | null = null) {
  const store = writable<User | null>(initialValue);
  
  return {
    ...store,
    setUser: vi.fn((user: User | null) => store.set(user)),
    logout: vi.fn(() => store.set(null))
  };
}

// Mock subjects store  
export function createMockSubjectsStore(subjects: Subject[] = []) {
  const store = writable<Subject[]>(subjects);
  
  return {
    ...store,
    load: vi.fn(),
    refresh: vi.fn()
  };
}

// Mock loading store
export function createMockLoadingStore(initial = false) {
  return writable<boolean>(initial);
}

// Generic mock store factory
export function mockStore<T>(initialValue: T): Writable<T> & {
  reset: () => void;
} {
  const store = writable<T>(initialValue);
  
  return {
    ...store,
    reset: () => store.set(initialValue)
  };
}

// Context key for testing
export const TEST_AUTH_CONTEXT = Symbol('test-auth-context');
```

#### File: `src/lib/components/UserProfile.test.ts`

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import { writable } from 'svelte/store';
import UserProfile from './UserProfile.svelte';

// Mock the auth store module
vi.mock('$lib/stores/auth', () => ({
  user: writable(null),
  isLoading: writable(false),
  authActions: {
    logout: vi.fn(),
    setUser: vi.fn()
  }
}));

import { user, authActions } from '$lib/stores/auth';

describe('UserProfile', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (user as any).set(null);
  });

  it('should show loading state', () => {
    render(UserProfile);
    
    expect(screen.getByText('Loading...')).toBeInTheDocument();
  });

  it('should show user info when logged in', () => {
    (user as any).set({
      id: '123',
      email: 'test@example.com',
      name: 'John Doe'
    });

    render(UserProfile);

    expect(screen.getByText('John Doe')).toBeInTheDocument();
    expect(screen.getByText('test@example.com')).toBeInTheDocument();
  });

  it('should call logout when logout button clicked', async () => {
    (user as any).set({
      id: '123',
      email: 'test@example.com',
      name: 'John Doe'
    });

    render(UserProfile);
    
    await fireEvent.click(screen.getByRole('button', { name: /logout/i }));

    expect(authActions.logout).toHaveBeenCalled();
  });

  it('should show login prompt when not logged in', () => {
    (user as any).set(null);
    
    render(UserProfile);

    expect(screen.getByText(/please login/i)).toBeInTheDocument();
  });
});
```

---

## 5. Integration Tests

### 5.1 API Service Tests with MSW

#### File: `src/tests/mocks/handlers.ts`

```typescript
import { http, HttpResponse } from 'msw';

const BASE_URL = 'http://localhost:3001/api';

// Mock data
export const mockUser = {
  id: '123',
  email: 'test@example.com',
  name: 'Test User'
};

export const mockSubjects = [
  {
    id: '1',
    code: 'FGA0001',
    name: 'Introdução à Engenharia',
    credits: 4,
    semester: 1,
    prerequisites: []
  },
  {
    id: '2',
    code: 'FGA0002',
    name: 'Cálculo 1',
    credits: 6,
    semester: 1,
    prerequisites: []
  }
];

export const mockCourses = [
  { id: '1', name: 'Engenharia de Software', code: 'ESW' },
  { id: '2', name: 'Engenharia Eletrônica', code: 'ELE' }
];

// API handlers
export const handlers = [
  // Auth endpoints
  http.post(`${BASE_URL}/auth/login`, async ({ request }) => {
    const body = await request.json() as { email: string; password: string };
    
    if (body.email === 'test@example.com' && body.password === 'password123') {
      return HttpResponse.json({
        user: mockUser,
        token: 'mock-jwt-token'
      });
    }
    
    return HttpResponse.json(
      { error: true, message: 'Invalid credentials' },
      { status: 401 }
    );
  }),

  http.post(`${BASE_URL}/auth/register`, async ({ request }) => {
    const body = await request.json() as { email: string; password: string; name: string };
    
    if (body.email === 'existing@example.com') {
      return HttpResponse.json(
        { error: true, message: 'Email already exists' },
        { status: 409 }
      );
    }
    
    return HttpResponse.json({
      user: { ...mockUser, email: body.email, name: body.name },
      token: 'mock-jwt-token'
    });
  }),

  http.post(`${BASE_URL}/auth/logout`, () => {
    return HttpResponse.json({ success: true });
  }),

  http.get(`${BASE_URL}/auth/me`, ({ request }) => {
    const authHeader = request.headers.get('Authorization');
    
    if (authHeader === 'Bearer mock-jwt-token') {
      return HttpResponse.json({ user: mockUser });
    }
    
    return HttpResponse.json(
      { error: true, message: 'Unauthorized' },
      { status: 401 }
    );
  }),

  // Subject endpoints
  http.get(`${BASE_URL}/subjects`, () => {
    return HttpResponse.json({ data: mockSubjects });
  }),

  http.get(`${BASE_URL}/subjects/:id`, ({ params }) => {
    const subject = mockSubjects.find(s => s.id === params.id);
    
    if (subject) {
      return HttpResponse.json({ data: subject });
    }
    
    return HttpResponse.json(
      { error: true, message: 'Subject not found' },
      { status: 404 }
    );
  }),

  // Course endpoints
  http.get(`${BASE_URL}/courses`, () => {
    return HttpResponse.json({ data: mockCourses });
  }),

  // User progress endpoints
  http.get(`${BASE_URL}/users/:userId/progress`, ({ params }) => {
    return HttpResponse.json({
      data: {
        userId: params.userId,
        completedSubjects: ['FGA0001'],
        totalCredits: 4,
        progress: 5
      }
    });
  }),

  http.post(`${BASE_URL}/users/:userId/progress`, async ({ params, request }) => {
    const body = await request.json() as { subjectId: string; completed: boolean };
    
    return HttpResponse.json({
      data: {
        userId: params.userId,
        subjectId: body.subjectId,
        completed: body.completed
      }
    });
  })
];
```

#### File: `src/tests/mocks/server.ts`

```typescript
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);

// Establish API mocking before all tests
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));

// Reset any request handlers between tests
afterEach(() => server.resetHandlers());

// Clean up after tests
afterAll(() => server.close());
```

#### File: `src/lib/services/auth.test.ts`

```typescript
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { server } from '../../tests/mocks/server';
import { http, HttpResponse } from 'msw';
import { authService } from './auth';

describe('AuthService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
  });

  describe('login', () => {
    it('should login successfully with valid credentials', async () => {
      const result = await authService.login('test@example.com', 'password123');

      expect(result.user).toEqual({
        id: '123',
        email: 'test@example.com',
        name: 'Test User'
      });
      expect(result.token).toBe('mock-jwt-token');
    });

    it('should throw error with invalid credentials', async () => {
      await expect(
        authService.login('wrong@example.com', 'wrongpassword')
      ).rejects.toThrow('Invalid credentials');
    });

    it('should store token in localStorage', async () => {
      await authService.login('test@example.com', 'password123');

      expect(localStorage.setItem).toHaveBeenCalledWith(
        'auth_token',
        'mock-jwt-token'
      );
    });

    it('should handle network errors', async () => {
      server.use(
        http.post('http://localhost:3001/api/auth/login', () => {
          return HttpResponse.error();
        })
      );

      await expect(
        authService.login('test@example.com', 'password123')
      ).rejects.toThrow();
    });
  });

  describe('register', () => {
    it('should register successfully', async () => {
      const result = await authService.register({
        email: 'new@example.com',
        password: 'password123',
        name: 'New User'
      });

      expect(result.user.email).toBe('new@example.com');
      expect(result.token).toBe('mock-jwt-token');
    });

    it('should throw error for existing email', async () => {
      await expect(
        authService.register({
          email: 'existing@example.com',
          password: 'password123',
          name: 'Existing User'
        })
      ).rejects.toThrow('Email already exists');
    });
  });

  describe('logout', () => {
    it('should clear token from localStorage', async () => {
      localStorage.setItem('auth_token', 'mock-jwt-token');
      
      await authService.logout();

      expect(localStorage.removeItem).toHaveBeenCalledWith('auth_token');
    });
  });

  describe('getCurrentUser', () => {
    it('should return user when authenticated', async () => {
      localStorage.setItem('auth_token', 'mock-jwt-token');
      
      const user = await authService.getCurrentUser();

      expect(user).toEqual({
        id: '123',
        email: 'test@example.com',
        name: 'Test User'
      });
    });

    it('should return null when not authenticated', async () => {
      server.use(
        http.get('http://localhost:3001/api/auth/me', () => {
          return HttpResponse.json(
            { error: true, message: 'Unauthorized' },
            { status: 401 }
          );
        })
      );

      const user = await authService.getCurrentUser();

      expect(user).toBeNull();
    });
  });
});
```

### 5.2 Auth Flow Integration Tests

#### File: `src/lib/features/auth/AuthFlow.test.ts`

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import { get } from 'svelte/store';
import LoginPage from '$lib/routes/login/+page.svelte';
import { user, isLoading } from '$lib/stores/auth';
import { goto } from '$app/navigation';

// Mock SvelteKit navigation
vi.mock('$app/navigation', () => ({
  goto: vi.fn()
}));

// Import MSW server
import '../../tests/mocks/server';

describe('Auth Flow Integration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    user.set(null);
    isLoading.set(false);
  });

  describe('Login Flow', () => {
    it('should complete full login flow', async () => {
      render(LoginPage);

      // Fill in form
      await fireEvent.input(
        screen.getByLabelText(/email/i),
        { target: { value: 'test@example.com' } }
      );
      await fireEvent.input(
        screen.getByLabelText(/password/i),
        { target: { value: 'password123' } }
      );

      // Submit form
      await fireEvent.click(screen.getByRole('button', { name: /login/i }));

      // Wait for navigation
      await waitFor(() => {
        expect(goto).toHaveBeenCalledWith('/dashboard');
      });

      // Verify user is set
      expect(get(user)).toEqual({
        id: '123',
        email: 'test@example.com',
        name: 'Test User'
      });
    });

    it('should show error for invalid credentials', async () => {
      render(LoginPage);

      await fireEvent.input(
        screen.getByLabelText(/email/i),
        { target: { value: 'wrong@example.com' } }
      );
      await fireEvent.input(
        screen.getByLabelText(/password/i),
        { target: { value: 'wrongpassword' } }
      );

      await fireEvent.click(screen.getByRole('button', { name: /login/i }));

      await waitFor(() => {
        expect(screen.getByText(/invalid credentials/i)).toBeInTheDocument();
      });

      expect(goto).not.toHaveBeenCalled();
      expect(get(user)).toBeNull();
    });

    it('should show loading state during submission', async () => {
      render(LoginPage);

      await fireEvent.input(
        screen.getByLabelText(/email/i),
        { target: { value: 'test@example.com' } }
      );
      await fireEvent.input(
        screen.getByLabelText(/password/i),
        { target: { value: 'password123' } }
      );

      const loginButton = screen.getByRole('button', { name: /login/i });
      fireEvent.click(loginButton);

      // Button should be disabled during loading
      expect(loginButton).toBeDisabled();
    });

    it('should validate email format', async () => {
      render(LoginPage);

      await fireEvent.input(
        screen.getByLabelText(/email/i),
        { target: { value: 'invalid-email' } }
      );
      await fireEvent.blur(screen.getByLabelText(/email/i));

      expect(screen.getByText(/invalid email/i)).toBeInTheDocument();
    });
  });
});
```

---

## 6. E2E Tests with Playwright

### 6.1 Setup and Configuration

#### File: `playwright.config.ts`

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  // Test directory
  testDir: './e2e',
  
  // Run tests in parallel
  fullyParallel: true,
  
  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,
  
  // Retry on CI only
  retries: process.env.CI ? 2 : 0,
  
  // Opt out of parallel tests on CI
  workers: process.env.CI ? 1 : undefined,
  
  // Reporter to use
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'playwright-report/results.json' }],
    process.env.CI ? ['github'] : ['list']
  ],
  
  // Shared settings for all projects
  use: {
    // Base URL to use in actions like `await page.goto('/')`
    baseURL: 'http://localhost:5173',
    
    // Collect trace when retrying the failed test
    trace: 'on-first-retry',
    
    // Screenshots on failure
    screenshot: 'only-on-failure',
    
    // Video recording
    video: 'on-first-retry'
  },
  
  // Configure projects for major browsers
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] }
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] }
    },
    
    // Mobile viewports
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] }
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] }
    }
  ],
  
  // Run local dev server before starting tests
  webServer: {
    command: 'pnpm dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000
  },
  
  // Global setup/teardown
  globalSetup: './e2e/global-setup.ts',
  globalTeardown: './e2e/global-teardown.ts'
});
```

#### File: `e2e/global-setup.ts`

```typescript
import { chromium, FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  console.log('Running global setup...');
  
  // Create auth state for authenticated tests
  const browser = await chromium.launch();
  const page = await browser.newPage();
  
  // Login and save state
  await page.goto('http://localhost:5173/login');
  await page.fill('[data-testid="email-input"]', 'test@example.com');
  await page.fill('[data-testid="password-input"]', 'password123');
  await page.click('[data-testid="login-button"]');
  
  // Wait for navigation after login
  await page.waitForURL('**/dashboard');
  
  // Save storage state
  await page.context().storageState({
    path: './e2e/.auth/user.json'
  });
  
  await browser.close();
  
  console.log('Global setup complete.');
}

export default globalSetup;
```

#### File: `e2e/global-teardown.ts`

```typescript
import { FullConfig } from '@playwright/test';
import fs from 'fs';
import path from 'path';

async function globalTeardown(config: FullConfig) {
  console.log('Running global teardown...');
  
  // Clean up auth state
  const authPath = './e2e/.auth/user.json';
  if (fs.existsSync(authPath)) {
    fs.unlinkSync(authPath);
  }
  
  console.log('Global teardown complete.');
}

export default globalTeardown;
```

### 6.2 Full User Flow Tests

#### File: `e2e/auth.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test.describe('Authentication', () => {
  test('should display login page', async ({ page }) => {
    await page.goto('/login');
    
    await expect(page.getByRole('heading', { name: /login/i })).toBeVisible();
    await expect(page.getByLabel(/email/i)).toBeVisible();
    await expect(page.getByLabel(/password/i)).toBeVisible();
  });

  test('should login successfully', async ({ page }) => {
    await page.goto('/login');
    
    await page.fill('[data-testid="email-input"]', 'test@example.com');
    await page.fill('[data-testid="password-input"]', 'password123');
    await page.click('[data-testid="login-button"]');
    
    // Should redirect to dashboard
    await expect(page).toHaveURL('/dashboard');
    await expect(page.getByText('Welcome')).toBeVisible();
  });

  test('should show error for invalid credentials', async ({ page }) => {
    await page.goto('/login');
    
    await page.fill('[data-testid="email-input"]', 'wrong@example.com');
    await page.fill('[data-testid="password-input"]', 'wrongpassword');
    await page.click('[data-testid="login-button"]');
    
    await expect(page.getByText(/invalid credentials/i)).toBeVisible();
    await expect(page).toHaveURL('/login');
  });

  test('should logout successfully', async ({ page }) => {
    // First login
    await page.goto('/login');
    await page.fill('[data-testid="email-input"]', 'test@example.com');
    await page.fill('[data-testid="password-input"]', 'password123');
    await page.click('[data-testid="login-button"]');
    await page.waitForURL('/dashboard');
    
    // Then logout
    await page.click('[data-testid="logout-button"]');
    
    await expect(page).toHaveURL('/');
  });

  test('should allow anonymous access', async ({ page }) => {
    await page.goto('/');
    
    await page.click('[data-testid="continue-anonymous-button"]');
    
    await expect(page).toHaveURL('/fluxograma');
    await expect(page.getByText(/anonymous mode/i)).toBeVisible();
  });
});
```

#### File: `e2e/fluxograma.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test.describe('Fluxograma', () => {
  test.beforeEach(async ({ page }) => {
    // Login before each test
    await page.goto('/login');
    await page.fill('[data-testid="email-input"]', 'test@example.com');
    await page.fill('[data-testid="password-input"]', 'password123');
    await page.click('[data-testid="login-button"]');
    await page.waitForURL('/dashboard');
  });

  test('should display course selection', async ({ page }) => {
    await page.goto('/fluxograma');
    
    await expect(page.getByRole('heading', { name: /seu fluxograma/i })).toBeVisible();
    await expect(page.getByTestId('course-selector')).toBeVisible();
  });

  test('should load subjects after course selection', async ({ page }) => {
    await page.goto('/fluxograma');
    
    await page.click('[data-testid="course-selector"]');
    await page.click('[data-testid="course-option-ESW"]');
    
    // Wait for subjects to load
    await expect(page.getByTestId('subject-grid')).toBeVisible();
    await expect(page.getByTestId('subject-card')).toHaveCount.greaterThan(0);
  });

  test('should mark subject as completed', async ({ page }) => {
    await page.goto('/fluxograma');
    
    // Select course first
    await page.click('[data-testid="course-selector"]');
    await page.click('[data-testid="course-option-ESW"]');
    await page.waitForSelector('[data-testid="subject-card"]');
    
    // Click on first subject
    const firstSubject = page.getByTestId('subject-card').first();
    await firstSubject.click();
    
    // Mark as completed
    await page.click('[data-testid="mark-completed-button"]');
    
    // Verify visual state change
    await expect(firstSubject).toHaveClass(/completed/);
  });

  test('should show prerequisites when hovering', async ({ page }) => {
    await page.goto('/fluxograma');
    
    await page.click('[data-testid="course-selector"]');
    await page.click('[data-testid="course-option-ESW"]');
    await page.waitForSelector('[data-testid="subject-card"]');
    
    // Hover on subject with prerequisites
    const subjectWithPrereqs = page.locator('[data-testid="subject-card"]').nth(5);
    await subjectWithPrereqs.hover();
    
    await expect(page.getByTestId('prereq-tooltip')).toBeVisible();
  });

  test('should persist progress across page reloads', async ({ page }) => {
    await page.goto('/fluxograma');
    
    await page.click('[data-testid="course-selector"]');
    await page.click('[data-testid="course-option-ESW"]');
    await page.waitForSelector('[data-testid="subject-card"]');
    
    // Mark subject as completed
    const firstSubject = page.getByTestId('subject-card').first();
    await firstSubject.click();
    await page.click('[data-testid="mark-completed-button"]');
    
    // Reload page
    await page.reload();
    
    // Verify progress persisted
    await expect(page.getByTestId('subject-card').first()).toHaveClass(/completed/);
  });
});
```

### 6.3 Visual Regression Tests

#### File: `e2e/visual.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test.describe('Visual Regression Tests', () => {
  test('home page matches snapshot', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    await expect(page).toHaveScreenshot('home-page.png', {
      fullPage: true,
      maxDiffPixels: 100
    });
  });

  test('login page matches snapshot', async ({ page }) => {
    await page.goto('/login');
    await page.waitForLoadState('networkidle');
    
    await expect(page).toHaveScreenshot('login-page.png');
  });

  test('dashboard matches snapshot', async ({ page }) => {
    // Use stored auth state
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    
    await expect(page).toHaveScreenshot('dashboard.png');
  });

  test('fluxograma matches snapshot', async ({ page }) => {
    await page.goto('/fluxograma');
    await page.click('[data-testid="course-selector"]');
    await page.click('[data-testid="course-option-ESW"]');
    await page.waitForSelector('[data-testid="subject-grid"]');
    await page.waitForLoadState('networkidle');
    
    await expect(page).toHaveScreenshot('fluxograma.png', {
      fullPage: true
    });
  });

  test('mobile navigation matches snapshot', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    
    // Open mobile menu
    await page.click('[data-testid="mobile-menu-button"]');
    await page.waitForSelector('[data-testid="mobile-nav"]');
    
    await expect(page).toHaveScreenshot('mobile-nav.png');
  });

  test('dark mode matches snapshot', async ({ page }) => {
    await page.goto('/');
    
    // Toggle dark mode
    await page.click('[data-testid="theme-toggle"]');
    await page.waitForTimeout(300); // Wait for transition
    
    await expect(page).toHaveScreenshot('home-dark-mode.png', {
      fullPage: true
    });
  });
});
```

#### File: `e2e/fixtures/auth.fixture.ts`

```typescript
import { test as base } from '@playwright/test';

// Extend base test with authentication fixture
export const test = base.extend<{
  authenticatedPage: any;
}>({
  authenticatedPage: async ({ page }, use) => {
    // Login before test
    await page.goto('/login');
    await page.fill('[data-testid="email-input"]', 'test@example.com');
    await page.fill('[data-testid="password-input"]', 'password123');
    await page.click('[data-testid="login-button"]');
    await page.waitForURL('/dashboard');
    
    // Use the authenticated page in tests
    await use(page);
    
    // Cleanup after test - logout
    await page.click('[data-testid="logout-button"]');
  }
});

export { expect } from '@playwright/test';
```

---

## 7. Testing Patterns

### 7.1 Arrange-Act-Assert (AAA)

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import { subjects, fluxogramActions } from './fluxogram';

describe('Fluxogram Store - AAA Pattern', () => {
  beforeEach(() => {
    // Reset state before each test
    subjects.set([]);
  });

  it('should add subject to list', () => {
    // Arrange - Set up test data and preconditions
    const newSubject = {
      id: '1',
      code: 'FGA0001',
      name: 'Test Subject',
      credits: 4,
      semester: 1,
      prerequisites: []
    };

    // Act - Perform the action being tested
    fluxogramActions.addSubject(newSubject);

    // Assert - Verify the expected outcome
    const currentSubjects = get(subjects);
    expect(currentSubjects).toHaveLength(1);
    expect(currentSubjects[0]).toEqual(newSubject);
  });
});
```

### 7.2 Test Fixtures

#### File: `src/tests/fixtures/users.ts`

```typescript
import { faker } from '@faker-js/faker';
import type { User } from '$lib/types';

// Fixed test user for deterministic tests
export const testUser: User = {
  id: 'test-user-123',
  email: 'test@example.com',
  name: 'Test User',
  createdAt: '2024-01-01T00:00:00.000Z'
};

// Factory function for custom users
export function createUser(overrides: Partial<User> = {}): User {
  return {
    id: faker.string.uuid(),
    email: faker.internet.email(),
    name: faker.person.fullName(),
    createdAt: faker.date.past().toISOString(),
    ...overrides
  };
}

// Multiple users for list tests
export function createUsers(count: number): User[] {
  return Array.from({ length: count }, () => createUser());
}
```

#### File: `src/tests/fixtures/subjects.ts`

```typescript
import { faker } from '@faker-js/faker';
import type { Subject } from '$lib/types';

const COURSE_PREFIXES = ['FGA', 'CIC', 'MAT', 'FIS', 'ENE'];

export const testSubject: Subject = {
  id: 'test-subject-1',
  code: 'FGA0001',
  name: 'Introdução à Engenharia',
  credits: 4,
  semester: 1,
  prerequisites: []
};

export function createSubject(overrides: Partial<Subject> = {}): Subject {
  const prefix = faker.helpers.arrayElement(COURSE_PREFIXES);
  const number = faker.number.int({ min: 1, max: 999 }).toString().padStart(4, '0');
  
  return {
    id: faker.string.uuid(),
    code: `${prefix}${number}`,
    name: faker.lorem.words(3),
    credits: faker.helpers.arrayElement([2, 4, 6]),
    semester: faker.number.int({ min: 1, max: 10 }),
    prerequisites: [],
    ...overrides
  };
}

export function createSubjectTree(): Subject[] {
  const sem1 = [
    createSubject({ code: 'FGA0001', semester: 1, prerequisites: [] }),
    createSubject({ code: 'FGA0002', semester: 1, prerequisites: [] })
  ];
  
  const sem2 = [
    createSubject({ code: 'FGA0003', semester: 2, prerequisites: ['FGA0001'] }),
    createSubject({ code: 'FGA0004', semester: 2, prerequisites: ['FGA0002'] })
  ];
  
  const sem3 = [
    createSubject({ 
      code: 'FGA0005', 
      semester: 3, 
      prerequisites: ['FGA0003', 'FGA0004'] 
    })
  ];
  
  return [...sem1, ...sem2, ...sem3];
}
```

### 7.3 Custom Matchers

#### File: `src/tests/matchers.ts`

```typescript
import { expect } from 'vitest';
import type { Subject, User } from '$lib/types';

// Custom matcher for User objects
expect.extend({
  toBeValidUser(received: any) {
    const pass = 
      typeof received === 'object' &&
      typeof received.id === 'string' &&
      typeof received.email === 'string' &&
      received.email.includes('@');

    return {
      pass,
      message: () =>
        pass
          ? `Expected ${JSON.stringify(received)} not to be a valid User`
          : `Expected ${JSON.stringify(received)} to be a valid User with id and valid email`
    };
  },

  toBeValidSubject(received: any) {
    const pass =
      typeof received === 'object' &&
      typeof received.id === 'string' &&
      typeof received.code === 'string' &&
      typeof received.name === 'string' &&
      typeof received.credits === 'number' &&
      typeof received.semester === 'number' &&
      Array.isArray(received.prerequisites);

    return {
      pass,
      message: () =>
        pass
          ? `Expected ${JSON.stringify(received)} not to be a valid Subject`
          : `Expected ${JSON.stringify(received)} to be a valid Subject`
    };
  },

  toHavePrerequisite(received: Subject, prerequisiteCode: string) {
    const pass = received.prerequisites.includes(prerequisiteCode);

    return {
      pass,
      message: () =>
        pass
          ? `Expected subject ${received.code} not to have prerequisite ${prerequisiteCode}`
          : `Expected subject ${received.code} to have prerequisite ${prerequisiteCode}`
    };
  }
});

// TypeScript declarations for custom matchers
declare module 'vitest' {
  interface Assertion<T = any> {
    toBeValidUser(): T;
    toBeValidSubject(): T;
    toHavePrerequisite(prerequisiteCode: string): T;
  }
  interface AsymmetricMatchersContaining {
    toBeValidUser(): any;
    toBeValidSubject(): any;
    toHavePrerequisite(prerequisiteCode: string): any;
  }
}
```

#### Usage Example:

```typescript
import { describe, it, expect } from 'vitest';
import './matchers'; // Import custom matchers
import { createUser, createSubject } from './fixtures';

describe('Custom Matchers', () => {
  it('should validate user', () => {
    const user = createUser();
    expect(user).toBeValidUser();
  });

  it('should validate subject', () => {
    const subject = createSubject();
    expect(subject).toBeValidSubject();
  });

  it('should check prerequisites', () => {
    const subject = createSubject({ prerequisites: ['FGA0001', 'FGA0002'] });
    expect(subject).toHavePrerequisite('FGA0001');
  });
});
```

---

## 8. CI/CD Integration

### GitHub Actions Configuration

#### File: `.github/workflows/test.yml`

```yaml
name: Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  unit-tests:
    name: Unit & Component Tests
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install pnpm
        uses: pnpm/action-setup@v2
        with:
          version: 9

      - name: Install dependencies
        run: pnpm install --frozen-lockfile
        working-directory: ./no_fluxo_frontend_svelte

      - name: Run unit tests with coverage
        run: pnpm test:coverage
        working-directory: ./no_fluxo_frontend_svelte

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./no_fluxo_frontend_svelte/coverage/lcov.info
          flags: frontend-unit
          fail_ci_if_error: true

  e2e-tests:
    name: E2E Tests
    runs-on: ubuntu-latest
    needs: unit-tests
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install pnpm
        uses: pnpm/action-setup@v2
        with:
          version: 9

      - name: Install dependencies
        run: pnpm install --frozen-lockfile
        working-directory: ./no_fluxo_frontend_svelte

      - name: Install Playwright browsers
        run: pnpm exec playwright install --with-deps
        working-directory: ./no_fluxo_frontend_svelte

      - name: Run E2E tests
        run: pnpm test:e2e
        working-directory: ./no_fluxo_frontend_svelte
        env:
          CI: true

      - name: Upload Playwright report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: ./no_fluxo_frontend_svelte/playwright-report/
          retention-days: 30

  visual-regression:
    name: Visual Regression Tests
    runs-on: ubuntu-latest
    needs: unit-tests
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install pnpm
        uses: pnpm/action-setup@v2
        with:
          version: 9

      - name: Install dependencies
        run: pnpm install --frozen-lockfile
        working-directory: ./no_fluxo_frontend_svelte

      - name: Install Playwright browsers
        run: pnpm exec playwright install --with-deps chromium
        working-directory: ./no_fluxo_frontend_svelte

      - name: Run visual tests
        run: pnpm test:visual
        working-directory: ./no_fluxo_frontend_svelte
        env:
          CI: true

      - name: Upload screenshot diffs
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: visual-diff
          path: ./no_fluxo_frontend_svelte/test-results/
          retention-days: 7

  check-coverage:
    name: Coverage Check
    runs-on: ubuntu-latest
    needs: unit-tests
    
    steps:
      - name: Download coverage
        uses: actions/download-artifact@v4
        with:
          name: coverage-report

      - name: Check coverage thresholds
        run: |
          COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
          echo "Line coverage: $COVERAGE%"
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage is below 80%!"
            exit 1
          fi
```

#### File: `.github/workflows/pr-checks.yml`

```yaml
name: PR Checks

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  lint-and-typecheck:
    name: Lint & Type Check
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install pnpm
        uses: pnpm/action-setup@v2
        with:
          version: 9

      - name: Install dependencies
        run: pnpm install --frozen-lockfile
        working-directory: ./no_fluxo_frontend_svelte

      - name: Run ESLint
        run: pnpm lint
        working-directory: ./no_fluxo_frontend_svelte

      - name: Run TypeScript check
        run: pnpm check
        working-directory: ./no_fluxo_frontend_svelte

  test-affected:
    name: Test Affected Files
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install pnpm
        uses: pnpm/action-setup@v2
        with:
          version: 9

      - name: Install dependencies
        run: pnpm install --frozen-lockfile
        working-directory: ./no_fluxo_frontend_svelte

      - name: Get changed files
        id: changed-files
        uses: tj-actions/changed-files@v40
        with:
          files: |
            no_fluxo_frontend_svelte/src/**/*.{ts,svelte}

      - name: Run tests for changed files
        if: steps.changed-files.outputs.any_changed == 'true'
        run: pnpm vitest run --changed
        working-directory: ./no_fluxo_frontend_svelte
```

---

## 9. Coverage Reports

### Vitest Coverage Configuration

#### File: `package.json` (scripts section)

```json
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:watch": "vitest --watch",
    "test:coverage": "vitest run --coverage",
    "test:ui": "vitest --ui",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:visual": "playwright test --project=chromium e2e/visual.spec.ts",
    "test:visual:update": "playwright test --project=chromium e2e/visual.spec.ts --update-snapshots"
  }
}
```

### Coverage Thresholds

```typescript
// vite.config.ts - coverage section
coverage: {
  provider: 'v8',
  reporter: ['text', 'json', 'html', 'lcov', 'cobertura'],
  reportsDirectory: './coverage',
  
  // Include only source files
  include: ['src/**/*.{ts,svelte}'],
  
  // Exclude test files and configs
  exclude: [
    'src/**/*.test.ts',
    'src/**/*.spec.ts',
    'src/tests/**/*',
    'src/**/*.d.ts',
    'src/app.d.ts',
    'src/hooks.server.ts'
  ],
  
  // Coverage thresholds
  thresholds: {
    // Global thresholds
    lines: 80,
    branches: 75,
    functions: 80,
    statements: 80,
    
    // Per-file thresholds (optional)
    perFile: true,
    autoUpdate: false,
    
    // Critical paths require higher coverage
    'src/lib/stores/**/*.ts': {
      lines: 90,
      branches: 85,
      functions: 90,
      statements: 90
    },
    'src/lib/services/**/*.ts': {
      lines: 85,
      branches: 80,
      functions: 85,
      statements: 85
    }
  },
  
  // Watermarks for report colors
  watermarks: {
    lines: [50, 80],
    branches: [50, 75],
    functions: [50, 80],
    statements: [50, 80]
  }
}
```

### Coverage Badge

Add to README.md:

```markdown
[![Coverage](https://codecov.io/gh/YOUR_ORG/no-fluxo-unb/branch/main/graph/badge.svg)](https://codecov.io/gh/YOUR_ORG/no-fluxo-unb)
```

---

## 10. Testing Best Practices

### What to Test

| Category | Priority | Examples |
|----------|----------|----------|
| **Business Logic** | High | Store reducers, validation, calculations |
| **User Interactions** | High | Button clicks, form submissions |
| **Error States** | High | Network errors, validation errors |
| **Edge Cases** | Medium | Empty states, max values, boundaries |
| **Accessibility** | Medium | ARIA labels, keyboard navigation |
| **Integration Points** | Medium | API calls, external libraries |
| **Visual States** | Low | Hover effects, animations |

### What NOT to Test

| Category | Why |
|----------|-----|
| **Third-party libraries** | They have their own tests |
| **Implementation details** | Test behavior, not internals |
| **Constant values** | No logic to verify |
| **Framework code** | SvelteKit, Vite internals |
| **Generated code** | Auto-generated types, routes |

### Test File Organization

```
src/
├── lib/
│   ├── stores/
│   │   ├── auth.ts
│   │   ├── auth.test.ts          # Unit tests alongside source
│   │   ├── fluxogram.ts
│   │   └── fluxogram.test.ts
│   ├── components/
│   │   ├── ui/
│   │   │   ├── Button.svelte
│   │   │   ├── Button.test.ts    # Component tests
│   │   │   └── __snapshots__/    # Snapshot files
│   │   └── features/
│   │       ├── SubjectCard.svelte
│   │       └── SubjectCard.test.ts
│   ├── services/
│   │   ├── api.ts
│   │   ├── api.test.ts
│   │   └── __mocks__/            # Service mocks
│   └── utils/
│       ├── validation.ts
│       └── validation.test.ts
├── tests/
│   ├── setup.ts                  # Test setup
│   ├── matchers.ts               # Custom matchers
│   ├── fixtures/                 # Test fixtures
│   │   ├── users.ts
│   │   └── subjects.ts
│   └── mocks/                    # MSW handlers
│       ├── handlers.ts
│       └── server.ts
e2e/
├── auth.spec.ts                  # E2E tests
├── fluxograma.spec.ts
├── visual.spec.ts
├── fixtures/                     # Playwright fixtures
└── .auth/                        # Auth state (gitignored)
```

### Naming Conventions

```typescript
// Test file naming
auth.test.ts           // Unit tests
Button.test.ts         // Component tests
auth.spec.ts           // E2E tests (Playwright convention)

// Test descriptions - Use clear, behavior-focused language
describe('AuthStore', () => {
  describe('login', () => {
    it('should set user when credentials are valid', () => {});
    it('should throw error when credentials are invalid', () => {});
    it('should persist token to localStorage', () => {});
  });
});

// Avoid vague descriptions
it('should work', () => {});           // ❌ Bad
it('should return data', () => {});    // ❌ Bad
it('should render correctly', () => {}); // ❌ Bad

// Use specific descriptions
it('should display user name in header', () => {});  // ✓ Good
it('should disable submit button when form is invalid', () => {}); // ✓ Good
```

### Test Data Management

```typescript
// Use factories instead of hardcoded data
import { createUser, createSubject } from '$tests/fixtures';

// ❌ Bad - Hardcoded data
const user = {
  id: '123',
  email: 'test@example.com',
  name: 'Test User'
};

// ✓ Good - Factory with overrides
const user = createUser({ name: 'Custom Name' });

// ✓ Good - Multiple items
const users = createUsers(5);

// ✓ Good - Specific test scenarios
const userWithoutName = createUser({ name: undefined });
```

### Async Testing Patterns

```typescript
import { describe, it, expect, vi } from 'vitest';
import { waitFor } from '@testing-library/svelte';

// Use async/await properly
it('should load users', async () => {
  // Arrange
  const mockUsers = createUsers(3);
  server.use(
    http.get('/api/users', () => HttpResponse.json(mockUsers))
  );

  // Act
  const result = await userService.getUsers();

  // Assert
  expect(result).toHaveLength(3);
});

// Use waitFor for DOM assertions
it('should show loading then content', async () => {
  render(UserList);

  // Initially loading
  expect(screen.getByText('Loading...')).toBeInTheDocument();

  // Wait for content
  await waitFor(() => {
    expect(screen.queryByText('Loading...')).not.toBeInTheDocument();
    expect(screen.getByText('User 1')).toBeInTheDocument();
  });
});

// Use fake timers for time-based tests
it('should debounce search input', async () => {
  vi.useFakeTimers();
  
  render(SearchInput);
  await fireEvent.input(screen.getByRole('textbox'), {
    target: { value: 'test' }
  });

  // Search not called immediately
  expect(mockSearch).not.toHaveBeenCalled();

  // Advance timers
  await vi.advanceTimersByTimeAsync(300);

  // Now search is called
  expect(mockSearch).toHaveBeenCalledWith('test');

  vi.useRealTimers();
});
```

---

## Quick Reference

### Running Tests

```bash
# Unit and component tests
pnpm test              # Watch mode
pnpm test:run          # Single run
pnpm test:coverage     # With coverage

# E2E tests
pnpm test:e2e          # Run all E2E tests
pnpm test:e2e:ui       # Interactive UI mode

# Visual regression
pnpm test:visual       # Run visual tests
pnpm test:visual:update # Update snapshots

# Type checking
pnpm check             # Svelte check
```

### Debugging Tests

```bash
# Vitest UI
pnpm vitest --ui

# Run single test file
pnpm vitest src/lib/stores/auth.test.ts

# Run tests matching pattern
pnpm vitest -t "should login"

# Playwright debug
pnpm playwright test --debug

# Playwright headed mode
pnpm playwright test --headed
```

---

## Migration Checklist

- [ ] Install testing dependencies
- [ ] Configure Vitest
- [ ] Set up test helpers and mocks
- [ ] Write store unit tests
- [ ] Write utility function tests
- [ ] Write component tests
- [ ] Set up MSW for API mocking
- [ ] Write integration tests
- [ ] Configure Playwright
- [ ] Write E2E tests
- [ ] Set up visual regression tests
- [ ] Configure GitHub Actions CI
- [ ] Set up coverage reporting
- [ ] Add coverage badges to README

---

## Related Documents

- [01-PROJECT-SETUP.md](01-PROJECT-SETUP.md) - Project initialization
- [02-AUTHENTICATION.md](02-AUTHENTICATION.md) - Auth implementation
- [06-COMPONENTS-UI.md](06-COMPONENTS-UI.md) - Component library
- [12-STATE-MANAGEMENT.md](12-STATE-MANAGEMENT.md) - Store patterns

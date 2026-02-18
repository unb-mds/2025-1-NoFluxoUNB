# Authentication Migration: Flutter to SvelteKit

## Overview

This document details the migration of the NoFluxo authentication system from Flutter/Dart to SvelteKit/TypeScript. The current implementation uses Supabase Auth with email/password, Google OAuth, and anonymous login support.

**Supabase Project:**
- URL: `https://lijmhbstgdinsukovyfl.supabase.co`

**Public Routes (no authentication required):**
- `/`, `/home`, `/login`, `/signup`, `/password-recovery`, `/login-anonimo`

---

## 1. Current Flutter Auth Analysis

### 1.1 AuthService Methods

The Flutter `AuthService` class provides:

| Method | Purpose |
|--------|---------|
| `signup(email, password)` | Register user with Supabase Auth |
| `signUpWithEmailAndPassword()` | Register user in both Supabase and backend |
| `login(email, password)` | Sign in and sync user from backend |
| `signInWithEmailAndPassword()` | Alternative login method |
| `signInWithGoogle()` | OAuth login with Google |
| `logout(context)` | Sign out with navigation |
| `signOut()` | Sign out without navigation |
| `getCurrentUser()` | Get current Supabase user |
| `isLoggedIn()` | Check authentication status |
| `authStateChanges` | Stream of auth state changes |
| `databaseSearchUser(email)` | Fetch user from backend by email |
| `databaseRegisterUserWhenLoggedInWithGoogle()` | Register Google user in backend |

### 1.2 User Storage (SharedPreferencesHelper)

```dart
// Flutter implementation stores:
- currentUser: UserModel (with token, id_user, email, nome_completo, dados_fluxograma)
- isAnonimo: bool flag for anonymous login state
```

### 1.3 Route Guards (AppRouter)

The Flutter app uses `go_router` with:
- `safeGetSession()`: Validates session and checks expiry
- `checkWhenUserLogged()`: Redirects to login if no valid session
- `checkLoggedIn()`: Full auth check including backend user sync
- Public routes bypass authentication checks

### 1.4 UserModel Structure

```typescript
interface UserModel {
  id_user: number;
  email: string;
  nome_completo: string;
  token?: string;
  dados_fluxograma?: DadosFluxogramaUser;
}
```

---

## 2. Supabase SSR Setup

### 2.1 Install Dependencies

```bash
npm install @supabase/ssr @supabase/supabase-js
```

### 2.2 Environment Variables

Create `.env` file:

```env
PUBLIC_SUPABASE_URL=https://lijmhbstgdinsukovyfl.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here  # Server-side only
PUBLIC_API_URL=http://localhost:3000
```

### 2.3 Supabase Client Configuration

Create `src/lib/supabase/client.ts`:

```typescript
import { createBrowserClient, createServerClient, isBrowser } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';
import type { Database } from './types';

export function createSupabaseClient(
  serverCookies?: {
    get: (key: string) => string | undefined;
    set: (key: string, value: string, options: any) => void;
    remove: (key: string, options: any) => void;
  }
) {
  if (isBrowser()) {
    return createBrowserClient<Database>(
      PUBLIC_SUPABASE_URL,
      PUBLIC_SUPABASE_ANON_KEY
    );
  }

  if (!serverCookies) {
    throw new Error('Server cookies required for SSR');
  }

  return createServerClient<Database>(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        get: serverCookies.get,
        set: serverCookies.set,
        remove: serverCookies.remove,
      },
    }
  );
}
```

### 2.4 Server-Side Supabase Hook

Create `src/hooks.server.ts`:

```typescript
import { createServerClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  event.locals.supabase = createServerClient(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        get: (key) => event.cookies.get(key),
        set: (key, value, options) => {
          event.cookies.set(key, value, {
            ...options,
            path: '/',
            httpOnly: true,
            secure: true,
            sameSite: 'lax',
          });
        },
        remove: (key, options) => {
          event.cookies.delete(key, { ...options, path: '/' });
        },
      },
    }
  );

  // Helper to get session
  event.locals.getSession = async () => {
    const {
      data: { session },
    } = await event.locals.supabase.auth.getSession();
    return session;
  };

  // Helper to get user from session
  event.locals.getUser = async () => {
    const {
      data: { user },
    } = await event.locals.supabase.auth.getUser();
    return user;
  };

  return resolve(event, {
    filterSerializedResponseHeaders(name) {
      return name === 'content-range' || name === 'x-supabase-api-version';
    },
  });
};
```

### 2.5 App.d.ts Type Definitions

Update `src/app.d.ts`:

```typescript
import type { Session, SupabaseClient, User } from '@supabase/supabase-js';
import type { Database } from '$lib/supabase/types';

declare global {
  namespace App {
    interface Locals {
      supabase: SupabaseClient<Database>;
      getSession: () => Promise<Session | null>;
      getUser: () => Promise<User | null>;
    }
    interface PageData {
      session: Session | null;
      user: UserModel | null;
    }
  }
}

export {};
```

---

## 3. Auth Store Implementation

### 3.1 Types

Create `src/lib/types/auth.ts`:

```typescript
export interface DadosMateria {
  codigo: string;
  mencao: string;
  professor: string;
  status: string;
  ano_periodo?: string;
  frequencia?: string;
  tipo_dado?: string;
  turma?: string;
}

export interface DadosFluxogramaUser {
  nome_curso: string;
  ira: number;
  matricula: string;
  matriz_curricular: string;
  semestre_atual: number;
  ano_atual: string;
  horas_integralizadas: number;
  suspensoes: string[];
  dados_fluxograma: DadosMateria[][];
}

export interface UserModel {
  id_user: number;
  email: string;
  nome_completo: string;
  token?: string;
  dados_fluxograma?: DadosFluxogramaUser;
}

export interface AuthState {
  user: UserModel | null;
  isAuthenticated: boolean;
  isAnonymous: boolean;
  isLoading: boolean;
  error: string | null;
}
```

### 3.2 Auth Store

Create `src/lib/stores/auth.ts`:

```typescript
import { writable, derived, get } from 'svelte/store';
import { browser } from '$app/environment';
import type { AuthState, UserModel } from '$lib/types/auth';
import type { Session, User } from '@supabase/supabase-js';

const STORAGE_KEY = 'nofluxo_user';
const ANON_KEY = 'nofluxo_anonimo';

// Initialize state from localStorage if available
function getInitialState(): AuthState {
  if (browser) {
    const storedUser = localStorage.getItem(STORAGE_KEY);
    const isAnonymous = localStorage.getItem(ANON_KEY) === 'true';
    
    if (storedUser && storedUser !== 'null') {
      try {
        const user = JSON.parse(storedUser) as UserModel;
        return {
          user,
          isAuthenticated: true,
          isAnonymous: false,
          isLoading: false,
          error: null,
        };
      } catch {
        localStorage.removeItem(STORAGE_KEY);
      }
    }
    
    if (isAnonymous) {
      return {
        user: null,
        isAuthenticated: false,
        isAnonymous: true,
        isLoading: false,
        error: null,
      };
    }
  }

  return {
    user: null,
    isAuthenticated: false,
    isAnonymous: false,
    isLoading: true,
    error: null,
  };
}

function createAuthStore() {
  const { subscribe, set, update } = writable<AuthState>(getInitialState());

  return {
    subscribe,

    setUser(user: UserModel | null) {
      if (browser) {
        if (user) {
          localStorage.setItem(STORAGE_KEY, JSON.stringify(user));
          localStorage.removeItem(ANON_KEY);
        } else {
          localStorage.removeItem(STORAGE_KEY);
        }
      }

      update((state) => ({
        ...state,
        user,
        isAuthenticated: !!user,
        isAnonymous: false,
        isLoading: false,
        error: null,
      }));
    },

    setAnonymous(value: boolean) {
      if (browser) {
        if (value) {
          localStorage.setItem(ANON_KEY, 'true');
          localStorage.removeItem(STORAGE_KEY);
        } else {
          localStorage.removeItem(ANON_KEY);
        }
      }

      update((state) => ({
        ...state,
        user: null,
        isAuthenticated: false,
        isAnonymous: value,
        isLoading: false,
        error: null,
      }));
    },

    setLoading(isLoading: boolean) {
      update((state) => ({ ...state, isLoading }));
    },

    setError(error: string | null) {
      update((state) => ({ ...state, error, isLoading: false }));
    },

    updateToken(token: string) {
      update((state) => {
        if (state.user) {
          const updatedUser = { ...state.user, token };
          if (browser) {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(updatedUser));
          }
          return { ...state, user: updatedUser };
        }
        return state;
      });
    },

    updateDadosFluxograma(dados: UserModel['dados_fluxograma']) {
      update((state) => {
        if (state.user) {
          const updatedUser = { ...state.user, dados_fluxograma: dados };
          if (browser) {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(updatedUser));
          }
          return { ...state, user: updatedUser };
        }
        return state;
      });
    },

    clear() {
      if (browser) {
        localStorage.removeItem(STORAGE_KEY);
        localStorage.removeItem(ANON_KEY);
      }
      set({
        user: null,
        isAuthenticated: false,
        isAnonymous: false,
        isLoading: false,
        error: null,
      });
    },

    getUser(): UserModel | null {
      return get({ subscribe }).user;
    },

    isLoggedIn(): boolean {
      const state = get({ subscribe });
      return state.isAuthenticated || state.isAnonymous;
    },
  };
}

export const authStore = createAuthStore();

// Derived stores for convenience
export const currentUser = derived(authStore, ($auth) => $auth.user);
export const isAuthenticated = derived(authStore, ($auth) => $auth.isAuthenticated);
export const isAnonymous = derived(authStore, ($auth) => $auth.isAnonymous);
export const isLoading = derived(authStore, ($auth) => $auth.isLoading);
export const authError = derived(authStore, ($auth) => $auth.error);
```

---

## 4. Auth Service Migration

### 4.1 Auth Service

Create `src/lib/services/auth.service.ts`:

```typescript
import { createSupabaseClient } from '$lib/supabase/client';
import { authStore } from '$lib/stores/auth';
import { PUBLIC_API_URL } from '$env/static/public';
import type { UserModel } from '$lib/types/auth';
import type { AuthError, User, Session } from '@supabase/supabase-js';

export class AuthService {
  private supabase = createSupabaseClient();

  /**
   * Search for user in backend database by email
   */
  async databaseSearchUser(email: string): Promise<{ success: true; user: UserModel } | { success: false; error: string }> {
    try {
      const response = await fetch(
        `${PUBLIC_API_URL}/users/get-user-by-email?email=${encodeURIComponent(email)}`
      );

      if (response.ok) {
        const data = await response.json();
        const user: UserModel = {
          id_user: data.id_user,
          email: data.email,
          nome_completo: data.nome_completo,
          token: (await this.supabase.auth.getSession()).data.session?.access_token,
          dados_fluxograma: this.parseDadosFluxograma(data),
        };
        return { success: true, user };
      }

      return { success: false, error: await response.text() };
    } catch (error) {
      console.error('databaseSearchUser error:', error);
      return { success: false, error: String(error) };
    }
  }

  /**
   * Register user in backend when logged in with Google
   */
  async databaseRegisterUserWithGoogle(
    email: string,
    nomeCompleto: string
  ): Promise<{ success: true; user: UserModel } | { success: false; error: string }> {
    try {
      const response = await fetch(`${PUBLIC_API_URL}/users/register-user-with-google`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          email,
          nome_completo: nomeCompleto,
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const user: UserModel = {
          id_user: data.id_user,
          email: data.email,
          nome_completo: data.nome_completo,
        };
        return { success: true, user };
      }

      return { success: false, error: await response.text() };
    } catch (error) {
      console.error('databaseRegisterUserWithGoogle error:', error);
      return { success: false, error: String(error) };
    }
  }

  /**
   * Register user in backend with email
   */
  async databaseRegisterUserWithEmail(
    email: string,
    nomeCompleto: string
  ): Promise<{ success: true; user: UserModel } | { success: false; error: string }> {
    try {
      const response = await fetch(`${PUBLIC_API_URL}/users/registrar-user-with-email`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          email,
          nome_completo: nomeCompleto,
        }),
      });

      if (response.ok) {
        const data = await response.json();
        const user: UserModel = {
          id_user: data.id_user,
          email: data.email,
          nome_completo: data.nome_completo,
        };
        return { success: true, user };
      }

      return { success: false, error: await response.text() };
    } catch (error) {
      console.error('databaseRegisterUserWithEmail error:', error);
      return { success: false, error: String(error) };
    }
  }

  /**
   * Sign up with email and password
   */
  async signUp(
    email: string,
    password: string,
    displayName?: string
  ): Promise<{ success: true; user: User } | { success: false; error: string }> {
    try {
      authStore.setLoading(true);

      // Create user in Supabase Auth
      const { data, error } = await this.supabase.auth.signUp({
        email,
        password,
        options: {
          data: displayName ? { display_name: displayName } : undefined,
        },
      });

      if (error) {
        authStore.setError(error.message);
        return { success: false, error: error.message };
      }

      if (!data.user) {
        const msg = 'Erro ao criar conta no Supabase';
        authStore.setError(msg);
        return { success: false, error: msg };
      }

      // Register in backend
      const backendResult = await this.databaseRegisterUserWithEmail(
        email,
        displayName || email.split('@')[0]
      );

      if (!backendResult.success) {
        // Rollback: sign out from Supabase
        await this.supabase.auth.signOut();
        authStore.setError(backendResult.error);
        return { success: false, error: backendResult.error };
      }

      authStore.setUser(backendResult.user);
      return { success: true, user: data.user };
    } catch (error) {
      const msg = `Erro inesperado: ${error}`;
      authStore.setError(msg);
      return { success: false, error: msg };
    }
  }

  /**
   * Sign in with email and password
   */
  async signIn(
    email: string,
    password: string
  ): Promise<{ success: true; user: UserModel } | { success: false; error: string }> {
    try {
      authStore.setLoading(true);

      const { data, error } = await this.supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        authStore.setError(error.message);
        return { success: false, error: error.message };
      }

      if (!data.user) {
        const msg = 'Email ou senha inválidos';
        authStore.setError(msg);
        return { success: false, error: msg };
      }

      // Fetch user from backend
      const result = await this.databaseSearchUser(email);

      if (!result.success) {
        authStore.setError(
          'Usuário autenticado, mas não encontrado no banco de dados interno. Contate o suporte.'
        );
        return {
          success: false,
          error: 'Usuário autenticado, mas não encontrado no banco de dados interno. Contate o suporte.',
        };
      }

      authStore.setUser(result.user);
      return { success: true, user: result.user };
    } catch (error) {
      const msg = `Erro: ${error}`;
      authStore.setError(msg);
      return { success: false, error: msg };
    }
  }

  /**
   * Sign in with Google OAuth
   */
  async signInWithGoogle(redirectTo?: string): Promise<void> {
    const { error } = await this.supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: redirectTo || `${window.location.origin}/auth/callback`,
        queryParams: {
          prompt: 'consent',
        },
      },
    });

    if (error) {
      authStore.setError(error.message);
      throw error;
    }
  }

  /**
   * Handle OAuth callback and sync with backend
   */
  async handleOAuthCallback(): Promise<{ success: true; user: UserModel } | { success: false; error: string }> {
    try {
      authStore.setLoading(true);

      const { data: { session }, error } = await this.supabase.auth.getSession();

      if (error || !session?.user?.email) {
        const msg = error?.message || 'Sessão inválida';
        authStore.setError(msg);
        return { success: false, error: msg };
      }

      const email = session.user.email;

      // Try to find user in backend
      let result = await this.databaseSearchUser(email);

      if (!result.success) {
        // User not found, register with Google
        const displayName = session.user.user_metadata?.name || session.user.user_metadata?.full_name || '';
        result = await this.databaseRegisterUserWithGoogle(email, displayName);
      }

      if (result.success) {
        authStore.setUser(result.user);
        return { success: true, user: result.user };
      }

      authStore.setError(result.error);
      return { success: false, error: result.error };
    } catch (error) {
      const msg = `Erro no callback OAuth: ${error}`;
      authStore.setError(msg);
      return { success: false, error: msg };
    }
  }

  /**
   * Set anonymous login state
   */
  setAnonymous(): void {
    authStore.setAnonymous(true);
  }

  /**
   * Sign out
   */
  async signOut(): Promise<void> {
    try {
      await this.supabase.auth.signOut();
      authStore.clear();
    } catch (error) {
      console.error('Sign out error:', error);
      // Clear local state even if Supabase signout fails
      authStore.clear();
    }
  }

  /**
   * Get current session
   */
  async getSession(): Promise<Session | null> {
    const { data: { session } } = await this.supabase.auth.getSession();
    return session;
  }

  /**
   * Get current user from Supabase
   */
  async getCurrentUser(): Promise<User | null> {
    const { data: { user } } = await this.supabase.auth.getUser();
    return user;
  }

  /**
   * Check if session is valid and not expired
   */
  async isSessionValid(): Promise<boolean> {
    const session = await this.getSession();

    if (!session) return false;

    if (session.expires_at) {
      const expiresAt = new Date(session.expires_at * 1000);
      if (new Date() > expiresAt) {
        await this.signOut();
        return false;
      }
    }

    return true;
  }

  /**
   * Refresh session and update token in store
   */
  async refreshSession(): Promise<Session | null> {
    const { data: { session }, error } = await this.supabase.auth.refreshSession();

    if (error) {
      console.error('Session refresh error:', error);
      return null;
    }

    if (session?.access_token) {
      authStore.updateToken(session.access_token);
    }

    return session;
  }

  /**
   * Get headers for authorized API requests
   */
  async getAuthHeaders(): Promise<Record<string, string>> {
    const session = await this.refreshSession();
    const user = authStore.getUser();

    return {
      'Authorization': session?.access_token || '',
      'User-ID': user?.id_user?.toString() || '',
      'Content-Type': 'application/json',
    };
  }

  /**
   * Listen to auth state changes
   */
  onAuthStateChange(callback: (event: string, session: Session | null) => void) {
    return this.supabase.auth.onAuthStateChange((event, session) => {
      callback(event, session);
    });
  }

  /**
   * Password recovery
   */
  async sendPasswordResetEmail(email: string): Promise<{ success: boolean; error?: string }> {
    const { error } = await this.supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/reset-password`,
    });

    if (error) {
      return { success: false, error: error.message };
    }

    return { success: true };
  }

  /**
   * Update password
   */
  async updatePassword(newPassword: string): Promise<{ success: boolean; error?: string }> {
    const { error } = await this.supabase.auth.updateUser({
      password: newPassword,
    });

    if (error) {
      return { success: false, error: error.message };
    }

    return { success: true };
  }

  // Helper to parse dados_fluxograma from API response
  private parseDadosFluxograma(data: any): UserModel['dados_fluxograma'] {
    if (
      data.dados_users?.[0]?.fluxograma_atual
    ) {
      try {
        return JSON.parse(data.dados_users[0].fluxograma_atual);
      } catch {
        return undefined;
      }
    }
    return undefined;
  }
}

// Singleton instance
export const authService = new AuthService();
```

---

## 5. Login Methods

### 5.1 Email/Password Login Component

Create `src/lib/components/auth/LoginForm.svelte`:

```svelte
<script lang="ts">
  import { authService } from '$lib/services/auth.service';
  import { goto } from '$app/navigation';
  import { isLoading, authError } from '$lib/stores/auth';

  let email = '';
  let password = '';
  let localError = '';
  let submitting = false;

  async function handleLogin() {
    if (!email || !password) {
      localError = 'Preencha todos os campos';
      return;
    }

    submitting = true;
    localError = '';

    const result = await authService.signIn(email, password);

    if (result.success) {
      await goto('/fluxogramas');
    } else {
      localError = result.error;
    }

    submitting = false;
  }

  async function handleGoogleLogin() {
    try {
      await authService.signInWithGoogle();
    } catch (error) {
      localError = 'Erro ao iniciar login com Google';
    }
  }
</script>

<form on:submit|preventDefault={handleLogin} class="login-form">
  <h2>Entrar</h2>

  {#if localError || $authError}
    <div class="error-message">
      {localError || $authError}
    </div>
  {/if}

  <div class="form-group">
    <label for="email">Email</label>
    <input
      type="email"
      id="email"
      bind:value={email}
      placeholder="seu@email.com"
      disabled={submitting}
    />
  </div>

  <div class="form-group">
    <label for="password">Senha</label>
    <input
      type="password"
      id="password"
      bind:value={password}
      placeholder="••••••••"
      disabled={submitting}
    />
  </div>

  <button type="submit" class="btn-primary" disabled={submitting || $isLoading}>
    {#if submitting}
      Entrando...
    {:else}
      Entrar
    {/if}
  </button>

  <div class="divider">
    <span>ou</span>
  </div>

  <button
    type="button"
    class="btn-google"
    on:click={handleGoogleLogin}
    disabled={submitting}
  >
    <svg viewBox="0 0 24 24" width="20" height="20">
      <path
        fill="#4285F4"
        d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
      />
      <path
        fill="#34A853"
        d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
      />
      <path
        fill="#FBBC05"
        d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
      />
      <path
        fill="#EA4335"
        d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
      />
    </svg>
    Continuar com Google
  </button>

  <div class="links">
    <a href="/signup">Criar conta</a>
    <a href="/password-recovery">Esqueci minha senha</a>
    <a href="/login-anonimo">Entrar sem conta</a>
  </div>
</form>

<style>
  .login-form {
    max-width: 400px;
    margin: 0 auto;
    padding: 2rem;
  }

  h2 {
    text-align: center;
    margin-bottom: 1.5rem;
    color: #183c8b;
  }

  .form-group {
    margin-bottom: 1rem;
  }

  label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 500;
  }

  input {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 8px;
    font-size: 1rem;
  }

  input:focus {
    outline: none;
    border-color: #183c8b;
  }

  .btn-primary {
    width: 100%;
    padding: 0.75rem;
    background: #183c8b;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-primary:hover:not(:disabled) {
    background: #122d6a;
  }

  .btn-primary:disabled {
    opacity: 0.7;
    cursor: not-allowed;
  }

  .btn-google {
    width: 100%;
    padding: 0.75rem;
    background: white;
    color: #333;
    border: 1px solid #ddd;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 500;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    transition: background 0.2s;
  }

  .btn-google:hover:not(:disabled) {
    background: #f5f5f5;
  }

  .divider {
    display: flex;
    align-items: center;
    margin: 1.5rem 0;
  }

  .divider::before,
  .divider::after {
    content: '';
    flex: 1;
    height: 1px;
    background: #ddd;
  }

  .divider span {
    padding: 0 1rem;
    color: #666;
    font-size: 0.875rem;
  }

  .error-message {
    background: #fee;
    color: #c00;
    padding: 0.75rem;
    border-radius: 8px;
    margin-bottom: 1rem;
    text-align: center;
  }

  .links {
    margin-top: 1.5rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
  }

  .links a {
    color: #183c8b;
    text-decoration: none;
  }

  .links a:hover {
    text-decoration: underline;
  }
</style>
```

### 5.2 Signup Form Component

Create `src/lib/components/auth/SignupForm.svelte`:

```svelte
<script lang="ts">
  import { authService } from '$lib/services/auth.service';
  import { goto } from '$app/navigation';
  import { isLoading } from '$lib/stores/auth';

  let email = '';
  let password = '';
  let confirmPassword = '';
  let displayName = '';
  let localError = '';
  let submitting = false;
  let success = false;

  async function handleSignup() {
    if (!email || !password || !confirmPassword) {
      localError = 'Preencha todos os campos obrigatórios';
      return;
    }

    if (password !== confirmPassword) {
      localError = 'As senhas não coincidem';
      return;
    }

    if (password.length < 6) {
      localError = 'A senha deve ter pelo menos 6 caracteres';
      return;
    }

    submitting = true;
    localError = '';

    const result = await authService.signUp(email, password, displayName || undefined);

    if (result.success) {
      success = true;
      // Supabase might require email confirmation
      // Show success message and redirect
      setTimeout(() => {
        goto('/login');
      }, 3000);
    } else {
      localError = result.error;
    }

    submitting = false;
  }
</script>

<form on:submit|preventDefault={handleSignup} class="signup-form">
  <h2>Criar Conta</h2>

  {#if success}
    <div class="success-message">
      Conta criada com sucesso! Verifique seu email para confirmar o cadastro.
      Redirecionando...
    </div>
  {:else}
    {#if localError}
      <div class="error-message">{localError}</div>
    {/if}

    <div class="form-group">
      <label for="displayName">Nome Completo</label>
      <input
        type="text"
        id="displayName"
        bind:value={displayName}
        placeholder="Seu nome"
        disabled={submitting}
      />
    </div>

    <div class="form-group">
      <label for="email">Email *</label>
      <input
        type="email"
        id="email"
        bind:value={email}
        placeholder="seu@email.com"
        disabled={submitting}
        required
      />
    </div>

    <div class="form-group">
      <label for="password">Senha *</label>
      <input
        type="password"
        id="password"
        bind:value={password}
        placeholder="Mínimo 6 caracteres"
        disabled={submitting}
        required
      />
    </div>

    <div class="form-group">
      <label for="confirmPassword">Confirmar Senha *</label>
      <input
        type="password"
        id="confirmPassword"
        bind:value={confirmPassword}
        placeholder="Repita a senha"
        disabled={submitting}
        required
      />
    </div>

    <button type="submit" class="btn-primary" disabled={submitting || $isLoading}>
      {#if submitting}
        Criando conta...
      {:else}
        Criar Conta
      {/if}
    </button>

    <div class="links">
      <a href="/login">Já tenho uma conta</a>
    </div>
  {/if}
</form>

<style>
  /* Same styles as LoginForm */
  .signup-form {
    max-width: 400px;
    margin: 0 auto;
    padding: 2rem;
  }

  h2 {
    text-align: center;
    margin-bottom: 1.5rem;
    color: #183c8b;
  }

  .form-group {
    margin-bottom: 1rem;
  }

  label {
    display: block;
    margin-bottom: 0.5rem;
    font-weight: 500;
  }

  input {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid #ddd;
    border-radius: 8px;
    font-size: 1rem;
  }

  input:focus {
    outline: none;
    border-color: #183c8b;
  }

  .btn-primary {
    width: 100%;
    padding: 0.75rem;
    background: #183c8b;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    margin-top: 0.5rem;
  }

  .btn-primary:hover:not(:disabled) {
    background: #122d6a;
  }

  .btn-primary:disabled {
    opacity: 0.7;
    cursor: not-allowed;
  }

  .error-message {
    background: #fee;
    color: #c00;
    padding: 0.75rem;
    border-radius: 8px;
    margin-bottom: 1rem;
    text-align: center;
  }

  .success-message {
    background: #e6faf0;
    color: #0a7;
    padding: 0.75rem;
    border-radius: 8px;
    margin-bottom: 1rem;
    text-align: center;
  }

  .links {
    margin-top: 1.5rem;
    text-align: center;
  }

  .links a {
    color: #183c8b;
    text-decoration: none;
  }

  .links a:hover {
    text-decoration: underline;
  }
</style>
```

### 5.3 Anonymous Login Component

Create `src/lib/components/auth/AnonymousLogin.svelte`:

```svelte
<script lang="ts">
  import { authService } from '$lib/services/auth.service';
  import { goto } from '$app/navigation';

  let showSuccess = false;

  function handleAnonymousLogin() {
    showSuccess = true;
    authService.setAnonymous();
    
    setTimeout(() => {
      goto('/fluxogramas');
    }, 2000);
  }
</script>

<div class="anonymous-container">
  {#if showSuccess}
    <div class="success-modal">
      <div class="success-icon">✓</div>
      <h3>Login anônimo</h3>
      <p>Você entrou como usuário anônimo.</p>
    </div>
  {:else}
    <div class="anonymous-card">
      <h2>Entrar sem conta</h2>
      <p>
        Você pode explorar os fluxogramas sem criar uma conta.
        Algumas funcionalidades estarão limitadas.
      </p>
      
      <div class="features">
        <div class="feature">
          <span class="check">✓</span>
          <span>Visualizar fluxogramas de cursos</span>
        </div>
        <div class="feature">
          <span class="cross">✕</span>
          <span>Salvar seu progresso</span>
        </div>
        <div class="feature">
          <span class="cross">✕</span>
          <span>Importar histórico acadêmico</span>
        </div>
      </div>

      <button class="btn-anonymous" on:click={handleAnonymousLogin}>
        Continuar sem conta
      </button>

      <a href="/login" class="back-link">
        Voltar para login
      </a>
    </div>
  {/if}
</div>

<style>
  .anonymous-container {
    max-width: 440px;
    margin: 2rem auto;
    padding: 2rem;
  }

  .anonymous-card {
    background: white;
    border-radius: 14px;
    padding: 2rem;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
  }

  h2 {
    text-align: center;
    color: #183c8b;
    margin-bottom: 1rem;
  }

  p {
    text-align: center;
    color: #666;
    margin-bottom: 1.5rem;
  }

  .features {
    margin-bottom: 1.5rem;
  }

  .feature {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.5rem 0;
  }

  .check {
    color: #0a7;
    font-weight: bold;
  }

  .cross {
    color: #c00;
    font-weight: bold;
  }

  .btn-anonymous {
    width: 100%;
    padding: 0.75rem;
    background: #183c8b;
    color: white;
    border: none;
    border-radius: 10px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-anonymous:hover {
    background: #122d6a;
  }

  .back-link {
    display: block;
    text-align: center;
    margin-top: 1rem;
    color: #183c8b;
    text-decoration: none;
  }

  .back-link:hover {
    text-decoration: underline;
  }

  .success-modal {
    background: white;
    border-radius: 14px;
    padding: 2rem;
    text-align: center;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
  }

  .success-icon {
    width: 56px;
    height: 56px;
    background: #e6faf0;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 1rem;
    font-size: 1.5rem;
    color: #0a7;
  }

  .success-modal h3 {
    color: #333;
    margin-bottom: 0.5rem;
  }

  .success-modal p {
    color: #666;
    margin: 0;
  }
</style>
```

---

## 6. Route Guards

### 6.1 Server Hook with Auth Guard

Update `src/hooks.server.ts`:

```typescript
import { createServerClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';
import { redirect, type Handle } from '@sveltejs/kit';

// Routes that don't require authentication
const PUBLIC_ROUTES = [
  '/',
  '/home',
  '/login',
  '/signup',
  '/password-recovery',
  '/login-anonimo',
  '/auth/callback',
  '/auth/reset-password',
];

function isPublicRoute(path: string): boolean {
  return PUBLIC_ROUTES.some(route => {
    if (route === path) return true;
    // Handle dynamic routes or route prefixes
    if (route.endsWith('*') && path.startsWith(route.slice(0, -1))) return true;
    return false;
  });
}

export const handle: Handle = async ({ event, resolve }) => {
  // Create Supabase client
  event.locals.supabase = createServerClient(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        get: (key) => event.cookies.get(key),
        set: (key, value, options) => {
          event.cookies.set(key, value, {
            ...options,
            path: '/',
            httpOnly: true,
            secure: true,
            sameSite: 'lax',
          });
        },
        remove: (key, options) => {
          event.cookies.delete(key, { ...options, path: '/' });
        },
      },
    }
  );

  // Session helpers
  event.locals.getSession = async () => {
    const { data: { session } } = await event.locals.supabase.auth.getSession();
    return session;
  };

  event.locals.getUser = async () => {
    const { data: { user } } = await event.locals.supabase.auth.getUser();
    return user;
  };

  const path = event.url.pathname;

  // Skip auth check for public routes and static assets
  if (isPublicRoute(path) || path.startsWith('/_app') || path.startsWith('/api')) {
    return resolve(event, {
      filterSerializedResponseHeaders(name) {
        return name === 'content-range' || name === 'x-supabase-api-version';
      },
    });
  }

  // Check for anonymous session (stored in cookie)
  const isAnonymous = event.cookies.get('nofluxo_anonimo') === 'true';
  
  if (isAnonymous) {
    // Allow anonymous users to access certain routes
    return resolve(event, {
      filterSerializedResponseHeaders(name) {
        return name === 'content-range' || name === 'x-supabase-api-version';
      },
    });
  }

  // Verify session for protected routes
  const session = await event.locals.getSession();

  if (!session) {
    // Check session expiry
    const redirectUrl = `/login?redirect=${encodeURIComponent(path)}`;
    throw redirect(303, redirectUrl);
  }

  // Verify session hasn't expired
  if (session.expires_at && Date.now() > session.expires_at * 1000) {
    await event.locals.supabase.auth.signOut();
    throw redirect(303, '/login?error=session_expired');
  }

  return resolve(event, {
    filterSerializedResponseHeaders(name) {
      return name === 'content-range' || name === 'x-supabase-api-version';
    },
  });
};
```

### 6.2 Client-Side Route Guard

Create `src/lib/guards/authGuard.ts`:

```typescript
import { browser } from '$app/environment';
import { goto } from '$app/navigation';
import { get } from 'svelte/store';
import { authStore } from '$lib/stores/auth';
import { authService } from '$lib/services/auth.service';

const PUBLIC_ROUTES = [
  '/',
  '/home',
  '/login',
  '/signup',
  '/password-recovery',
  '/login-anonimo',
  '/auth/callback',
  '/auth/reset-password',
];

export function isPublicRoute(path: string): boolean {
  return PUBLIC_ROUTES.includes(path);
}

/**
 * Check if user should be redirected
 * Call this in +layout.svelte or individual pages
 */
export async function checkAuth(path: string): Promise<boolean> {
  if (!browser) return true;
  
  if (isPublicRoute(path)) return true;

  const state = get(authStore);

  // Allow anonymous users
  if (state.isAnonymous) return true;

  // Check if authenticated
  if (state.isAuthenticated && state.user) {
    // Verify session is still valid
    const isValid = await authService.isSessionValid();
    if (isValid) return true;
  }

  // Not authenticated, redirect to login
  await goto(`/login?redirect=${encodeURIComponent(path)}`);
  return false;
}

/**
 * Guard for pages that should redirect logged-in users
 * (e.g., login page should redirect to home if already logged in)
 */
export async function checkAlreadyAuthenticated(redirectTo = '/fluxogramas'): Promise<boolean> {
  if (!browser) return false;

  const state = get(authStore);

  if (state.isAuthenticated || state.isAnonymous) {
    await goto(redirectTo);
    return true;
  }

  return false;
}
```

### 6.3 Layout with Auth Check

Create `src/routes/+layout.svelte`:

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { browser } from '$app/environment';
  import { authStore, isLoading } from '$lib/stores/auth';
  import { authService } from '$lib/services/auth.service';
  import { checkAuth, isPublicRoute } from '$lib/guards/authGuard';
  import '../app.css';

  // Watch for route changes and verify auth
  $: if (browser && $page.url.pathname) {
    checkAuth($page.url.pathname);
  }

  onMount(() => {
    // Set up auth state listener
    const { data: { subscription } } = authService.onAuthStateChange(
      async (event, session) => {
        console.log('Auth state changed:', event);

        if (event === 'SIGNED_OUT') {
          authStore.clear();
        } else if (event === 'SIGNED_IN' && session?.user?.email) {
          // Fetch user from backend if not already loaded
          const currentUser = authStore.getUser();
          if (!currentUser) {
            const result = await authService.databaseSearchUser(session.user.email);
            if (result.success) {
              authStore.setUser(result.user);
            }
          }
        } else if (event === 'TOKEN_REFRESHED' && session?.access_token) {
          authStore.updateToken(session.access_token);
        }
      }
    );

    // Initial session check
    authService.getSession().then(async (session) => {
      if (session?.user?.email) {
        const result = await authService.databaseSearchUser(session.user.email);
        if (result.success) {
          authStore.setUser(result.user);
        }
      } else {
        authStore.setLoading(false);
      }
    });

    return () => {
      subscription.unsubscribe();
    };
  });
</script>

{#if $isLoading && !isPublicRoute($page.url.pathname)}
  <div class="loading-overlay">
    <div class="spinner"></div>
    <p>Carregando...</p>
  </div>
{:else}
  <slot />
{/if}

<style>
  .loading-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    background: rgba(255, 255, 255, 0.9);
    z-index: 9999;
  }

  .spinner {
    width: 40px;
    height: 40px;
    border: 3px solid #ddd;
    border-top-color: #183c8b;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .loading-overlay p {
    margin-top: 1rem;
    color: #666;
  }
</style>
```

---

## 7. Session Management

### 7.1 OAuth Callback Handler

Create `src/routes/auth/callback/+page.server.ts`:

```typescript
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ url, locals }) => {
  const code = url.searchParams.get('code');
  const next = url.searchParams.get('next') || '/fluxogramas';

  if (code) {
    const { error } = await locals.supabase.auth.exchangeCodeForSession(code);
    
    if (error) {
      console.error('OAuth callback error:', error);
      throw redirect(303, `/login?error=${encodeURIComponent(error.message)}`);
    }
  }

  throw redirect(303, next);
};
```

Create `src/routes/auth/callback/+page.svelte`:

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { authService } from '$lib/services/auth.service';

  let status = 'Processando autenticação...';
  let error = '';

  onMount(async () => {
    try {
      const result = await authService.handleOAuthCallback();
      
      if (result.success) {
        status = 'Login realizado com sucesso!';
        setTimeout(() => {
          goto('/fluxogramas');
        }, 1000);
      } else {
        error = result.error;
      }
    } catch (err) {
      error = 'Erro ao processar autenticação';
      console.error(err);
    }
  });
</script>

<div class="callback-container">
  {#if error}
    <div class="error">
      <h2>Erro na autenticação</h2>
      <p>{error}</p>
      <a href="/login">Voltar para login</a>
    </div>
  {:else}
    <div class="loading">
      <div class="spinner"></div>
      <p>{status}</p>
    </div>
  {/if}
</div>

<style>
  .callback-container {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .loading {
    text-align: center;
  }

  .spinner {
    width: 48px;
    height: 48px;
    border: 4px solid #ddd;
    border-top-color: #183c8b;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin: 0 auto 1rem;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .error {
    text-align: center;
    padding: 2rem;
  }

  .error h2 {
    color: #c00;
    margin-bottom: 1rem;
  }

  .error a {
    color: #183c8b;
    text-decoration: none;
  }

  .error a:hover {
    text-decoration: underline;
  }
</style>
```

### 7.2 Session Refresh Hook

Create `src/lib/hooks/useSession.ts`:

```typescript
import { onMount, onDestroy } from 'svelte';
import { authService } from '$lib/services/auth.service';
import { authStore } from '$lib/stores/auth';

/**
 * Hook to manage session refresh
 * Call this in a root layout or component that's always mounted
 */
export function useSession() {
  let refreshInterval: ReturnType<typeof setInterval>;
  let subscription: { unsubscribe: () => void } | null = null;

  onMount(() => {
    // Refresh session every 10 minutes to keep token fresh
    refreshInterval = setInterval(async () => {
      const session = await authService.refreshSession();
      if (!session) {
        // Session expired or invalid
        authStore.clear();
      }
    }, 10 * 60 * 1000); // 10 minutes

    // Listen to auth state changes
    const { data } = authService.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_OUT') {
        authStore.clear();
      } else if (event === 'TOKEN_REFRESHED' && session?.access_token) {
        authStore.updateToken(session.access_token);
      }
    });

    subscription = data.subscription;
  });

  onDestroy(() => {
    if (refreshInterval) {
      clearInterval(refreshInterval);
    }
    if (subscription) {
      subscription.unsubscribe();
    }
  });
}
```

### 7.3 Anonymous Session Cookie

Update the anonymous login to use a cookie for SSR compatibility:

```typescript
// In authService
setAnonymous(): void {
  authStore.setAnonymous(true);
  
  // Set cookie for SSR
  if (typeof document !== 'undefined') {
    document.cookie = 'nofluxo_anonimo=true; path=/; max-age=31536000; samesite=lax';
  }
}

// When clearing auth
clear(): void {
  // Remove anonymous cookie
  if (typeof document !== 'undefined') {
    document.cookie = 'nofluxo_anonimo=; path=/; max-age=0';
  }
  // ... rest of clear logic
}
```

---

## 8. Backend User Sync

> **⚡ ARCHITECTURE UPDATE:** User sync no longer calls the backend API endpoints (`/users/get-user-by-email`, `/users/register-user-*`). Instead, it queries the `users` table **directly via Supabase** with RLS policies. See [14-SUPABASE-DIRECT-RLS.md](../plans/14-SUPABASE-DIRECT-RLS.md) for the full RLS setup.
>
> **Prerequisites:** The `users` table must have an `auth_id UUID` column linking to `auth.users.id`, and RLS policies must be enabled. See the migration SQL in plan 14.

### 8.1 User Sync Service (Direct Supabase)

Create `src/lib/services/user.service.ts`:

```typescript
import { createSupabaseBrowserClient } from '$lib/supabase/client';
import { authStore } from '$lib/stores/auth';
import type { UserModel, DadosFluxogramaUser } from '$lib/types/auth';

export class UserService {
  private supabase = createSupabaseBrowserClient();

  /**
   * Fetch current user data — DIRECT SUPABASE QUERY (no backend call)
   * REPLACES: GET /users/get-user-by-email
   */
  async fetchCurrentUser(): Promise<UserModel | null> {
    const { data: authUser } = await this.supabase.auth.getUser();

    if (!authUser.user) {
      return null;
    }

    const { data, error } = await this.supabase
      .from('users')
      .select('*, dados_users(*)')
      .eq('auth_id', authUser.user.id)
      .single();

    if (error || !data) {
      console.warn('User profile not found:', error?.message);
      return null;
    }

    const user: UserModel = {
      id_user: data.id_user,
      email: data.email || '',
      nome_completo: data.nome_completo || '',
      token: (await this.supabase.auth.getSession()).data.session?.access_token,
      dados_fluxograma: data.dados_users?.[0]?.fluxograma_atual
        ? JSON.parse(data.dados_users[0].fluxograma_atual)
        : undefined
    };

    authStore.setUser(user);
    return user;
  }

  /**
   * Update user's fluxograma data — DIRECT SUPABASE QUERY (no backend call)
   * REPLACES: POST /fluxograma/upload-dados-fluxograma
   */
  async updateFluxograma(dados: DadosFluxogramaUser): Promise<boolean> {
    try {
      const user = authStore.getUser();

      if (!user) {
        throw new Error('Usuário não autenticado');
      }

      const { error } = await this.supabase
        .from('dados_users')
        .upsert(
          {
            id_user: user.id_user,
            fluxograma_atual: JSON.stringify(dados)
          },
          { onConflict: 'id_user' }
        );

      if (error) {
        console.error('Failed to update fluxograma:', error.message);
        return false;
      }

      authStore.updateDadosFluxograma(dados);
      return true;
    } catch (error) {
      console.error('updateFluxograma error:', error);
      return false;
    }
  }

  /**
   * Sync user state after app loads — DIRECT SUPABASE QUERY
   */
  async syncUserState(): Promise<void> {
    const { data: authUser } = await this.supabase.auth.getUser();

    if (!authUser.user) {
      authStore.setLoading(false);
      return;
    }

    const user = await this.fetchCurrentUser();

    if (!user) {
      console.warn('User not found in database');
      authStore.setError('Usuário não encontrado no sistema. Contate o suporte.');
    }
  }
}

export const userService = new UserService();
```

### 8.2 API Request Helper

> **Note:** `apiRequest` is now only needed for the 3 backend endpoints (PDF upload, discipline matching, AI assistant). Most data access uses direct Supabase queries.

Create `src/lib/utils/api.ts`:

```typescript
import { authService } from '$lib/services/auth.service';
import { PUBLIC_API_URL } from '$env/static/public';

type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';

interface ApiOptions {
  method?: HttpMethod;
  body?: unknown;
  headers?: Record<string, string>;
  requireAuth?: boolean;
}

/**
 * Generic API request helper — for the few remaining backend API calls only.
 * For data queries, use direct Supabase queries instead.
 */
export async function apiRequest<T>(
  endpoint: string,
  options: ApiOptions = {}
): Promise<{ data: T | null; error: string | null; status: number }> {
  const {
    method = 'GET',
    body,
    headers = {},
    requireAuth = true,
  } = options;

  try {
    let requestHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
      ...headers,
    };

    if (requireAuth) {
      const authHeaders = await authService.getAuthHeaders();
      requestHeaders = { ...requestHeaders, ...authHeaders };
    }

    const response = await fetch(`${PUBLIC_API_URL}${endpoint}`, {
      method,
      headers: requestHeaders,
      body: body ? JSON.stringify(body) : undefined,
    });

    const status = response.status;

    if (!response.ok) {
      const errorText = await response.text();
      return { data: null, error: errorText, status };
    }

    const data = await response.json();
    return { data, error: null, status };
  } catch (error) {
    return {
      data: null,
      error: error instanceof Error ? error.message : 'Unknown error',
      status: 0,
    };
  }
}
```

---

## 9. Logout Flow

### 9.1 Logout Handler

Create `src/lib/components/auth/LogoutButton.svelte`:

```svelte
<script lang="ts">
  import { authService } from '$lib/services/auth.service';
  import { goto } from '$app/navigation';

  let loading = false;

  async function handleLogout() {
    loading = true;
    
    try {
      await authService.signOut();
      await goto('/');
    } catch (error) {
      console.error('Logout error:', error);
      // Still redirect even if signout fails
      await goto('/');
    } finally {
      loading = false;
    }
  }
</script>

<button
  class="logout-btn"
  on:click={handleLogout}
  disabled={loading}
>
  {#if loading}
    Saindo...
  {:else}
    <slot>Sair</slot>
  {/if}
</button>

<style>
  .logout-btn {
    background: transparent;
    border: 1px solid currentColor;
    padding: 0.5rem 1rem;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.875rem;
    transition: all 0.2s;
  }

  .logout-btn:hover:not(:disabled) {
    background: rgba(0, 0, 0, 0.05);
  }

  .logout-btn:disabled {
    opacity: 0.7;
    cursor: not-allowed;
  }
</style>
```

### 9.2 Complete Signout Process

The signout process should:

1. Call Supabase `auth.signOut()`
2. Clear the auth store (`authStore.clear()`)
3. Clear localStorage (`nofluxo_user`, `nofluxo_anonimo`)
4. Clear anonymous cookie
5. Redirect to home/login

This is all handled in the `AuthService.signOut()` method and `authStore.clear()`.

---

## 10. Error Handling

### 10.1 Auth Error Types

Create `src/lib/types/errors.ts`:

```typescript
export enum AuthErrorCode {
  INVALID_CREDENTIALS = 'invalid_credentials',
  USER_NOT_FOUND = 'user_not_found',
  EMAIL_NOT_CONFIRMED = 'email_not_confirmed',
  SIGNUP_DISABLED = 'signup_disabled',
  WEAK_PASSWORD = 'weak_password',
  EMAIL_IN_USE = 'email_in_use',
  SESSION_EXPIRED = 'session_expired',
  NETWORK_ERROR = 'network_error',
  BACKEND_ERROR = 'backend_error',
  UNKNOWN = 'unknown',
}

export interface AuthError {
  code: AuthErrorCode;
  message: string;
  originalError?: unknown;
}

export function parseAuthError(error: unknown): AuthError {
  if (error instanceof Error) {
    const message = error.message.toLowerCase();

    if (message.includes('invalid login credentials')) {
      return {
        code: AuthErrorCode.INVALID_CREDENTIALS,
        message: 'Email ou senha incorretos',
        originalError: error,
      };
    }

    if (message.includes('email not confirmed')) {
      return {
        code: AuthErrorCode.EMAIL_NOT_CONFIRMED,
        message: 'Por favor, confirme seu email antes de fazer login',
        originalError: error,
      };
    }

    if (message.includes('user already registered')) {
      return {
        code: AuthErrorCode.EMAIL_IN_USE,
        message: 'Este email já está em uso',
        originalError: error,
      };
    }

    if (message.includes('password should be at least')) {
      return {
        code: AuthErrorCode.WEAK_PASSWORD,
        message: 'A senha deve ter pelo menos 6 caracteres',
        originalError: error,
      };
    }

    if (message.includes('session') && message.includes('expired')) {
      return {
        code: AuthErrorCode.SESSION_EXPIRED,
        message: 'Sua sessão expirou. Por favor, faça login novamente',
        originalError: error,
      };
    }

    if (message.includes('network') || message.includes('fetch')) {
      return {
        code: AuthErrorCode.NETWORK_ERROR,
        message: 'Erro de conexão. Verifique sua internet',
        originalError: error,
      };
    }
  }

  return {
    code: AuthErrorCode.UNKNOWN,
    message: 'Ocorreu um erro inesperado. Tente novamente',
    originalError: error,
  };
}
```

### 10.2 Error Display Component

Create `src/lib/components/ui/AuthErrorAlert.svelte`:

```svelte
<script lang="ts">
  import { authError } from '$lib/stores/auth';
  import { parseAuthError, type AuthError } from '$lib/types/errors';
  import { fade } from 'svelte/transition';

  export let error: string | null = null;

  $: displayError = error || $authError;
  $: parsedError = displayError ? parseAuthError(new Error(displayError)) : null;

  function dismiss() {
    // Clear from store if it's a store error
    if ($authError) {
      // authStore.setError(null);
    }
  }
</script>

{#if parsedError}
  <div
    class="error-alert"
    class:network={parsedError.code === 'network_error'}
    class:session={parsedError.code === 'session_expired'}
    transition:fade={{ duration: 200 }}
    role="alert"
  >
    <span class="icon">⚠️</span>
    <span class="message">{parsedError.message}</span>
    <button class="dismiss" on:click={dismiss} aria-label="Fechar">×</button>
  </div>
{/if}

<style>
  .error-alert {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    background: #fef2f2;
    border: 1px solid #fecaca;
    border-radius: 8px;
    padding: 0.75rem 1rem;
    color: #991b1b;
    margin-bottom: 1rem;
  }

  .error-alert.network {
    background: #fefce8;
    border-color: #fef08a;
    color: #854d0e;
  }

  .error-alert.session {
    background: #f0f9ff;
    border-color: #bae6fd;
    color: #075985;
  }

  .icon {
    flex-shrink: 0;
  }

  .message {
    flex: 1;
    font-size: 0.875rem;
  }

  .dismiss {
    background: none;
    border: none;
    font-size: 1.25rem;
    cursor: pointer;
    padding: 0;
    line-height: 1;
    opacity: 0.7;
    color: inherit;
  }

  .dismiss:hover {
    opacity: 1;
  }
</style>
```

### 10.3 Error Boundary for Auth Failures

Create `src/lib/components/auth/AuthErrorBoundary.svelte`:

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { authStore } from '$lib/stores/auth';
  import { goto } from '$app/navigation';

  export let fallbackRoute = '/login';

  let hasError = false;
  let errorMessage = '';

  onMount(() => {
    const unsubscribe = authStore.subscribe((state) => {
      if (state.error) {
        // Check for critical errors that require redirect
        if (
          state.error.includes('session') ||
          state.error.includes('token') ||
          state.error.includes('não encontrado')
        ) {
          hasError = true;
          errorMessage = state.error;
        }
      }
    });

    return unsubscribe;
  });

  function handleRetry() {
    hasError = false;
    errorMessage = '';
    goto(fallbackRoute);
  }
</script>

{#if hasError}
  <div class="error-boundary">
    <div class="error-card">
      <div class="icon">🔒</div>
      <h2>Problema de autenticação</h2>
      <p>{errorMessage}</p>
      <button on:click={handleRetry}>
        Fazer login novamente
      </button>
    </div>
  </div>
{:else}
  <slot />
{/if}

<style>
  .error-boundary {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
    background: #f5f5f5;
  }

  .error-card {
    background: white;
    border-radius: 12px;
    padding: 2rem;
    text-align: center;
    max-width: 400px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }

  .icon {
    font-size: 3rem;
    margin-bottom: 1rem;
  }

  h2 {
    color: #333;
    margin-bottom: 0.5rem;
  }

  p {
    color: #666;
    margin-bottom: 1.5rem;
  }

  button {
    background: #183c8b;
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 8px;
    font-size: 1rem;
    cursor: pointer;
    transition: background 0.2s;
  }

  button:hover {
    background: #122d6a;
  }
</style>
```

---

## 11. Migration Checklist

### Phase 1: Setup
- [x] Install `@supabase/ssr` and `@supabase/supabase-js`
- [x] Configure environment variables
- [x] Create `src/lib/supabase/client.ts`
- [x] Update `src/hooks.server.ts` with Supabase SSR
- [x] Define TypeScript types in `src/app.d.ts`

### Phase 2: Stores & Services
- [x] Create auth types in `src/lib/types/auth.ts`
- [x] Implement auth store in `src/lib/stores/auth.ts`
- [x] Implement auth service in `src/lib/services/auth.service.ts`
- [x] Create user service in `src/lib/services/user.service.ts`

### Phase 3: Auth UI Components
- [x] Create `LoginForm.svelte`
- [x] Create `SignupForm.svelte`
- [x] Create `AnonymousLogin.svelte`
- [x] Create `PasswordRecovery.svelte`
- [x] Create `LogoutButton.svelte`

### Phase 4: Route Protection
- [x] Implement server-side route guard in `hooks.server.ts`
- [x] Create client-side guard utilities
- [x] Add auth check to root layout
- [x] Create OAuth callback route

### Phase 5: Error Handling
- [x] Define error types and parser
- [x] Create error display components
- [x] Add error boundaries

### Phase 6: Testing
- [ ] Test email/password signup
- [ ] Test email/password login
- [ ] Test Google OAuth flow
- [ ] Test anonymous login
- [ ] Test session persistence
- [ ] Test logout flow
- [ ] Test route protection
- [ ] Test backend user sync

> **Note:** Implementation complete. Manual testing pending against live backend.

---

## 12. Key Differences from Flutter

| Aspect | Flutter | SvelteKit |
|--------|---------|-----------|
| State Management | Singleton + SharedPreferences | Svelte stores + localStorage |
| Route Guards | go_router redirect | hooks.server.ts + client guards |
| OAuth Flow | In-app browser | Full redirect flow |
| Session Persistence | SharedPreferences | Cookies (SSR) + localStorage |
| Token Refresh | Manual stream handling | Supabase SSR auto-handles |
| API Headers | Manual from session | Helper function with refresh |
| Anonymous Login | Boolean in SharedPreferences | Cookie + store flag |

---

## 13. Environment Configuration

### Development (.env.development)
```env
PUBLIC_SUPABASE_URL=https://lijmhbstgdinsukovyfl.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your_dev_key
PUBLIC_API_URL=http://localhost:3000
```

### Production (.env.production)
```env
PUBLIC_SUPABASE_URL=https://lijmhbstgdinsukovyfl.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your_prod_key
PUBLIC_API_URL=https://nofluxo.lappis.rocks
```

---

## 14. Security Considerations

1. **Never expose `SUPABASE_SERVICE_ROLE_KEY`** in client code
2. **Use `httpOnly` cookies** for session tokens when possible
3. **Validate sessions server-side** in `hooks.server.ts`
4. **Implement rate limiting** on auth endpoints
5. **Use PKCE flow** for OAuth (default in `@supabase/ssr`)
6. **Sanitize redirect URLs** to prevent open redirect attacks
7. **Clear all auth state** on logout including localStorage and cookies

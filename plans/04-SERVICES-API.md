# 04 - Services and API Migration

This document covers the migration of Flutter services and API communication patterns to SvelteKit with TypeScript.

> **⚡ ARCHITECTURE UPDATE (Feb 2026):** Most backend endpoints have been replaced by **direct Supabase queries** from the frontend using Row-Level Security (RLS). Only 3 endpoints remain on the backend. See [14-SUPABASE-DIRECT-RLS.md](14-SUPABASE-DIRECT-RLS.md) for the full RLS setup and migration SQL.

## Table of Contents

1. [Backend Endpoints Summary (Updated)](#1-backend-endpoints-summary-updated)
2. [HTTP Client Setup](#2-http-client-setup)
3. [Environment Configuration](#3-environment-configuration)
4. [API Service Pattern](#4-api-service-pattern)
5. [AuthService Migration](#5-authservice-migration)
6. [FluxogramaService Migration](#6-fluxogramaservice-migration)
7. [UploadService Migration](#7-uploadservice-migration)
8. [AI Assistant Service](#8-ai-assistant-service)
9. [Error Handling](#9-error-handling)
10. [SvelteKit Server Routes](#10-sveltekit-server-routes)
11. [Type Safety](#11-type-safety)

---

## 1. Backend Endpoints Summary (Updated)

### Architecture Change: Direct Supabase + RLS

Most data previously fetched through the backend is now queried **directly from the frontend** using the Supabase JS client with the **anon key** and **Row-Level Security (RLS)** policies. This eliminates the backend as a middleman for simple CRUD operations.

```
BEFORE:  Frontend → Backend (Express + Service Role Key) → Supabase
AFTER:   Frontend → Supabase (Anon Key + RLS)              ← 9 endpoints
         Frontend → Backend → External Services             ← 3 endpoints only
```

### Endpoints Now Using Direct Supabase (NO backend call)

| Old Endpoint | Replacement | Notes |
|-------------|-------------|-------|
| `GET /users/get-user-by-email` | `supabase.from('users').select('*, dados_users(*)').eq('auth_id', uid)` | RLS: users can read own record |
| `POST /users/register-user-with-google` | `supabase.from('users').insert({...})` | RLS: users can insert own record |
| `POST /users/registrar-user-with-email` | `supabase.from('users').insert({...})` | RLS: users can insert own record |
| `GET /cursos/all-cursos` | `supabase.from('creditos_por_curso').select('*')` | RLS: public read |
| `GET /fluxograma/fluxograma` | Multiple Supabase queries (cursos + materias + prereqs + coreqs + equivalencias) | RLS: public read on academic tables |
| `POST /materias/materias-name-by-code` | `supabase.from('materias').select(...).in('codigo_materia', codes)` | RLS: public read |
| `POST /materias/materias-from-codigos` | `supabase.from('materias').select('*, materias_por_curso!inner(...)').in(...)` | RLS: public read |
| `POST /fluxograma/upload-dados-fluxograma` | `supabase.from('dados_users').upsert({...})` | RLS: users can write own data |
| `DELETE /fluxograma/delete-fluxograma` | `supabase.from('dados_users').delete().eq('id_user', uid)` | RLS: users can delete own data |

### Endpoints Still on Backend API (`Environment.apiUrl` - default: `http://localhost:3000`)

| Endpoint | Method | Description | Why It Stays |
|----------|--------|-------------|--------------|
| `/fluxograma/read_pdf` | POST | Upload and parse PDF transcript | Proxies to Python PDF parser microservice (port 3001) |
| `/fluxograma/casar_disciplinas` | POST | Match extracted disciplines | ~500 lines of complex business logic (multi-matrix matching, equivalency resolution, deduplication) |

### AI Agent API (`Environment.agentUrl` - default: `http://localhost:4652`)

| Endpoint | Method | Description | Why It Stays |
|----------|--------|-------------|--------------|
| `/assistente` | POST | Send message to AI assistant | External RAGFlow service, API key must stay server-side |

---

## 2. HTTP Client Setup

Create a base HTTP client wrapper with error handling, request/response interceptors, and type safety.

### `src/lib/api/client.ts`

```typescript
import { browser } from '$app/environment';
import { env } from '$env/dynamic/public';
import { Result, ok, err } from '$lib/utils/result';

export interface RequestOptions extends RequestInit {
  params?: Record<string, string>;
  timeout?: number;
}

export interface ApiError {
  message: string;
  status: number;
  code?: string;
  details?: unknown;
}

export class HttpClient {
  private baseUrl: string;
  private defaultHeaders: HeadersInit;

  constructor(baseUrl: string, defaultHeaders: HeadersInit = {}) {
    this.baseUrl = baseUrl;
    this.defaultHeaders = defaultHeaders;
  }

  private buildUrl(path: string, params?: Record<string, string>): string {
    const url = new URL(path, this.baseUrl);
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        url.searchParams.append(key, value);
      });
    }
    return url.toString();
  }

  private async handleResponse<T>(response: Response): Promise<Result<T, ApiError>> {
    if (!response.ok) {
      let errorMessage = `HTTP ${response.status}`;
      let details: unknown;

      try {
        const errorBody = await response.json();
        errorMessage = errorBody.error || errorBody.message || errorMessage;
        details = errorBody;
      } catch {
        errorMessage = await response.text().catch(() => errorMessage);
      }

      return err({
        message: errorMessage,
        status: response.status,
        details
      });
    }

    try {
      const data = await response.json();
      return ok(data as T);
    } catch {
      // Empty response is okay for some endpoints
      return ok(undefined as T);
    }
  }

  async get<T>(path: string, options: RequestOptions = {}): Promise<Result<T, ApiError>> {
    const { params, timeout = 30000, ...fetchOptions } = options;

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);

      const response = await fetch(this.buildUrl(path, params), {
        method: 'GET',
        headers: { ...this.defaultHeaders, ...fetchOptions.headers },
        signal: controller.signal,
        ...fetchOptions
      });

      clearTimeout(timeoutId);
      return this.handleResponse<T>(response);
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        return err({ message: 'Request timeout', status: 408 });
      }
      return err({
        message: error instanceof Error ? error.message : 'Network error',
        status: 0
      });
    }
  }

  async post<T>(
    path: string,
    body?: unknown,
    options: RequestOptions = {}
  ): Promise<Result<T, ApiError>> {
    const { params, timeout = 30000, ...fetchOptions } = options;

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);

      const headers: HeadersInit = {
        'Content-Type': 'application/json',
        ...this.defaultHeaders,
        ...fetchOptions.headers
      };

      const response = await fetch(this.buildUrl(path, params), {
        method: 'POST',
        headers,
        body: body ? JSON.stringify(body) : undefined,
        signal: controller.signal,
        ...fetchOptions
      });

      clearTimeout(timeoutId);
      return this.handleResponse<T>(response);
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        return err({ message: 'Request timeout', status: 408 });
      }
      return err({
        message: error instanceof Error ? error.message : 'Network error',
        status: 0
      });
    }
  }

  async postFormData<T>(
    path: string,
    formData: FormData,
    options: RequestOptions = {}
  ): Promise<Result<T, ApiError>> {
    const { params, timeout = 60000, ...fetchOptions } = options;

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);

      // Don't set Content-Type header - browser will set it with boundary
      const response = await fetch(this.buildUrl(path, params), {
        method: 'POST',
        headers: { ...this.defaultHeaders, ...fetchOptions.headers },
        body: formData,
        signal: controller.signal,
        ...fetchOptions
      });

      clearTimeout(timeoutId);
      return this.handleResponse<T>(response);
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        return err({ message: 'Request timeout', status: 408 });
      }
      return err({
        message: error instanceof Error ? error.message : 'Network error',
        status: 0
      });
    }
  }

  async delete<T>(path: string, options: RequestOptions = {}): Promise<Result<T, ApiError>> {
    const { params, timeout = 30000, ...fetchOptions } = options;

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);

      const response = await fetch(this.buildUrl(path, params), {
        method: 'DELETE',
        headers: { ...this.defaultHeaders, ...fetchOptions.headers },
        signal: controller.signal,
        ...fetchOptions
      });

      clearTimeout(timeoutId);
      return this.handleResponse<T>(response);
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        return err({ message: 'Request timeout', status: 408 });
      }
      return err({
        message: error instanceof Error ? error.message : 'Network error',
        status: 0
      });
    }
  }

  setHeader(key: string, value: string): void {
    this.defaultHeaders = { ...this.defaultHeaders, [key]: value };
  }

  removeHeader(key: string): void {
    const headers = { ...this.defaultHeaders } as Record<string, string>;
    delete headers[key];
    this.defaultHeaders = headers;
  }
}

// Singleton instances
export const apiClient = new HttpClient(
  browser ? (env.PUBLIC_API_URL || 'http://localhost:3000') : ''
);

export const aiClient = new HttpClient(
  browser ? (env.PUBLIC_AGENT_URL || 'http://localhost:4652') : ''
);
```

---

## 3. Environment Configuration

### SvelteKit Environment Variables

Create `.env` files for different environments:

#### `.env`

```env
# Backend API
PUBLIC_API_URL=http://localhost:3000
PUBLIC_AGENT_URL=http://localhost:4652

# Supabase
PUBLIC_SUPABASE_URL=your-supabase-url
PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key

# OAuth Redirect
PUBLIC_REDIRECT_URL=http://localhost:5173
```

#### `.env.production`

```env
PUBLIC_API_URL=https://nofluxo.lappis.rocks
PUBLIC_AGENT_URL=https://ai.nofluxo.arthrok.shop
PUBLIC_SUPABASE_URL=your-production-supabase-url
PUBLIC_SUPABASE_ANON_KEY=your-production-anon-key
PUBLIC_REDIRECT_URL=https://no-fluxo.com
```

### Environment Helper

#### `src/lib/config/env.ts`

```typescript
import { browser } from '$app/environment';
import { env } from '$env/dynamic/public';

export type EnvironmentType = 'development' | 'production';

interface EnvironmentConfig {
  apiUrl: string;
  agentUrl: string;
  supabaseUrl: string;
  supabaseAnonKey: string;
  redirectUrl: string;
  environmentType: EnvironmentType;
}

function getEnvironmentConfig(): EnvironmentConfig {
  // Server-side should use private env vars when needed
  if (!browser) {
    return {
      apiUrl: '',
      agentUrl: '',
      supabaseUrl: '',
      supabaseAnonKey: '',
      redirectUrl: '',
      environmentType: 'development'
    };
  }

  const isProd = env.PUBLIC_API_URL?.includes('nofluxo.lappis.rocks') || false;

  return {
    apiUrl: env.PUBLIC_API_URL || 'http://localhost:3000',
    agentUrl: env.PUBLIC_AGENT_URL || 'http://localhost:4652',
    supabaseUrl: env.PUBLIC_SUPABASE_URL || '',
    supabaseAnonKey: env.PUBLIC_SUPABASE_ANON_KEY || '',
    redirectUrl: env.PUBLIC_REDIRECT_URL || 'http://localhost:5173',
    environmentType: isProd ? 'production' : 'development'
  };
}

export const config = getEnvironmentConfig();

export function isDevelopment(): boolean {
  return config.environmentType === 'development';
}

export function isProduction(): boolean {
  return config.environmentType === 'production';
}
```

---

## 4. API Service Pattern

Recommended service structure using dependency injection and the Result type pattern.

### `src/lib/services/base.service.ts`

```typescript
import type { HttpClient, ApiError } from '$lib/api/client';
import type { Result } from '$lib/utils/result';

export abstract class BaseService {
  protected client: HttpClient;

  constructor(client: HttpClient) {
    this.client = client;
  }

  protected log(level: 'info' | 'warn' | 'error', message: string, data?: unknown): void {
    const timestamp = new Date().toISOString();
    const prefix = `[${level.toUpperCase()}][${timestamp}][${this.constructor.name}]`;

    if (level === 'error') {
      console.error(prefix, message, data);
    } else if (level === 'warn') {
      console.warn(prefix, message, data);
    } else {
      console.log(prefix, message, data);
    }
  }
}
```

### Service Factory Pattern

> **⚡ Updated:** Services no longer depend on a shared `HttpClient` for most operations. Instead, they use the Supabase browser client directly. Only the `UploadService` and `AssistenteService` still use `fetch` to call backend/external APIs.

#### `src/lib/services/index.ts`

```typescript
import { authService } from './auth.service';
import { fluxogramaService } from './fluxograma.service';
import { uploadService } from './upload.service';
import { assistenteService } from './assistente.service';

// Re-export singleton instances
export { authService, fluxogramaService, uploadService, assistenteService };

// Re-export types
export type { AuthService } from './auth.service';
export type { FluxogramaService } from './fluxograma.service';
export type { UploadService } from './upload.service';
export type { AssistenteService } from './assistente.service';
```

---

## 5. AuthService Migration

> **⚡ Updated:** User lookup and registration now use **direct Supabase queries** instead of backend API calls. The backend `users` endpoints are no longer needed.

### Types

#### `src/lib/types/user.ts`

```typescript
export interface User {
  id_user: number;
  email: string;
  nome_completo: string;
  auth_id?: string;  // Links to Supabase auth.users.id
  avatar_url?: string;
  token?: string;
  created_at?: string;
  updated_at?: string;
}

export interface AuthUser {
  id: string;
  email?: string;
  user_metadata?: {
    display_name?: string;
    avatar_url?: string;
    full_name?: string;
  };
}

export interface Session {
  access_token: string;
  refresh_token: string;
  expires_at?: number;
  user: AuthUser;
}
```

### AuthService Implementation (Direct Supabase)

#### `src/lib/services/auth.service.ts`

```typescript
import type { User, AuthUser, Session } from '$lib/types/user';
import { createSupabaseBrowserClient } from '$lib/supabase/client';
import { userStore } from '$lib/stores/user.store';

export class AuthService {
  private supabase = createSupabaseBrowserClient();

  /**
   * Search for user in database by their auth ID (direct Supabase query)
   * REPLACES: GET /users/get-user-by-email
   */
  async getUserProfile(): Promise<{ success: true; user: User } | { success: false; error: string }> {
    const { data: authUser } = await this.supabase.auth.getUser();
    if (!authUser.user) {
      return { success: false, error: 'Não autenticado' };
    }

    const { data, error } = await this.supabase
      .from('users')
      .select('*, dados_users(*)')
      .eq('auth_id', authUser.user.id)
      .single();

    if (error || !data) {
      return { success: false, error: error?.message || 'Usuário não encontrado' };
    }

    const user: User = {
      id_user: data.id_user,
      email: data.email || '',
      nome_completo: data.nome_completo || '',
      auth_id: data.auth_id,
      token: (await this.supabase.auth.getSession()).data.session?.access_token
    };

    return { success: true, user };
  }

  /**
   * Register user in database (direct Supabase insert)
   * REPLACES: POST /users/register-user-with-google AND POST /users/registrar-user-with-email
   */
  async registerUserInDB(
    email: string,
    nomeCompleto: string
  ): Promise<{ success: true; user: User } | { success: false; error: string }> {
    const { data: authUser } = await this.supabase.auth.getUser();
    if (!authUser.user) {
      return { success: false, error: 'Não autenticado' };
    }

    const { data, error } = await this.supabase
      .from('users')
      .insert({
        email,
        nome_completo: nomeCompleto,
        auth_id: authUser.user.id
      })
      .select()
      .single();

    if (error) {
      // User already exists (unique constraint on auth_id)
      if (error.code === '23505') {
        return this.getUserProfile();
      }
      return { success: false, error: error.message };
    }

    const user: User = {
      id_user: data.id_user,
      email: data.email || '',
      nome_completo: data.nome_completo || '',
      auth_id: data.auth_id,
      token: (await this.supabase.auth.getSession()).data.session?.access_token
    };

    return { success: true, user };
  }

  /**
   * Sign up with email and password (Supabase Auth + direct DB registration)
   */
  async signUpWithEmailAndPassword(
    email: string,
    password: string,
    displayName?: string
  ): Promise<{ success: true; user: AuthUser } | { success: false; error: string }> {
    try {
      // 1. Create user in Supabase Auth
      const { data: authData, error: authError } = await this.supabase.auth.signUp({
        email,
        password,
        options: {
          data: displayName ? { display_name: displayName } : undefined
        }
      });

      if (authError || !authData.user) {
        return { success: false, error: authError?.message || 'Erro ao criar conta' };
      }

      // 2. Register in users table (direct Supabase, no backend call)
      const dbResult = await this.registerUserInDB(
        email,
        displayName || email.split('@')[0]
      );

      if (!dbResult.success) {
        await this.supabase.auth.signOut();
        return { success: false, error: dbResult.error };
      }

      userStore.setUser(dbResult.user);
      return { success: true, user: authData.user };
    } catch (error) {
      return { success: false, error: `Erro inesperado: ${error}` };
    }
  }

  /**
   * Sign in with email and password
   */
  async signInWithEmailAndPassword(
    email: string,
    password: string
  ): Promise<{ success: true; user: AuthUser } | { success: false; error: string }> {
    try {
      const { data, error } = await this.supabase.auth.signInWithPassword({
        email,
        password
      });

      if (error || !data.user) {
        return { success: false, error: error?.message || 'Email ou senha inválidos' };
      }

      // Fetch user profile from DB (direct Supabase, no backend call)
      const userResult = await this.getUserProfile();

      if (!userResult.success) {
        return { success: false, error: 'Usuário autenticado, mas não encontrado no banco.' };
      }

      userStore.setUser(userResult.user);
      return { success: true, user: data.user };
    } catch (error) {
      return { success: false, error: `Erro inesperado: ${error}` };
    }
  }

  /**
   * Handle OAuth callback — register in DB if first login
   */
  async handleOAuthCallback(): Promise<{ success: true; user: User } | { success: false; error: string }> {
    const session = await this.getCurrentSession();

    if (!session?.user?.email) {
      return { success: false, error: 'No session found after OAuth' };
    }

    // Try to find existing user (direct Supabase query)
    let result = await this.getUserProfile();

    if (!result.success) {
      // First login — register in users table (direct Supabase insert)
      const displayName =
        session.user.user_metadata?.full_name ||
        session.user.user_metadata?.display_name ||
        session.user.email?.split('@')[0] || '';

      result = await this.registerUserInDB(session.user.email, displayName);
    }

    if (result.success) {
      userStore.setUser(result.user);
    }

    return result;
  }

  // ... (signInWithGoogle, signOut, getCurrentSession, etc. remain the same)
}
```

---

## 6. FluxogramaService Migration

> **⚡ Updated:** All course/subject data queries now use **direct Supabase queries**. The backend endpoints `/fluxograma/fluxograma`, `/cursos/all-cursos`, `/materias/*` are no longer called. Flowchart save/delete also use direct Supabase.

### Types

#### `src/lib/types/curso.ts`

```typescript
export interface Materia {
  id_materia: number;
  nome_materia: string | null;
  codigo_materia: string | null;
  carga_horaria: number | null;
  ementa: string | null;
  departamento: string | null;
  /** Populated from materias_por_curso join */
  nivel?: number;
  /** Derived fields */
  prerequisitos?: number[];
  corequisitos?: number[];
}

export interface Curso {
  id_curso: number;
  nome_curso: string | null;
  matriz_curricular: string | null;
  data_inicio_matriz: string | null;
  creditos: number | null;
  classificacao: string | null;
  tipo_curso: string | null;
}

export interface CursoComCreditos {
  id_curso: number;
  nome_curso: string | null;
  creditos_obrigatorios: number | null;
  creditos_optativos: number | null;
  creditos_totais: number | null;
}

export interface FlowchartData {
  curso: Curso;
  materias: Array<{
    id_materia_curso: number;
    id_materia: number | null;
    id_curso: number | null;
    nivel: number | null;
    materias: Materia | null;
  }>;
  equivalencias: Array<{
    id_equivalencia: number;
    codigo_materia_origem: string | null;
    nome_materia_origem: string | null;
    codigo_materia_equivalente: string | null;
    nome_materia_equivalente: string | null;
    expressao: string | null;
  }>;
  preRequisitos: Array<{
    id_pre_requisito: number;
    id_materia: number;
    id_materia_requisito: number;
  }>;
  coRequisitos: Array<{
    id_co_requisito: number;
    id_materia: number;
    id_materia_corequisito: number;
  }>;
}
```

### FluxogramaService Implementation (Direct Supabase)

#### `src/lib/services/fluxograma.service.ts`

```typescript
import { createSupabaseBrowserClient } from '$lib/supabase/client';
import type { FlowchartData, CursoComCreditos, Materia } from '$lib/types/curso';

export class FluxogramaService {
  private supabase = createSupabaseBrowserClient();

  /**
   * Get full course flowchart data by course name
   * REPLACES: GET /fluxograma/fluxograma
   */
  async getCourseData(courseName: string): Promise<FlowchartData> {
    if (!courseName.trim()) {
      throw new Error('Nome do curso não informado');
    }

    // 1. Get course
    const { data: curso, error: cursoError } = await this.supabase
      .from('cursos')
      .select('*')
      .eq('nome_curso', courseName)
      .single();

    if (cursoError || !curso) {
      throw new Error(`Curso não encontrado: ${courseName}`);
    }

    // 2. Get subjects for this course (with join to materias)
    const { data: materiasCurso, error: mcError } = await this.supabase
      .from('materias_por_curso')
      .select('*, materias(*)')
      .eq('id_curso', curso.id_curso);

    if (mcError) throw new Error(`Erro ao buscar matérias: ${mcError.message}`);

    const materiaIds = (materiasCurso || [])
      .map(mc => mc.id_materia)
      .filter((id): id is number => id !== null);

    // 3. Get equivalencies, prerequisites, co-requisites in parallel
    const [equivResult, prereqResult, coreqResult] = await Promise.all([
      this.supabase
        .from('vw_equivalencias_com_materias')
        .select('*')
        .eq('id_curso', curso.id_curso),

      materiaIds.length > 0
        ? this.supabase.from('pre_requisitos').select('*').in('id_materia', materiaIds)
        : Promise.resolve({ data: [], error: null }),

      materiaIds.length > 0
        ? this.supabase.from('co_requisitos').select('*').in('id_materia', materiaIds)
        : Promise.resolve({ data: [], error: null }),
    ]);

    return {
      curso,
      materias: materiasCurso || [],
      equivalencias: equivResult.data || [],
      preRequisitos: prereqResult.data || [],
      coRequisitos: coreqResult.data || [],
    };
  }

  /**
   * Get all courses with credit info
   * REPLACES: GET /cursos/all-cursos
   */
  async getAllCursos(): Promise<CursoComCreditos[]> {
    const { data, error } = await this.supabase
      .from('creditos_por_curso')
      .select('*')
      .order('nome_curso');

    if (error) throw new Error(`Erro ao buscar cursos: ${error.message}`);
    return data || [];
  }

  /**
   * Get subject names by their codes
   * REPLACES: GET /materias/materias-name-by-code
   */
  async getMateriaNamesByCode(codes: string[]): Promise<Record<string, string>> {
    const { data, error } = await this.supabase
      .from('materias')
      .select('codigo_materia, nome_materia')
      .in('codigo_materia', codes);

    if (error) throw new Error(`Erro ao buscar matérias: ${error.message}`);

    const map: Record<string, string> = {};
    for (const m of data || []) {
      if (m.codigo_materia && m.nome_materia) {
        map[m.codigo_materia] = m.nome_materia;
      }
    }
    return map;
  }

  /**
   * Get subjects with nivel from codes + course
   * REPLACES: POST /materias/materias-from-codigos
   */
  async getMateriasFromCodigos(codes: string[], idCurso: number) {
    const { data, error } = await this.supabase
      .from('materias')
      .select('*, materias_por_curso!inner(nivel, id_curso)')
      .in('codigo_materia', codes)
      .eq('materias_por_curso.id_curso', idCurso);

    if (error) throw new Error(`Erro ao buscar matérias do curso: ${error.message}`);
    return data || [];
  }

  /**
   * Save user's flowchart data
   * REPLACES: POST /fluxograma/upload-dados-fluxograma
   */
  async saveFluxograma(idUser: number, fluxogramaData: unknown, semestreAtual?: number) {
    const { data, error } = await this.supabase
      .from('dados_users')
      .upsert(
        {
          id_user: idUser,
          fluxograma_atual: JSON.stringify(fluxogramaData),
          semestre_atual: semestreAtual ?? null
        },
        { onConflict: 'id_user' }
      )
      .select()
      .single();

    if (error) throw new Error(`Erro ao salvar fluxograma: ${error.message}`);
    return data;
  }

  /**
   * Delete user's flowchart
   * REPLACES: DELETE /fluxograma/delete-fluxograma
   */
  async deleteFluxograma(idUser: number) {
    const { error } = await this.supabase
      .from('dados_users')
      .delete()
      .eq('id_user', idUser);

    if (error) throw new Error(`Erro ao deletar fluxograma: ${error.message}`);
    return true;
  }
}

// Singleton
export const fluxogramaService = new FluxogramaService();
```

---

## 7. UploadService Migration

> **⚡ Updated:** This is now a **hybrid service**. PDF parsing and discipline matching still call the backend (complex logic / external service). But saving flowchart data uses **direct Supabase** insert.

### Types

#### `src/lib/types/upload.ts`

```typescript
export interface ExtractedPdfData {
  extracted_data: ExtractedDiscipline[];
  curso_extraido: string;
  matriz_curricular: string;
  media_ponderada?: number;
  frequencia_geral?: number;
}

export interface ExtractedDiscipline {
  codigo: string;
  nome: string;
  creditos?: number;
  status?: string;
  nota?: number;
  periodo?: string;
}

export interface DisciplineMatchResult {
  disciplinas_casadas: MatchedDiscipline[];
  materias_concluidas: Materia[];
  materias_pendentes: Materia[];
  materias_optativas: Materia[];
  resumo: MatchSummary;
  dados_validacao: ValidationData;
}

export interface MatchedDiscipline {
  codigo: string;
  nome: string;
  encontrada_no_banco: boolean;
  id_materia?: number;
  status?: string;
}

export interface MatchSummary {
  percentual_conclusao_obrigatorias: number;
  total_disciplinas: number;
  total_obrigatorias_concluidas: number;
  total_obrigatorias_pendentes: number;
  total_optativas: number;
}

export interface ValidationData {
  ira?: number;
  media_ponderada?: number;
  frequencia_geral?: number;
  horas_integralizadas?: number;
  pendencias?: string[] | Record<string, string>;
  curso_extraido?: string;
  matriz_curricular?: string;
}

export interface CourseSelectionError {
  message: string;
  cursos_disponiveis: Array<{ id: number; nome: string }>;
}

export function isCourseSelectionError(
  data: unknown
): data is CourseSelectionError {
  return (
    typeof data === 'object' &&
    data !== null &&
    'cursos_disponiveis' in data &&
    Array.isArray((data as CourseSelectionError).cursos_disponiveis)
  );
}
```

### UploadService Implementation (Hybrid: Backend + Direct Supabase)

#### `src/lib/services/upload.service.ts`

```typescript
import { PUBLIC_API_URL } from '$env/static/public';
import { createSupabaseBrowserClient } from '$lib/supabase/client';
import type { ExtractedPdfData, DisciplineMatchResult } from '$lib/types/upload';
import { isCourseSelectionError } from '$lib/types/upload';

export class UploadService {
  private supabase = createSupabaseBrowserClient();

  /**
   * Upload PDF transcript and extract data
   * ⚠️ STILL CALLS BACKEND — proxies to Python PDF parser microservice
   */
  async uploadPdf(file: File): Promise<ExtractedPdfData> {
    const formData = new FormData();
    formData.append('pdf', file, file.name);

    const response = await fetch(`${PUBLIC_API_URL}/fluxograma/read_pdf`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) {
      throw new Error(`Erro ao processar PDF: ${response.statusText}`);
    }

    return response.json();
  }

  /**
   * Match extracted disciplines with database
   * ⚠️ STILL CALLS BACKEND — ~500 lines of complex business logic
   */
  async casarDisciplinas(dadosExtraidos: ExtractedPdfData): Promise<DisciplineMatchResult> {
    const response = await fetch(`${PUBLIC_API_URL}/fluxograma/casar_disciplinas`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ dados_extraidos: dadosExtraidos })
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({ error: response.statusText }));

      if (isCourseSelectionError(errorData)) {
        throw errorData; // Contains cursos_disponiveis for user selection
      }

      throw new Error(errorData.error || 'Erro no casamento de disciplinas');
    }

    return response.json();
  }

  /**
   * Save flowchart data to database
   * ✅ NOW USES DIRECT SUPABASE — replaces POST /fluxograma/upload-dados-fluxograma
   */
  async saveFluxogramaToDB(idUser: number, fluxogramaData: unknown, semestreAtual?: number) {
    const { data, error } = await this.supabase
      .from('dados_users')
      .upsert(
        {
          id_user: idUser,
          fluxograma_atual: JSON.stringify(fluxogramaData),
          semestre_atual: semestreAtual ?? null
        },
        { onConflict: 'id_user' }
      )
      .select()
      .single();

    if (error) throw new Error(`Erro ao salvar fluxograma: ${error.message}`);
    return data;
  }
}

// Singleton
export const uploadService = new UploadService();
```

### Usage Example with SvelteKit

```svelte
<script lang="ts">
  import { uploadService } from '$lib/services';

  let uploading = false;
  let error = '';

  async function handleFileUpload(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];

    if (!file || file.type !== 'application/pdf') {
      error = 'Por favor, selecione um arquivo PDF válido.';
      return;
    }

    uploading = true;
    error = '';

    // Step 1: Upload and extract PDF data
    const uploadResult = await uploadService.uploadPdf(file);

    if (!uploadResult.ok) {
      error = uploadResult.error.message;
      uploading = false;
      return;
    }

    // Step 2: Match disciplines
    const matchResult = await uploadService.casarDisciplinas(uploadResult.value);

    if (!matchResult.ok) {
      // Check if it's a course selection error
      if ('cursos_disponiveis' in matchResult.error) {
        // Handle course selection UI
        console.log('Courses available:', matchResult.error.cursos_disponiveis);
      } else {
        error = matchResult.error.message;
      }
      uploading = false;
      return;
    }

    console.log('Matching complete:', matchResult.value);
    uploading = false;
  }
</script>

<input type="file" accept=".pdf" on:change={handleFileUpload} disabled={uploading} />
{#if error}
  <p class="error">{error}</p>
{/if}
```

---

## 8. AI Assistant Service

### Types

#### `src/lib/types/assistente.ts`

```typescript
export interface ChatMessage {
  isUser: boolean;
  text: string;
  timestamp?: Date;
}

export interface AssistenteRequest {
  materia: string;
}

export interface AssistenteResponse {
  resultado?: string;
  erro?: string;
}
```

### AssistenteService Implementation

#### `src/lib/services/assistente.service.ts`

```typescript
import { BaseService } from './base.service';
import type { HttpClient, ApiError } from '$lib/api/client';
import { Result, ok, err } from '$lib/utils/result';
import type { AssistenteResponse } from '$lib/types/assistente';

export class AssistenteService extends BaseService {
  constructor(client: HttpClient) {
    super(client);
  }

  /**
   * Send message to AI assistant
   */
  async sendMessage(mensagem: string): Promise<Result<string, ApiError>> {
    this.log('info', `Sending message to AI: ${mensagem.substring(0, 50)}...`);

    const result = await this.client.post<AssistenteResponse>(
      '/assistente',
      { materia: mensagem },
      { timeout: 60000 } // 60 second timeout for AI responses
    );

    if (result.ok) {
      const response = result.value;

      if (response.erro) {
        return err({
          message: response.erro,
          status: 400
        });
      }

      return ok(response.resultado || 'Sem resposta da IA.');
    }

    return err(result.error);
  }
}
```

### Svelte Store for Chat

#### `src/lib/stores/chat.store.ts`

```typescript
import { writable, derived } from 'svelte/store';
import type { ChatMessage } from '$lib/types/assistente';

interface ChatState {
  messages: ChatMessage[];
  isLoading: boolean;
  error: string | null;
}

const initialMessage: ChatMessage = {
  isUser: false,
  text: `Olá! Sou o assistente NoFluxo. Estou aqui para te ajudar a encontrar matérias interessantes para adicionar ao seu fluxograma.
Me conte quais áreas você tem interesse ou quais habilidades gostaria de desenvolver!`,
  timestamp: new Date()
};

function createChatStore() {
  const { subscribe, set, update } = writable<ChatState>({
    messages: [initialMessage],
    isLoading: false,
    error: null
  });

  return {
    subscribe,

    addUserMessage(text: string) {
      update((state) => ({
        ...state,
        messages: [
          ...state.messages,
          { isUser: true, text, timestamp: new Date() }
        ],
        error: null
      }));
    },

    addAssistantMessage(text: string) {
      update((state) => ({
        ...state,
        messages: [
          ...state.messages,
          { isUser: false, text, timestamp: new Date() }
        ]
      }));
    },

    setLoading(isLoading: boolean) {
      update((state) => ({ ...state, isLoading }));
    },

    setError(error: string | null) {
      update((state) => ({ ...state, error }));
    },

    reset() {
      set({
        messages: [initialMessage],
        isLoading: false,
        error: null
      });
    }
  };
}

export const chatStore = createChatStore();

// Derived store for just messages
export const messages = derived(chatStore, ($chat) => $chat.messages);
export const isLoading = derived(chatStore, ($chat) => $chat.isLoading);
```

### Chat Component Example

```svelte
<script lang="ts">
  import { assistenteService } from '$lib/services';
  import { chatStore, messages, isLoading } from '$lib/stores/chat.store';

  let inputValue = '';

  async function sendMessage() {
    const text = inputValue.trim();
    if (!text || $isLoading) return;

    inputValue = '';
    chatStore.addUserMessage(text);
    chatStore.setLoading(true);

    const result = await assistenteService.sendMessage(text);

    chatStore.setLoading(false);

    if (result.ok) {
      chatStore.addAssistantMessage(result.value);
    } else {
      chatStore.setError(result.error.message);
      chatStore.addAssistantMessage('Erro ao se comunicar com a IA.');
    }
  }
</script>

<div class="chat-container">
  <div class="messages">
    {#each $messages as message}
      <div class="message" class:user={message.isUser}>
        {message.text}
      </div>
    {/each}
    {#if $isLoading}
      <div class="typing-indicator">...</div>
    {/if}
  </div>

  <form on:submit|preventDefault={sendMessage}>
    <input
      bind:value={inputValue}
      placeholder="Digite sua mensagem..."
      disabled={$isLoading}
    />
    <button type="submit" disabled={$isLoading || !inputValue.trim()}>
      Enviar
    </button>
  </form>
</div>
```

---

## 9. Error Handling

The Flutter code uses `dartz` package's `Either<L, R>` type. In TypeScript, we recommend a simpler `Result` type.

### Option 1: Simple Result Type (Recommended)

#### `src/lib/utils/result.ts`

```typescript
/**
 * Result type for handling success/failure without exceptions
 * Inspired by Rust's Result and Kotlin's Result types
 */
export type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

/**
 * Create a success Result
 */
export function ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}

/**
 * Create a failure Result
 */
export function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}

/**
 * Check if result is success
 */
export function isOk<T, E>(result: Result<T, E>): result is { ok: true; value: T } {
  return result.ok;
}

/**
 * Check if result is failure
 */
export function isErr<T, E>(result: Result<T, E>): result is { ok: false; error: E } {
  return !result.ok;
}

/**
 * Unwrap value or throw error
 */
export function unwrap<T, E>(result: Result<T, E>): T {
  if (result.ok) {
    return result.value;
  }
  throw result.error;
}

/**
 * Unwrap value or return default
 */
export function unwrapOr<T, E>(result: Result<T, E>, defaultValue: T): T {
  return result.ok ? result.value : defaultValue;
}

/**
 * Map success value
 */
export function map<T, U, E>(
  result: Result<T, E>,
  fn: (value: T) => U
): Result<U, E> {
  return result.ok ? ok(fn(result.value)) : result;
}

/**
 * Map error value
 */
export function mapErr<T, E, F>(
  result: Result<T, E>,
  fn: (error: E) => F
): Result<T, F> {
  return result.ok ? result : err(fn(result.error));
}

/**
 * Chain async operations (flatMap)
 */
export async function andThen<T, U, E>(
  result: Result<T, E>,
  fn: (value: T) => Promise<Result<U, E>>
): Promise<Result<U, E>> {
  return result.ok ? fn(result.value) : result;
}

/**
 * Fold/match pattern - execute different functions based on success/failure
 * Similar to Flutter's Either.fold()
 */
export function fold<T, E, R>(
  result: Result<T, E>,
  onError: (error: E) => R,
  onSuccess: (value: T) => R
): R {
  return result.ok ? onSuccess(result.value) : onError(result.error);
}

/**
 * Try to execute a function and wrap result
 */
export function trySync<T>(fn: () => T): Result<T, Error> {
  try {
    return ok(fn());
  } catch (e) {
    return err(e instanceof Error ? e : new Error(String(e)));
  }
}

/**
 * Try to execute async function and wrap result
 */
export async function tryAsync<T>(fn: () => Promise<T>): Promise<Result<T, Error>> {
  try {
    return ok(await fn());
  } catch (e) {
    return err(e instanceof Error ? e : new Error(String(e)));
  }
}

/**
 * Collect array of Results into Result of array
 * Returns first error if any fails
 */
export function collect<T, E>(results: Result<T, E>[]): Result<T[], E> {
  const values: T[] = [];

  for (const result of results) {
    if (!result.ok) {
      return result;
    }
    values.push(result.value);
  }

  return ok(values);
}
```

### Option 2: Using neverthrow Library

If you prefer a more feature-rich library, install `neverthrow`:

```bash
npm install neverthrow
```

```typescript
import { ok, err, Result, ResultAsync } from 'neverthrow';

// Usage is similar to our custom Result type
async function fetchUser(id: string): Promise<Result<User, ApiError>> {
  const response = await fetch(`/api/users/${id}`);

  if (!response.ok) {
    return err({ message: 'User not found', status: 404 });
  }

  return ok(await response.json());
}

// With ResultAsync for cleaner async chains
const getUser = (id: string) =>
  ResultAsync.fromPromise(
    fetch(`/api/users/${id}`).then((r) => r.json()),
    (e) => ({ message: 'Failed to fetch', status: 500 })
  );
```

### Usage Examples

```typescript
import { ok, err, fold, unwrapOr } from '$lib/utils/result';
import { authService } from '$lib/services';

// Example 1: Basic usage
const result = await authService.getUserByEmail('test@example.com');

if (result.ok) {
  console.log('User found:', result.value);
} else {
  console.error('Error:', result.error.message);
}

// Example 2: Using fold (like Flutter's Either.fold)
const message = fold(
  result,
  (error) => `Failed: ${error.message}`,
  (user) => `Welcome, ${user.nome_completo}!`
);

// Example 3: Default value
const user = unwrapOr(result, { id_user: 0, email: '', nome_completo: 'Guest' });

// Example 4: Chaining with map
import { map, andThen } from '$lib/utils/result';

const greeting = map(result, (user) => `Hello, ${user.nome_completo}`);
```

---

## 10. SvelteKit Server Routes

Use `+server.ts` API routes as proxies when you need to:
- Hide API keys or sensitive endpoints from the client
- Add server-side authentication headers
- Transform or aggregate data from multiple sources
- Handle CORS issues

### Proxy Route Example

#### `src/routes/api/fluxograma/+server.ts`

```typescript
import { json, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { BACKEND_URL } from '$env/static/private';

export const GET: RequestHandler = async ({ url, locals }) => {
  const nomeCurso = url.searchParams.get('nome_curso');

  if (!nomeCurso) {
    throw error(400, 'nome_curso parameter is required');
  }

  try {
    const response = await fetch(
      `${BACKEND_URL}/fluxograma/fluxograma?nome_curso=${encodeURIComponent(nomeCurso)}`,
      {
        headers: {
          'Content-Type': 'application/json'
        }
      }
    );

    if (!response.ok) {
      throw error(response.status, await response.text());
    }

    const data = await response.json();
    return json(data);
  } catch (e) {
    console.error('Fluxograma proxy error:', e);
    throw error(500, 'Failed to fetch fluxograma data');
  }
};
```

### Protected Route with Auth

#### `src/routes/api/fluxograma/upload/+server.ts`

```typescript
import { json, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { BACKEND_URL } from '$env/static/private';

export const POST: RequestHandler = async ({ request, locals }) => {
  // Check authentication
  const session = await locals.getSession();

  if (!session?.access_token) {
    throw error(401, 'Authentication required');
  }

  try {
    const body = await request.json();

    const response = await fetch(`${BACKEND_URL}/fluxograma/upload-dados-fluxograma`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${session.access_token}`,
        'User-ID': session.user?.id || ''
      },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw error(response.status, errorData.error || 'Upload failed');
    }

    return json(await response.json());
  } catch (e) {
    if (e instanceof Error && 'status' in e) throw e;
    console.error('Upload proxy error:', e);
    throw error(500, 'Failed to upload fluxograma');
  }
};
```

### PDF Upload with Streaming

#### `src/routes/api/upload/pdf/+server.ts`

```typescript
import { json, error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { BACKEND_URL } from '$env/static/private';

export const POST: RequestHandler = async ({ request }) => {
  const contentType = request.headers.get('content-type');

  if (!contentType?.includes('multipart/form-data')) {
    throw error(400, 'Expected multipart/form-data');
  }

  try {
    // Forward the multipart form data to backend
    const response = await fetch(`${BACKEND_URL}/fluxograma/read_pdf`, {
      method: 'POST',
      headers: {
        // Let fetch set the boundary for multipart
      },
      body: await request.arrayBuffer()
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw error(response.status, errorText);
    }

    return json(await response.json());
  } catch (e) {
    if (e instanceof Error && 'status' in e) throw e;
    console.error('PDF upload proxy error:', e);
    throw error(500, 'Failed to process PDF');
  }
};
```

### When to Use Server Routes (Updated)

> **⚡ With direct Supabase queries, most server-side proxying is no longer needed.** Server routes are only needed for the 3 backend endpoints.

| Scenario | Use Server Route? | Reason |
|----------|------------------|--------|
| Course/subject data | **No** | Direct Supabase query with public RLS |
| User profile lookup | **No** | Direct Supabase query with auth RLS |
| Flowchart save/delete | **No** | Direct Supabase with auth RLS |
| PDF upload | **Yes** | Must proxy to backend → Python parser |
| Discipline matching | **Yes** | Must proxy to backend (complex logic) |
| AI Agent requests | **Yes** | External API, key should stay server-side |
| Rate limiting needed | **Yes** | Implement server-side throttling |

---

## 11. Type Safety

### Generic Response Types

#### `src/lib/types/api.ts`

```typescript
/**
 * Generic API response wrapper
 */
export interface ApiResponse<T> {
  data: T;
  message?: string;
  meta?: {
    total?: number;
    page?: number;
    limit?: number;
  };
}

/**
 * Paginated response
 */
export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  hasMore: boolean;
}

/**
 * Error response from API
 */
export interface ErrorResponse {
  error: string;
  message?: string;
  code?: string;
  details?: Record<string, string[]>;
}
```

### Generic Service Methods

```typescript
import type { HttpClient, ApiError } from '$lib/api/client';
import { Result } from '$lib/utils/result';

export class GenericService {
  constructor(private client: HttpClient) {}

  /**
   * Generic GET with type safety
   */
  async get<T>(path: string, params?: Record<string, string>): Promise<Result<T, ApiError>> {
    return this.client.get<T>(path, { params });
  }

  /**
   * Generic POST with type safety
   */
  async post<TRequest, TResponse>(
    path: string,
    body: TRequest
  ): Promise<Result<TResponse, ApiError>> {
    return this.client.post<TResponse>(path, body);
  }

  /**
   * Get single item by ID
   */
  async getById<T>(resource: string, id: number | string): Promise<Result<T, ApiError>> {
    return this.client.get<T>(`/${resource}/${id}`);
  }

  /**
   * Get list with pagination
   */
  async getList<T>(
    resource: string,
    params: { page?: number; limit?: number } = {}
  ): Promise<Result<PaginatedResponse<T>, ApiError>> {
    return this.client.get<PaginatedResponse<T>>(`/${resource}`, {
      params: {
        page: (params.page || 1).toString(),
        limit: (params.limit || 20).toString()
      }
    });
  }
}
```

### Type Guards

```typescript
/**
 * Type guard for checking if response has error field
 */
export function hasError(data: unknown): data is { error: string } {
  return typeof data === 'object' && data !== null && 'error' in data;
}

/**
 * Type guard for User type
 */
export function isUser(data: unknown): data is User {
  return (
    typeof data === 'object' &&
    data !== null &&
    'id_user' in data &&
    'email' in data &&
    'nome_completo' in data
  );
}

/**
 * Type guard for array of specific type
 */
export function isArrayOf<T>(
  data: unknown,
  guard: (item: unknown) => item is T
): data is T[] {
  return Array.isArray(data) && data.every(guard);
}
```

### Zod Schema Validation (Optional)

For runtime type validation, consider using Zod:

```bash
npm install zod
```

```typescript
import { z } from 'zod';

// Define schemas
export const UserSchema = z.object({
  id_user: z.number(),
  email: z.string().email(),
  nome_completo: z.string(),
  avatar_url: z.string().optional(),
  token: z.string().optional()
});

export const MateriaSchema = z.object({
  id_materia: z.number(),
  nome: z.string(),
  codigo: z.string(),
  creditos: z.number(),
  tipo: z.enum(['obrigatoria', 'optativa'])
});

// Infer types from schemas
export type User = z.infer<typeof UserSchema>;
export type Materia = z.infer<typeof MateriaSchema>;

// Validate API responses
async function fetchUser(email: string): Promise<Result<User, ApiError>> {
  const result = await client.get<unknown>('/users/get-user-by-email', {
    params: { email }
  });

  if (!result.ok) return result;

  const parsed = UserSchema.safeParse(result.value);

  if (!parsed.success) {
    return err({
      message: 'Invalid response format',
      status: 500,
      details: parsed.error.format()
    });
  }

  return ok(parsed.data);
}
```

---

## Summary

This migration guide covers:

1. **Direct Supabase Queries** - 9 of 12 backend endpoints replaced with direct Supabase queries using RLS
2. **RLS Policies** - Row-Level Security setup detailed in [14-SUPABASE-DIRECT-RLS.md](14-SUPABASE-DIRECT-RLS.md)
3. **HTTP Client** - Only needed for the 3 remaining backend endpoints (PDF, matching, AI)
4. **AuthService** - Supabase Auth + direct DB queries (no backend user endpoints)
5. **FluxogramaService** - All course/subject data via direct Supabase queries
6. **UploadService** - Hybrid: backend for PDF/matching, direct Supabase for save/delete
7. **AssistenteService** - Backend-proxied AI chat (unchanged)
8. **Error Handling** - Result type for backend calls, try/catch for Supabase calls
9. **Server Routes** - Only needed to proxy PDF upload, discipline matching, and AI agent
10. **Type Safety** - Generated database types from Supabase CLI + Zod validation

The patterns maintain similar structure to the Flutter code while dramatically reducing backend dependencies. The backend becomes a thin processing layer for PDF parsing and discipline matching only.

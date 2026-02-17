# 14 - Supabase Direct Access & RLS Migration

This document details the strategy for eliminating unnecessary backend API calls by querying Supabase directly from the frontend using Row-Level Security (RLS). This reduces latency, simplifies the architecture, and removes the backend as a bottleneck for simple CRUD operations.

## Table of Contents

1. [Overview: What Changes](#1-overview-what-changes)
2. [RLS Policies to Create in Supabase](#2-rls-policies-to-create-in-supabase)
3. [Endpoints Replaced by Direct Supabase Queries](#3-endpoints-replaced-by-direct-supabase-queries)
4. [Endpoints That MUST Stay on Backend](#4-endpoints-that-must-stay-on-backend)
5. [Database Type Generation](#5-database-type-generation)
6. [Updated Service Implementations](#6-updated-service-implementations)
7. [Migration SQL Script](#7-migration-sql-script)
8. [Testing Strategy](#8-testing-strategy)

---

## 1. Overview: What Changes

### Current Architecture (Backend-Proxied)

```
Frontend → Backend (Express.js + Service Role Key) → Supabase
```

The backend currently uses the **Supabase Service Role Key** which bypasses all RLS. Every data query goes through the Express.js backend, even for simple selects.

### New Architecture (Direct + Backend Hybrid)

```
Frontend → Supabase (with Anon Key + RLS)      ← Simple CRUD
Frontend → Backend → Supabase / Python services ← Complex logic only
```

| Category | Approach | Endpoints |
|----------|----------|-----------|
| **Public read-only data** | Direct Supabase (no auth needed) | Cursos, Materias, Fluxograma data, Equivalências, Pré/Co-requisitos |
| **User CRUD** | Direct Supabase (auth via RLS) | User lookup, registration, flowchart save/delete |
| **Complex business logic** | Keep on backend | PDF parsing, discipline matching |
| **External services** | Keep on backend | AI assistant (RAGFlow) |

### Benefits

- **~9 of 12 endpoints eliminated** from backend dependency
- **Lower latency** — direct DB queries vs backend round-trip
- **Simpler deployment** — fewer services to maintain
- **Better security** — RLS enforces access rules at the DB level
- **Offline-ready** — Supabase JS client has built-in caching

---

## 2. RLS Policies to Create in Supabase

> **CRITICAL**: The current database has **NO RLS policies** and **NO RLS enabled** on any table. The backend bypasses RLS using the service role key. Before switching to direct frontend queries with the anon key, we MUST enable RLS and create appropriate policies.

### 2.1 Public Read-Only Tables

These tables contain curriculum/academic data that all users (even unauthenticated) should be able to read. No one should be able to modify them from the frontend.

#### `cursos` — Courses

```sql
ALTER TABLE public.cursos ENABLE ROW LEVEL SECURITY;

-- Anyone can read courses
CREATE POLICY "cursos_select_public" ON public.cursos
  FOR SELECT
  USING (true);

-- No insert/update/delete from frontend (admin only via service role)
```

#### `materias` — Subjects

```sql
ALTER TABLE public.materias ENABLE ROW LEVEL SECURITY;

CREATE POLICY "materias_select_public" ON public.materias
  FOR SELECT
  USING (true);
```

#### `materias_por_curso` — Subject-Course mapping

```sql
ALTER TABLE public.materias_por_curso ENABLE ROW LEVEL SECURITY;

CREATE POLICY "materias_por_curso_select_public" ON public.materias_por_curso
  FOR SELECT
  USING (true);
```

#### `pre_requisitos` — Prerequisites

```sql
ALTER TABLE public.pre_requisitos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pre_requisitos_select_public" ON public.pre_requisitos
  FOR SELECT
  USING (true);
```

#### `co_requisitos` — Co-requisites

```sql
ALTER TABLE public.co_requisitos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "co_requisitos_select_public" ON public.co_requisitos
  FOR SELECT
  USING (true);
```

#### `equivalencias` — Equivalences

```sql
ALTER TABLE public.equivalencias ENABLE ROW LEVEL SECURITY;

CREATE POLICY "equivalencias_select_public" ON public.equivalencias
  FOR SELECT
  USING (true);
```

### 2.2 User Tables (Auth-Protected)

These tables contain user-specific data. RLS must tie records to the authenticated Supabase Auth user.

> **Important**: The current `users` table uses a custom `id_user` (bigint auto-increment) and does NOT reference `auth.users.id`. To enable RLS, we need to either:
> - **(Option A — Recommended)**: Add a `auth_id UUID` column to `users` that references `auth.users.id`, then use `auth.uid()` in RLS policies.
> - **(Option B)**: Look up the user by email using `auth.jwt() ->> 'email'` in policies (less efficient but no schema change).

We recommend **Option A** for performance and correctness.

#### Schema Change: Link `users` to `auth.users`

```sql
-- Add auth_id column to link with Supabase Auth
ALTER TABLE public.users 
  ADD COLUMN IF NOT EXISTS auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_auth_id ON public.users(auth_id);

-- Backfill existing users (match by email)
UPDATE public.users u
SET auth_id = au.id
FROM auth.users au
WHERE u.email = au.email
AND u.auth_id IS NULL;
```

#### `users` — User profiles

```sql
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Anyone can read users (needed for profile lookups)
-- If you want to restrict to only the authenticated user's own record:
-- USING (auth_id = auth.uid())
CREATE POLICY "users_select_own" ON public.users
  FOR SELECT
  USING (auth_id = auth.uid());

-- Users can insert their own record (on signup)
CREATE POLICY "users_insert_own" ON public.users
  FOR INSERT
  WITH CHECK (auth_id = auth.uid());

-- Users can update only their own record
CREATE POLICY "users_update_own" ON public.users
  FOR UPDATE
  USING (auth_id = auth.uid())
  WITH CHECK (auth_id = auth.uid());
```

#### `dados_users` — User flowchart data

```sql
ALTER TABLE public.dados_users ENABLE ROW LEVEL SECURITY;

-- Users can only read their own data
CREATE POLICY "dados_users_select_own" ON public.dados_users
  FOR SELECT
  USING (
    id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid())
  );

-- Users can insert their own data
CREATE POLICY "dados_users_insert_own" ON public.dados_users
  FOR INSERT
  WITH CHECK (
    id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid())
  );

-- Users can update their own data
CREATE POLICY "dados_users_update_own" ON public.dados_users
  FOR UPDATE
  USING (
    id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid())
  )
  WITH CHECK (
    id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid())
  );

-- Users can delete their own data
CREATE POLICY "dados_users_delete_own" ON public.dados_users
  FOR DELETE
  USING (
    id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid())
  );
```

### 2.3 Backup Tables (No Access)

The backup tables (`co_requisitos_backup`, `dados_users_backup`, `equivalencia_backup1`, `users_backup`) should have RLS enabled with NO policies (blocking all access from anon key).

```sql
ALTER TABLE public.co_requisitos_backup ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dados_users_backup ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equivalencia_backup1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_backup ENABLE ROW LEVEL SECURITY;
-- No policies = no access via anon key
```

### 2.4 Views

Views follow the RLS of the underlying tables they query. The three views (`creditos_por_curso`, `vw_equivalencias_com_materias`, `vw_pre_requisitos_detalhado`) query only public-read tables, so they'll work with the anon key after their base tables have public SELECT policies.

> **Note on Supabase Views**: By default, Supabase views run with the permissions of the **view creator** (SECURITY DEFINER). If this is the case, they'll bypass RLS. To respect RLS, set them to `SECURITY INVOKER`:

```sql
ALTER VIEW public.creditos_por_curso SET (security_invoker = on);
ALTER VIEW public.vw_equivalencias_com_materias SET (security_invoker = on);
ALTER VIEW public.vw_pre_requisitos_detalhado SET (security_invoker = on);
```

---

## 3. Endpoints Replaced by Direct Supabase Queries

### 3.1 `GET /users/get-user-by-email` → Direct Supabase

**Before (backend call):**
```typescript
const response = await fetch(`${API_URL}/users/get-user-by-email?email=${email}`);
```

**After (direct Supabase):**
```typescript
const { data, error } = await supabase
  .from('users')
  .select('*, dados_users(*)')
  .eq('auth_id', (await supabase.auth.getUser()).data.user?.id)
  .single();
```

### 3.2 `POST /users/register-user-with-google` & `POST /users/registrar-user-with-email` → Direct Supabase

**Before:**
```typescript
await fetch(`${API_URL}/users/register-user-with-google`, { method: 'POST', body: ... });
```

**After:**
```typescript
const { data: authUser } = await supabase.auth.getUser();
const { data, error } = await supabase
  .from('users')
  .insert({
    email,
    nome_completo: nomeCompleto,
    auth_id: authUser.user?.id
  })
  .select()
  .single();
```

### 3.3 `GET /cursos/all-cursos` → Direct Supabase

**Before:**
```typescript
const response = await fetch(`${API_URL}/cursos/all-cursos`);
```

**After:**
```typescript
// Option A: Use the view
const { data, error } = await supabase
  .from('creditos_por_curso')
  .select('*');

// Option B: Query cursos directly
const { data, error } = await supabase
  .from('cursos')
  .select('*')
  .order('nome_curso');
```

### 3.4 `GET /materias/materias-name-by-code` → Direct Supabase

**Before:**
```typescript
const response = await fetch(`${API_URL}/materias/materias-name-by-code`, {
  method: 'POST', body: JSON.stringify({ codes })
});
```

**After:**
```typescript
const { data, error } = await supabase
  .from('materias')
  .select('codigo_materia, nome_materia')
  .in('codigo_materia', codes);
```

### 3.5 `POST /materias/materias-from-codigos` → Direct Supabase

**Before:**
```typescript
const response = await fetch(`${API_URL}/materias/materias-from-codigos`, {
  method: 'POST', body: JSON.stringify({ codigos, id_curso })
});
```

**After:**
```typescript
const { data, error } = await supabase
  .from('materias')
  .select('*, materias_por_curso!inner(nivel, id_curso)')
  .in('codigo_materia', codes)
  .eq('materias_por_curso.id_curso', idCurso);
```

### 3.6 `GET /fluxograma/fluxograma` → Direct Supabase (multiple queries)

This endpoint does 4 sequential queries. They can all be done directly:

**After:**
```typescript
// 1. Get course + subjects
const { data: curso } = await supabase
  .from('cursos')
  .select('*, materias_por_curso(*, materias(*))')
  .eq('nome_curso', courseName)
  .single();

// 2. Get equivalencies (via view)
const { data: equivalencias } = await supabase
  .from('vw_equivalencias_com_materias')
  .select('*')
  .eq('id_curso', curso.id_curso);

// 3. Get prerequisites for all subjects in the course
const materiaIds = curso.materias_por_curso.map(m => m.id_materia);
const { data: prereqs } = await supabase
  .from('pre_requisitos')
  .select('*')
  .in('id_materia', materiaIds);

// 4. Get co-requisites
const { data: coreqs } = await supabase
  .from('co_requisitos')
  .select('*')
  .in('id_materia', materiaIds);
```

### 3.7 `POST /fluxograma/upload-dados-fluxograma` → Direct Supabase

**Before:**
```typescript
await fetch(`${API_URL}/fluxograma/upload-dados-fluxograma`, {
  method: 'POST', headers: authHeaders, body: JSON.stringify(data)
});
```

**After:**
```typescript
const { data, error } = await supabase
  .from('dados_users')
  .upsert({
    id_user: userId,
    fluxograma_atual: JSON.stringify(fluxogramaData),
    semestre_atual: semestreAtual
  }, { onConflict: 'id_user' });
```

### 3.8 `DELETE /fluxograma/delete-fluxograma` → Direct Supabase

**Before:**
```typescript
await fetch(`${API_URL}/fluxograma/delete-fluxograma`, {
  method: 'DELETE', headers: authHeaders
});
```

**After:**
```typescript
const { error } = await supabase
  .from('dados_users')
  .delete()
  .eq('id_user', userId);
```

---

## 4. Endpoints That MUST Stay on Backend

These endpoints have complex business logic or depend on external services and **cannot** be moved to direct Supabase queries:

| Endpoint | Reason |
|----------|--------|
| `POST /fluxograma/read_pdf` | Proxies file upload to Python PDF parser microservice (port 3001). Binary file processing cannot be done client-side. |
| `POST /fluxograma/casar_disciplinas` | ~500 lines of complex discipline matching logic: multi-matrix fallback, equivalency resolution, duplicate deduplication with priority, classification, and percentage calculations. This is the core business logic. |
| `POST /assistente` | Calls external RAGFlow AI agent. Separate Python Flask service. API key/URL should remain server-side. |

For these 3 endpoints, the frontend will continue to call the backend API (or use SvelteKit server routes as proxies).

---

## 5. Database Type Generation

Use the Supabase CLI to generate TypeScript types from the database schema for type-safe queries.

### Generate Types

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Login to Supabase
supabase login

# Generate types from your project
supabase gen types typescript --project-id lijmhbstgdinsukovyfl > src/lib/types/database.ts
```

### Usage with Supabase Client

```typescript
import { createBrowserClient } from '@supabase/ssr';
import type { Database } from '$lib/types/database';

export function createSupabaseBrowserClient() {
  return createBrowserClient<Database>(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_ANON_KEY
  );
}
```

This provides full autocomplete and type safety for all Supabase queries:

```typescript
// TypeScript knows the exact shape of 'cursos' rows
const { data } = await supabase.from('cursos').select('id_curso, nome_curso');
// data is typed as { id_curso: number; nome_curso: string | null }[] | null
```

---

## 6. Updated Service Implementations

### 6.1 `src/lib/services/supabase-data.service.ts` — New Direct Supabase Service

```typescript
import { createSupabaseBrowserClient } from '$lib/supabase/client';
import type { Database } from '$lib/types/database';

type Curso = Database['public']['Tables']['cursos']['Row'];
type Materia = Database['public']['Tables']['materias']['Row'];
type MateriaPorCurso = Database['public']['Tables']['materias_por_curso']['Row'];
type PreRequisito = Database['public']['Tables']['pre_requisitos']['Row'];
type CoRequisito = Database['public']['Tables']['co_requisitos']['Row'];
type DadosUser = Database['public']['Tables']['dados_users']['Row'];
type UserRow = Database['public']['Tables']['users']['Row'];

export class SupabaseDataService {
  private supabase = createSupabaseBrowserClient();

  // ─── Courses ──────────────────────────────────────────────

  async getAllCursos() {
    const { data, error } = await this.supabase
      .from('cursos')
      .select('*')
      .order('nome_curso');

    if (error) throw new Error(`Erro ao buscar cursos: ${error.message}`);
    return data;
  }

  async getCursosComCreditos() {
    const { data, error } = await this.supabase
      .from('creditos_por_curso')
      .select('*');

    if (error) throw new Error(`Erro ao buscar créditos: ${error.message}`);
    return data;
  }

  // ─── Subjects ─────────────────────────────────────────────

  async getMateriasByCode(codes: string[]) {
    const { data, error } = await this.supabase
      .from('materias')
      .select('codigo_materia, nome_materia')
      .in('codigo_materia', codes);

    if (error) throw new Error(`Erro ao buscar matérias: ${error.message}`);
    return data;
  }

  async getMateriasFromCodigos(codes: string[], idCurso: number) {
    const { data, error } = await this.supabase
      .from('materias')
      .select('*, materias_por_curso!inner(nivel, id_curso)')
      .in('codigo_materia', codes)
      .eq('materias_por_curso.id_curso', idCurso);

    if (error) throw new Error(`Erro ao buscar matérias do curso: ${error.message}`);
    return data;
  }

  // ─── Full Course Flowchart Data ───────────────────────────

  async getCourseFlowchartData(courseName: string) {
    // 1. Get course
    const { data: curso, error: cursoError } = await this.supabase
      .from('cursos')
      .select('*')
      .eq('nome_curso', courseName)
      .single();

    if (cursoError || !curso) {
      throw new Error(`Curso não encontrado: ${courseName}`);
    }

    // 2. Get subjects for this course
    const { data: materiasCurso, error: mcError } = await this.supabase
      .from('materias_por_curso')
      .select('*, materias(*)')
      .eq('id_curso', curso.id_curso);

    if (mcError) throw new Error(`Erro ao buscar matérias: ${mcError.message}`);

    const materiaIds = (materiasCurso || []).map(mc => mc.id_materia).filter(Boolean) as number[];

    // 3. Get equivalencies, prerequisites, and co-requisites in parallel
    const [equivalenciasResult, prereqsResult, coreqsResult] = await Promise.all([
      this.supabase
        .from('vw_equivalencias_com_materias')
        .select('*')
        .eq('id_curso', curso.id_curso),

      materiaIds.length > 0
        ? this.supabase
            .from('pre_requisitos')
            .select('*')
            .in('id_materia', materiaIds)
        : Promise.resolve({ data: [], error: null }),

      materiaIds.length > 0
        ? this.supabase
            .from('co_requisitos')
            .select('*')
            .in('id_materia', materiaIds)
        : Promise.resolve({ data: [], error: null })
    ]);

    return {
      curso,
      materias: materiasCurso || [],
      equivalencias: equivalenciasResult.data || [],
      preRequisitos: prereqsResult.data || [],
      coRequisitos: coreqsResult.data || []
    };
  }

  // ─── User Data ────────────────────────────────────────────

  async getCurrentUserProfile() {
    const { data: authUser } = await this.supabase.auth.getUser();
    if (!authUser.user) return null;

    const { data, error } = await this.supabase
      .from('users')
      .select('*, dados_users(*)')
      .eq('auth_id', authUser.user.id)
      .single();

    if (error) {
      console.warn('User profile not found:', error.message);
      return null;
    }

    return data;
  }

  async registerUser(email: string, nomeCompleto: string) {
    const { data: authUser } = await this.supabase.auth.getUser();
    if (!authUser.user) throw new Error('Não autenticado');

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
      // If user already exists, fetch instead
      if (error.code === '23505') {
        return this.getCurrentUserProfile();
      }
      throw new Error(`Erro ao registrar usuário: ${error.message}`);
    }

    return data;
  }

  // ─── Flowchart User Data ──────────────────────────────────

  async saveFluxogramaData(idUser: number, fluxogramaData: unknown, semestreAtual?: number) {
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

  async deleteFluxogramaData(idUser: number) {
    const { error } = await this.supabase
      .from('dados_users')
      .delete()
      .eq('id_user', idUser);

    if (error) throw new Error(`Erro ao deletar fluxograma: ${error.message}`);
    return true;
  }
}

// Singleton instance
export const supabaseDataService = new SupabaseDataService();
```

### 6.2 Updated `auth.service.ts` — Remove Backend Calls

The auth service should be updated to register/lookup users directly via Supabase instead of calling the backend:

```typescript
// BEFORE: Backend call
async databaseSearchUser(email: string) {
  const response = await fetch(`${API_URL}/users/get-user-by-email?email=${email}`);
  // ...
}

// AFTER: Direct Supabase query
async databaseSearchUser() {
  const { data: authUser } = await this.supabase.auth.getUser();
  if (!authUser.user) return { success: false, error: 'Not authenticated' };

  const { data, error } = await this.supabase
    .from('users')
    .select('*, dados_users(*)')
    .eq('auth_id', authUser.user.id)
    .single();

  if (error || !data) return { success: false, error: error?.message || 'User not found' };

  const user: UserModel = {
    id_user: data.id_user,
    email: data.email || '',
    nome_completo: data.nome_completo || '',
    token: (await this.supabase.auth.getSession()).data.session?.access_token,
    dados_fluxograma: data.dados_users?.[0]?.fluxograma_atual
      ? JSON.parse(data.dados_users[0].fluxograma_atual)
      : undefined
  };

  return { success: true, user };
}
```

### 6.3 Updated `fluxograma.service.ts` — Use Direct Supabase

```typescript
import { supabaseDataService } from './supabase-data.service';

export class FluxogramaService {
  async getCourseData(courseName: string) {
    return supabaseDataService.getCourseFlowchartData(courseName);
  }

  async getAllCursos() {
    return supabaseDataService.getCursosComCreditos();
  }

  async getMateriasByCode(codes: string[]) {
    return supabaseDataService.getMateriasByCode(codes);
  }

  async getMateriasFromCodigos(codes: string[], idCurso: number) {
    return supabaseDataService.getMateriasFromCodigos(codes, idCurso);
  }

  async deleteFluxograma(userId: number) {
    return supabaseDataService.deleteFluxogramaData(userId);
  }

  async saveFluxograma(userId: number, data: unknown, semestre?: number) {
    return supabaseDataService.saveFluxogramaData(userId, data, semestre);
  }
}

export const fluxogramaService = new FluxogramaService();
```

### 6.4 Updated `upload.service.ts` — Hybrid (Backend for PDF + Direct for Save)

```typescript
import { PUBLIC_API_URL } from '$env/static/public';
import { supabaseDataService } from './supabase-data.service';

export class UploadService {
  /**
   * Upload PDF — STILL calls backend (proxies to Python parser)
   */
  async uploadPdf(file: File) {
    const formData = new FormData();
    formData.append('pdf', file, file.name);

    const response = await fetch(`${PUBLIC_API_URL}/fluxograma/read_pdf`, {
      method: 'POST',
      body: formData
    });

    if (!response.ok) throw new Error('Erro ao processar PDF');
    return response.json();
  }

  /**
   * Match disciplines — STILL calls backend (complex business logic)
   */
  async casarDisciplinas(dadosExtraidos: unknown) {
    const response = await fetch(`${PUBLIC_API_URL}/fluxograma/casar_disciplinas`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ dados_extraidos: dadosExtraidos })
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw errorData;
    }

    return response.json();
  }

  /**
   * Save flowchart to DB — NOW uses direct Supabase
   */
  async saveFluxogramaToDB(userId: number, fluxogramaData: unknown, semestre?: number) {
    return supabaseDataService.saveFluxogramaData(userId, fluxogramaData, semestre);
  }
}

export const uploadService = new UploadService();
```

---

## 7. Migration SQL Script

Run this SQL in the Supabase SQL Editor to set up all RLS policies:

```sql
-- =============================================================================
-- SUPABASE RLS MIGRATION SCRIPT
-- Run this in Supabase SQL Editor
-- =============================================================================

BEGIN;

-- ─── 1. Add auth_id to users table ────────────────────────────────────────────

ALTER TABLE public.users 
  ADD COLUMN IF NOT EXISTS auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_users_auth_id ON public.users(auth_id);

-- Backfill existing users by matching email
UPDATE public.users u
SET auth_id = au.id
FROM auth.users au
WHERE u.email = au.email
AND u.auth_id IS NULL;

-- ─── 2. Enable RLS on all tables ──────────────────────────────────────────────

ALTER TABLE public.cursos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materias_por_curso ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pre_requisitos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.co_requisitos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equivalencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dados_users ENABLE ROW LEVEL SECURITY;

-- Backup tables (block all access)
ALTER TABLE public.co_requisitos_backup ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dados_users_backup ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equivalencia_backup1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users_backup ENABLE ROW LEVEL SECURITY;

-- ─── 3. Public read-only policies ─────────────────────────────────────────────

CREATE POLICY "cursos_select_public" ON public.cursos
  FOR SELECT USING (true);

CREATE POLICY "materias_select_public" ON public.materias
  FOR SELECT USING (true);

CREATE POLICY "materias_por_curso_select_public" ON public.materias_por_curso
  FOR SELECT USING (true);

CREATE POLICY "pre_requisitos_select_public" ON public.pre_requisitos
  FOR SELECT USING (true);

CREATE POLICY "co_requisitos_select_public" ON public.co_requisitos
  FOR SELECT USING (true);

CREATE POLICY "equivalencias_select_public" ON public.equivalencias
  FOR SELECT USING (true);

-- ─── 4. User-scoped policies ──────────────────────────────────────────────────

-- Users: can read/insert/update own record
CREATE POLICY "users_select_own" ON public.users
  FOR SELECT USING (auth_id = auth.uid());

CREATE POLICY "users_insert_own" ON public.users
  FOR INSERT WITH CHECK (auth_id = auth.uid());

CREATE POLICY "users_update_own" ON public.users
  FOR UPDATE 
  USING (auth_id = auth.uid()) 
  WITH CHECK (auth_id = auth.uid());

-- Dados Users: can read/insert/update/delete own data
CREATE POLICY "dados_users_select_own" ON public.dados_users
  FOR SELECT USING (
    id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid())
  );

CREATE POLICY "dados_users_insert_own" ON public.dados_users
  FOR INSERT WITH CHECK (
    id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid())
  );

CREATE POLICY "dados_users_update_own" ON public.dados_users
  FOR UPDATE 
  USING (id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid()))
  WITH CHECK (id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid()));

CREATE POLICY "dados_users_delete_own" ON public.dados_users
  FOR DELETE USING (
    id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid())
  );

-- ─── 5. Views: set security invoker ──────────────────────────────────────────

ALTER VIEW public.creditos_por_curso SET (security_invoker = on);
ALTER VIEW public.vw_equivalencias_com_materias SET (security_invoker = on);
ALTER VIEW public.vw_pre_requisitos_detalhado SET (security_invoker = on);

COMMIT;
```

---

## 8. Testing Strategy

### 8.1 Test RLS Policies

After applying the migration, test with the anon key:

```typescript
// Test 1: Public data access (should work without auth)
const { data: cursos } = await supabase.from('cursos').select('*');
console.assert(cursos !== null, 'Should read cursos without auth');

// Test 2: Private data access (should fail without auth)
const { data: users, error } = await supabase.from('users').select('*');
console.assert(error !== null || users?.length === 0, 'Should NOT read other users');

// Test 3: Authenticated user reads own data
const { data: myData } = await supabase.from('users')
  .select('*, dados_users(*)')
  .eq('auth_id', session.user.id)
  .single();
console.assert(myData !== null, 'Should read own user data');

// Test 4: Insert blocked on public tables
const { error: insertError } = await supabase.from('cursos').insert({ nome_curso: 'TEST' });
console.assert(insertError !== null, 'Should NOT insert into cursos');
```

### 8.2 Test Backend Endpoints Still Work

The backend uses the **service role key** which bypasses RLS, so existing backend endpoints for PDF parsing and discipline matching should continue to work unchanged.

### 8.3 Integration Tests

Create Vitest tests for each migrated service method to verify they return the correct data shapes via direct Supabase queries.

---

## Summary

| Metric | Before | After |
|--------|--------|-------|
| Backend endpoints called | 12 | 3 |
| Network hops for simple queries | 2 (frontend→backend→DB) | 1 (frontend→DB) |
| RLS policies | 0 | 12 |
| Auth-protected tables | 0 | 2 (users, dados_users) |
| Public-read tables | 0 | 6 (cursos, materias, etc.) |
| Type-safe queries | No | Yes (generated types) |

The backend becomes a thin service layer for PDF processing, discipline matching, and AI assistance — the three operations that genuinely need server-side logic.

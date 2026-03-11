# Plan 22 — SSR Removal & Client-First Architecture

## Problem

The app currently uses `adapter-auto` (defaults to SSR via `adapter-node`), which means every page request hits a Node.js server before reaching the client. This adds:

- **Unnecessary latency**: Every navigation goes through the server even though the app already fetches all data client-side via `createBrowserClient`
- **Server cost & complexity**: Requires a Node.js server in production when a static deployment (CDN) would be faster and cheaper
- **Redundant auth checks**: `hooks.server.ts` validates the session server-side on every protected request, then `+layout.svelte` does it again client-side via `onMount`
- **One heavy server endpoint**: `/api/casar-disciplinas` runs ~860 lines of discipline-matching logic server-side, which should be a Supabase Edge Function

### Current SSR Surface

| File | What it does server-side | Can move to client? |
|------|-------------------------|-------------------|
| `hooks.server.ts` | Auth guard + server Supabase client on every request | Yes — already duplicated in `+layout.svelte` client-side auth guard |
| `auth/callback/+page.server.ts` | OAuth code exchange via `locals.supabase` | Yes — Supabase JS SDK handles PKCE client-side natively |
| `home/+page.server.ts` | `redirect(301, '/')` | Yes — client-side redirect or remove route entirely |
| `api/casar-disciplinas/+server.ts` | ~860 lines of discipline matching with 4 DB queries | Yes — move to Supabase Edge Function |
| `src/lib/server/supabase.ts` | Dead code — never imported | Delete |

### What's Already Client-Side (no changes needed)

- All page data fetching (`SupabaseDataService`, `FluxogramaService`, etc.) — uses `createBrowserClient`
- Auth operations (`AuthService`) — uses `createBrowserClient`
- PDF parsing — runs entirely in-browser via PDF.js
- User state management — Svelte stores + `localStorage`
- No pages use `export let data` or `$page.data`

---

## Solution Overview

```
BEFORE:  User → Node.js Server (SSR + hooks.server.ts) → CDN → Client hydration → Client fetches data
AFTER:   User → CDN (static HTML/JS) → Client renders → Client fetches data from Supabase directly
```

**Expected performance gains:**
- **TTFB drops to ~20-50ms** (CDN static file vs ~200-500ms Node.js SSR)
- **No server cold starts** (critical for Vercel/serverless)
- **Simpler deployment** — just static files on any CDN
- **Fewer network hops** for data — client talks directly to Supabase, not through SvelteKit server

---

## Phase 1 — Switch to Static Adapter (SPA Mode)

### 1.1 Install `adapter-static` and configure SPA fallback

```bash
pnpm remove @sveltejs/adapter-auto
pnpm add -D @sveltejs/adapter-static
```

Update `svelte.config.js`:

```js
import adapter from '@sveltejs/adapter-static';

const config = {
  kit: {
    adapter: adapter({
      fallback: 'index.html',  // SPA fallback — all routes serve the same HTML shell
      pages: 'build',
      assets: 'build',
      precompress: true         // gzip + brotli for faster CDN delivery
    })
  }
};
```

### 1.2 Disable SSR globally

Create or update `src/routes/+layout.ts`:

```ts
export const ssr = false;
export const prerender = false;  // we handle routing client-side
```

This tells SvelteKit: never render any page on the server; always serve the SPA shell and let the client handle everything.

### 1.3 Keep the landing page prerendered (optional optimization)

The root `/` page is already `export const prerender = true` in `src/routes/+page.ts`. With `adapter-static`, this still works — SvelteKit will generate a fully static `index.html` at build time for `/`, giving instant LCP for the marketing page.

Update `src/routes/+page.ts`:

```ts
export const prerender = true;
// SSR is disabled globally, but prerender still generates static HTML at build time
```

### 1.4 Update Vercel/deployment config

If deploying to Vercel, update `vercel.json` to handle SPA routing:

```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ],
  "headers": [
    {
      "source": "/assets/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    }
  ]
}
```

---

## Phase 2 — Remove Server-Side Auth Guard

### 2.1 Delete `hooks.server.ts`

The entire file becomes unnecessary. The client-side auth guard in `+layout.svelte` already handles:
- Session bootstrap via `authService.getSession()` in `onMount`
- Route protection via `checkAuth($page.url.pathname)` in `$effect`
- Anonymous session detection via `authStore`

**Before deleting**, verify the client-side guard covers all cases:

| `hooks.server.ts` feature | Client-side equivalent | Location |
|---------------------------|----------------------|----------|
| `createServerClient` on every request | Not needed — client uses `createBrowserClient` singleton | `$lib/supabase/client.ts` |
| Auth check for protected routes | `checkAuth()` in `$effect` | `+layout.svelte` |
| Redirect to `/login?redirect=...` | `goto('/login?redirect=...')` in `authGuard.ts` | `$lib/guards/authGuard.ts` |
| Anonymous cookie check | `$isAnonymous` store check | `authStore` |
| Session expiry check | `authService.isSessionValid()` | `+layout.svelte` onMount |
| `filterSerializedResponseHeaders` | Not needed — no server responses to filter | — |

### 2.2 Strengthen the client-side auth guard

Update `+layout.svelte` to cover edge cases currently handled by `hooks.server.ts`:

```ts
// In the $effect that runs on route change:
$effect(() => {
  const path = $page.url.pathname;

  if (isPublicRoute(path)) return;

  // Check anonymous session
  if ($isAnonymous) return;

  // If still loading auth, wait (the loading spinner handles this)
  if ($isLoading) return;

  // If not authenticated, redirect to login
  if (!$isAuthenticated) {
    goto(`/login?redirect=${encodeURIComponent(path)}`);
    return;
  }

  // Check session expiry
  authService.isSessionValid().then(valid => {
    if (!valid) {
      authService.signOut();
      goto('/login?error=session_expired');
    }
  });
});
```

### 2.3 Update `app.d.ts`

Remove the `Locals` interface since there's no server-side locals anymore:

```ts
declare global {
  namespace App {
    // interface Locals {} — removed, no server-side code
    interface PageData {
      // Keep if needed, but likely empty now
    }
  }
}
```

---

## Phase 3 — Move OAuth Callback to Client-Side

### 3.1 Replace server-side code exchange with client-side PKCE

Delete `src/routes/auth/callback/+page.server.ts`.

Update `src/routes/auth/callback/+page.svelte` to handle the full OAuth flow client-side:

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { authService } from '$lib/services/auth.service';

  let error = $state('');

  onMount(async () => {
    const code = $page.url.searchParams.get('code');
    const next = $page.url.searchParams.get('next') || '/fluxogramas';
    const errorParam = $page.url.searchParams.get('error');

    if (errorParam) {
      goto(`/login?error=${errorParam}`);
      return;
    }

    if (code) {
      // Exchange the code for a session client-side
      const supabase = authService.getSupabaseClient();
      const { error: exchangeError } = await supabase.auth.exchangeCodeForSession(code);

      if (exchangeError) {
        goto(`/login?error=${encodeURIComponent(exchangeError.message)}`);
        return;
      }

      // Handle user registration/lookup
      await authService.handleOAuthCallback();
      goto(next);
    } else {
      goto('/login?error=no_code');
    }
  });
</script>

<!-- Loading spinner while processing -->
<div class="flex items-center justify-center min-h-screen">
  <div class="animate-spin rounded-full h-8 w-8 border-2 border-purple-500 border-t-transparent"></div>
</div>
```

### 3.2 Remove `/home` server redirect

Delete `src/routes/home/+page.server.ts`.

Create a simple client-side redirect in `src/routes/home/+page.svelte`:

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  onMount(() => goto('/', { replaceState: true }));
</script>
```

Or, if the `/home` route is only for legacy Flutter links, just add a redirect in the Vercel config and delete the route entirely.

---

## Phase 4 — Move `casar-disciplinas` to Supabase Edge Function

This is the biggest change. The `/api/casar-disciplinas/+server.ts` endpoint has ~860 lines of business logic that queries 4 tables and does complex matching. Moving it to a **Supabase Edge Function** keeps it server-side (for security and performance of multi-table queries) but removes the need for a Node.js server.

### 4.1 Create the Edge Function

```bash
# In the project root (or wherever supabase/ directory lives)
supabase functions new casar-disciplinas
```

This creates `supabase/functions/casar-disciplinas/index.ts`.

### 4.2 Port the logic

The Edge Function will:
1. Receive the same POST body (`dados_extraidos`)
2. Create a Supabase client using the service role key (available as env var in Edge Functions)
3. Run the same matching algorithm
4. Return the same JSON response

Key differences from the SvelteKit route:
- Uses `Deno.serve()` instead of SvelteKit's `RequestHandler`
- Uses `createClient` from `@supabase/supabase-js` (not `@supabase/ssr`)
- Has access to `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` automatically

```ts
// supabase/functions/casar-disciplinas/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const { dados_extraidos } = await req.json();

  // ... port the matching logic from +server.ts ...

  return new Response(JSON.stringify(result), {
    headers: { 'Content-Type': 'application/json' }
  });
});
```

### 4.3 Update the frontend to call the Edge Function

In `upload.service.ts`, change the endpoint:

```ts
async casarDisciplinas(dadosExtraidos: unknown) {
  const supabase = createSupabaseBrowserClient();
  const { data, error } = await supabase.functions.invoke('casar-disciplinas', {
    body: { dados_extraidos: dadosExtraidos }
  });

  if (error) throw error;
  return data;
}
```

**Benefits of Edge Functions over SvelteKit API routes:**
- Runs at the edge (closer to the database) — lower latency for DB queries
- No cold start penalty (Deno runtime is fast)
- Automatically handles CORS for your Supabase project
- Can use the service role key securely (not exposed to clients)
- Eliminates the Node.js server requirement entirely

### 4.4 Alternative: Move matching logic to a Supabase Database Function (plpgsql)

For maximum performance, the matching algorithm could be a **PostgreSQL function** called via `supabase.rpc()`. This eliminates the network round-trips between the Edge Function and the database (currently 4 queries). However, this is a larger refactor and can be done as a follow-up.

```sql
-- Example: a single RPC call that does all matching
CREATE OR REPLACE FUNCTION public.casar_disciplinas(p_dados_extraidos jsonb)
RETURNS jsonb AS $$
  -- All matching logic in SQL/plpgsql
  -- Single database round-trip
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

Frontend call:
```ts
const { data, error } = await supabase.rpc('casar_disciplinas', {
  p_dados_extraidos: dadosExtraidos
});
```

---

## Phase 5 — Enable RLS (prerequisite for client-side security)

> This phase is already documented in detail in [Plan 14 — Supabase Direct Access & RLS Migration](./14-SUPABASE-DIRECT-RLS.md). The SQL migration script and policies are ready.

### Summary of what Plan 14 covers:

1. Enable RLS on all tables
2. Public SELECT policies on curriculum tables (`cursos`, `materias`, `materias_por_curso`, `pre_requisitos`, `co_requisitos`, `equivalencias`)
3. User-scoped policies on `users` and `dados_users` (using `auth.uid()`)
4. No-access policies on backup tables
5. Security invoker on views

### What's needed before going fully client-side:

- [ ] Run the RLS migration SQL from Plan 14 Section 7
- [ ] Test with anon key: public tables readable, user tables scoped
- [ ] Verify the `vw_creditos_por_matriz` view works with RLS (it's referenced by `SupabaseDataService.getCursosComCreditos()` but not listed in Plan 14's view section — may need `security_invoker = on`)

---

## Phase 6 — Clean Up Dead Server Code

### 6.1 Files to delete

| File | Reason |
|------|--------|
| `src/hooks.server.ts` | Server auth guard — replaced by client-side guard |
| `src/routes/auth/callback/+page.server.ts` | Server OAuth exchange — handled client-side |
| `src/routes/home/+page.server.ts` | Server redirect — handled by Vercel config or client redirect |
| `src/routes/api/casar-disciplinas/+server.ts` | Moved to Supabase Edge Function |
| `src/lib/server/supabase.ts` | Dead code — never imported anywhere |
| `src/routes/health/+server.ts` | Health check — not needed for static deployment (CDN handles this) |
| `src/routes/sitemap.xml/+server.ts` | Generate at build time instead, or serve as a static file |

### 6.2 Dependencies to remove

```bash
# @supabase/ssr's createServerClient is no longer needed
# But keep @supabase/ssr since createBrowserClient still comes from it
```

### 6.3 Update `app.d.ts`

Remove `Locals` interface entirely since there's no server-side context.

---

## Phase 7 — Performance Optimizations

With SSR removed, optimize client-side loading:

### 7.1 Aggressive code splitting

SvelteKit already code-splits per route. Verify heavy dependencies are lazy-loaded:

```ts
// PDF.js should only load on the upload page
// In upload-historico/+page.svelte or the upload service:
const pdfjs = await import('pdfjs-dist');
```

### 7.2 Preload critical data

For the `/fluxogramas` page (course listing), preload data during navigation:

```svelte
<!-- In Navbar or wherever the link is -->
<a
  href="/fluxogramas"
  on:mouseenter={() => fluxogramaService.prefetchCursos()}
>
  Fluxogramas
</a>
```

### 7.3 Cache Supabase responses

Add client-side caching for public data that rarely changes (courses, subjects):

```ts
// Simple cache wrapper for SupabaseDataService
const cache = new Map<string, { data: unknown; timestamp: number }>();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

async getCursosComCreditos() {
  const cached = cache.get('cursos_creditos');
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data;
  }

  const { data, error } = await this.supabase
    .from('vw_creditos_por_matriz')
    .select('*');

  if (!error && data) {
    cache.set('cursos_creditos', { data, timestamp: Date.now() });
  }
  return data;
}
```

### 7.4 Optimize initial auth check

The current auth bootstrap in `+layout.svelte` blocks all protected page rendering with a spinner while checking the session. Optimize by:

1. **Check `localStorage` first** — Supabase stores the session in `localStorage`. Read it synchronously to avoid the spinner flash:

```ts
// In authStore initialization (runs synchronously)
const storedSession = localStorage.getItem('sb-<project-ref>-auth-token');
if (storedSession) {
  try {
    const parsed = JSON.parse(storedSession);
    // Optimistically set authenticated state
    authStore.setLoading(false);
    authStore.setAuthenticated(true);
    // Then validate async in the background
    authService.getSession().then(session => {
      if (!session) authStore.clear();
    });
  } catch {}
}
```

2. **Show skeleton UI instead of spinner** — render page layout immediately with skeleton placeholders, filling in data as it loads.

### 7.5 Generate sitemap at build time

Instead of a server route, generate `sitemap.xml` during the build:

```ts
// vite.config.ts or a custom plugin
// Generate static sitemap.xml into the build output
```

Or simply create `static/sitemap.xml` as a static file.

---

## Phase 8 — Migrate `/health` and `/sitemap.xml`

### 8.1 Health check

For a static deployment, the CDN provider handles health checks. If you need a custom health endpoint:
- Vercel: Use the built-in health check
- Or: Create a static `public/health.json` → `{ "status": "ok" }`

### 8.2 Sitemap

Move from dynamic server route to static file at `static/sitemap.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://nofluxo.com/</loc><changefreq>monthly</changefreq><priority>1.0</priority></url>
  <url><loc>https://nofluxo.com/login</loc><changefreq>monthly</changefreq><priority>0.5</priority></url>
  <url><loc>https://nofluxo.com/signup</loc><changefreq>monthly</changefreq><priority>0.5</priority></url>
  <url><loc>https://nofluxo.com/password-recovery</loc><changefreq>monthly</changefreq><priority>0.3</priority></url>
</urlset>
```

---

## Implementation Order & Risk Assessment

| Phase | Effort | Risk | Dependencies |
|-------|--------|------|-------------|
| **Phase 1**: Static adapter | Small | Low — just config changes | None |
| **Phase 2**: Remove server auth guard | Small | Medium — must verify client guard covers all cases | Phase 1 |
| **Phase 5**: Enable RLS | Medium | **High — database changes** | Must test thoroughly before Phase 4 |
| **Phase 3**: Client-side OAuth | Small | Low — well-documented Supabase pattern | Phase 2 |
| **Phase 4**: Edge Function for `casar-disciplinas` | Large | Medium — largest logic port | Phase 5 (RLS) |
| **Phase 6**: Clean up dead code | Small | Low — just deletions | Phases 1-4 |
| **Phase 7**: Performance optimizations | Medium | Low — all additive improvements | Phase 1 |
| **Phase 8**: Static health/sitemap | Small | Low | Phase 1 |

### Recommended execution order:

1. **Phase 5** (RLS) — do this first since it's a database-level prerequisite
2. **Phase 1** (static adapter) — biggest architectural win, lowest risk
3. **Phase 2** (remove server auth) — depends on Phase 1
4. **Phase 3** (client OAuth) — quick win after Phase 2
5. **Phase 4** (Edge Function) — biggest effort, do after core migration
6. **Phase 6** (cleanup) — after all migrations done
7. **Phase 7** (performance) — polish layer
8. **Phase 8** (static files) — trivial, do anytime

---

## Rollback Strategy

Each phase is independently reversible:

- **Phase 1**: Switch back to `adapter-auto` in `svelte.config.js`
- **Phase 2**: Restore `hooks.server.ts` from git
- **Phase 3**: Restore `+page.server.ts` from git
- **Phase 4**: Point `upload.service.ts` back to `/api/casar-disciplinas`; restore the `+server.ts`
- **Phase 5**: RLS policies can be dropped without data loss

---

## Success Metrics

| Metric | Current (SSR) | Target (Client-First) |
|--------|--------------|----------------------|
| TTFB (Time to First Byte) | ~200-500ms (server render) | ~20-50ms (CDN static) |
| Server infrastructure | Node.js server required | Static CDN only |
| Auth check latency | ~100ms server + ~100ms client (duplicate) | ~100ms client only |
| `casar-disciplinas` latency | ~300ms (SvelteKit → Supabase) | ~100ms (Edge Function, co-located with DB) |
| Deployment complexity | Node.js runtime + build | Static build only |
| Cold start risk | Yes (serverless function boot) | None (static files) |

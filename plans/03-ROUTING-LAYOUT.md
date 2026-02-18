# 03 - Routing & Layouts: Flutter to SvelteKit Migration

> **NoFluxo UNB** - Complete Routing and Layout System Migration

This document provides a comprehensive guide to migrate the Flutter go_router implementation to SvelteKit's file-based routing system.

---

## Table of Contents

1. [Flutter vs SvelteKit Routing](#1-flutter-vs-sveltekit-routing)
2. [Complete Route Structure](#2-complete-route-structure)
3. [Root Layout](#3-root-layout)
4. [Page Layouts](#4-page-layouts)
5. [Dynamic Routes](#5-dynamic-routes)
6. [Error Pages](#6-error-pages)
7. [Route Groups](#7-route-groups)
8. [Loading States](#8-loading-states)
9. [Navigation](#9-navigation)
10. [SEO and Meta Tags](#10-seo-and-meta-tags)

---

## 1. Flutter vs SvelteKit Routing

### 1.1 Routing Comparison

| Feature | Flutter (go_router) | SvelteKit |
|---------|---------------------|-----------|
| Routing Type | Imperative/Configuration | File-based |
| Route Definition | `GoRoute(path: '/login')` | `src/routes/login/+page.svelte` |
| Dynamic Routes | `/meu-fluxograma/:courseName` | `/meu-fluxograma/[courseName]` |
| Route Guards | `redirect` callback | `+page.server.ts` load |
| Nested Layouts | `ShellRoute` | `+layout.svelte` |
| Error Handling | `errorBuilder` | `+error.svelte` |
| Navigation | `context.go('/path')` | `goto('/path')` |
| State Parameter | `GoRouterState` | `PageData`, `$page` store |
| URL Strategy | `usePathUrlStrategy()` | Default behavior |

### 1.2 Current Flutter Routes

From `app_router.dart`:

```dart
// Flutter route definitions
static Map<String, Widget Function(BuildContext, GoRouterState)> routes = {
  '/home': (context, state) => const HomeScreen(),
  '/': (context, state) => const HomeScreen(),
  '/assistente': (context, state) => const AssistenteScreen(),
  '/upload-historico': (context, state) => const UploadHistoricoScreen(),
  '/login': (context, state) => const AuthPage(isLogin: true),
  '/signup': (context, state) => const AuthPage(isLogin: false),
  '/password-recovery': (context, state) => const PasswordRecoveryScreen(),
  '/fluxogramas': (context, state) => const FluxogramasIndexScreen(),
  '/meu-fluxograma': (context, state) => const MeuFluxogramaScreen(),
  '/meu-fluxograma/:courseName': (context, state) {
    final courseName = state.pathParameters['courseName'] ?? '';
    return MeuFluxogramaScreen(courseName: courseName);
  },
  '/login-anonimo': (context, state) => const AnonymousLoginScreen(),
};
```

### 1.3 Route Classification

| Route | Flutter Screen | Auth Required | SvelteKit Group |
|-------|----------------|---------------|-----------------|
| `/`, `/home` | HomeScreen | No | `(public)` |
| `/login` | AuthPage(isLogin: true) | No | `(auth)` |
| `/signup` | AuthPage(isLogin: false) | No | `(auth)` |
| `/password-recovery` | PasswordRecoveryScreen | No | `(auth)` |
| `/login-anonimo` | AnonymousLoginScreen | No | `(auth)` |
| `/assistente` | AssistenteScreen | Yes | `(protected)` |
| `/upload-historico` | UploadHistoricoScreen | Yes | `(protected)` |
| `/fluxogramas` | FluxogramasIndexScreen | Yes | `(protected)` |
| `/meu-fluxograma` | MeuFluxogramaScreen | Yes | `(protected)` |
| `/meu-fluxograma/[courseName]` | MeuFluxogramaScreen | Yes | `(protected)` |

---

## 2. Complete Route Structure

### 2.1 Full Folder Structure

```
src/
├── routes/
│   ├── +layout.svelte              # Root layout (navbar, fonts, theme)
│   ├── +layout.server.ts           # Root server load (auth state)
│   ├── +layout.ts                  # Client-side layout load
│   ├── +error.svelte               # Global error page
│   ├── +page.svelte                # Home page (/)
│   ├── +page.ts                    # Home page load function
│   │
│   ├── (auth)/                     # Auth group (no auth required)
│   │   ├── +layout.svelte          # Auth layout (centered card)
│   │   ├── login/
│   │   │   ├── +page.svelte        # Login page
│   │   │   └── +page.ts            # Login page metadata
│   │   ├── signup/
│   │   │   ├── +page.svelte        # Signup page
│   │   │   └── +page.ts
│   │   ├── password-recovery/
│   │   │   ├── +page.svelte        # Password recovery page
│   │   │   └── +page.ts
│   │   └── login-anonimo/
│   │       ├── +page.svelte        # Anonymous login page
│   │       └── +page.ts
│   │
│   ├── (protected)/                # Protected routes group
│   │   ├── +layout.svelte          # Dashboard layout (sidebar)
│   │   ├── +layout.server.ts       # Auth guard
│   │   ├── assistente/
│   │   │   ├── +page.svelte        # AI Assistant page
│   │   │   └── +page.ts
│   │   ├── upload-historico/
│   │   │   ├── +page.svelte        # Upload history page
│   │   │   └── +page.ts
│   │   ├── fluxogramas/
│   │   │   ├── +page.svelte        # Fluxogramas index
│   │   │   └── +page.ts
│   │   └── meu-fluxograma/
│   │       ├── +page.svelte        # My fluxograma (default)
│   │       ├── +page.ts
│   │       └── [courseName]/
│   │           ├── +page.svelte    # My fluxograma (with course)
│   │           └── +page.ts
│   │
│   ├── api/                        # API routes
│   │   └── auth/
│   │       └── callback/
│   │           └── +server.ts      # OAuth callback handler
│   │
│   └── home/                       # Redirect /home to /
│       └── +page.server.ts
│
├── lib/
│   ├── components/
│   │   ├── layout/
│   │   │   ├── Navbar.svelte       # Global navigation bar
│   │   │   ├── Footer.svelte       # Footer component
│   │   │   ├── Sidebar.svelte      # Dashboard sidebar
│   │   │   └── MobileNav.svelte    # Mobile navigation
│   │   └── ui/                     # shadcn-svelte components
│   │
│   ├── stores/
│   │   └── navigation.ts           # Navigation state store
│   │
│   └── config/
│       └── routes.ts               # Route constants
│
├── app.html                        # HTML template
├── app.css                         # Global styles
└── app.d.ts                        # Type definitions
```

### 2.2 Route Constants

Create `src/lib/config/routes.ts`:

```typescript
// Route path constants
export const ROUTES = {
  // Public routes
  HOME: '/',
  LOGIN: '/login',
  SIGNUP: '/signup',
  PASSWORD_RECOVERY: '/password-recovery',
  ANONYMOUS_LOGIN: '/login-anonimo',

  // Protected routes
  ASSISTENTE: '/assistente',
  UPLOAD_HISTORICO: '/upload-historico',
  FLUXOGRAMAS: '/fluxogramas',
  MEU_FLUXOGRAMA: '/meu-fluxograma',

  // Dynamic routes
  meuFluxograma: (courseName: string) => `/meu-fluxograma/${encodeURIComponent(courseName)}`,
} as const;

// Routes that don't require authentication (matching Flutter)
export const PUBLIC_ROUTES = [
  '/',
  '/home',
  '/login',
  '/signup',
  '/password-recovery',
  '/login-anonimo',
] as const;

// Protected routes require authentication
export const PROTECTED_ROUTES = [
  '/assistente',
  '/upload-historico',
  '/fluxogramas',
  '/meu-fluxograma',
] as const;

// Check if route requires authentication
export function requiresAuth(pathname: string): boolean {
  // Check public routes
  if (PUBLIC_ROUTES.includes(pathname as any)) {
    return false;
  }

  // Check protected route prefixes
  return PROTECTED_ROUTES.some((route) => pathname.startsWith(route));
}
```

---

## 3. Root Layout

### 3.1 HTML Template

Create/update `src/app.html`:

```html
<!doctype html>
<html lang="pt-BR" class="h-full">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#7c3aed" />
    <meta name="description" content="NoFluxo UNB - Gerenciamento de fluxograma acadêmico" />
    
    <!-- Favicon -->
    <link rel="icon" href="%sveltekit.assets%/favicon.ico" />
    <link rel="apple-touch-icon" href="%sveltekit.assets%/apple-touch-icon.png" />
    
    <!-- Preconnect to Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    
    <!-- Poppins Font (matching Flutter GoogleFonts.poppinsTextTheme()) -->
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
    
    %sveltekit.head%
  </head>
  <body class="h-full font-poppins antialiased" data-sveltekit-preload-data="hover">
    <div class="min-h-full">%sveltekit.body%</div>
  </body>
</html>
```

### 3.2 Root Layout Server Load

Create `src/routes/+layout.server.ts`:

```typescript
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals, url }) => {
  // Get the session from hooks.server.ts
  const session = await locals.safeGetSession();
  const user = locals.user;

  return {
    session,
    user,
    url: url.pathname,
  };
};
```

### 3.3 Root Layout Client Load

Create `src/routes/+layout.ts`:

```typescript
import type { LayoutLoad } from './$types';
import { createSupabaseBrowserClient } from '$lib/supabase/client';

export const load: LayoutLoad = async ({ data, depends }) => {
  // Depend on supabase auth state
  depends('supabase:auth');

  const supabase = createSupabaseBrowserClient();

  // Get fresh session from browser client
  const {
    data: { session },
  } = await supabase.auth.getSession();

  return {
    ...data,
    supabase,
    session,
  };
};
```

### 3.4 Root Layout Component

Create `src/routes/+layout.svelte`:

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { invalidate } from '$app/navigation';
  import { page } from '$app/stores';
  import '../app.css';
  import Navbar from '$lib/components/layout/Navbar.svelte';
  import Footer from '$lib/components/layout/Footer.svelte';
  import { Toaster } from '$lib/components/ui/sonner';

  export let data;

  $: ({ supabase, session, user } = data);

  // Track auth state changes
  onMount(() => {
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, _session) => {
      if (_session?.expires_at !== session?.expires_at) {
        // Invalidate all data that depends on auth
        invalidate('supabase:auth');
      }
    });

    return () => subscription.unsubscribe();
  });

  // Determine if we should show the navbar
  $: showNavbar = !$page.url.pathname.startsWith('/login') &&
                  !$page.url.pathname.startsWith('/signup') &&
                  !$page.url.pathname.startsWith('/password-recovery') &&
                  !$page.url.pathname.startsWith('/login-anonimo');

  // Determine if we should show the footer
  $: showFooter = $page.url.pathname === '/' || $page.url.pathname === '/home';
</script>

<svelte:head>
  <title>NoFluxo UNB</title>
</svelte:head>

<div class="flex min-h-screen flex-col bg-background text-foreground">
  {#if showNavbar}
    <Navbar {session} {user} />
  {/if}

  <main class="flex-1">
    <slot />
  </main>

  {#if showFooter}
    <Footer />
  {/if}
</div>

<!-- Toast notifications -->
<Toaster richColors position="top-right" />
```

### 3.5 Navbar Component

Create `src/lib/components/layout/Navbar.svelte`:

```svelte
<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { Button } from '$lib/components/ui/button';
  import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
  import * as Avatar from '$lib/components/ui/avatar';
  import { createSupabaseBrowserClient } from '$lib/supabase/client';
  import { ROUTES } from '$lib/config/routes';
  import { Menu, X, User, LogOut, LayoutDashboard } from 'lucide-svelte';
  import type { Session } from '@supabase/supabase-js';
  import type { UserModel } from '$lib/types/user';

  export let session: Session | null;
  export let user: UserModel | null;

  let mobileMenuOpen = false;
  const supabase = createSupabaseBrowserClient();

  // Navigation links
  const navLinks = [
    { href: ROUTES.FLUXOGRAMAS, label: 'Fluxogramas' },
    { href: ROUTES.ASSISTENTE, label: 'Assistente' },
    { href: ROUTES.UPLOAD_HISTORICO, label: 'Importar Histórico' },
  ];

  async function handleLogout() {
    await supabase.auth.signOut();
    goto(ROUTES.LOGIN);
  }

  function toggleMobileMenu() {
    mobileMenuOpen = !mobileMenuOpen;
  }

  $: isActive = (href: string) => $page.url.pathname === href;
</script>

<header class="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
  <nav class="container mx-auto flex h-16 items-center justify-between px-4">
    <!-- Logo -->
    <a href="/" class="flex items-center space-x-2">
      <img src="/logo.svg" alt="NoFluxo" class="h-8 w-8" />
      <span class="text-xl font-bold text-primary">NoFluxo</span>
    </a>

    <!-- Desktop Navigation -->
    <div class="hidden md:flex md:items-center md:space-x-6">
      {#if session}
        {#each navLinks as link}
          <a
            href={link.href}
            class="text-sm font-medium transition-colors hover:text-primary {isActive(link.href)
              ? 'text-primary'
              : 'text-muted-foreground'}"
          >
            {link.label}
          </a>
        {/each}

        <!-- User Menu -->
        <DropdownMenu.Root>
          <DropdownMenu.Trigger asChild let:builder>
            <Button builders={[builder]} variant="ghost" class="relative h-10 w-10 rounded-full">
              <Avatar.Root class="h-10 w-10">
                <Avatar.Fallback>
                  {user?.nome_completo?.charAt(0).toUpperCase() || 'U'}
                </Avatar.Fallback>
              </Avatar.Root>
            </Button>
          </DropdownMenu.Trigger>
          <DropdownMenu.Content class="w-56" align="end">
            <DropdownMenu.Label class="font-normal">
              <div class="flex flex-col space-y-1">
                <p class="text-sm font-medium leading-none">{user?.nome_completo || 'Usuário'}</p>
                <p class="text-xs leading-none text-muted-foreground">{user?.email}</p>
              </div>
            </DropdownMenu.Label>
            <DropdownMenu.Separator />
            <DropdownMenu.Item onclick={() => goto(ROUTES.MEU_FLUXOGRAMA)}>
              <LayoutDashboard class="mr-2 h-4 w-4" />
              Meu Fluxograma
            </DropdownMenu.Item>
            <DropdownMenu.Separator />
            <DropdownMenu.Item onclick={handleLogout} class="text-destructive">
              <LogOut class="mr-2 h-4 w-4" />
              Sair
            </DropdownMenu.Item>
          </DropdownMenu.Content>
        </DropdownMenu.Root>
      {:else}
        <Button variant="ghost" onclick={() => goto(ROUTES.LOGIN)}>Entrar</Button>
        <Button onclick={() => goto(ROUTES.SIGNUP)}>Criar Conta</Button>
      {/if}
    </div>

    <!-- Mobile Menu Button -->
    <button
      class="md:hidden"
      onclick={toggleMobileMenu}
      aria-label={mobileMenuOpen ? 'Fechar menu' : 'Abrir menu'}
    >
      {#if mobileMenuOpen}
        <X class="h-6 w-6" />
      {:else}
        <Menu class="h-6 w-6" />
      {/if}
    </button>
  </nav>

  <!-- Mobile Navigation -->
  {#if mobileMenuOpen}
    <div class="border-t md:hidden">
      <div class="container mx-auto space-y-1 px-4 py-3">
        {#if session}
          {#each navLinks as link}
            <a
              href={link.href}
              class="block rounded-md px-3 py-2 text-base font-medium {isActive(link.href)
                ? 'bg-primary/10 text-primary'
                : 'text-muted-foreground hover:bg-accent'}"
              onclick={() => (mobileMenuOpen = false)}
            >
              {link.label}
            </a>
          {/each}
          <hr class="my-2" />
          <button
            onclick={handleLogout}
            class="block w-full rounded-md px-3 py-2 text-left text-base font-medium text-destructive hover:bg-accent"
          >
            Sair
          </button>
        {:else}
          <a
            href={ROUTES.LOGIN}
            class="block rounded-md px-3 py-2 text-base font-medium hover:bg-accent"
            onclick={() => (mobileMenuOpen = false)}
          >
            Entrar
          </a>
          <a
            href={ROUTES.SIGNUP}
            class="block rounded-md px-3 py-2 text-base font-medium text-primary hover:bg-accent"
            onclick={() => (mobileMenuOpen = false)}
          >
            Criar Conta
          </a>
        {/if}
      </div>
    </div>
  {/if}
</header>
```

### 3.6 Global CSS Configuration

Update `src/app.css`:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    /* NoFluxo Purple Theme (matching Flutter Colors.deepPurple) */
    --background: 0 0% 100%;
    --foreground: 240 10% 3.9%;
    --card: 0 0% 100%;
    --card-foreground: 240 10% 3.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 240 10% 3.9%;
    --primary: 262 83% 58%;      /* Purple 600 */
    --primary-foreground: 0 0% 98%;
    --secondary: 240 4.8% 95.9%;
    --secondary-foreground: 240 5.9% 10%;
    --muted: 240 4.8% 95.9%;
    --muted-foreground: 240 3.8% 46.1%;
    --accent: 262 83% 95%;       /* Purple light */
    --accent-foreground: 262 83% 30%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 0 0% 98%;
    --border: 240 5.9% 90%;
    --input: 240 5.9% 90%;
    --ring: 262 83% 58%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 240 10% 3.9%;
    --foreground: 0 0% 98%;
    --card: 240 10% 3.9%;
    --card-foreground: 0 0% 98%;
    --popover: 240 10% 3.9%;
    --popover-foreground: 0 0% 98%;
    --primary: 262 83% 65%;
    --primary-foreground: 262 83% 10%;
    --secondary: 240 3.7% 15.9%;
    --secondary-foreground: 0 0% 98%;
    --muted: 240 3.7% 15.9%;
    --muted-foreground: 240 5% 64.9%;
    --accent: 262 30% 20%;
    --accent-foreground: 262 83% 80%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 0 0% 98%;
    --border: 240 3.7% 15.9%;
    --input: 240 3.7% 15.9%;
    --ring: 262 83% 65%;
  }
}

@layer base {
  * {
    @apply border-border;
  }

  body {
    @apply bg-background text-foreground;
    font-family: 'Poppins', system-ui, sans-serif;
  }
}

/* Custom scrollbar */
@layer utilities {
  .scrollbar-thin {
    scrollbar-width: thin;
  }

  .scrollbar-thin::-webkit-scrollbar {
    width: 6px;
    height: 6px;
  }

  .scrollbar-thin::-webkit-scrollbar-track {
    @apply bg-muted;
  }

  .scrollbar-thin::-webkit-scrollbar-thumb {
    @apply rounded-full bg-muted-foreground/20;
  }

  .scrollbar-thin::-webkit-scrollbar-thumb:hover {
    @apply bg-muted-foreground/40;
  }
}

/* Page transition animations */
@layer utilities {
  .page-transition {
    @apply transition-opacity duration-200 ease-in-out;
  }

  .page-enter {
    @apply opacity-0;
  }

  .page-enter-active {
    @apply opacity-100;
  }
}
```

---

## 4. Page Layouts

### 4.1 Auth Layout (Login/Signup Pages)

Create `src/routes/(auth)/+layout.svelte`:

```svelte
<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  export let data;

  // Redirect if already logged in
  onMount(() => {
    if (data.session) {
      goto('/upload-historico');
    }
  });
</script>

<div class="min-h-screen bg-gradient-to-br from-primary/5 via-background to-accent/10">
  <!-- Background decoration -->
  <div class="fixed inset-0 -z-10 overflow-hidden">
    <div class="absolute -left-40 -top-40 h-80 w-80 rounded-full bg-primary/10 blur-3xl"></div>
    <div class="absolute -bottom-40 -right-40 h-80 w-80 rounded-full bg-accent/20 blur-3xl"></div>
  </div>

  <div class="container mx-auto flex min-h-screen items-center justify-center px-4 py-8">
    <div class="w-full max-w-md">
      <!-- Logo -->
      <div class="mb-8 text-center">
        <a href="/" class="inline-flex items-center space-x-2">
          <img src="/logo.svg" alt="NoFluxo" class="h-12 w-12" />
          <span class="text-2xl font-bold text-primary">NoFluxo</span>
        </a>
      </div>

      <!-- Content Card -->
      <div class="rounded-xl border bg-card p-6 shadow-lg sm:p-8">
        <slot />
      </div>

      <!-- Footer Links -->
      <div class="mt-6 text-center text-sm text-muted-foreground">
        {#if $page.url.pathname === '/login'}
          <p>
            Não tem uma conta?
            <a href="/signup" class="font-medium text-primary hover:underline">Criar conta</a>
          </p>
        {:else if $page.url.pathname === '/signup'}
          <p>
            Já tem uma conta?
            <a href="/login" class="font-medium text-primary hover:underline">Entrar</a>
          </p>
        {:else if $page.url.pathname === '/password-recovery'}
          <p>
            Lembrou a senha?
            <a href="/login" class="font-medium text-primary hover:underline">Voltar ao login</a>
          </p>
        {/if}
      </div>
    </div>
  </div>
</div>
```

### 4.2 Protected Layout (Dashboard)

Create `src/routes/(protected)/+layout.svelte`:

```svelte
<script lang="ts">
  import { page } from '$app/stores';
  import Sidebar from '$lib/components/layout/Sidebar.svelte';
  import { Sheet, SheetContent, SheetTrigger } from '$lib/components/ui/sheet';
  import { Button } from '$lib/components/ui/button';
  import { Menu } from 'lucide-svelte';

  export let data;

  $: ({ user } = data);

  let sidebarOpen = false;
</script>

<div class="flex min-h-screen">
  <!-- Desktop Sidebar -->
  <aside class="hidden w-64 flex-shrink-0 border-r bg-card lg:block">
    <Sidebar {user} currentPath={$page.url.pathname} />
  </aside>

  <!-- Mobile Sidebar -->
  <Sheet bind:open={sidebarOpen}>
    <SheetTrigger asChild let:builder>
      <Button
        builders={[builder]}
        variant="ghost"
        size="icon"
        class="fixed bottom-4 right-4 z-50 rounded-full shadow-lg lg:hidden"
      >
        <Menu class="h-6 w-6" />
      </Button>
    </SheetTrigger>
    <SheetContent side="left" class="w-64 p-0">
      <Sidebar {user} currentPath={$page.url.pathname} onNavigate={() => (sidebarOpen = false)} />
    </SheetContent>
  </Sheet>

  <!-- Main Content -->
  <main class="flex-1 overflow-auto">
    <div class="container mx-auto p-4 lg:p-6">
      <slot />
    </div>
  </main>
</div>
```

### 4.3 Protected Layout Server Guard

Create `src/routes/(protected)/+layout.server.ts`:

```typescript
import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';
import { ROUTES } from '$lib/config/routes';

export const load: LayoutServerLoad = async ({ locals, url }) => {
  const session = await locals.safeGetSession();
  const user = locals.user;

  // Check for anonymous user
  const isAnonymous = locals.isAnonymous;

  // If no session and not anonymous, redirect to login
  if (!session && !isAnonymous) {
    throw redirect(303, `${ROUTES.LOGIN}?redirectTo=${encodeURIComponent(url.pathname)}`);
  }

  // If session exists but no user in backend, redirect to signup
  if (session && !user && !isAnonymous) {
    throw redirect(303, ROUTES.SIGNUP);
  }

  return {
    session,
    user,
    isAnonymous,
  };
};
```

### 4.4 Sidebar Component

Create `src/lib/components/layout/Sidebar.svelte`:

```svelte
<script lang="ts">
  import { ROUTES } from '$lib/config/routes';
  import {
    LayoutDashboard,
    Bot,
    Upload,
    GitBranch,
    Settings,
    HelpCircle,
  } from 'lucide-svelte';
  import type { UserModel } from '$lib/types/user';

  export let user: UserModel | null;
  export let currentPath: string;
  export let onNavigate: (() => void) | undefined = undefined;

  const navItems = [
    {
      title: 'Dashboard',
      items: [
        { href: ROUTES.FLUXOGRAMAS, label: 'Fluxogramas', icon: GitBranch },
        { href: ROUTES.MEU_FLUXOGRAMA, label: 'Meu Fluxograma', icon: LayoutDashboard },
      ],
    },
    {
      title: 'Ferramentas',
      items: [
        { href: ROUTES.UPLOAD_HISTORICO, label: 'Importar Histórico', icon: Upload },
        { href: ROUTES.ASSISTENTE, label: 'Assistente IA', icon: Bot },
      ],
    },
  ];

  function isActive(href: string): boolean {
    return currentPath === href || currentPath.startsWith(href + '/');
  }
</script>

<div class="flex h-full flex-col">
  <!-- Logo -->
  <div class="flex h-16 items-center border-b px-6">
    <a href="/" class="flex items-center space-x-2" onclick={onNavigate}>
      <img src="/logo.svg" alt="NoFluxo" class="h-8 w-8" />
      <span class="text-lg font-bold text-primary">NoFluxo</span>
    </a>
  </div>

  <!-- Navigation -->
  <nav class="flex-1 overflow-y-auto p-4">
    {#each navItems as group}
      <div class="mb-6">
        <h3 class="mb-2 px-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          {group.title}
        </h3>
        <ul class="space-y-1">
          {#each group.items as item}
            <li>
              <a
                href={item.href}
                class="flex items-center rounded-lg px-3 py-2 text-sm font-medium transition-colors
                  {isActive(item.href)
                  ? 'bg-primary/10 text-primary'
                  : 'text-muted-foreground hover:bg-accent hover:text-accent-foreground'}"
                onclick={onNavigate}
              >
                <svelte:component this={item.icon} class="mr-3 h-5 w-5" />
                {item.label}
              </a>
            </li>
          {/each}
        </ul>
      </div>
    {/each}
  </nav>

  <!-- User Info -->
  {#if user}
    <div class="border-t p-4">
      <div class="flex items-center space-x-3">
        <div class="flex h-10 w-10 items-center justify-center rounded-full bg-primary/10 text-primary">
          {user.nome_completo?.charAt(0).toUpperCase() || 'U'}
        </div>
        <div class="flex-1 truncate">
          <p class="truncate text-sm font-medium">{user.nome_completo}</p>
          <p class="truncate text-xs text-muted-foreground">{user.email}</p>
        </div>
      </div>
    </div>
  {/if}
</div>
```

---

## 5. Dynamic Routes

### 5.1 Dynamic Route with Parameter

Create `src/routes/(protected)/meu-fluxograma/[courseName]/+page.svelte`:

```svelte
<script lang="ts">
  import { page } from '$app/stores';
  import FluxogramaView from '$lib/components/fluxogramas/FluxogramaView.svelte';
  import { Skeleton } from '$lib/components/ui/skeleton';
  import { Button } from '$lib/components/ui/button';
  import { ArrowLeft } from 'lucide-svelte';

  export let data;

  $: courseName = data.courseName;
  $: fluxogramaData = data.fluxogramaData;
</script>

<svelte:head>
  <title>Fluxograma - {courseName} | NoFluxo UNB</title>
</svelte:head>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex items-center space-x-4">
    <Button variant="ghost" size="icon" href="/meu-fluxograma">
      <ArrowLeft class="h-5 w-5" />
    </Button>
    <div>
      <h1 class="text-2xl font-bold">{courseName}</h1>
      <p class="text-muted-foreground">Visualize o progresso do seu fluxograma</p>
    </div>
  </div>

  <!-- Fluxograma Content -->
  {#if fluxogramaData}
    <FluxogramaView data={fluxogramaData} />
  {:else}
    <div class="rounded-lg border p-8 text-center">
      <p class="text-muted-foreground">Nenhum dado de fluxograma encontrado para este curso.</p>
      <Button href="/upload-historico" class="mt-4">Importar Histórico</Button>
    </div>
  {/if}
</div>
```

### 5.2 Dynamic Route Load Function

Create `src/routes/(protected)/meu-fluxograma/[courseName]/+page.ts`:

```typescript
import type { PageLoad } from './$types';
import { error } from '@sveltejs/kit';

export const load: PageLoad = async ({ params, parent }) => {
  const { supabase, user } = await parent();

  // Decode the course name from URL
  const courseName = decodeURIComponent(params.courseName);

  if (!courseName) {
    throw error(404, {
      message: 'Curso não encontrado',
    });
  }

  // Fetch fluxograma data for this course
  // This would call your backend API
  try {
    // Example API call
    // const response = await fetch(`/api/fluxograma/${encodeURIComponent(courseName)}`);
    // const fluxogramaData = await response.json();

    return {
      courseName,
      fluxogramaData: user?.dados_fluxograma ?? null,
    };
  } catch (e) {
    console.error('Failed to load fluxograma:', e);
    return {
      courseName,
      fluxogramaData: null,
    };
  }
};
```

### 5.3 Default Meu Fluxograma Page

Create `src/routes/(protected)/meu-fluxograma/+page.svelte`:

```svelte
<script lang="ts">
  import { goto } from '$app/navigation';
  import { Button } from '$lib/components/ui/button';
  import * as Card from '$lib/components/ui/card';
  import { ROUTES } from '$lib/config/routes';
  import { GitBranch, Upload, ArrowRight } from 'lucide-svelte';

  export let data;

  $: user = data.user;
  $: hasFluxograma = user?.dados_fluxograma != null;

  // Available courses (would come from API)
  const availableCourses = [
    { name: 'Engenharia de Software', slug: 'engenharia-de-software' },
    { name: 'Ciência da Computação', slug: 'ciencia-da-computacao' },
    { name: 'Engenharia de Computação', slug: 'engenharia-de-computacao' },
  ];
</script>

<svelte:head>
  <title>Meu Fluxograma | NoFluxo UNB</title>
</svelte:head>

<div class="space-y-6">
  <div>
    <h1 class="text-2xl font-bold">Meu Fluxograma</h1>
    <p class="text-muted-foreground">
      Visualize e gerencie seu progresso acadêmico
    </p>
  </div>

  {#if hasFluxograma}
    <!-- Show user's fluxograma -->
    <Card.Root>
      <Card.Header>
        <Card.Title class="flex items-center">
          <GitBranch class="mr-2 h-5 w-5" />
          Seu Fluxograma Atual
        </Card.Title>
        <Card.Description>
          Baseado no histórico importado
        </Card.Description>
      </Card.Header>
      <Card.Content>
        <!-- Fluxograma preview would go here -->
        <div class="aspect-video rounded-lg bg-muted"></div>
      </Card.Content>
      <Card.Footer>
        <Button onclick={() => goto(ROUTES.UPLOAD_HISTORICO)}>
          Atualizar Histórico
        </Button>
      </Card.Footer>
    </Card.Root>
  {:else}
    <!-- No fluxograma - prompt to upload -->
    <Card.Root class="border-dashed">
      <Card.Header class="text-center">
        <div class="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
          <Upload class="h-8 w-8 text-primary" />
        </div>
        <Card.Title>Nenhum Fluxograma Encontrado</Card.Title>
        <Card.Description>
          Importe seu histórico acadêmico para gerar seu fluxograma personalizado
        </Card.Description>
      </Card.Header>
      <Card.Footer class="justify-center">
        <Button onclick={() => goto(ROUTES.UPLOAD_HISTORICO)}>
          <Upload class="mr-2 h-4 w-4" />
          Importar Histórico
        </Button>
      </Card.Footer>
    </Card.Root>
  {/if}

  <!-- Course Selection -->
  <div>
    <h2 class="mb-4 text-lg font-semibold">Explorar Cursos</h2>
    <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {#each availableCourses as course}
        <Card.Root class="cursor-pointer transition-shadow hover:shadow-md">
          <a href={ROUTES.meuFluxograma(course.slug)} class="block">
            <Card.Header>
              <Card.Title class="text-base">{course.name}</Card.Title>
            </Card.Header>
            <Card.Footer>
              <span class="flex items-center text-sm text-primary">
                Ver fluxograma
                <ArrowRight class="ml-1 h-4 w-4" />
              </span>
            </Card.Footer>
          </a>
        </Card.Root>
      {/each}
    </div>
  </div>
</div>
```

---

## 6. Error Pages

### 6.1 Global Error Page

Create `src/routes/+error.svelte`:

```svelte
<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { Button } from '$lib/components/ui/button';
  import { Home, ArrowLeft, RefreshCw } from 'lucide-svelte';

  $: error = $page.error;
  $: status = $page.status;

  function goBack() {
    history.back();
  }

  function retry() {
    location.reload();
  }

  // Error messages in Portuguese (matching Flutter error page)
  const errorMessages: Record<number, { title: string; description: string }> = {
    404: {
      title: 'Página não encontrada',
      description: 'A página que você está procurando não existe ou foi movida.',
    },
    401: {
      title: 'Não autorizado',
      description: 'Você precisa estar logado para acessar esta página.',
    },
    403: {
      title: 'Acesso negado',
      description: 'Você não tem permissão para acessar esta página.',
    },
    500: {
      title: 'Erro interno do servidor',
      description: 'Algo deu errado. Por favor, tente novamente mais tarde.',
    },
  };

  $: errorInfo = errorMessages[status] || {
    title: 'Algo deu errado',
    description: error?.message || 'Ocorreu um erro inesperado.',
  };
</script>

<svelte:head>
  <title>{status} - {errorInfo.title} | NoFluxo UNB</title>
</svelte:head>

<div class="flex min-h-[60vh] items-center justify-center px-4">
  <div class="text-center">
    <!-- Error Icon -->
    <div class="mx-auto mb-6 flex h-24 w-24 items-center justify-center rounded-full bg-destructive/10">
      <span class="text-4xl font-bold text-destructive">{status}</span>
    </div>

    <!-- Error Message -->
    <h1 class="mb-2 text-2xl font-bold">{errorInfo.title}</h1>
    <p class="mb-8 max-w-md text-muted-foreground">
      {errorInfo.description}
    </p>

    <!-- Actions -->
    <div class="flex flex-wrap justify-center gap-3">
      <Button variant="outline" onclick={goBack}>
        <ArrowLeft class="mr-2 h-4 w-4" />
        Voltar
      </Button>
      <Button onclick={() => goto('/')}>
        <Home class="mr-2 h-4 w-4" />
        Ir para o início
      </Button>
      {#if status >= 500}
        <Button variant="secondary" onclick={retry}>
          <RefreshCw class="mr-2 h-4 w-4" />
          Tentar novamente
        </Button>
      {/if}
    </div>

    <!-- Debug info in development -->
    {#if import.meta.env.DEV && error?.stack}
      <details class="mt-8 text-left">
        <summary class="cursor-pointer text-sm text-muted-foreground">
          Detalhes técnicos
        </summary>
        <pre class="mt-2 overflow-auto rounded-lg bg-muted p-4 text-xs">
          {error.stack}
        </pre>
      </details>
    {/if}
  </div>
</div>
```

### 6.2 Throwing Custom Errors

Example of throwing custom errors in load functions:

```typescript
// In any +page.ts or +page.server.ts
import { error } from '@sveltejs/kit';

export const load = async ({ params }) => {
  const course = await fetchCourse(params.id);

  if (!course) {
    throw error(404, {
      message: `O curso "${params.id}" não foi encontrado.`,
    });
  }

  return { course };
};
```

### 6.3 Nested Error Pages

For protected routes, create a specific error page:

Create `src/routes/(protected)/+error.svelte`:

```svelte
<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { Button } from '$lib/components/ui/button';
  import { ROUTES } from '$lib/config/routes';
  import { Home, LogIn } from 'lucide-svelte';

  $: status = $page.status;
</script>

<div class="flex min-h-[50vh] items-center justify-center">
  <div class="text-center">
    <div class="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-destructive/10">
      <span class="text-3xl font-bold text-destructive">{status}</span>
    </div>

    {#if status === 401}
      <h1 class="mb-2 text-xl font-bold">Sessão expirada</h1>
      <p class="mb-6 text-muted-foreground">
        Sua sessão expirou. Por favor, faça login novamente.
      </p>
      <Button onclick={() => goto(ROUTES.LOGIN)}>
        <LogIn class="mr-2 h-4 w-4" />
        Fazer login
      </Button>
    {:else}
      <h1 class="mb-2 text-xl font-bold">Erro</h1>
      <p class="mb-6 text-muted-foreground">
        Ocorreu um erro ao carregar esta página.
      </p>
      <Button onclick={() => goto(ROUTES.FLUXOGRAMAS)}>
        <Home class="mr-2 h-4 w-4" />
        Voltar ao dashboard
      </Button>
    {/if}
  </div>
</div>
```

---

## 7. Route Groups

### 7.1 Understanding Route Groups

SvelteKit route groups (folders with parentheses) allow organizing routes without affecting the URL structure:

```
src/routes/
├── (auth)/             # Group for auth pages - URL: /login, /signup
│   ├── login/
│   └── signup/
├── (protected)/        # Group for protected pages - URL: /assistente, etc.
│   ├── assistente/
│   └── fluxogramas/
└── (marketing)/        # Group for marketing pages - URL: /about, /pricing
    ├── about/
    └── pricing/
```

### 7.2 Route Group Layout Inheritance

```
+layout.svelte (root)
├── (auth)/+layout.svelte (auth-specific layout)
│   ├── login/+page.svelte (inherits both)
│   └── signup/+page.svelte
└── (protected)/+layout.svelte (dashboard layout)
    ├── assistente/+page.svelte (inherits both)
    └── fluxogramas/+page.svelte
```

### 7.3 Creating the Home Redirect

Create `src/routes/home/+page.server.ts`:

```typescript
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Redirect /home to / (matching Flutter behavior)
export const load: PageServerLoad = async () => {
  throw redirect(301, '/');
};
```

### 7.4 Public vs Protected Route Summary

| Group | Purpose | Layout Features | Auth Required |
|-------|---------|-----------------|---------------|
| `(auth)` | Login, signup, recovery | Centered card, no navbar | No (redirects if logged in) |
| `(protected)` | Dashboard pages | Sidebar, full navbar | Yes (redirects to login) |
| `(public)` | Marketing pages | Full navbar, footer | No |
| Root (`/`) | Home page | Full navbar, hero | No |

---

## 8. Loading States

### 8.1 Global Loading Indicator

Create `src/lib/components/layout/LoadingBar.svelte`:

```svelte
<script lang="ts">
  import { navigating } from '$app/stores';
  import { fade, fly } from 'svelte/transition';
</script>

{#if $navigating}
  <div
    class="fixed left-0 right-0 top-0 z-[100]"
    in:fade={{ duration: 150 }}
    out:fade={{ duration: 300 }}
  >
    <div class="h-1 w-full overflow-hidden bg-primary/20">
      <div
        class="h-full w-full origin-left animate-[loading_1s_ease-in-out_infinite] bg-primary"
      ></div>
    </div>
  </div>
{/if}

<style>
  @keyframes loading {
    0% {
      transform: translateX(-100%);
    }
    50% {
      transform: translateX(0%);
    }
    100% {
      transform: translateX(100%);
    }
  }
</style>
```

Add to root layout:

```svelte
<!-- In +layout.svelte -->
<script lang="ts">
  import LoadingBar from '$lib/components/layout/LoadingBar.svelte';
</script>

<LoadingBar />
<!-- rest of layout -->
```

### 8.2 Page Loading State

Create `src/lib/components/ui/PageLoading.svelte`:

```svelte
<script lang="ts">
  import { Skeleton } from '$lib/components/ui/skeleton';

  export let title = 'Carregando...';
</script>

<div class="space-y-6 animate-in fade-in duration-300">
  <!-- Header skeleton -->
  <div class="space-y-2">
    <Skeleton class="h-8 w-48" />
    <Skeleton class="h-4 w-72" />
  </div>

  <!-- Content skeleton -->
  <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
    {#each Array(6) as _}
      <div class="rounded-lg border p-4 space-y-3">
        <Skeleton class="h-4 w-3/4" />
        <Skeleton class="h-4 w-1/2" />
        <Skeleton class="h-20 w-full" />
      </div>
    {/each}
  </div>
</div>

<span class="sr-only">{title}</span>
```

### 8.3 Using Loading State in Pages

```svelte
<script lang="ts">
  import PageLoading from '$lib/components/ui/PageLoading.svelte';

  export let data;

  // SvelteKit provides loading state through the page store
  $: isLoading = !data.items;
</script>

{#if isLoading}
  <PageLoading title="Carregando fluxogramas..." />
{:else}
  <!-- Page content -->
{/if}
```

### 8.4 Splash Screen (Initial Load)

Create `src/lib/components/layout/SplashScreen.svelte`:

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { fade } from 'svelte/transition';

  let visible = true;

  onMount(() => {
    // Hide splash after initial render
    const timeout = setTimeout(() => {
      visible = false;
    }, 500);

    return () => clearTimeout(timeout);
  });
</script>

{#if visible}
  <div
    class="fixed inset-0 z-[200] flex items-center justify-center bg-background"
    out:fade={{ duration: 300 }}
  >
    <div class="text-center">
      <img src="/logo.svg" alt="NoFluxo" class="mx-auto h-16 w-16 animate-pulse" />
      <p class="mt-4 text-lg font-medium text-primary">NoFluxo</p>
      <p class="text-sm text-muted-foreground">Carregando...</p>
    </div>
  </div>
{/if}
```

### 8.5 Streaming with Await Blocks

For pages with slow data fetching:

```svelte
<script lang="ts">
  import { Skeleton } from '$lib/components/ui/skeleton';

  export let data;
</script>

<div>
  <h1>Dashboard</h1>

  <!-- Streamed data with loading state -->
  {#await data.streamed.fluxogramas}
    <div class="grid gap-4">
      {#each Array(3) as _}
        <Skeleton class="h-32 w-full" />
      {/each}
    </div>
  {:then fluxogramas}
    <div class="grid gap-4">
      {#each fluxogramas as item}
        <div class="rounded-lg border p-4">{item.name}</div>
      {/each}
    </div>
  {:catch error}
    <p class="text-destructive">Erro ao carregar: {error.message}</p>
  {/await}
</div>
```

---

## 9. Navigation

### 9.1 Programmatic Navigation

```typescript
// Using goto() for programmatic navigation
import { goto } from '$app/navigation';
import { ROUTES } from '$lib/config/routes';

// Simple navigation
await goto(ROUTES.LOGIN);

// With options
await goto('/fluxogramas', {
  replaceState: true,      // Replace history entry
  noScroll: true,          // Don't scroll to top
  keepFocus: true,         // Keep current focus
  invalidateAll: true,     // Invalidate all load functions
});

// Dynamic route
const courseName = 'engenharia-de-software';
await goto(ROUTES.meuFluxograma(courseName));

// With query parameters
await goto(`/login?redirectTo=${encodeURIComponent(currentPath)}`);
```

### 9.2 Navigation After Form Submit

```svelte
<script lang="ts">
  import { goto } from '$app/navigation';
  import { enhance } from '$app/forms';

  function handleSuccess() {
    goto('/dashboard');
  }
</script>

<form
  method="POST"
  use:enhance={() => {
    return async ({ result, update }) => {
      if (result.type === 'redirect') {
        goto(result.location);
      } else if (result.type === 'success') {
        handleSuccess();
      } else {
        await update();
      }
    };
  }}
>
  <!-- form fields -->
</form>
```

### 9.3 Navigation Store

Create `src/lib/stores/navigation.ts`:

```typescript
import { writable, derived, get } from 'svelte/store';
import { page } from '$app/stores';
import { goto } from '$app/navigation';
import { ROUTES, PUBLIC_ROUTES } from '$lib/config/routes';

// Navigation history tracking
function createNavigationStore() {
  const history = writable<string[]>([]);

  return {
    subscribe: history.subscribe,

    push(path: string) {
      history.update((h) => [...h.slice(-9), path]); // Keep last 10
    },

    canGoBack: derived(history, ($history) => $history.length > 1),

    goBack() {
      const currentHistory = get(history);
      if (currentHistory.length > 1) {
        const previousPath = currentHistory[currentHistory.length - 2];
        history.update((h) => h.slice(0, -1));
        goto(previousPath);
      } else {
        goto(ROUTES.HOME);
      }
    },

    clear() {
      history.set([]);
    },
  };
}

export const navigationStore = createNavigationStore();

// Breadcrumb generation
export function getBreadcrumbs(pathname: string): Array<{ label: string; href: string }> {
  const segments = pathname.split('/').filter(Boolean);
  const breadcrumbs: Array<{ label: string; href: string }> = [
    { label: 'Início', href: '/' },
  ];

  let currentPath = '';
  for (const segment of segments) {
    currentPath += `/${segment}`;

    // Skip route groups
    if (segment.startsWith('(') && segment.endsWith(')')) continue;

    // Human-readable labels
    const labels: Record<string, string> = {
      assistente: 'Assistente',
      'upload-historico': 'Importar Histórico',
      fluxogramas: 'Fluxogramas',
      'meu-fluxograma': 'Meu Fluxograma',
      login: 'Login',
      signup: 'Criar Conta',
    };

    breadcrumbs.push({
      label: labels[segment] || decodeURIComponent(segment),
      href: currentPath,
    });
  }

  return breadcrumbs;
}
```

### 9.4 Breadcrumb Component

Create `src/lib/components/layout/Breadcrumbs.svelte`:

```svelte
<script lang="ts">
  import { page } from '$app/stores';
  import { getBreadcrumbs } from '$lib/stores/navigation';
  import { ChevronRight, Home } from 'lucide-svelte';

  $: breadcrumbs = getBreadcrumbs($page.url.pathname);
</script>

{#if breadcrumbs.length > 1}
  <nav class="mb-4" aria-label="Breadcrumb">
    <ol class="flex items-center space-x-2 text-sm">
      {#each breadcrumbs as crumb, i}
        <li class="flex items-center">
          {#if i > 0}
            <ChevronRight class="mx-2 h-4 w-4 text-muted-foreground" />
          {/if}

          {#if i === breadcrumbs.length - 1}
            <span class="font-medium text-foreground">{crumb.label}</span>
          {:else}
            <a
              href={crumb.href}
              class="text-muted-foreground transition-colors hover:text-foreground"
            >
              {#if i === 0}
                <Home class="h-4 w-4" />
                <span class="sr-only">{crumb.label}</span>
              {:else}
                {crumb.label}
              {/if}
            </a>
          {/if}
        </li>
      {/each}
    </ol>
  </nav>
{/if}
```

### 9.5 Link Prefetching

SvelteKit automatically prefetches links on hover. Configure in `svelte.config.js`:

```javascript
const config = {
  kit: {
    prerender: {
      handleHttpError: 'warn',
    },
  },
};
```

Control per-link prefetching:

```svelte
<!-- Disable prefetching for this link -->
<a href="/heavy-page" data-sveltekit-preload-data="off">
  Heavy Page
</a>

<!-- Prefetch on tap (mobile) -->
<a href="/quick-page" data-sveltekit-preload-data="tap">
  Quick Page
</a>
```

---

## 10. SEO and Meta Tags

### 10.1 Page-Level SEO

For each page, add SEO in `+page.ts` and `+page.svelte`:

```typescript
// src/routes/(protected)/fluxogramas/+page.ts
import type { PageLoad } from './$types';

export const load: PageLoad = async () => {
  return {
    meta: {
      title: 'Fluxogramas',
      description: 'Visualize e gerencie todos os fluxogramas disponíveis na UnB.',
    },
  };
};
```

```svelte
<!-- src/routes/(protected)/fluxogramas/+page.svelte -->
<script lang="ts">
  export let data;
</script>

<svelte:head>
  <title>{data.meta.title} | NoFluxo UNB</title>
  <meta name="description" content={data.meta.description} />

  <!-- Open Graph -->
  <meta property="og:title" content={data.meta.title} />
  <meta property="og:description" content={data.meta.description} />
  <meta property="og:type" content="website" />
  <meta property="og:image" content="/og-image.png" />

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content={data.meta.title} />
  <meta name="twitter:description" content={data.meta.description} />
</svelte:head>

<!-- Page content -->
```

### 10.2 Dynamic SEO Component

Create `src/lib/components/seo/PageMeta.svelte`:

```svelte
<script lang="ts">
  import { page } from '$app/stores';

  export let title: string;
  export let description: string = '';
  export let image: string = '/og-image.png';
  export let noIndex: boolean = false;
  export let type: 'website' | 'article' = 'website';

  const siteName = 'NoFluxo UNB';
  const siteUrl = 'https://nofluxo.unb.br';

  $: fullTitle = title ? `${title} | ${siteName}` : siteName;
  $: canonicalUrl = `${siteUrl}${$page.url.pathname}`;
  $: imageUrl = image.startsWith('http') ? image : `${siteUrl}${image}`;
</script>

<svelte:head>
  <title>{fullTitle}</title>
  <meta name="description" content={description} />
  <link rel="canonical" href={canonicalUrl} />

  {#if noIndex}
    <meta name="robots" content="noindex, nofollow" />
  {/if}

  <!-- Open Graph -->
  <meta property="og:site_name" content={siteName} />
  <meta property="og:title" content={title} />
  <meta property="og:description" content={description} />
  <meta property="og:type" content={type} />
  <meta property="og:url" content={canonicalUrl} />
  <meta property="og:image" content={imageUrl} />
  <meta property="og:locale" content="pt_BR" />

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content={title} />
  <meta name="twitter:description" content={description} />
  <meta name="twitter:image" content={imageUrl} />

  <!-- Additional Meta -->
  <meta name="theme-color" content="#7c3aed" />
  <meta name="application-name" content={siteName} />
</svelte:head>
```

Usage:

```svelte
<script lang="ts">
  import PageMeta from '$lib/components/seo/PageMeta.svelte';
</script>

<PageMeta
  title="Meu Fluxograma"
  description="Visualize e gerencie seu progresso acadêmico na UnB"
/>
```

### 10.3 Structured Data (JSON-LD)

Create `src/lib/components/seo/JsonLd.svelte`:

```svelte
<script lang="ts">
  export let data: Record<string, any>;
</script>

<svelte:head>
  {@html `<script type="application/ld+json">${JSON.stringify(data)}</script>`}
</svelte:head>
```

Usage for organization:

```svelte
<script lang="ts">
  import JsonLd from '$lib/components/seo/JsonLd.svelte';

  const organizationData = {
    '@context': 'https://schema.org',
    '@type': 'EducationalOrganization',
    name: 'NoFluxo UNB',
    description: 'Plataforma de gerenciamento de fluxograma acadêmico',
    url: 'https://nofluxo.unb.br',
    logo: 'https://nofluxo.unb.br/logo.png',
    sameAs: ['https://github.com/nofluxo-unb'],
  };
</script>

<JsonLd data={organizationData} />
```

### 10.4 Sitemap Generation

Create `src/routes/sitemap.xml/+server.ts`:

```typescript
import type { RequestHandler } from './$types';

const siteUrl = 'https://nofluxo.unb.br';

// Public routes for sitemap
const staticRoutes = ['/', '/login', '/signup', '/password-recovery'];

export const GET: RequestHandler = async () => {
  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  ${staticRoutes
    .map(
      (route) => `
  <url>
    <loc>${siteUrl}${route}</loc>
    <lastmod>${new Date().toISOString().split('T')[0]}</lastmod>
    <changefreq>weekly</changefreq>
    <priority>${route === '/' ? '1.0' : '0.8'}</priority>
  </url>`
    )
    .join('')}
</urlset>`;

  return new Response(sitemap.trim(), {
    headers: {
      'Content-Type': 'application/xml',
      'Cache-Control': 'max-age=3600',
    },
  });
};
```

### 10.5 robots.txt

Create `static/robots.txt`:

```
User-agent: *
Disallow: /api/
Disallow: /upload-historico
Disallow: /meu-fluxograma

Sitemap: https://nofluxo.unb.br/sitemap.xml
```

---

## Summary: Migration Checklist

### Route Migration Status

> **Note:** Route groups `(auth)` and `(protected)` were **not used** in the final implementation. Auth protection is handled via `hooks.server.ts` (server-side) and `authGuard.ts` (client-side) instead. Routes use a flat structure.

| Flutter Route | SvelteKit Path | Status |
|---------------|----------------|--------|
| `/`, `/home` | `src/routes/+page.svelte` | ✅ |
| `/login` | `src/routes/login/+page.svelte` | ✅ |
| `/signup` | `src/routes/signup/+page.svelte` | ✅ |
| `/password-recovery` | `src/routes/password-recovery/+page.svelte` | ✅ |
| `/login-anonimo` | `src/routes/login-anonimo/+page.svelte` | ✅ |
| `/assistente` | `src/routes/assistente/+page.svelte` | ✅ (stub) |
| `/upload-historico` | `src/routes/upload-historico/+page.svelte` | ✅ (stub) |
| `/fluxogramas` | `src/routes/fluxogramas/+page.svelte` | ✅ (stub) |
| `/meu-fluxograma` | `src/routes/meu-fluxograma/+page.svelte` | ✅ (stub) |
| `/meu-fluxograma/:courseName` | `src/routes/meu-fluxograma/[courseName]/+page.svelte` | ✅ (stub) |

### Layout Components Status

| Component | Location | Status |
|-----------|----------|--------|
| Root Layout | `src/routes/+layout.svelte` | ✅ |
| Auth Layout | N/A (visibility handled in root layout) | ✅ |
| Protected Layout | N/A (auth guard in hooks.server.ts) | ✅ |
| Navbar | `src/lib/components/layout/Navbar.svelte` | ✅ |
| Sidebar | `src/lib/components/layout/Sidebar.svelte` | ✅ |
| Footer | `src/lib/components/layout/Footer.svelte` | ✅ |
| Error Page | `src/routes/+error.svelte` | ✅ |
| Loading Bar | `src/lib/components/layout/LoadingBar.svelte` | ✅ |
| Breadcrumbs | `src/lib/components/layout/Breadcrumbs.svelte` | ✅ |
| SplashScreen | `src/lib/components/layout/SplashScreen.svelte` | ✅ |
| PageLoading | `src/lib/components/layout/PageLoading.svelte` | ✅ |
| PageMeta (SEO) | `src/lib/components/seo/PageMeta.svelte` | ✅ |
| JsonLd (SEO) | `src/lib/components/seo/JsonLd.svelte` | ✅ |
| Route Constants | `src/lib/config/routes.ts` | ✅ |
| Navigation Store | `src/lib/stores/navigation.ts` | ✅ |
| Sitemap | `src/routes/sitemap.xml/+server.ts` | ✅ |
| robots.txt | `static/robots.txt` | ✅ |
| /home redirect | `src/routes/home/+page.server.ts` | ✅ |

### Key Differences Summary

| Aspect | Flutter (go_router) | SvelteKit |
|--------|---------------------|-----------|
| Route definition | Code-based `GoRoute()` | File-based `+page.svelte` |
| Route guards | `redirect` callback | `+layout.server.ts` |
| Layouts | `ShellRoute` | `+layout.svelte` |
| Dynamic params | `:param` | `[param]` |
| Navigation | `context.go()` | `goto()` |
| Error handling | `errorBuilder` | `+error.svelte` |
| Route groups | Manual | `(groupName)` folders |
| Loading state | `RouterWidget` | `$navigating` store |

---

## Implementation Notes

### Completed (February 2026)

All items in this plan have been implemented:

1. ✅ Route folder structure created (flat routes, no route groups)
2. ✅ Root layout with Navbar, Footer, LoadingBar, and Toaster
3. ✅ Auth protection via `hooks.server.ts` + `authGuard.ts` (no route group layouts)
4. ✅ All page stubs created with SEO meta tags
5. ✅ Global error page with localized messages
6. ✅ Loading bar, splash screen, and page loading skeleton
7. ✅ Route constants, navigation store, breadcrumbs
8. ✅ SEO utilities (PageMeta, JsonLd, sitemap.xml, robots.txt)
9. ✅ `/home` → `/` redirect
10. ✅ PostCSS config fixed for Tailwind v4 (`@tailwindcss/postcss`)

### Architectural Decisions

- **No route groups**: Instead of `(auth)` and `(protected)` file-based groups, auth protection is handled at the server hooks level and client-side guard. This was chosen because auth pages already existed in flat structure.
- **Navbar visibility**: Controlled by `$derived` in root layout based on `isAuthRoute()` check.
- **Protected pages**: Stub pages created for assistente, upload-historico, fluxogramas, meu-fluxograma. Full implementations will be done in their respective plan phases.
- **Svelte 5**: All components use runes syntax (`$props()`, `$state()`, `$derived()`, `$effect()`).

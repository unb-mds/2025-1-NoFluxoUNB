# 01 - Project Setup: Flutter to SvelteKit Migration

> **NoFluxo UNB** - SvelteKit 2.x Migration Guide

This document provides a complete step-by-step guide to set up the SvelteKit project with shadcn-svelte, Tailwind CSS, TypeScript, and Supabase.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Project Initialization](#2-project-initialization)
3. [shadcn-svelte Installation](#3-shadcn-svelte-installation)
4. [Tailwind CSS Configuration](#4-tailwind-css-configuration)
5. [TypeScript Configuration](#5-typescript-configuration)
6. [Supabase Client Setup](#6-supabase-client-setup)
7. [Environment Variables](#7-environment-variables)
8. [Project Structure](#8-project-structure)
9. [Package.json Scripts](#9-packagejson-scripts)
10. [VSCode Extensions](#10-vscode-extensions)

---

## 1. Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Node.js | 20.x LTS or later | [nodejs.org](https://nodejs.org) |
| pnpm | 9.x | `npm install -g pnpm` |
| Git | 2.x | [git-scm.com](https://git-scm.com) |
| VS Code | Latest | [code.visualstudio.com](https://code.visualstudio.com) |

### Verify Installation

```bash
# Check Node.js version (should be 20.x+)
node --version

# Check pnpm version
pnpm --version

# Check Git version
git --version
```

### Why pnpm?

- Faster than npm and yarn
- Efficient disk space usage via content-addressable storage
- Strict dependency resolution prevents phantom dependencies
- Native monorepo support
- Recommended by shadcn-svelte

---

## 2. Project Initialization

### Step 1: Create SvelteKit Project

```bash
# Navigate to project root
cd /Users/otaviomaya/Documents/GitHub/2025-1-NoFluxoUNB-2

# Create new SvelteKit project (replacing the old Rollup-based setup)
pnpm create svelte@latest no_fluxo_frontend_svelte_new

# When prompted, select:
# ✔ Which Svelte app template? › Skeleton project
# ✔ Add type checking with TypeScript? › Yes, using TypeScript syntax
# ✔ Select additional options:
#   ◉ Add ESLint for code linting
#   ◉ Add Prettier for code formatting
#   ◉ Add Playwright for browser testing
#   ◉ Add Vitest for unit testing
```

### Step 2: Navigate and Install Dependencies

```bash
cd no_fluxo_frontend_svelte_new
pnpm install
```

### Step 3: Verify Installation

```bash
# Start development server
pnpm dev

# Open http://localhost:5173 in browser
```

### Step 4: Initial Commit

```bash
git init
git add .
git commit -m "chore: initialize SvelteKit 2.x project"
```

---

## 3. shadcn-svelte Installation

### Step 1: Install shadcn-svelte CLI

```bash
pnpm dlx shadcn-svelte@latest init
```

### Step 2: Configuration Prompts

When running the init command, you'll be prompted with these options:

```
✔ Which style would you like to use? › Default
✔ Which color would you like to use as base color? › Violet
✔ Where is your global CSS file? › src/app.css
✔ Where is your tailwind.config.[cjs|js|ts] located? › tailwind.config.ts
✔ Configure the import alias for components: › $lib/components
✔ Configure the import alias for utils: › $lib/utils
✔ Are you using CSS variables for colors? › yes
```

### Step 3: Install Essential Components

```bash
# Install core UI components
pnpm dlx shadcn-svelte@latest add button
pnpm dlx shadcn-svelte@latest add card
pnpm dlx shadcn-svelte@latest add input
pnpm dlx shadcn-svelte@latest add label
pnpm dlx shadcn-svelte@latest add badge
pnpm dlx shadcn-svelte@latest add dialog
pnpm dlx shadcn-svelte@latest add dropdown-menu
pnpm dlx shadcn-svelte@latest add avatar
pnpm dlx shadcn-svelte@latest add skeleton
pnpm dlx shadcn-svelte@latest add toast
pnpm dlx shadcn-svelte@latest add tooltip
pnpm dlx shadcn-svelte@latest add separator
pnpm dlx shadcn-svelte@latest add scroll-area
pnpm dlx shadcn-svelte@latest add sheet
pnpm dlx shadcn-svelte@latest add tabs

# Or install all at once
pnpm dlx shadcn-svelte@latest add button card input label badge dialog dropdown-menu avatar skeleton toast tooltip separator scroll-area sheet tabs
```

### Step 4: Verify Component Installation

Components will be added to `src/lib/components/ui/`. Check the structure:

```
src/lib/components/ui/
├── button/
│   ├── button.svelte
│   └── index.ts
├── card/
│   ├── card.svelte
│   ├── card-content.svelte
│   ├── card-description.svelte
│   ├── card-footer.svelte
│   ├── card-header.svelte
│   ├── card-title.svelte
│   └── index.ts
└── ...
```

### Components.json Reference

After initialization, a `components.json` file will be created:

```json
{
  "$schema": "https://shadcn-svelte.com/schema.json",
  "style": "default",
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "src/app.css",
    "baseColor": "violet"
  },
  "aliases": {
    "components": "$lib/components",
    "utils": "$lib/utils"
  },
  "typescript": true
}
```

---

## 4. Tailwind CSS Configuration

### Complete tailwind.config.ts

This configuration maps the Flutter `AppColors` to Tailwind CSS custom colors:

```typescript
// tailwind.config.ts
import { fontFamily } from 'tailwindcss/defaultTheme';
import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: ['class'],
  content: ['./src/**/*.{html,js,svelte,ts}'],
  safelist: ['dark'],
  theme: {
    container: {
      center: true,
      padding: '2rem',
      screens: {
        '2xl': '1400px'
      }
    },
    extend: {
      // Custom colors matching Flutter AppColors
      colors: {
        // Base colors from shadcn-svelte (CSS variables)
        border: 'hsl(var(--border) / <alpha-value>)',
        input: 'hsl(var(--input) / <alpha-value>)',
        ring: 'hsl(var(--ring) / <alpha-value>)',
        background: 'hsl(var(--background) / <alpha-value>)',
        foreground: 'hsl(var(--foreground) / <alpha-value>)',
        primary: {
          DEFAULT: 'hsl(var(--primary) / <alpha-value>)',
          foreground: 'hsl(var(--primary-foreground) / <alpha-value>)'
        },
        secondary: {
          DEFAULT: 'hsl(var(--secondary) / <alpha-value>)',
          foreground: 'hsl(var(--secondary-foreground) / <alpha-value>)'
        },
        destructive: {
          DEFAULT: 'hsl(var(--destructive) / <alpha-value>)',
          foreground: 'hsl(var(--destructive-foreground) / <alpha-value>)'
        },
        muted: {
          DEFAULT: 'hsl(var(--muted) / <alpha-value>)',
          foreground: 'hsl(var(--muted-foreground) / <alpha-value>)'
        },
        accent: {
          DEFAULT: 'hsl(var(--accent) / <alpha-value>)',
          foreground: 'hsl(var(--accent-foreground) / <alpha-value>)'
        },
        popover: {
          DEFAULT: 'hsl(var(--popover) / <alpha-value>)',
          foreground: 'hsl(var(--popover-foreground) / <alpha-value>)'
        },
        card: {
          DEFAULT: 'hsl(var(--card) / <alpha-value>)',
          foreground: 'hsl(var(--card-foreground) / <alpha-value>)'
        },

        // NoFluxo Custom Colors (from Flutter AppColors)
        nofluxo: {
          // Primary colors
          'primary': '#6C63FF',
          'primary-dark': '#5A52D5',
          'purple': '#9C27B0',
          'pink': '#E91E63',
          'yellow': '#FFC107',

          // Neutral colors
          'black': '#000000',
          'white': '#FFFFFF',
          'gray': '#9E9E9E',
          'dark-gray': '#424242',

          // Dialog/Modal background
          'dialog': '#1A1A1A',

          // Course Card - Completed Subject
          'completed-start': 'rgb(45, 192, 99)',
          'completed-end': 'rgb(11, 125, 53)',

          // Course Card - Current Subject
          'current-start': '#A78BFA',
          'current-end': '#8B5CF6',

          // Course Card - Selected Subject
          'selected-start': '#FB7185',
          'selected-end': '#E11D48',

          // Course Card - Optative Subject
          'optative-start': '#3B82F6',
          'optative-end': '#1D4ED8',

          // Course Card - Ready Subject (prerequisites done)
          'ready-start': '#F59E0B',
          'ready-end': '#D97706',

          // Splash screen gradients
          'splash-light-1': '#E0EAFC',
          'splash-light-2': '#CFDEF3',
          'splash-purple': '#9333EA',
          'splash-rose': '#E11D48',
          'splash-orange': '#EA580C',
          'splash-amber': '#CA8A04',
          'splash-teal': '#43CEA2',
          'splash-coral': '#FF5E62',
          'splash-gold': '#F9D423',
          'splash-violet': '#8E44AD',
          'splash-cyan': '#36D1C4'
        }
      },

      // Custom border radius
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
        'cta': '30px' // From GradientCTAButton borderRadius
      },

      // Custom font families
      fontFamily: {
        sans: ['Poppins', ...fontFamily.sans],
        poppins: ['Poppins', 'sans-serif']
      },

      // Custom keyframes for animations
      keyframes: {
        'accordion-down': {
          from: { height: '0' },
          to: { height: 'var(--bits-accordion-content-height)' }
        },
        'accordion-up': {
          from: { height: 'var(--bits-accordion-content-height)' },
          to: { height: '0' }
        },
        'caret-blink': {
          '0%,70%,100%': { opacity: '1' },
          '20%,50%': { opacity: '0' }
        },
        'gradient-shift': {
          '0%, 100%': { backgroundPosition: '0% 50%' },
          '50%': { backgroundPosition: '100% 50%' }
        },
        'pulse-scale': {
          '0%, 100%': { transform: 'scale(1)' },
          '50%': { transform: 'scale(1.05)' }
        },
        'fade-in': {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' }
        },
        'slide-up': {
          '0%': { transform: 'translateY(20px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' }
        }
      },

      // Custom animations
      animation: {
        'accordion-down': 'accordion-down 0.2s ease-out',
        'accordion-up': 'accordion-up 0.2s ease-out',
        'caret-blink': 'caret-blink 1.25s ease-out infinite',
        'gradient-shift': 'gradient-shift 3s ease infinite',
        'pulse-scale': 'pulse-scale 2s ease-in-out infinite',
        'fade-in': 'fade-in 0.3s ease-out',
        'slide-up': 'slide-up 0.4s ease-out'
      },

      // Custom background gradients
      backgroundImage: {
        // Primary gradient (purple to pink)
        'gradient-primary': 'linear-gradient(to right, #9C27B0, #E91E63)',
        
        // Course card gradients
        'gradient-completed': 'linear-gradient(to right, rgb(45, 192, 99), rgb(11, 125, 53))',
        'gradient-current': 'linear-gradient(to right, #A78BFA, #8B5CF6)',
        'gradient-selected': 'linear-gradient(to right, #FB7185, #E11D48)',
        'gradient-optative': 'linear-gradient(to right, #3B82F6, #1D4ED8)',
        'gradient-ready': 'linear-gradient(to right, #F59E0B, #D97706)',
        
        // Splash gradients
        'gradient-splash-light': 'linear-gradient(to bottom, #E0EAFC, #CFDEF3)',
        'gradient-splash-colorful': 'linear-gradient(to right, #9333EA, #E11D48, #EA580C, #CA8A04, #000000)',
        
        // Dark background gradient
        'gradient-dark': 'linear-gradient(to bottom, #1A1A1A, #000000)'
      },

      // Box shadows
      boxShadow: {
        'card': '0 4px 6px -1px rgba(0, 0, 0, 0.3)',
        'card-hover': '0 10px 15px -3px rgba(0, 0, 0, 0.4)',
        'glow-purple': '0 0 20px rgba(156, 39, 176, 0.5)',
        'glow-pink': '0 0 20px rgba(233, 30, 99, 0.5)'
      }
    }
  },
  plugins: [
    require('tailwindcss-animate'),
    require('@tailwindcss/typography')
  ]
};

export default config;
```

### Install Required Tailwind Plugins

```bash
pnpm add -D tailwindcss-animate @tailwindcss/typography
```

### Global CSS (src/app.css)

```css
/* src/app.css */
@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap');

@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 240 10% 3.9%;
    --card: 0 0% 100%;
    --card-foreground: 240 10% 3.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 240 10% 3.9%;
    --primary: 262.1 83.3% 57.8%;
    --primary-foreground: 0 0% 100%;
    --secondary: 240 4.8% 95.9%;
    --secondary-foreground: 240 5.9% 10%;
    --muted: 240 4.8% 95.9%;
    --muted-foreground: 240 3.8% 46.1%;
    --accent: 240 4.8% 95.9%;
    --accent-foreground: 240 5.9% 10%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 0 0% 98%;
    --border: 240 5.9% 90%;
    --input: 240 5.9% 90%;
    --ring: 262.1 83.3% 57.8%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 240 10% 3.9%;
    --foreground: 0 0% 98%;
    --card: 240 10% 3.9%;
    --card-foreground: 0 0% 98%;
    --popover: 240 10% 3.9%;
    --popover-foreground: 0 0% 98%;
    --primary: 263.4 70% 50.4%;
    --primary-foreground: 0 0% 100%;
    --secondary: 240 3.7% 15.9%;
    --secondary-foreground: 0 0% 98%;
    --muted: 240 3.7% 15.9%;
    --muted-foreground: 240 5% 64.9%;
    --accent: 240 3.7% 15.9%;
    --accent-foreground: 0 0% 98%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 0 0% 98%;
    --border: 240 3.7% 15.9%;
    --input: 240 3.7% 15.9%;
    --ring: 263.4 70% 50.4%;
  }
}

@layer base {
  * {
    @apply border-border;
  }

  body {
    @apply bg-background text-foreground font-poppins;
    font-feature-settings: "rlig" 1, "calt" 1;
  }

  /* Smooth scrolling */
  html {
    scroll-behavior: smooth;
  }

  /* Selection styling */
  ::selection {
    @apply bg-primary/20 text-foreground;
  }
}

@layer components {
  /* NoFluxo specific component styles */
  
  /* Gradient CTA Button (from Flutter) */
  .btn-gradient-cta {
    @apply bg-gradient-primary text-white font-bold py-3 px-6 rounded-cta 
           transition-transform duration-200 ease-in-out 
           hover:scale-105 active:scale-95
           min-w-[260px] text-center;
  }

  /* Course Card base styles */
  .course-card {
    @apply rounded-lg p-4 transition-all duration-200 
           shadow-card hover:shadow-card-hover;
  }

  .course-card-completed {
    @apply course-card bg-gradient-completed text-white;
  }

  .course-card-current {
    @apply course-card bg-gradient-current text-white;
  }

  .course-card-selected {
    @apply course-card bg-gradient-selected text-white;
  }

  .course-card-optative {
    @apply course-card bg-gradient-optative text-white;
  }

  .course-card-ready {
    @apply course-card bg-gradient-ready text-white;
  }

  .course-card-future {
    @apply course-card bg-white/10 text-white/70 border border-white/20;
  }

  /* Gradient underline effect */
  .gradient-underline {
    @apply relative;
  }

  .gradient-underline::after {
    content: '';
    @apply absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-primary 
           transition-all duration-300 ease-out;
  }

  .gradient-underline:hover::after {
    @apply w-full;
  }

  /* Glass morphism effect */
  .glass {
    @apply bg-white/10 backdrop-blur-md border border-white/20;
  }

  /* Dark container */
  .container-dark {
    @apply bg-black/20 rounded-lg;
  }
}

@layer utilities {
  /* Hide scrollbar but keep functionality */
  .scrollbar-hide {
    -ms-overflow-style: none;
    scrollbar-width: none;
  }

  .scrollbar-hide::-webkit-scrollbar {
    display: none;
  }

  /* Text gradient */
  .text-gradient {
    @apply bg-gradient-primary bg-clip-text text-transparent;
  }

  /* Animated gradient background */
  .animate-gradient {
    background-size: 200% 200%;
    @apply animate-gradient-shift;
  }
}
```

---

## 5. TypeScript Configuration

### tsconfig.json

```json
{
  "extends": "./.svelte-kit/tsconfig.json",
  "compilerOptions": {
    "allowJs": true,
    "checkJs": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "sourceMap": true,
    "strict": true,
    "moduleResolution": "bundler",
    "target": "ES2022",
    "module": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "types": ["vitest/globals"],
    
    // Path aliases (SvelteKit default)
    "paths": {
      "$lib": ["./src/lib"],
      "$lib/*": ["./src/lib/*"],
      "$components": ["./src/lib/components"],
      "$components/*": ["./src/lib/components/*"]
    },

    // Strict type checking
    "noImplicitAny": true,
    "noImplicitReturns": true,
    "noImplicitThis": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "strictBindCallApply": true,
    "strictPropertyInitialization": true,
    "useUnknownInCatchVariables": true,

    // Module settings
    "verbatimModuleSyntax": true,
    "isolatedModules": true
  },
  "include": [
    ".svelte-kit/ambient.d.ts",
    ".svelte-kit/types/**/$types.d.ts",
    "src/**/*.js",
    "src/**/*.ts",
    "src/**/*.svelte",
    "tests/**/*.ts"
  ],
  "exclude": ["node_modules/*", "**/*.spec.ts"]
}
```

### Type Definitions (src/app.d.ts)

```typescript
// src/app.d.ts
// See https://kit.svelte.dev/docs/types#app

import type { Session, User } from '@supabase/supabase-js';

declare global {
  namespace App {
    interface Error {
      message: string;
      code?: string;
    }
    
    interface Locals {
      supabase: import('@supabase/supabase-js').SupabaseClient;
      safeGetSession: () => Promise<{
        session: Session | null;
        user: User | null;
      }>;
      session: Session | null;
      user: User | null;
    }
    
    interface PageData {
      session: Session | null;
      user: User | null;
    }
    
    interface PageState {}
    
    interface Platform {}
  }
}

export {};
```

---

## 6. Supabase Client Setup

### Step 1: Install Supabase Dependencies

```bash
pnpm add @supabase/supabase-js @supabase/ssr
```

### Step 2: Create Supabase Client Configuration

#### Server Client (src/lib/supabase/server.ts)

```typescript
// src/lib/supabase/server.ts
import { createServerClient } from '@supabase/ssr';
import type { RequestEvent } from '@sveltejs/kit';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

export function createSupabaseServerClient(event: RequestEvent) {
  return createServerClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
    cookies: {
      getAll: () => event.cookies.getAll(),
      setAll: (cookiesToSet) => {
        cookiesToSet.forEach(({ name, value, options }) => {
          event.cookies.set(name, value, { ...options, path: '/' });
        });
      }
    }
  });
}
```

#### Browser Client (src/lib/supabase/client.ts)

```typescript
// src/lib/supabase/client.ts
import { createBrowserClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

export function createSupabaseBrowserClient() {
  return createBrowserClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY);
}
```

### Step 3: Create Hooks (src/hooks.server.ts)

```typescript
// src/hooks.server.ts
import { createSupabaseServerClient } from '$lib/supabase/server';
import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  // Create Supabase client for this request
  event.locals.supabase = createSupabaseServerClient(event);

  // Helper function to safely get session
  event.locals.safeGetSession = async () => {
    const {
      data: { session }
    } = await event.locals.supabase.auth.getSession();

    if (!session) {
      return { session: null, user: null };
    }

    const {
      data: { user },
      error
    } = await event.locals.supabase.auth.getUser();

    if (error) {
      return { session: null, user: null };
    }

    return { session, user };
  };

  // Get session and user
  const { session, user } = await event.locals.safeGetSession();
  event.locals.session = session;
  event.locals.user = user;

  return resolve(event, {
    filterSerializedResponseHeaders(name) {
      return name === 'content-range' || name === 'x-supabase-api-version';
    }
  });
};
```

### Step 4: Root Layout (src/routes/+layout.ts)

```typescript
// src/routes/+layout.ts
import { createSupabaseBrowserClient } from '$lib/supabase/client';
import type { LayoutLoad } from './$types';

export const load: LayoutLoad = async ({ data, depends }) => {
  depends('supabase:auth');

  const supabase = createSupabaseBrowserClient();

  const {
    data: { session }
  } = await supabase.auth.getSession();

  return {
    supabase,
    session,
    user: data.user
  };
};
```

### Step 5: Root Layout Server (src/routes/+layout.server.ts)

```typescript
// src/routes/+layout.server.ts
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals }) => {
  return {
    session: locals.session,
    user: locals.user
  };
};
```

### Step 6: Type-safe Database Types (Optional)

Generate types from your Supabase database:

```bash
# Install Supabase CLI
pnpm add -D supabase

# Login to Supabase
pnpm supabase login

# Generate types
pnpm supabase gen types typescript --project-id lijmhbstgdinsukovyfl > src/lib/types/database.types.ts
```

---

## 7. Environment Variables

### .env File Structure

```bash
# .env (for local development - DO NOT COMMIT)

# ============================================
# Supabase Configuration
# ============================================
PUBLIC_SUPABASE_URL=https://lijmhbstgdinsukovyfl.supabase.co
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxpam1oYnN0Z2RpbnN1a292eWZsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MzkzNzMsImV4cCI6MjA2MzQxNTM3M30.A0bqhbEOn1SdDa5s6d9xFKHXgwpDZOA-1QJpfftFoco

# Server-only keys (never expose to client)
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

# ============================================
# Application Configuration
# ============================================
PUBLIC_APP_NAME=NoFluxo UNB
PUBLIC_APP_URL=http://localhost:5173

# ============================================
# Backend API (for custom endpoints)
# ============================================
PUBLIC_API_URL=http://localhost:3001

# ============================================
# Feature Flags
# ============================================
PUBLIC_ENABLE_AI_AGENT=true
PUBLIC_ENABLE_ANALYTICS=false

# ============================================
# Development Settings
# ============================================
NODE_ENV=development
```

### .env.example (Commit this file)

```bash
# .env.example - Copy to .env and fill in values

# Supabase Configuration
PUBLIC_SUPABASE_URL=
PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Application Configuration
PUBLIC_APP_NAME=NoFluxo UNB
PUBLIC_APP_URL=http://localhost:5173

# Backend API
PUBLIC_API_URL=http://localhost:3001

# Feature Flags
PUBLIC_ENABLE_AI_AGENT=true
PUBLIC_ENABLE_ANALYTICS=false

# Environment
NODE_ENV=development
```

### Environment Type Safety (src/env.d.ts)

```typescript
// src/env.d.ts
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly PUBLIC_SUPABASE_URL: string;
  readonly PUBLIC_SUPABASE_ANON_KEY: string;
  readonly PUBLIC_APP_NAME: string;
  readonly PUBLIC_APP_URL: string;
  readonly PUBLIC_API_URL: string;
  readonly PUBLIC_ENABLE_AI_AGENT: string;
  readonly PUBLIC_ENABLE_ANALYTICS: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

### .gitignore Additions

```gitignore
# Environment files
.env
.env.local
.env.*.local
!.env.example
```

---

## 8. Project Structure

### Recommended Folder Organization

```
no_fluxo_frontend_svelte/
├── src/
│   ├── app.css                    # Global styles with Tailwind
│   ├── app.d.ts                   # App-level TypeScript declarations
│   ├── app.html                   # HTML template
│   ├── env.d.ts                   # Environment type definitions
│   ├── hooks.server.ts            # Server hooks (auth, etc.)
│   │
│   ├── lib/                       # Shared library code ($lib alias)
│   │   ├── components/
│   │   │   ├── ui/               # shadcn-svelte components
│   │   │   │   ├── button/
│   │   │   │   ├── card/
│   │   │   │   └── ...
│   │   │   │
│   │   │   ├── layout/           # Layout components
│   │   │   │   ├── Navbar.svelte
│   │   │   │   ├── Footer.svelte
│   │   │   │   ├── Sidebar.svelte
│   │   │   │   └── MobileNav.svelte
│   │   │   │
│   │   │   ├── course/           # Course-related components
│   │   │   │   ├── CourseCard.svelte
│   │   │   │   ├── CourseGrid.svelte
│   │   │   │   ├── FlowChart.svelte
│   │   │   │   └── SemesterSection.svelte
│   │   │   │
│   │   │   ├── auth/             # Authentication components
│   │   │   │   ├── LoginForm.svelte
│   │   │   │   ├── SignupForm.svelte
│   │   │   │   └── AuthGuard.svelte
│   │   │   │
│   │   │   └── shared/           # Shared/common components
│   │   │       ├── LoadingSpinner.svelte
│   │   │       ├── GradientButton.svelte
│   │   │       ├── GlassCard.svelte
│   │   │       └── AnimatedBackground.svelte
│   │   │
│   │   ├── stores/               # Svelte stores (state management)
│   │   │   ├── auth.ts           # Authentication state
│   │   │   ├── courses.ts        # Course/curriculum state
│   │   │   ├── preferences.ts    # User preferences
│   │   │   └── theme.ts          # Theme state
│   │   │
│   │   ├── supabase/             # Supabase configuration
│   │   │   ├── client.ts
│   │   │   └── server.ts
│   │   │
│   │   ├── services/             # API/business logic services
│   │   │   ├── auth.service.ts
│   │   │   ├── course.service.ts
│   │   │   ├── equivalence.service.ts
│   │   │   └── ai-agent.service.ts
│   │   │
│   │   ├── types/                # TypeScript type definitions
│   │   │   ├── database.types.ts # Generated Supabase types
│   │   │   ├── course.types.ts
│   │   │   ├── user.types.ts
│   │   │   └── index.ts
│   │   │
│   │   ├── utils/                # Utility functions
│   │   │   ├── cn.ts             # Class name utility (shadcn)
│   │   │   ├── format.ts         # Formatting utilities
│   │   │   ├── validation.ts     # Form validation
│   │   │   └── constants.ts      # App constants
│   │   │
│   │   └── config/               # Configuration files
│   │       ├── navigation.ts     # Navigation config
│   │       └── app.config.ts     # App configuration
│   │
│   └── routes/                   # SvelteKit routes
│       ├── +layout.svelte        # Root layout
│       ├── +layout.ts            # Root layout load
│       ├── +layout.server.ts     # Server-side layout load
│       ├── +page.svelte          # Home page
│       ├── +error.svelte         # Error page
│       │
│       ├── (auth)/               # Auth group (shared layout)
│       │   ├── +layout.svelte
│       │   ├── login/
│       │   │   └── +page.svelte
│       │   ├── signup/
│       │   │   └── +page.svelte
│       │   └── forgot-password/
│       │       └── +page.svelte
│       │
│       ├── (app)/                # App group (requires auth)
│       │   ├── +layout.svelte
│       │   ├── +layout.server.ts
│       │   ├── dashboard/
│       │   │   └── +page.svelte
│       │   ├── courses/
│       │   │   ├── +page.svelte
│       │   │   └── [id]/
│       │   │       └── +page.svelte
│       │   ├── flow/
│       │   │   └── +page.svelte
│       │   ├── equivalences/
│       │   │   └── +page.svelte
│       │   └── profile/
│       │       └── +page.svelte
│       │
│       ├── api/                  # API routes
│       │   ├── auth/
│       │   │   └── callback/
│       │   │       └── +server.ts
│       │   └── courses/
│       │       └── +server.ts
│       │
│       └── (marketing)/          # Marketing pages
│           ├── +layout.svelte
│           ├── about/
│           │   └── +page.svelte
│           └── contact/
│               └── +page.svelte
│
├── static/                       # Static assets
│   ├── favicon.png
│   ├── images/
│   │   └── logo.svg
│   └── fonts/
│
├── tests/                        # Test files
│   ├── unit/
│   └── e2e/
│
├── .env                          # Environment variables (git-ignored)
├── .env.example                  # Environment template
├── .gitignore
├── .eslintrc.cjs
├── .prettierrc
├── components.json               # shadcn-svelte config
├── package.json
├── svelte.config.js
├── tailwind.config.ts
├── tsconfig.json
├── vite.config.ts
└── README.md
```

---

## 9. Package.json Scripts

### Complete package.json

```json
{
  "name": "nofluxo-unb-svelte",
  "version": "2.0.0",
  "description": "NoFluxo UNB - SvelteKit Web Application",
  "type": "module",
  "private": true,
  "scripts": {
    "dev": "vite dev",
    "dev:host": "vite dev --host",
    "build": "vite build",
    "preview": "vite preview",
    "preview:host": "vite preview --host",
    
    "check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json",
    "check:watch": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json --watch",
    
    "lint": "eslint . --ext .js,.ts,.svelte",
    "lint:fix": "eslint . --ext .js,.ts,.svelte --fix",
    
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:ui": "vitest --ui",
    
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    
    "typecheck": "tsc --noEmit",
    
    "db:types": "supabase gen types typescript --project-id lijmhbstgdinsukovyfl > src/lib/types/database.types.ts",
    "db:push": "supabase db push",
    "db:pull": "supabase db pull",
    
    "clean": "rm -rf .svelte-kit node_modules/.vite",
    "reinstall": "rm -rf node_modules pnpm-lock.yaml && pnpm install",
    
    "prepare": "svelte-kit sync"
  },
  "devDependencies": {
    "@playwright/test": "^1.45.0",
    "@sveltejs/adapter-auto": "^3.2.0",
    "@sveltejs/kit": "^2.5.0",
    "@sveltejs/vite-plugin-svelte": "^3.1.0",
    "@tailwindcss/typography": "^0.5.13",
    "@types/node": "^20.14.0",
    "@typescript-eslint/eslint-plugin": "^7.13.0",
    "@typescript-eslint/parser": "^7.13.0",
    "@vitest/coverage-v8": "^1.6.0",
    "@vitest/ui": "^1.6.0",
    "autoprefixer": "^10.4.19",
    "eslint": "^8.57.0",
    "eslint-config-prettier": "^9.1.0",
    "eslint-plugin-svelte": "^2.40.0",
    "postcss": "^8.4.38",
    "prettier": "^3.3.2",
    "prettier-plugin-svelte": "^3.2.4",
    "prettier-plugin-tailwindcss": "^0.6.4",
    "supabase": "^1.176.0",
    "svelte": "^4.2.18",
    "svelte-check": "^3.8.0",
    "tailwindcss": "^3.4.4",
    "tailwindcss-animate": "^1.0.7",
    "tslib": "^2.6.3",
    "typescript": "^5.4.5",
    "vite": "^5.3.1",
    "vitest": "^1.6.0"
  },
  "dependencies": {
    "@supabase/ssr": "^0.4.0",
    "@supabase/supabase-js": "^2.43.0",
    "bits-ui": "^0.21.10",
    "clsx": "^2.1.1",
    "lucide-svelte": "^0.395.0",
    "mode-watcher": "^0.3.1",
    "svelte-sonner": "^0.3.24",
    "tailwind-merge": "^2.3.0",
    "tailwind-variants": "^0.2.1"
  },
  "engines": {
    "node": ">=20.0.0",
    "pnpm": ">=9.0.0"
  }
}
```

### Script Descriptions

| Script | Description |
|--------|-------------|
| `dev` | Start development server on localhost:5173 |
| `dev:host` | Start dev server accessible on network |
| `build` | Create production build |
| `preview` | Preview production build locally |
| `check` | Run Svelte type checking |
| `check:watch` | Run type checking in watch mode |
| `lint` | Run ESLint |
| `lint:fix` | Run ESLint with auto-fix |
| `format` | Format code with Prettier |
| `test` | Run unit tests once |
| `test:watch` | Run unit tests in watch mode |
| `test:coverage` | Run tests with coverage report |
| `test:e2e` | Run Playwright E2E tests |
| `typecheck` | Run TypeScript type checking |
| `db:types` | Generate Supabase TypeScript types |
| `clean` | Remove build caches |
| `reinstall` | Clean reinstall dependencies |

---

## 10. VSCode Extensions

### Recommended Extensions

Create `.vscode/extensions.json`:

```json
{
  "recommendations": [
    "svelte.svelte-vscode",
    "bradlc.vscode-tailwindcss",
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "formulahendry.auto-rename-tag",
    "christian-kohler.path-intellisense",
    "usernamehw.errorlens",
    "GitHub.copilot",
    "ms-playwright.playwright",
    "vitest.explorer",
    "csstools.postcss",
    "naumovs.color-highlight",
    "antfu.iconify",
    "antfu.vite"
  ]
}
```

### Extension Details

| Extension | ID | Purpose |
|-----------|-----|---------|
| Svelte for VS Code | `svelte.svelte-vscode` | Svelte language support, syntax highlighting, IntelliSense |
| Tailwind CSS IntelliSense | `bradlc.vscode-tailwindcss` | Tailwind class autocomplete, hover previews |
| ESLint | `dbaeumer.vscode-eslint` | JavaScript/TypeScript linting |
| Prettier | `esbenp.prettier-vscode` | Code formatting |
| Auto Rename Tag | `formulahendry.auto-rename-tag` | Auto-rename paired HTML tags |
| Path Intellisense | `christian-kohler.path-intellisense` | Path autocomplete |
| Error Lens | `usernamehw.errorlens` | Inline error display |
| GitHub Copilot | `GitHub.copilot` | AI code completion |
| Playwright | `ms-playwright.playwright` | E2E test runner |
| Vitest | `vitest.explorer` | Unit test runner |
| PostCSS | `csstools.postcss` | PostCSS syntax support |
| Color Highlight | `naumovs.color-highlight` | Color value preview |
| Iconify | `antfu.iconify` | Icon preview |
| Vite | `antfu.vite` | Vite integration |

### VSCode Settings

Create `.vscode/settings.json`:

```json
{
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit",
    "source.organizeImports": "explicit"
  },
  
  "[svelte]": {
    "editor.defaultFormatter": "svelte.svelte-vscode"
  },
  
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  
  "[json]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  
  "svelte.enable-ts-plugin": true,
  "svelte.plugin.svelte.format.enable": true,
  
  "tailwindCSS.includeLanguages": {
    "svelte": "html"
  },
  "tailwindCSS.experimental.classRegex": [
    ["cn\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)"],
    ["cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]"],
    ["clsx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)"]
  ],
  
  "files.associations": {
    "*.css": "tailwindcss"
  },
  
  "typescript.preferences.importModuleSpecifier": "non-relative",
  "typescript.tsdk": "node_modules/typescript/lib",
  
  "search.exclude": {
    "**/node_modules": true,
    "**/.svelte-kit": true,
    "**/build": true
  }
}
```

---

## Quick Start Summary

```bash
# 1. Create project
pnpm create svelte@latest no_fluxo_frontend_svelte_new
cd no_fluxo_frontend_svelte_new
pnpm install

# 2. Install shadcn-svelte
pnpm dlx shadcn-svelte@latest init

# 3. Install Tailwind plugins
pnpm add -D tailwindcss-animate @tailwindcss/typography

# 4. Install Supabase
pnpm add @supabase/supabase-js @supabase/ssr

# 5. Install additional dependencies
pnpm add lucide-svelte mode-watcher svelte-sonner

# 6. Add core components
pnpm dlx shadcn-svelte@latest add button card input label badge dialog dropdown-menu avatar skeleton toast tooltip

# 7. Create .env file
cp .env.example .env
# Edit .env with your values

# 8. Start development
pnpm dev
```

---

## Next Steps

After completing the project setup:

1. **02-LAYOUT-MIGRATION.md** - Migrate Flutter layouts to SvelteKit
2. **03-COMPONENTS-MIGRATION.md** - Convert Flutter widgets to Svelte components
3. **04-STATE-MANAGEMENT.md** - Migrate state management patterns
4. **05-ROUTING-MIGRATION.md** - Convert GoRouter to SvelteKit routing
5. **06-API-INTEGRATION.md** - Configure API calls and Supabase queries

---

*Document created: February 2026*
*Flutter source: no_fluxo_frontend (Dart/Flutter)*
*Target: SvelteKit 2.x with shadcn-svelte*

# NoFluxo Frontend Migration: Complete Implementation Guide
## Flutter to SvelteKit + shadcn-svelte

**Generated:** February 16, 2026  
**Version:** 1.0.0

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Migration Overview](#migration-overview)
3. [Current Application Analysis](#current-application-analysis)
4. [Target Architecture](#target-architecture)
5. [Implementation Phases](#implementation-phases)
6. [Detailed Plans Index](#detailed-plans-index)
7. [Quick Reference](#quick-reference)
8. [Risk Assessment](#risk-assessment)
9. [Success Criteria](#success-criteria)

---

## Executive Summary

This document serves as the master guide for migrating the NoFluxo Flutter web application to SvelteKit with shadcn-svelte. The migration encompasses 67+ Dart files across 10 major features, to be converted into a modern TypeScript/Svelte codebase.

### Key Metrics

| Metric | Flutter Source | SvelteKit Target |
|--------|---------------|------------------|
| Total Pages/Routes | 10 | 10 |
| Services | 4 | 4+ |
| Data Models | 8 | 8+ |
| UI Components | 30+ | 40+ |
| Lines of Code (est.) | ~15,000 | ~12,000 |

### Timeline Estimate

| Phase | Duration | Status |
|-------|----------|--------|
| Foundation & Setup | 1 week | ✅ Complete |
| Authentication | 1 week | ✅ Complete |
| Core Pages & UI | 1 week | ✅ Complete |
| Features (Upload, Chat) | 2 weeks | 🟡 Upload Complete, Chat Not Started |
| Fluxograma Feature | 2 weeks | ✅ Complete |
| Testing & Polish | 1 week | Not Started |
| **Total** | **8 weeks** | - |

---

## Migration Overview

### Technology Transformation

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER (CURRENT)                        │
├─────────────────────────────────────────────────────────────┤
│  Framework:     Flutter Web                                 │
│  Language:      Dart                                        │
│  Routing:       go_router                                   │
│  State:         StatefulWidget + SharedPreferences          │
│  Styling:       Material Design 3                           │
│  Auth:          Supabase Flutter SDK                        │
│  HTTP:          http package                                │
└─────────────────────────────────────────────────────────────┘
                           ↓ ↓ ↓
┌─────────────────────────────────────────────────────────────┐
│                    SVELTEKIT (TARGET)                       │
├─────────────────────────────────────────────────────────────┤
│  Framework:     SvelteKit 2.x                               │
│  Language:      TypeScript                                  │
│  Routing:       File-based routing                          │
│  State:         Svelte stores + Svelte 5 runes              │
│  Styling:       Tailwind CSS + shadcn-svelte                │
│  Auth:          Supabase SSR (@supabase/ssr)                │
│  HTTP:          Native fetch API                            │
└─────────────────────────────────────────────────────────────┘
```

### Why SvelteKit?

| Benefit | Impact |
|---------|--------|
| **Smaller Bundle** | 5-10x smaller than Flutter Web |
| **Faster Load** | No Dart runtime overhead |
| **SEO-Friendly** | Server-side rendering support |
| **Developer Experience** | Simpler reactivity model |
| **shadcn-svelte** | Accessible, customizable components |
| **TypeScript** | Type safety with better tooling |

---

## Current Application Analysis

### Route Structure

| Route | Flutter Component | Purpose |
|-------|-------------------|---------|
| `/`, `/home` | HomeScreen | Landing page |
| `/login` | AuthPage (LoginForm) | User login |
| `/signup` | AuthPage (SignupForm) | User registration |
| `/password-recovery` | PasswordRecoveryScreen | Password reset |
| `/login-anonimo` | AnonymousLoginScreen | Guest access |
| `/assistente` | AssistenteScreen | AI chat assistant |
| `/upload-historico` | UploadHistoricoScreen | PDF transcript upload |
| `/fluxogramas` | FluxogramasIndexScreen | Course selection |
| `/meu-fluxograma` | MeuFluxogramaScreen | Interactive flowchart |
| `/meu-fluxograma/:courseName` | MeuFluxogramaScreen | Course-specific flowchart |

### Services Architecture

> **⚡ ARCHITECTURE UPDATE:** 9 of 12 backend endpoints have been replaced with **direct Supabase queries + RLS** from the frontend. Only 3 endpoints (PDF parsing, discipline matching, AI assistant) remain on the backend. See [14-SUPABASE-DIRECT-RLS.md](14-SUPABASE-DIRECT-RLS.md).

```
┌──────────────────────────────────────────────────────────┐
│                      Frontend Services                    │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────────┐    ┌─────────────────┐             │
│  │   AuthService   │    │ FluxogramaService│             │
│  │  - login        │    │  - getCourseData │             │
│  │  - signup       │    │  - getMateriaData│             │
│  │  - googleOAuth  │    │  - getEquivalents│             │
│  │  - logout       │    │  - deleteFxUser  │             │
│  └────────┬────────┘    └────────┬─────────┘             │
│           │ DIRECT               │ DIRECT                │
│  ┌────────┴────────┐    ┌────────┴─────────┐             │
│  │ UploadService   │    │AssistenteService │             │
│  │  - uploadPdf ──►│BKND│  - sendMessage──►│BKND         │
│  │  - casarDisc──►│BKND│  └──────────────────┘           │
│  │  - saveToDb     │ DIRECT                              │
│  └─────────────────┘                                     │
│                                                          │
└──────────┬───────────────────────┬───────────────────────┘
           │ (9 endpoints)         │ (3 endpoints)
           ▼                       ▼
┌────────────────────┐   ┌────────────────────────────────┐
│  Supabase (Direct) │   │    Backend API (Node.js)       │
│  with RLS policies │   │    localhost:3000 (dev)         │
│  ──────────────────│   ├────────────────────────────────┤
│  users, cursos,    │   │  /fluxograma/read_pdf          │
│  materias, dados,  │   │  /fluxograma/casar_disciplinas │
│  equivalencias,    │   │  /assistente                   │
│  pre/co-requisitos │   └────────────────────────────────┘
└────────────────────┘
```

### Data Models

| Model | Fields | Usage |
|-------|--------|-------|
| **UserModel** | id, email, nomeCompleto, dadosFluxograma, token | User profile |
| **DadosMateria** | codigoMateria, mencao, professor, status | Subject grade |
| **DadosFluxogramaUser** | nomeCurso, ira, matricula, semestreAtual | User's flowchart |
| **CursoModel** | idCurso, nomeCurso, materias, equivalencias | Course structure |
| **MateriaModel** | id, codigo, nome, semestre, prerequisitos | Subject details |
| **EquivalenciaModel** | materiaOrigem, equivalentes, expressao | Equivalences |
| **PrerequisiteTree** | nodes, edges, metadata | Prerequisite graph |

---

## Target Architecture

### Project Structure

```
no_fluxo_frontend_svelte/
├── src/
│   ├── lib/
│   │   ├── components/
│   │   │   ├── ui/              # shadcn-svelte (Button, Card, Dialog...)
│   │   │   ├── layout/          # AppNavbar, Footer, Background
│   │   │   ├── home/            # HeroSection, ComoFunciona, SobreNos
│   │   │   ├── auth/            # LoginForm, SignupForm
│   │   │   ├── chat/            # ChatMessage, ChatInput, TypingIndicator
│   │   │   ├── fluxograma/      # FluxogramContainer, CourseCard, Lines
│   │   │   └── upload/          # FileDropzone, ProgressBar
│   │   │
│   │   ├── services/
│   │   │   ├── auth.ts          # Supabase auth + backend sync
│   │   │   ├── fluxograma.ts    # Course and subject data
│   │   │   ├── upload.ts        # PDF upload and processing
│   │   │   └── assistente.ts    # AI chat integration
│   │   │
│   │   ├── stores/
│   │   │   ├── auth.ts          # Auth state and session
│   │   │   ├── user.ts          # User profile data
│   │   │   ├── fluxograma.ts    # Flowchart state
│   │   │   ├── chat.ts          # Chat messages
│   │   │   └── ui.ts            # Modals, toasts, loading
│   │   │
│   │   ├── types/
│   │   │   ├── user.ts          # UserModel, DadosMateria
│   │   │   ├── curso.ts         # CursoModel, MateriaModel
│   │   │   └── api.ts           # Generic API types
│   │   │
│   │   ├── utils/
│   │   │   ├── api.ts           # Fetch wrapper
│   │   │   ├── validation.ts    # Zod schemas
│   │   │   └── format.ts        # Date, number formatters
│   │   │
│   │   └── server/
│   │       └── supabase.ts      # Server-side Supabase client
│   │
│   ├── routes/
│   │   ├── +layout.svelte       # Root layout
│   │   ├── +layout.server.ts    # Auth check on server
│   │   ├── +page.svelte         # Home page
│   │   ├── login/+page.svelte
│   │   ├── signup/+page.svelte
│   │   ├── password-recovery/+page.svelte
│   │   ├── login-anonimo/+page.svelte
│   │   ├── assistente/+page.svelte
│   │   ├── upload-historico/+page.svelte
│   │   ├── fluxogramas/+page.svelte
│   │   ├── meu-fluxograma/
│   │   │   ├── +page.svelte
│   │   │   └── [courseName]/+page.svelte
│   │   └── auth/callback/+server.ts  # OAuth callback
│   │
│   ├── app.css                  # Global styles
│   └── app.html                 # HTML template
│
├── static/
│   └── assets/                  # SVGs, images
│
├── tests/
│   ├── unit/                    # Vitest unit tests
│   ├── integration/             # API tests
│   └── e2e/                     # Playwright tests
│
├── svelte.config.js
├── tailwind.config.js
├── vite.config.ts
└── package.json
```

### Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         +layout.svelte                       │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                       AppNavbar                          ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │                         <slot />                         ││
│  │                    (route content)                       ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │                 Toaster (notifications)                  ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1)
**Document:** [01-PROJECT-SETUP.md](01-PROJECT-SETUP.md)

- [x] Initialize SvelteKit project
- [x] Install and configure shadcn-svelte
- [x] Set up Tailwind CSS with custom theme
- [x] Configure TypeScript
- [x] Set up Supabase client
- [x] Configure environment variables
- [x] Create folder structure

### Phase 2: Authentication (Week 2) ✅
**Documents:** [02-AUTHENTICATION.md](02-AUTHENTICATION.md), [08-AUTH-PAGES.md](08-AUTH-PAGES.md)

- [x] Implement auth store
- [x] Create Supabase SSR configuration
- [x] Build login page (enhanced with remember-me, validation, password strength)
- [x] Build signup page (enhanced with password requirements, terms, Google signup)
- [x] Build password recovery page (enhanced styling and UX)
- [x] Implement Google OAuth
- [x] Build anonymous login flow (enhanced with feature list)
- [x] Set up route guards
- [x] Create Zod validation schemas for auth forms
- [x] Create GoogleIcon reusable component

### Phase 3: Core UI & Pages (Week 3)
**Documents:** [03-ROUTING-LAYOUT.md](03-ROUTING-LAYOUT.md), [06-COMPONENTS-UI.md](06-COMPONENTS-UI.md), [07-HOME-PAGE.md](07-HOME-PAGE.md)

- [x] Create root layout
- [x] Build AppNavbar component
- [x] Create background components
- [x] Build loading bar and splash screen
- [x] Create route constants and navigation store
- [x] Build error pages (global + localized messages)
- [x] Create page stubs for all routes
- [x] Build SEO utilities (PageMeta, JsonLd, sitemap, robots.txt)
- [x] Build Footer component
- [x] Build Sidebar component
- [x] Build Breadcrumbs component
- [x] Set up /home redirect
- [ ] Implement home page hero (full redesign)
- [ ] Build "Como Funciona" section (detailed)
- [ ] Build "Sobre Nós" section
- [ ] Set up responsive breakpoints

### Phase 4: Services & Types (Week 3-4)
**Documents:** [04-SERVICES-API.md](04-SERVICES-API.md), [05-MODELS-TYPES.md](05-MODELS-TYPES.md), [14-SUPABASE-DIRECT-RLS.md](14-SUPABASE-DIRECT-RLS.md)

- [x] Run RLS migration SQL (enable RLS, create policies, add `auth_id` to `users`)
- [x] Define TypeScript interfaces
- [x] Implement AuthService (direct Supabase — no backend)
- [x] Implement FluxogramaService (direct Supabase — no backend)
- [x] Implement UploadService (hybrid: backend for PDF/matching, direct Supabase for save)
- [x] Implement AssistenteService (backend proxy to AI agent)
- [x] Create `apiRequest` helper for remaining backend calls
- [x] Add Zod validation schemas
- [x] Implement factory functions (snake_case ↔ camelCase conversion)
- [x] Implement type guards and assertion functions
- [x] Integrate new types into existing services and components

### Phase 5: PDF Upload (Week 4) ✅
**Documents:** [10-PDF-UPLOAD.md](10-PDF-UPLOAD.md), [12-STATE-MANAGEMENT.md](12-STATE-MANAGEMENT.md)

- [x] Build file dropzone component (drag-and-drop with validation)
- [x] Implement upload progress UI (animated gradient progress bar)
- [x] Create upload store (full state management with progress simulation)
- [x] Handle discipline matching (with course selection modal)
- [x] Build results display (stats cards, expandable discipline lists)
- [x] Implement error handling (toast notifications, retry flow)
- [x] Build help button and modal (SIGAA instructions)
- [x] Create file validation utilities
- [x] Build course selection modal
- [x] Create click-outside action

### Phase 6: AI Assistant (Week 5)
**Document:** [09-ASSISTANT-CHAT.md](09-ASSISTANT-CHAT.md)

- [ ] Build chat container
- [ ] Create message components
- [ ] Implement chat input
- [ ] Build quick tags
- [ ] Add loading animations
- [ ] Implement markdown rendering
- [x] Create chat store

### Phase 7: Fluxograma (Weeks 6-7) ✅
**Document:** [11-FLUXOGRAMA.md](11-FLUXOGRAMA.md)

- [x] Build course index page (search, filter, pagination)
- [x] Create fluxogram container with pan/zoom (drag, wheel zoom, CSS transform)
- [x] Build semester column layout
- [x] Create course card component (glass-morphism style)
- [x] Implement prerequisite SVG lines (bezier curves, arrow markers, color-coded)
- [x] Build subject details modal (tabbed: Info, Pré-requisitos, Equivalências)
- [x] Create progress summary (credits, completion %, semester info)
- [x] Build optativas modal (searchable electives list)
- [x] Implement screenshot export (html2canvas utility)
- [x] Create fluxograma store (zoom, connections, hover state)
- [x] Build FluxogramaHeader with screenshot button
- [x] Build FluxogramaLegendControls with status legend and zoom slider

### Phase 8: Testing & Polish (Week 8)
**Document:** [13-TESTING.md](13-TESTING.md)

- [ ] Set up Vitest configuration
- [ ] Write unit tests for stores
- [ ] Write component tests
- [ ] Set up Playwright
- [ ] Write E2E tests for auth flow
- [ ] Write E2E tests for upload flow
- [ ] Cross-browser testing
- [ ] Performance optimization
- [ ] Accessibility audit

---

## Detailed Plans Index

| # | Document | Description | Priority |
|---|----------|-------------|----------|
| 00 | [MIGRATION-OVERVIEW.md](00-MIGRATION-OVERVIEW.md) | Executive summary and overview | - |
| 01 | [PROJECT-SETUP.md](01-PROJECT-SETUP.md) | Initial project configuration | 🔴 Critical |
| 02 | [AUTHENTICATION.md](02-AUTHENTICATION.md) | Supabase auth implementation | 🔴 Critical |
| 03 | [ROUTING-LAYOUT.md](03-ROUTING-LAYOUT.md) | Routes and layouts | ✅ Complete |
| 04 | [SERVICES-API.md](04-SERVICES-API.md) | Backend API integration | 🔴 Critical |
| 05 | [MODELS-TYPES.md](05-MODELS-TYPES.md) | TypeScript type definitions | 🟡 High |
| 06 | [COMPONENTS-UI.md](06-COMPONENTS-UI.md) | UI component library | 🟡 High |
| 07 | [HOME-PAGE.md](07-HOME-PAGE.md) | Landing page implementation | 🟡 High |
| 08 | [AUTH-PAGES.md](08-AUTH-PAGES.md) | Login/signup pages | ✅ Complete |
| 09 | [ASSISTANT-CHAT.md](09-ASSISTANT-CHAT.md) | AI chat feature | 🟢 Medium |
| 10 | [PDF-UPLOAD.md](10-PDF-UPLOAD.md) | Transcript upload feature | ✅ Complete |
| 11 | [FLUXOGRAMA.md](11-FLUXOGRAMA.md) | Interactive flowchart | ✅ Complete |
| 12 | [STATE-MANAGEMENT.md](12-STATE-MANAGEMENT.md) | Svelte stores | 🟡 High |
| 13 | [TESTING.md](13-TESTING.md) | Testing strategy | 🟢 Medium |
| 14 | [SUPABASE-DIRECT-RLS.md](14-SUPABASE-DIRECT-RLS.md) | Direct Supabase + RLS (replaces 9 backend endpoints) | 🔴 Critical |

---

## Quick Reference

### Common Commands

```bash
# Development
pnpm dev                  # Start dev server
pnpm build                # Production build
pnpm preview              # Preview production build

# Testing
pnpm test                 # Run unit tests
pnpm test:e2e             # Run E2E tests
pnpm test:coverage        # Coverage report

# Code Quality
pnpm lint                 # ESLint
pnpm format               # Prettier
pnpm check                # Svelte check

# shadcn-svelte
pnpm dlx shadcn-svelte add button  # Add component
```

### Environment Variables

```env
# .env
PUBLIC_SUPABASE_URL=https://lijmhbstgdinsukovyfl.supabase.co
PUBLIC_SUPABASE_ANON_KEY=...
PUBLIC_API_URL=http://localhost:3000
PUBLIC_AGENT_URL=http://localhost:4652
PUBLIC_REDIRECT_URL=http://localhost:5173
```

### Key Dependencies

```json
{
  "dependencies": {
    "@supabase/supabase-js": "^2.x",
    "@supabase/ssr": "^0.x",
    "bits-ui": "latest",
    "clsx": "^2.x",
    "tailwind-merge": "^2.x",
    "lucide-svelte": "latest",
    "zod": "^3.x",
    "marked": "^12.x"
  },
  "devDependencies": {
    "@sveltejs/kit": "^2.x",
    "svelte": "^5.x",
    "tailwindcss": "^3.x",
    "typescript": "^5.x",
    "vitest": "^1.x",
    "@playwright/test": "^1.x"
  }
}
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Fluxograma complexity | High | High | Phase implementation, SVG first |
| Auth edge cases | Medium | High | Comprehensive testing |
| Performance regression | Medium | Medium | Lighthouse audits |
| Browser compatibility | Low | Medium | Cross-browser testing |
| API breaking changes | Low | High | Type-safe API layer |

---

## Success Criteria

### Functional Requirements
- [x] All 10 routes implemented and functional
- [x] Authentication works (email, Google, anonymous)
- [x] PDF upload processes correctly
- [ ] AI assistant responds properly
- [x] Fluxograma displays and is interactive
- [x] Progress tracking works

### Non-Functional Requirements
- [ ] Lighthouse Performance > 80
- [ ] Lighthouse Accessibility > 90
- [ ] First Contentful Paint < 1.5s
- [ ] Time to Interactive < 3s
- [ ] No critical accessibility issues
- [ ] Works on Chrome, Firefox, Safari, Edge

### Code Quality
- [ ] TypeScript strict mode enabled
- [ ] No type errors
- [ ] Test coverage > 70%
- [ ] All E2E critical paths passing
- [ ] No ESLint errors

---

## Appendix

### Related Documentation

- [SvelteKit Documentation](https://kit.svelte.dev/docs)
- [shadcn-svelte](https://www.shadcn-svelte.com/)
- [Supabase Auth](https://supabase.com/docs/guides/auth)
- [Tailwind CSS](https://tailwindcss.com/docs)

### Backend API Reference

> **⚡ ARCHITECTURE UPDATE:** 9 of 12 endpoints have been replaced with **direct Supabase queries + RLS** from the frontend. The table below shows the current status.

#### Endpoints Replaced by Direct Supabase (no longer called from frontend)

| Method | Old Endpoint | Replacement |
|--------|-------------|-------------|
| GET | `/users/get-user-by-email` | `supabase.from('users').select()` |
| POST | `/users/register-user-with-google` | `supabase.from('users').insert()` |
| POST | `/users/registrar-user-with-email` | `supabase.from('users').insert()` |
| GET | `/fluxograma/fluxograma` | `supabase.from('materias_por_curso').select()` + joins |
| POST | `/fluxograma/upload-dados-fluxograma` | `supabase.from('dados_users').upsert()` |
| DELETE | `/fluxograma/limpar-fluxograma-por-user` | `supabase.from('dados_users').delete()` |
| GET | `/cursos/all-cursos` | `supabase.from('cursos').select()` |
| GET | `/materias/:id` | `supabase.from('materias').select()` |
| GET | `/materias/nomes-por-codigo` | `supabase.from('materias').select('codigo, nome')` |

#### Endpoints Remaining on Backend

| Method | Endpoint | Purpose | Why Backend? |
|--------|----------|---------|-------------|
| POST | `/fluxograma/read_pdf` | Upload and parse PDF | Python microservice proxy |
| POST | `/fluxograma/casar_disciplinas` | Match disciplines | Server-side logic |
| POST | `/assistente` | AI assistant | RAGFlow agent proxy |

See [14-SUPABASE-DIRECT-RLS.md](14-SUPABASE-DIRECT-RLS.md) for full details.

---

*This document will be updated as the migration progresses.*

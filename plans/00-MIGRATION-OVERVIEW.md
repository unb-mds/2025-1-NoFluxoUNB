# NoFluxo Frontend Migration Plan: Flutter to SvelteKit + shadcn-svelte

## Executive Summary

This document outlines the comprehensive migration plan for moving the NoFluxo Flutter web application to SvelteKit with shadcn-svelte components. The migration will modernize the frontend stack while maintaining all existing functionality.

## Current Flutter Application Analysis

### Technology Stack
- **Framework**: Flutter Web
- **Routing**: go_router
- **Authentication**: Supabase (email/password, Google OAuth, anonymous)
- **State Management**: SharedPreferences + StatefulWidget local state
- **HTTP Client**: http package
- **UI**: Material Design 3 + Google Fonts (Poppins)
- **Functional Programming**: dartz (Either type)

### Route Structure

| Route | Component | Description |
|-------|-----------|-------------|
| `/`, `/home` | HomeScreen | Landing page with hero section, features, about us |
| `/login` | AuthPage (LoginForm) | Email/password login + Google OAuth |
| `/signup` | AuthPage (SignupForm) | User registration |
| `/password-recovery` | PasswordRecoveryScreen | Password reset flow |
| `/login-anonimo` | AnonymousLoginScreen | Anonymous guest access |
| `/assistente` | AssistenteScreen | AI-powered course recommendation chat |
| `/upload-historico` | UploadHistoricoScreen | Academic transcript PDF upload |
| `/fluxogramas` | FluxogramasIndexScreen | Course selection index |
| `/meu-fluxograma` | MeuFluxogramaScreen | Interactive flowchart visualization |
| `/meu-fluxograma/:courseName` | MeuFluxogramaScreen | Course-specific flowchart |

### Services Layer

> **⚡ ARCHITECTURE UPDATE:** Most service calls now use **direct Supabase queries with RLS** instead of routing through the backend API. Only 3 endpoints remain on the backend (PDF parsing, discipline matching, AI assistant). See [14-SUPABASE-DIRECT-RLS.md](14-SUPABASE-DIRECT-RLS.md) for full details.

1. **AuthService** (`lib/service/auth_service.dart`)
   - Supabase authentication integration
   - Email/password signup and login
   - Google OAuth flow
   - User database registration/lookup → **now direct Supabase insert/select**
   - Session management

2. **MeuFluxogramaService** (`lib/screens/fluxogramas/services/`)
   - Course data fetching → **now direct Supabase query**
   - Subject information retrieval → **now direct Supabase query**
   - Prerequisites management → **now direct Supabase query**
   - Equivalence checking → **now direct Supabase query**

3. **UploadHistoricoService** (`lib/screens/upload-historico/services/`)
   - PDF file upload handling → **stays on backend** (Python microservice)
   - Discipline matching/parsing → **stays on backend** (server-side logic)
   - Academic data save → **now direct Supabase upsert**

### Data Models

| Model | Location | Purpose |
|-------|----------|---------|
| UserModel | `lib/models/user_model.dart` | User profile, fluxogram data |
| DadosMateria | `lib/models/user_model.dart` | Subject grade/status data |
| DadosFluxogramaUser | `lib/models/user_model.dart` | User's flowchart data |
| CursoModel | `lib/screens/fluxogramas/data/` | Course structure |
| MateriaModel | `lib/screens/fluxogramas/data/` | Subject details |
| EquivalenciaModel | `lib/screens/fluxogramas/data/` | Subject equivalences |

### Widget/Component Inventory

**Global Components:**
- `AppNavbar` - Navigation bar with responsive mobile menu
- `AnimatedBackground` - Gradient animated background
- `GraffitiBackground` - Textured dark background
- `GlassContainer` - Glassmorphism card container
- `GradientCTAButton` - Call-to-action button with gradient
- `PremiumHoverButton` - Interactive hover button
- `AppLogo` - Logo component
- `SplashWidget` - Loading splash screen

**Home Page Sections:**
- `ComoFuncionaSection` - "How it works" feature section
- `ProntoParaOrganizarSection` - CTA section
- `SobreNosSection` - About us section

**Fluxograma Components:**
- `FluxogramaHeader` - Flowchart header
- `FluxogramaLegendControls` - Legend and zoom controls
- `FluxogramContainer` - Main flowchart wrapper
- `CourseCardWidget` - Subject card in flowchart
- `PrerequisiteConnectionsWidget` - Prerequisite line connections
- `PrerequisiteIndicatorWidget` - Prerequisite status indicator
- `ProgressSummarySection` - Academic progress stats
- `ProgressToolsSection` - Tools for managing progress
- `OptativasModal` - Elective subjects modal
- `MateriaDataDialogContent` - Subject details dialog

**Chat/Assistant Components:**
- `ChatContainer` - Chat window container
- `ChatMessage` - Individual message bubble
- `ChatInput` - Message input field
- `TypingIndicator` - Loading animation

### Key Features to Migrate

1. **Authentication System**
   - Supabase integration
   - Multiple auth providers
   - Session persistence
   - Protected routes

2. **PDF Upload & Processing**
   - File upload
   - Server-side parsing integration
   - Data extraction display

3. **Interactive Flowchart**
   - Zoom/pan controls
   - Subject selection
   - Prerequisite visualization
   - Progress tracking
   - Screenshot export

4. **AI Assistant**
   - Chat interface
   - Backend integration
   - Typing animations
   - Quick response tags

5. **Responsive Design**
   - Mobile-first approach
   - Breakpoint handling
   - Drawer navigation

---

## Target Technology Stack

### Core Stack
- **Framework**: SvelteKit 2.x
- **UI Components**: shadcn-svelte
- **Styling**: Tailwind CSS
- **Type Safety**: TypeScript
- **Authentication**: Supabase (same provider)
- **HTTP Client**: native fetch API
- **State Management**: Svelte stores

### Additional Libraries (Recommended)
- **Icons**: lucide-svelte
- **Forms**: superforms + zod
- **Charts**: Chart.js or D3 for flowchart
- **Canvas/SVG**: D3.js or Konva for interactive flowchart
- **PDF**: pdf-lib for client-side handling

---

## Migration Documents

The following detailed migration documents will be created:

| Document | Description |
|----------|-------------|
| `01-PROJECT-SETUP.md` | SvelteKit + shadcn-svelte project initialization |
| `02-AUTHENTICATION.md` | Supabase auth migration and route guards |
| `03-ROUTING-LAYOUT.md` | Route structure and layouts |
| `04-SERVICES-API.md` | API services and data fetching |
| `05-MODELS-TYPES.md` | TypeScript types and interfaces |
| `06-COMPONENTS-UI.md` | UI component library migration ✅ |
| `07-HOME-PAGE.md` | Landing page implementation ✅ |
| `08-AUTH-PAGES.md` | Login/Signup/Recovery pages |
| `09-ASSISTANT-CHAT.md` | AI assistant chat interface |
| `10-PDF-UPLOAD.md` | Academic transcript upload feature |
| `11-FLUXOGRAMA.md` | Interactive flowchart implementation |
| `12-STATE-MANAGEMENT.md` | Global state and stores |
| `13-TESTING.md` | Testing strategy and setup |
| `14-SUPABASE-DIRECT-RLS.md` | Direct Supabase + RLS migration (replaces 9 backend endpoints) |

---

## Migration Phases

### Phase 1: Foundation (Week 1)
- Project setup and configuration
- shadcn-svelte installation
- Basic routing structure
- Supabase client configuration
- TypeScript types definition

### Phase 2: Authentication (Week 2)
- Auth store and session management
- Login/Signup pages
- Password recovery
- Route guards
- Google OAuth integration

### Phase 3: Core Pages (Week 3)
- Home page with all sections
- Navigation components
- Responsive layouts
- Background effects

### Phase 4: Features (Week 4-5)
- PDF upload functionality (backend for parsing, direct Supabase for save)
- AI assistant chat (backend proxy)
- Fluxograma index page (direct Supabase queries)
- RLS migration: enable RLS policies, add `auth_id` column to `users`
- See [14-SUPABASE-DIRECT-RLS.md](14-SUPABASE-DIRECT-RLS.md)

### Phase 5: Flowchart (Week 6-7)
- Interactive flowchart canvas
- Subject cards and connections
- Prerequisites visualization
- Progress tracking
- Tools and modals

### Phase 6: Polish & Testing (Week 8)
- Cross-browser testing
- Performance optimization
- Accessibility audit
- Documentation

---

## File Structure (Target)

```
no_fluxo_frontend_svelte/
├── src/
│   ├── lib/
│   │   ├── components/
│   │   │   ├── ui/           # shadcn-svelte components
│   │   │   ├── layout/       # Header, Footer, Nav
│   │   │   ├── home/         # Home page sections
│   │   │   ├── auth/         # Auth forms
│   │   │   ├── chat/         # Assistant components
│   │   │   ├── fluxograma/   # Flowchart components
│   │   │   └── common/       # Shared components
│   │   ├── services/
│   │   │   ├── auth.ts
│   │   │   ├── fluxograma.ts
│   │   │   └── upload.ts
│   │   ├── stores/
│   │   │   ├── auth.ts
│   │   │   ├── user.ts
│   │   │   └── fluxograma.ts
│   │   ├── types/
│   │   │   ├── user.ts
│   │   │   ├── curso.ts
│   │   │   ├── materia.ts
│   │   │   └── api.ts
│   │   ├── utils/
│   │   │   ├── api.ts
│   │   │   ├── format.ts
│   │   │   └── validation.ts
│   │   └── server/
│   │       └── supabase.ts
│   ├── routes/
│   │   ├── +layout.svelte
│   │   ├── +layout.server.ts
│   │   ├── +page.svelte        # Home
│   │   ├── login/
│   │   ├── signup/
│   │   ├── password-recovery/
│   │   ├── login-anonimo/
│   │   ├── assistente/
│   │   ├── upload-historico/
│   │   ├── fluxogramas/
│   │   └── meu-fluxograma/
│   │       └── [courseName]/
│   └── app.css
├── static/
│   └── assets/
├── tailwind.config.js
├── svelte.config.js
└── package.json
```

---

## Environment Variables

```env
PUBLIC_SUPABASE_URL=https://lijmhbstgdinsukovyfl.supabase.co
PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
PUBLIC_API_URL=http://localhost:3000
PUBLIC_AGENT_URL=http://localhost:4652
PUBLIC_REDIRECT_URL=http://localhost:5173
```

---

## Next Steps

1. Review individual migration documents (01-13)
2. Set up the SvelteKit project
3. Begin implementation following the phased approach
4. Conduct testing at each phase
5. Deploy to staging environment

---

*Document generated: 2026-02-16*

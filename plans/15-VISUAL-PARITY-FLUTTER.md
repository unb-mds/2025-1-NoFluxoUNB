# 15 — Visual Parity: Match Svelte Frontend to Flutter Design

## Goal

Make the SvelteKit application visually identical to the Flutter app. This plan covers every design token, component style, animation, and layout difference identified through a full audit of both codebases.

---

## Current State Summary

| Area | Flutter | Svelte (current) | Match? |
|------|---------|-------------------|--------|
| Primary color | `#6C63FF` | `hsl(262.1 83.3% 57.8%)` ≈ `#7C3AED` | ❌ |
| Display font | **Permanent Marker** (graffiti) | Poppins only | ❌ |
| Hero background | Graffiti gradient + brick wall | Static dark gradient | ❌ |
| Auth background | Animated smoke blobs (black) | Plain `#f9fafb` (light gray) | ❌ |
| Auth card | White, rounded 16px, shadow | No card wrapper | ❌ |
| Navbar | Glass (black/30%, blur), PermanentMarker links | Standard shadcn navbar | ❌ |
| Auth buttons | `#2563EB`, rounded 14px, h52 | `#183c8b`, rounded 8px | ❌ |
| Form inputs | Rounded 14px, border `#D1D5DB` | Rounded 8px, border `#ddd` | ❌ |
| Home sections | Full feature/about/CTA sections | Simplified placeholders | ❌ |
| Fluxograma page | Course cards with gradient status | Empty | ❌ |
| Chat page | Bot/user bubbles, markdown, tags | Empty | ❌ |
| Nofluxo colors (status gradients) | Defined | Defined in Tailwind ✓ | ✅ |

---

## Phase 1 — Design Tokens & Fonts (Foundation)

### Task 1.1: Fix Primary Color Variable

**File**: `src/app.css`

Change `--primary` from the current HSL value (`262.1 83.3% 57.8%` → `#7C3AED`) to match Flutter's `#6C63FF`:
```
--primary: 243 96% 69.4%;   /* #6C63FF */
```

Also add missing tokens:
```css
--primary-dark: 243 57% 58%;  /* #5A52D5 */
--future: 0 0% 100% / 0.1;     /* white @ 10% */
```

### Task 1.2: Add Permanent Marker Font

**File**: `src/app.html` (or `<svelte:head>` in `+layout.svelte`)

Add Google Fonts import:
```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Permanent+Marker&family=Poppins:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
```

**File**: `tailwind.config.ts`

Add to `fontFamily`:
```ts
marker: ['Permanent Marker', 'cursive'],
mono: ['JetBrains Mono', ...fontFamily.mono],
```

### Task 1.3: Add Font Utility Classes

**File**: `src/app.css`

Add utility classes:
```css
@layer utilities {
  .font-marker { font-family: 'Permanent Marker', cursive; }
  .text-shadow { text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
  .text-shadow-lg { text-shadow: 3px 3px 6px rgba(0,0,0,0.5); }
}
```

### Task 1.4: Fix Auth Page Button Colors

Replace all `#183c8b` references in auth components with `#2563EB` (Flutter's auth primary).

**Files affected**:
- `src/lib/components/auth/LoginForm.svelte`
- `src/lib/components/auth/SignupForm.svelte`
- `src/lib/components/auth/PasswordRecovery.svelte`

**CSS changes per component**:
```
button bg: #183c8b → #2563EB
button hover: #122d6a → #1D4ED8
heading color: #183c8b → #2563EB
input focus border: #183c8b → #2563EB
```

---

## Phase 2 — Backgrounds & Visual Effects

### Task 2.1: Create Animated Smoke Background Component

**New file**: `src/lib/components/effects/AnimatedBackground.svelte`

Replicates Flutter's `animated_background.dart`:
- Solid black (`#000000`) base
- 5 floating blurred circles (CSS, no canvas):
  - Purple `#6B19C9`, Pink `#E63783`, Yellow `#F0C419`, Blue `#3B82F6`, Red `#E11D48`
- Each blob: 200–400px diameter, `filter: blur(80–120px)`, opacity 0.45–0.7
- CSS `@keyframes` animation: 38–55s infinite alternate, translate ±3–5%, scale 0.95–1.12
- `position: fixed; inset: 0; z-index: -1; overflow: hidden`

### Task 2.2: Create Graffiti Background Component

**New file**: `src/lib/components/effects/GraffitiBackground.svelte`

Replicates Flutter's `graffiti_background.dart`:
- Multi-stop gradient: `#9333EA → #E11D48 → #EA580C → #CA8A04 → #000000` (stops 0, 0.3, 0.5, 0.7, 1.0)
- Brick wall pattern overlay: CSS repeating-background or SVG pattern of 60×30px bricks in `rgba(255,255,255,0.13)`
- Scattered decorative shapes (optional — can use pseudo-elements or SVGs)
- Container: `position: fixed; inset: 0; z-index: -1`

### Task 2.3: Replace `animated-bg` in `app.css`

**File**: `src/app.css`

Remove the current static `.animated-bg` class (lines ~115–144). The new `AnimatedBackground.svelte` and `GraffitiBackground.svelte` components replace it.

### Task 2.4: Create Glass Container Utility

**File**: `src/app.css`

Update `.glass` class to match Flutter's `GlassContainer`:
```css
.glass {
  backdrop-filter: blur(4px);
  -webkit-backdrop-filter: blur(4px);
  background: rgba(0, 0, 0, 0.3);
  /* border-radius configurable via Tailwind classes */
}
.glass-light {
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.1);
}
```

---

## Phase 3 — Navbar (Match Flutter `app_navbar.dart`)

### Task 3.1: Restyle Navbar

**File**: `src/lib/components/layout/Navbar.svelte`

**Current** → **Target**:
| Property | Current | Target (Flutter) |
|----------|---------|-------------------|
| Background | `bg-background/95 backdrop-blur` + `border-b` | `glass` (black/30%, blur 4px, no border) |
| Logo text | "NoFluxo" in primary color, bold | "NOFLX UNB" in Permanent Marker, white, `text-shadow: 2px 2px 4px rgba(0,0,0,0.3)` |
| Logo size | Fixed | Responsive 20–36px |
| Nav links font | System/Poppins | Permanent Marker, bold, white |
| Nav link size | Default | Responsive 15–22px |
| Nav link hover | Color change | Gradient underline (purple `#9333EA` → pink `#E11D48`), animated 300ms |
| Padding | Standard | 16–32px horizontal, 6–12px vertical (responsive) |
| Border | `border-b` | None |
| Position | Default | `sticky top-0 z-50` |

### Task 3.2: Create Gradient Underline Hover Effect

**Component or CSS class**: Nav links should have a `::after` pseudo-element:
```css
.nav-link::after {
  content: '';
  position: absolute;
  bottom: -2px;
  left: 0;
  width: 0;
  height: 3px;
  background: linear-gradient(to right, #9333EA, #E11D48);
  border-radius: 2px;
  transition: width 300ms ease-in-out;
}
.nav-link:hover::after {
  width: 100%;
}
```

### Task 3.3: Build Mobile Drawer

Restyle mobile menu to match Flutter's drawer:
- Dark gradient background (black → deep purple)
- Menu items with left purple border accent on active
- Icon + label layout
- Gradient CTA button inside drawer
- Footer: "NoFluxoUNB © 2025"

---

## Phase 4 — Auth Pages (Login, Signup, Password Recovery)

### Task 4.1: Add Animated Background to Auth Pages

**Files**:
- `src/routes/login/+page.svelte`
- `src/routes/signup/+page.svelte`
- `src/routes/password-recovery/+page.svelte`
- `src/routes/login-anonimo/+page.svelte`

Replace the light gray background with the `<AnimatedBackground />` component. Layout becomes:
```svelte
<AnimatedBackground />
<div class="auth-page">
  <!-- form card -->
</div>
```

### Task 4.2: Wrap Auth Forms in Card

Add a white card wrapper around each auth form:
```css
.auth-card {
  background: white;
  border-radius: 16px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
  padding: 40px 40px 28px;
  max-width: 440px;
  width: 100%;
}
```

### Task 4.3: Restyle Form Inputs

**All auth forms** — update input styles:
```css
input {
  border-radius: 14px;        /* was 8px */
  border: 1px solid #D1D5DB;  /* was #ddd */
  padding: 18px;              /* was 0.75rem */
  font-size: 16px;
  font-family: 'Poppins', sans-serif;
}
input:focus {
  border-color: #2563EB;      /* was #183c8b */
  box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
}
input::placeholder {
  color: #9CA3AF;  /* gray-400 */
}
```

### Task 4.4: Restyle Auth Buttons

**Primary button**:
```css
.btn-primary {
  background: #2563EB;
  color: white;
  border-radius: 14px;
  height: 52px;
  font-size: 18px;
  font-weight: 600;
  font-family: 'Poppins', sans-serif;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}
.btn-primary:hover {
  background: #1D4ED8;
}
```

**Google button**:
```css
.btn-google {
  background: white;
  border: 1px solid #D1D5DB;
  border-radius: 14px;
  height: 52px;
  font-size: 16px;
}
```

**Visitor/Anonymous button** (login-anonimo page):
```css
.btn-visitor {
  background: rgba(0, 0, 0, 0.87);
  color: white;
  border-radius: 14px;
  height: 52px;
}
```

### Task 4.5: Add Password Visibility Toggle

Add an eye/eye-off icon button inside password inputs (using Lucide `Eye` / `EyeOff` icons).

### Task 4.6: Implement Error Banner (Flutter Style)

Replace the current red error div with Flutter-style warning banner:
```css
.error-banner {
  background: #FFF4E5;
  border: 1px solid #FFB020;
  border-radius: 8px;
  padding: 12px 16px;
  display: flex;
  align-items: center;
  gap: 12px;
}
```
With a warning triangle icon (Lucide `AlertTriangle`).

### Task 4.7: Implement Success Modal

Create a success dialog component matching Flutter:
- White card, rounded 14px
- Green circle icon (`#E6FAF0` bg, `#2DC063` checkmark)
- Heading + message text
- "OK" button in `#183C8B`
- Auto-redirect to destination after 2 seconds

### Task 4.8: Style Auth Links

Link colors: `#6366F1` (indigo-500) with underline, matching Flutter's `Esqueceu a senha?` link.

---

## Phase 5 — Home Page (Match Flutter `home_screen.dart`)

### Task 5.1: Hero Section

**File**: `src/routes/+page.svelte`

**Target design**:
- Background: `<GraffitiBackground />`
- Title: "TENHA SEU FLUXOGRAMA MUITO" (white) + "RÁPIDO" (`#F472B6` pink) — Permanent Marker font
- Font size: 64px desktop / 32px mobile
- Text shadow: `3px 3px 6px rgba(0,0,0,0.5)`
- Description: Poppins, 20px desktop / 14px mobile, white/80%
- CTA button: Blue gradient `#2296EE → #1D4ED8`, rounded 32px, Permanent Marker text, `scale(1.05)` hover, min-width 260px
- SVG illustration: `computer_phone.svg` (copy from Flutter assets to `static/`)

### Task 5.2: "Como Funciona" Section

**New component**: `src/lib/components/home/ComoFunciona.svelte`

- Section title: "COMO FUNCIONA" — Permanent Marker, 32px, white, centered
- Black background @ 50% opacity container
- 3 feature cards in a row (responsive to column on mobile):
  - `glass-light` style (white/10% bg, white/10% border, rounded 12px)
  - Icon in gradient circle (64×64px, rounded-full, linear-gradient matching each feature color)
  - Title: Poppins bold, white
  - Description: Poppins, white/70%
  - Hover: `scale(1.05)`, transition 200ms
- Features:
  1. "Monte seu Fluxograma" — purple gradient circle, `LayoutDashboard` icon
  2. "Visualize seu Progresso" — blue gradient circle, `GitBranch` icon
  3. "Planeje suas Matérias" — pink gradient circle, `BookOpen` icon

### Task 5.3: "Pronto Para Organizar" Section

**New component**: `src/lib/components/home/ProntoParaOrganizar.svelte`

- Black background @ 30% opacity
- Heading: Permanent Marker, 32px, white
- Subheading: Poppins, 18px, white/70%
- CTA: Blue gradient `#0099FF → #0033CC`, rounded 32px, Poppins bold 20px, white text

### Task 5.4: "Sobre Nós" Section

**New component**: `src/lib/components/home/SobreNos.svelte`

- Section title: "SOBRE NÓS" — Permanent Marker, 32px, white
- Black background @ 50% opacity
- About card: white/10% bg, rounded 24px, border white/20%, shadow blur 16
- Team member cards: 280×280px desktop (180px mobile), white/10% bg, rounded 12px, hover scale 1.05
- Member avatar: gradient circle placeholder
- Member name: Poppins bold
- Member role: Poppins, white/70%

### Task 5.5: Footer (Home Page)

**File**: `src/lib/components/layout/Footer.svelte`

Footer should match Flutter:
- Dark background
- "NoFluxoUNB © 2025" text
- Links if any

---

## Phase 6 — Fluxograma Pages

### Task 6.1: Course Card Component

**New file**: `src/lib/components/fluxograma/CourseCard.svelte`

- Width: 192px
- Gradient backgrounds by status (already defined in Tailwind config):
  - Completed: `#2DC063 → #0B7D35`
  - Current: `#A78BFA → #8B5CF6`
  - Selected: `#FB7185 → #E11D48`
  - Optative: `#3B82F6 → #1D4ED8`
  - Ready: `#F59E0B → #D97706`
  - Future: `white @ 10%`
- Border-radius: 8px
- Shadow: `0 4px 8px rgba(0,0,0,0.3)`
- Padding: 12px
- Title: 14px Poppins bold, white
- Subtitle (code): 12px Poppins, white/80%
- Credits: 10px Poppins, white/70%
- Hover: subtle lift (`translateY(-2px)`, increased shadow)

### Task 6.2: Fluxograma Container

**File**: `src/routes/fluxogramas/+page.svelte` and/or `src/routes/meu-fluxograma/`

- Container: black/40% bg, rounded 24px, padding 32px, max-width 1280px
- Semester column layout with headers
- Horizontal scroll for wide flowcharts
- Zoom controls: white/10% bg, rounded 8px, `+`/`-`/reset buttons
- Legend bar: gradient swatches with labels for each status

### Task 6.3: Fluxograma Index Page

Grid of available courses, each as a card that links to `/meu-fluxograma/[courseName]`.

---

## Phase 7 — Chat/Assistant Page

### Task 7.1: Chat Layout

**File**: `src/routes/assistente/+page.svelte`

- Full-height layout with message area + input bar
- Bot avatar: `#B72EFF` circle, 40×40, white "A" letter
- User avatar: primary color circle with user initial

### Task 7.2: Message Bubbles

- **User messages**: `rgba(139, 92, 246, 0.8)` bg, rounded `16px 4px 16px 16px`
- **Bot messages**: `rgba(255, 255, 255, 0.1)` bg, rounded `4px 16px 16px 16px`
- Timestamp: 10px, white/50%, aligned accordingly
- Max-width: 80% of container

### Task 7.3: Markdown Rendering in Chat

Install and configure a Svelte markdown renderer (e.g., `svelte-markdown` or `marked` + custom renderer):
- Headers: Poppins bold, sizes 24/22/20/18/16/14px
- Code blocks: JetBrains Mono, dark bg, rounded 8px, copy button
- Tables: bordered, striped
- Blockquotes: left purple border

### Task 7.4: Interest Tags & Typing Indicator

- Interest tags: Pill-shaped buttons for selecting areas of interest
- Typing indicator: 3 pulsing dots in `#8B5CF6`
- Loading curiosities: Fun facts shown while AI processes

---

## Phase 8 — Upload Histórico Page

### Task 8.1: Upload Drop Zone

**File**: `src/routes/upload-historico/+page.svelte`

- Dotted border container, rounded 16px
- Drag-and-drop zone with icon + text
- File type restriction: PDF only
- Progress bar: gradient animation during upload
- Success state: green checkmark + parsed data preview

---

## Phase 9 — Shared Components & Polish

### Task 9.1: Loading/Splash Screen

**File**: `src/lib/components/layout/SplashScreen.svelte`

Match Flutter's splash with animated bar, particles, and text animation.

### Task 9.2: Hover Animations

Add consistent hover effects across all interactive elements:
- Cards: `transform: scale(1.05); transition: 200ms ease-in-out`
- Buttons: `transform: scale(1.02); transition: 150ms`
- Nav links: gradient underline 300ms

### Task 9.3: Responsive Breakpoints

Ensure all components use consistent breakpoints:
- Mobile: < 640px
- Tablet: 640–1024px
- Desktop: ≥ 1024px

Match Flutter's responsive sizing patterns (font sizes scale down ~50% on mobile).

### Task 9.4: Shadow Consistency

Standardize shadow values:
- **Cards**: `0 4px 8px rgba(0,0,0,0.3)`
- **Auth card**: `0 4px 16px rgba(0,0,0,0.08)`
- **Elevated buttons**: `0 2px 4px rgba(0,0,0,0.1)`
- **Modals**: `0 8px 32px rgba(0,0,0,0.2)`

---

## Implementation Order (Recommended)

| Step | Phase | Tasks | Impact |
|------|-------|-------|--------|
| 1 | Phase 1 | 1.1–1.4 | Foundation — fixes colors, adds fonts globally |
| 2 | Phase 2 | 2.1–2.4 | Backgrounds — biggest visual identity change |
| 3 | Phase 3 | 3.1–3.3 | Navbar — visible on every page |
| 4 | Phase 4 | 4.1–4.8 | Auth pages — first user-facing flow |
| 5 | Phase 5 | 5.1–5.5 | Home page — the landing experience |
| 6 | Phase 9 | 9.1–9.4 | Polish — consistent across all pages |
| 7 | Phase 6 | 6.1–6.3 | Fluxograma — core feature page |
| 8 | Phase 7 | 7.1–7.4 | Chat — AI assistant page |
| 9 | Phase 8 | 8.1 | Upload — supporting feature |

---

## Reference: Flutter Source Files

| Flutter File | Purpose | Svelte Equivalent |
|---|---|---|
| `lib/config/app_colors.dart` | Color constants | `tailwind.config.ts` + `app.css` vars |
| `lib/widgets/animated_background.dart` | Smoke animation | `AnimatedBackground.svelte` (new) |
| `lib/widgets/graffiti_background.dart` | Home bg | `GraffitiBackground.svelte` (new) |
| `lib/widgets/glass_container.dart` | Glassmorphism | `.glass` / `.glass-light` CSS class |
| `lib/widgets/app_navbar.dart` | Navigation bar | `Navbar.svelte` |
| `lib/screens/home_screen.dart` | Home page | `routes/+page.svelte` |
| `lib/screens/auth/login_form.dart` | Login form | `LoginForm.svelte` |
| `lib/screens/auth/signup_form.dart` | Signup form | `SignupForm.svelte` |
| `lib/widgets/como_funciona_section.dart` | Features section | `ComoFunciona.svelte` (new) |
| `lib/widgets/sobre_nos_section.dart` | About section | `SobreNos.svelte` (new) |
| `lib/widgets/pronto_para_organizar_section.dart` | CTA section | `ProntoParaOrganizar.svelte` (new) |
| `lib/screens/fluxogramas/presentation/widgets/course_card_widget.dart` | Course card | `CourseCard.svelte` (new) |
| `lib/screens/assistente/assistente_screen.dart` | Chat UI | `routes/assistente/+page.svelte` |
| `lib/config/size_config.dart` | Responsive sizing | Tailwind responsive utilities |

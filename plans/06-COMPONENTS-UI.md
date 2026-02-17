# 06 - UI Components Migration Guide

This document provides a comprehensive guide for migrating Flutter widgets to SvelteKit/Svelte 5 components with shadcn-svelte and Tailwind CSS.

## Table of Contents

1. [Flutter to Svelte Component Mapping](#1-flutter-to-svelte-component-mapping)
2. [shadcn-svelte Components to Use](#2-shadcn-svelte-components-to-use)
3. [Custom Component Library](#3-custom-component-library)
4. [Responsive Utilities](#4-responsive-utilities)
5. [Animation Patterns](#5-animation-patterns)
6. [Icon System](#6-icon-system)
7. [Form Components](#7-form-components)
8. [Modal/Dialog Patterns](#8-modaldialog-patterns)
9. [Toast Notifications](#9-toast-notifications)
10. [Dark Mode](#10-dark-mode)

---

## 1. Flutter to Svelte Component Mapping

### Widget Equivalents

| Flutter Widget | Svelte/HTML Equivalent | Notes |
|----------------|------------------------|-------|
| `Container` | `<div>` with Tailwind classes | Use `class` for styling |
| `Column` | `<div class="flex flex-col">` | Flexbox column |
| `Row` | `<div class="flex flex-row">` | Flexbox row |
| `Stack` | `<div class="relative">` + `absolute` children | CSS positioning |
| `Positioned` | `<div class="absolute">` | With `top/left/right/bottom` |
| `Text` | `<p>`, `<span>`, `<h1-h6>` | Semantic HTML |
| `TextButton` | `<button>` or `Button` from shadcn | Custom styling |
| `ElevatedButton` | `<button>` with shadow classes | Tailwind shadows |
| `IconButton` | `<button>` with icon child | lucide-svelte icons |
| `ListView` | `<div class="overflow-auto">` | Scrollable container |
| `Scaffold` | `<div>` with layout structure | Page wrapper |
| `AppBar` | `<nav>` or `<header>` | Navigation component |
| `Drawer` | Sheet component (shadcn) | Side navigation |
| `Dialog` | Dialog component (shadcn) | Modal dialogs |
| `ClipRRect` | `<div class="rounded-[Xpx] overflow-hidden">` | Border radius + clip |
| `BackdropFilter` | `backdrop-blur-[Xpx]` (Tailwind) | CSS backdrop filter |
| `Opacity` | `opacity-[X]` class | CSS opacity |
| `Transform.scale` | `transform scale-[X]` | CSS transform |
| `AnimatedContainer` | Svelte transitions + CSS | `transition:` directive |
| `BoxDecoration` | Tailwind utility classes | Gradients, shadows, borders |
| `LinearGradient` | `bg-gradient-to-*` + from/to colors | Tailwind gradients |
| `BoxShadow` | `shadow-*` classes | Tailwind shadows |
| `MediaQuery` | CSS media queries / `matchMedia` | Responsive design |
| `GestureDetector` | `on:click`, `on:mouseenter`, etc. | DOM events |
| `MouseRegion` | `on:mouseenter`, `on:mouseleave` | Hover states |

### State Management Mapping

| Flutter | Svelte 5 | Purpose |
|---------|----------|---------|
| `StatefulWidget` | `$state()` rune | Local component state |
| `setState()` | Reactive assignment | Update triggers re-render |
| `Provider` | Svelte stores / `$state` | Global state |
| `ValueNotifier` | `$state()` + `$derived()` | Reactive values |
| `Stream` | Svelte stores | Async data streams |

---

## 2. shadcn-svelte Components to Use

### Installation

```bash
# Initialize shadcn-svelte
npx shadcn-svelte@latest init

# Add components
npx shadcn-svelte@latest add button
npx shadcn-svelte@latest add card
npx shadcn-svelte@latest add dialog
npx shadcn-svelte@latest add sheet
npx shadcn-svelte@latest add input
npx shadcn-svelte@latest add select
npx shadcn-svelte@latest add dropdown-menu
npx shadcn-svelte@latest add toast
npx shadcn-svelte@latest add avatar
npx shadcn-svelte@latest add badge
npx shadcn-svelte@latest add tooltip
npx shadcn-svelte@latest add separator
npx shadcn-svelte@latest add scroll-area
```

### Component Usage Table

| Component | Use Case in NoFluxo |
|-----------|---------------------|
| `Button` | Navigation links, form submissions, CTAs |
| `Card` | Course cards, info panels |
| `Dialog` | Confirmations, course details modal |
| `Sheet` | Mobile navigation drawer |
| `Input` | Login form, file upload |
| `Select` | Course selection, filters |
| `DropdownMenu` | User menu, options |
| `Avatar` | User profile picture |
| `Badge` | Status indicators, course tags |
| `Tooltip` | Helpful hints |
| `ScrollArea` | Scrollable lists |

---

## 3. Custom Component Library

### 3.1 AppNavbar - Responsive Navigation

**File:** `src/lib/components/AppNavbar.svelte`

```svelte
<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { user, isAnonymous, signOut } from '$lib/stores/auth';
  import AppLogo from './AppLogo.svelte';
  import GradientCTAButton from './GradientCTAButton.svelte';
  import GradientUnderlineButton from './GradientUnderlineButton.svelte';
  import GlassContainer from './GlassContainer.svelte';
  import { Menu, X, Home, GitBranch, Bot, LogOut, LogIn } from 'lucide-svelte';

  // Props
  interface Props {
    hideAccessButton?: boolean;
    isFluxogramasPage?: boolean;
  }

  let { hideAccessButton = false, isFluxogramasPage = false }: Props = $props();

  // State
  let isDrawerOpen = $state(false);
  let screenWidth = $state(typeof window !== 'undefined' ? window.innerWidth : 1200);

  // Computed
  let isMobile = $derived(screenWidth < 800);
  let isDesktop = $derived(screenWidth >= 800);

  // Responsive values
  let fontSize = $derived(
    screenWidth > 1300 ? 22 :
    screenWidth > 1100 ? 18 :
    screenWidth > 900 ? 15 : 15
  );

  let logoFontSize = $derived(
    screenWidth > 1300 ? 36 :
    screenWidth > 1100 ? 30 :
    screenWidth > 900 ? 24 : 20
  );

  // Navigation items
  type NavItem = {
    text: string;
    path: string;
    icon: typeof Home;
    isCTA?: boolean;
    requiresAuth?: boolean;
    hideWhenAuth?: boolean;
  };

  let navItems = $derived.by(() => {
    const items: NavItem[] = [];
    const currentPath = $page?.url?.pathname || '/';
    const isPublicRoute = ['/', '/login', '/signup', '/password-recovery'].includes(currentPath);
    const isUploadRoute = currentPath === '/upload-historico';

    if (isUploadRoute && $user) {
      return [{ text: 'SAIR', path: '/logout', icon: LogOut }];
    }

    items.push({ text: 'HOME', path: '/', icon: Home });

    if ($user) {
      const hasFluxograma = $user.dadosFluxograma != null;
      items.push({
        text: 'MEUS FLUXOGRAMAS',
        path: hasFluxograma ? '/meu-fluxograma' : '/upload-historico',
        icon: GitBranch,
        requiresAuth: true
      });
    }

    if (!isPublicRoute && !currentPath.startsWith('/fluxogramas')) {
      items.push({ text: 'FLUXOGRAMAS', path: '/fluxogramas', icon: GitBranch });

      if (!$isAnonymous && $user) {
        items.push({ text: 'ASSISTENTE', path: '/assistente', icon: Bot });
      }
    }

    if ((currentPath === '/' && !$user) || $isAnonymous) {
      if (!hideAccessButton) {
        items.push({
          text: 'ACESSE NOSSO SISTEMA',
          path: '/login',
          icon: LogIn,
          isCTA: true
        });
      }
    }

    if ($user) {
      items.push({ text: 'SAIR', path: '/logout', icon: LogOut });
    }

    return items;
  });

  // Handlers
  function handleNavigation(path: string) {
    if (path === '/logout') {
      signOut();
      goto('/login');
    } else {
      goto(path);
    }
    isDrawerOpen = false;
  }

  function toggleDrawer() {
    isDrawerOpen = !isDrawerOpen;
  }

  // Resize listener
  $effect(() => {
    if (typeof window === 'undefined') return;

    const handleResize = () => {
      screenWidth = window.innerWidth;
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  });
</script>

<nav class="fixed top-0 left-0 right-0 z-50">
  <GlassContainer padding="px-4 py-2 md:px-6 md:py-3 lg:px-8 lg:py-4">
    <div class="flex items-center justify-between">
      <!-- Logo -->
      <button onclick={() => goto('/')} class="focus:outline-none">
        <AppLogo fontSize={logoFontSize} />
      </button>

      <!-- Desktop Navigation -->
      {#if isDesktop}
        <div class="flex items-center gap-2 lg:gap-3 xl:gap-4">
          {#each navItems as item}
            {#if item.isCTA}
              <GradientCTAButton
                text={item.text}
                {fontSize}
                onclick={() => handleNavigation(item.path)}
              />
            {:else}
              <GradientUnderlineButton
                text={item.text}
                {fontSize}
                onclick={() => handleNavigation(item.path)}
              />
            {/if}
          {/each}
        </div>
      {:else}
        <!-- Mobile Menu Button -->
        <button
          onclick={toggleDrawer}
          class="p-2 text-white hover:bg-white/10 rounded-lg transition-colors"
          aria-label="Toggle menu"
        >
          <Menu size={28} />
        </button>
      {/if}
    </div>
  </GlassContainer>
</nav>

<!-- Mobile Drawer -->
{#if isDrawerOpen}
  <!-- Backdrop -->
  <button
    class="fixed inset-0 bg-black/50 z-40 transition-opacity"
    onclick={() => isDrawerOpen = false}
    aria-label="Close menu"
  ></button>

  <!-- Drawer Panel -->
  <aside
    class="fixed top-0 right-0 h-full w-[85vw] max-w-[400px] z-50
           bg-gradient-to-br from-[#1a1a1a]/98 to-black/96
           border-l-2 border-purple-500/30
           shadow-[-8px_0_25px_rgba(0,0,0,0.4)]
           transform transition-transform duration-300 ease-out"
    class:translate-x-0={isDrawerOpen}
    class:translate-x-full={!isDrawerOpen}
  >
    <!-- Drawer Header -->
    <div class="flex items-center justify-between p-4 md:p-5
                bg-gradient-to-r from-purple-500/20 to-pink-500/10
                border-b border-white/10">
      <div class="flex items-center gap-3">
        <div class="p-2 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg">
          <Menu size={18} class="text-white" />
        </div>
        <span class="text-white font-bold text-lg">Menu de Navegação</span>
      </div>
      <button
        onclick={() => isDrawerOpen = false}
        class="p-2 hover:bg-white/10 rounded-lg transition-colors"
        aria-label="Close menu"
      >
        <X size={24} class="text-white" />
      </button>
    </div>

    <!-- Drawer Links -->
    <div class="flex-1 overflow-y-auto p-4 space-y-3">
      {#each navItems as item}
        {#if item.isCTA}
          <button
            onclick={() => handleNavigation(item.path)}
            class="w-full flex items-center gap-4 p-4 md:p-5
                   bg-gradient-to-r from-purple-500 to-pink-500
                   rounded-2xl shadow-[0_6px_16px_rgba(123,47,242,0.4)]
                   text-white font-semibold
                   hover:scale-[1.02] active:scale-[0.98]
                   transition-transform duration-200"
          >
            <div class="p-1.5 bg-white/20 rounded-lg">
              <svelte:component this={item.icon} size={20} />
            </div>
            <span class="flex-1 text-left">{item.text}</span>
          </button>
        {:else}
          <button
            onclick={() => handleNavigation(item.path)}
            class="w-full flex items-center gap-4 p-4 md:p-5
                   border border-white/10 rounded-2xl
                   text-white font-medium
                   hover:bg-white/5 active:bg-white/10
                   transition-colors duration-200"
          >
            <div class="p-2 bg-white/10 rounded-lg">
              <svelte:component this={item.icon} size={18} class="text-white/90" />
            </div>
            <span class="flex-1 text-left">{item.text}</span>
            <span class="text-white/40 text-sm">→</span>
          </button>
        {/if}
      {/each}
    </div>

    <!-- Drawer Footer -->
    <div class="p-4 border-t border-white/10 text-center text-white/60 text-sm">
      NoFluxoUNB © 2025
    </div>
  </aside>
{/if}

<style>
  /* Ensure smooth drawer animation */
  aside {
    will-change: transform;
  }
</style>
```

---

### 3.2 AnimatedBackground - Gradient Smoke Animation

**File:** `src/lib/components/AnimatedBackground.svelte`

```svelte
<script lang="ts">
  import { onMount } from 'svelte';

  // Smoke orb configuration
  const smokeOrbs = [
    { size: 180, color: '#6B19C9', topPercent: 0.10, leftPercent: 0.05, duration: 40 },
    { size: 220, color: '#E63783', topPercent: 0.60, leftPercent: 0.70, duration: 50 },
    { size: 200, color: '#F0C419', topPercent: 0.30, leftPercent: 0.60, duration: 45 },
    { size: 140, color: '#6B19C9', topPercent: 0.70, leftPercent: 0.20, duration: 38 },
    { size: 210, color: '#F0C419', topPercent: 0.76, leftPercent: 0.43, duration: 55 },
  ];

  let mounted = $state(false);

  onMount(() => {
    mounted = true;
  });
</script>

<div class="animated-background">
  <!-- Black base -->
  <div class="absolute inset-0 bg-black"></div>

  <!-- Animated smoke orbs -->
  {#each smokeOrbs as orb, i}
    <div
      class="smoke-orb"
      class:animate={mounted}
      style="
        --size: {orb.size}px;
        --color: {orb.color};
        --top: {orb.topPercent * 100}%;
        --left: {orb.leftPercent * 100}%;
        --duration: {orb.duration}s;
        --delay: {i * 0.5}s;
      "
    ></div>
  {/each}

  <!-- Content slot -->
  <div class="relative z-10">
    <slot />
  </div>
</div>

<style>
  .animated-background {
    position: fixed;
    inset: 0;
    overflow: hidden;
    z-index: -1;
  }

  .smoke-orb {
    position: absolute;
    width: var(--size);
    height: var(--size);
    top: var(--top);
    left: var(--left);
    border-radius: 50%;
    background: transparent;
    box-shadow:
      0 0 calc(var(--size) * 1.2) calc(var(--size) * 0.56) var(--color);
    opacity: 0;
    transform: scale(0.95);
    transition: opacity 1s ease-out;
  }

  .smoke-orb.animate {
    opacity: 0.55;
    animation:
      smoke-move var(--duration) ease-in-out infinite alternate,
      smoke-scale var(--duration) ease-in-out infinite alternate,
      smoke-opacity var(--duration) ease-in-out infinite alternate;
    animation-delay: var(--delay);
  }

  @keyframes smoke-move {
    0% {
      transform: translate(0, 0);
    }
    50% {
      transform: translate(3%, 3%);
    }
    100% {
      transform: translate(-3%, -3%);
    }
  }

  @keyframes smoke-scale {
    0% {
      transform: scale(0.95);
    }
    50% {
      transform: scale(1.12);
    }
    100% {
      transform: scale(0.95);
    }
  }

  @keyframes smoke-opacity {
    0% {
      opacity: 0.45;
    }
    50% {
      opacity: 0.7;
    }
    100% {
      opacity: 0.45;
    }
  }
</style>
```

---

### 3.3 GraffitiBackground - Dark Textured Background

**File:** `src/lib/components/GraffitiBackground.svelte`

```svelte
<script lang="ts">
  import { onMount } from 'svelte';

  // SVG shapes configuration
  const shapes = [
    { top: 38, left: 36, opacity: 0.33, color: '#CA8A04', height: 56.68 },
    { top: 65, left: 22, opacity: 0.32, color: '#E11D48', height: 59.58 },
    { top: 70, left: 62, opacity: 0.30, color: '#EA580C', height: 58.19 },
    { top: 1, left: 56, opacity: 0.32, color: '#4A1D96', height: 36.81 },
  ];

  const circles = [
    { top: 31, left: 8, opacity: 0.68, color: '#4ade80', size: 2.6 },
    { top: 45, left: 82, opacity: 0.55, color: '#E91E63', size: 3.2 },
    { top: 75, left: 15, opacity: 0.50, color: '#FFC107', size: 2.8 },
    { top: 20, left: 70, opacity: 0.45, color: '#9333EA', size: 2.4 },
  ];

  let canvasRef: HTMLCanvasElement;

  onMount(() => {
    if (canvasRef) {
      drawBrickWall(canvasRef);
    }
  });

  function drawBrickWall(canvas: HTMLCanvasElement) {
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    ctx.strokeStyle = 'rgba(255, 255, 255, 0.13)';
    ctx.lineWidth = 1;

    const brickWidth = 60;
    const brickHeight = 30;

    for (let y = 0; y < canvas.height; y += brickHeight) {
      const offset = Math.floor(y / brickHeight) % 2 === 0 ? 0 : brickWidth / 2;
      for (let x = -brickWidth; x < canvas.width; x += brickWidth) {
        const left = x + offset;
        ctx.strokeRect(left, y, brickWidth, brickHeight);
      }
    }
  }
</script>

<svelte:window on:resize={() => canvasRef && drawBrickWall(canvasRef)} />

<div class="graffiti-background">
  <!-- Gradient base -->
  <div class="absolute inset-0 bg-gradient-to-br from-purple-600 via-rose-600 via-orange-600 via-amber-600 to-black"
       style="background: linear-gradient(135deg,
         #9333EA 0%,
         #E11D48 30%,
         #EA580C 50%,
         #CA8A04 70%,
         #000000 100%
       );">
  </div>

  <!-- Brick wall overlay -->
  <canvas
    bind:this={canvasRef}
    class="absolute inset-0 pointer-events-none"
  ></canvas>

  <!-- SVG Shapes -->
  {#each shapes as shape}
    <div
      class="absolute pointer-events-none"
      style="top: {shape.top}%; left: {shape.left}%; opacity: {shape.opacity};"
    >
      <svg width="50" height="100" viewBox="0 0 50 100">
        <path
          d="M25,0 Q20,{shape.height / 2} 25,{shape.height} Q30,{shape.height / 2} 25,0 Z"
          fill={shape.color}
        />
      </svg>
    </div>
  {/each}

  <!-- Circles -->
  {#each circles as circle}
    <div
      class="absolute pointer-events-none"
      style="top: {circle.top}%; left: {circle.left}%; opacity: {circle.opacity};"
    >
      <svg width="10" height="10" viewBox="0 0 10 10">
        <circle cx="5" cy="5" r={circle.size} fill={circle.color} />
      </svg>
    </div>
  {/each}

  <!-- Content slot -->
  <div class="relative z-10">
    <slot />
  </div>
</div>

<style>
  .graffiti-background {
    position: fixed;
    inset: 0;
    overflow: hidden;
    z-index: -1;
  }
</style>
```

---

### 3.4 GlassContainer - Glassmorphism Effect

**File:** `src/lib/components/GlassContainer.svelte`

```svelte
<script lang="ts">
  import { cn } from '$lib/utils';

  interface Props {
    padding?: string;
    borderRadius?: number;
    backgroundOpacity?: number;
    borderOpacity?: number;
    blurAmount?: number;
    class?: string;
    gradient?: string | null;
    shadow?: boolean;
    border?: boolean;
    children?: import('svelte').Snippet;
  }

  let {
    padding = 'p-4',
    borderRadius = 16,
    backgroundOpacity = 0.1,
    borderOpacity = 0.2,
    blurAmount = 10,
    class: className = '',
    gradient = null,
    shadow = false,
    border = true,
    children
  }: Props = $props();

  let computedStyle = $derived(`
    backdrop-filter: blur(${blurAmount}px);
    -webkit-backdrop-filter: blur(${blurAmount}px);
    background: ${gradient || `rgba(255, 255, 255, ${backgroundOpacity})`};
    border-radius: ${borderRadius}px;
    ${border ? `border: 1px solid rgba(255, 255, 255, ${borderOpacity});` : ''}
    ${shadow ? 'box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.37);' : ''}
  `);
</script>

<div
  class={cn('glass-container relative overflow-hidden', padding, className)}
  style={computedStyle}
>
  <!-- Subtle gradient overlay -->
  <div class="absolute inset-0 pointer-events-none
              bg-gradient-to-br from-white/10 via-white/5 to-transparent">
  </div>

  <!-- Content -->
  <div class="relative z-10">
    {@render children?.()}
  </div>
</div>

<style>
  .glass-container {
    will-change: backdrop-filter;
  }
</style>
```

---

### 3.5 GradientCTAButton - Gradient Call-to-Action Button

**File:** `src/lib/components/GradientCTAButton.svelte`

```svelte
<script lang="ts">
  import { cn } from '$lib/utils';

  interface Props {
    text: string;
    fontSize?: number;
    textColor?: string;
    fontWeight?: string;
    gradientColors?: [string, string];
    animationDuration?: number;
    scaleOnHover?: number;
    borderRadius?: number;
    padding?: string;
    minWidth?: string;
    minHeight?: string;
    disabled?: boolean;
    class?: string;
    onclick?: () => void;
  }

  let {
    text,
    fontSize = 19,
    textColor = 'white',
    fontWeight = 'bold',
    gradientColors = ['#9C27B0', '#E91E63'],
    animationDuration = 200,
    scaleOnHover = 1.05,
    borderRadius = 30,
    padding = 'px-4 py-3',
    minWidth = '260px',
    minHeight = '40px',
    disabled = false,
    class: className = '',
    onclick
  }: Props = $props();

  let isHovered = $state(false);
</script>

<button
  class={cn(
    'gradient-cta-button',
    'inline-flex items-center justify-center',
    'font-display border-none cursor-pointer',
    'relative overflow-hidden',
    'shadow-lg hover:shadow-xl',
    'active:scale-[0.98]',
    'disabled:opacity-60 disabled:cursor-not-allowed',
    'transition-all',
    padding,
    className
  )}
  style="
    font-size: {fontSize}px;
    font-weight: {fontWeight};
    color: {textColor};
    border-radius: {borderRadius}px;
    min-width: {minWidth};
    min-height: {minHeight};
    background: linear-gradient(135deg, {gradientColors[0]}, {gradientColors[1]});
    transition-duration: {animationDuration}ms;
    transform: scale({isHovered && !disabled ? scaleOnHover : 1});
  "
  {disabled}
  on:mouseenter={() => isHovered = true}
  on:mouseleave={() => isHovered = false}
  on:click={onclick}
>
  <!-- Shine effect on hover -->
  <span class="shine-effect"></span>

  <!-- Text -->
  <span class="relative z-10">{text}</span>
</button>

<style>
  .gradient-cta-button {
    font-family: var(--font-display, 'Permanent Marker', cursive);
  }

  .shine-effect {
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(
      90deg,
      transparent,
      rgba(255, 255, 255, 0.2),
      transparent
    );
    transition: left 0.5s ease;
  }

  .gradient-cta-button:hover:not(:disabled) .shine-effect {
    left: 100%;
  }

  .gradient-cta-button:disabled .shine-effect {
    display: none;
  }
</style>
```

---

### 3.6 GradientUnderlineButton - Text Button with Animated Underline

**File:** `src/lib/components/GradientUnderlineButton.svelte`

```svelte
<script lang="ts">
  import { cn } from '$lib/utils';

  interface Props {
    text: string;
    fontSize?: number;
    textColor?: string;
    fontWeight?: string;
    gradientColors?: [string, string];
    animationDuration?: number;
    underlineHeight?: number;
    class?: string;
    onclick?: () => void;
  }

  let {
    text,
    fontSize = 19,
    textColor = 'white',
    fontWeight = 'bold',
    gradientColors = ['#9C27B0', '#E91E63'],
    animationDuration = 300,
    underlineHeight = 2,
    class: className = '',
    onclick
  }: Props = $props();

  let isHovered = $state(false);
</script>

<button
  class={cn(
    'gradient-underline-button',
    'relative inline-flex items-center justify-center',
    'px-2 py-1 bg-transparent border-none cursor-pointer',
    'font-display',
    className
  )}
  style="
    font-size: {fontSize}px;
    font-weight: {fontWeight};
    color: {textColor};
  "
  on:mouseenter={() => isHovered = true}
  on:mouseleave={() => isHovered = false}
  on:click={onclick}
>
  <span class="button-text">{text}</span>

  <!-- Animated underline -->
  <span
    class="underline-bar absolute bottom-0 left-0 transition-all"
    style="
      height: {underlineHeight}px;
      width: {isHovered ? '100%' : '0%'};
      background: linear-gradient(90deg, {gradientColors[0]}, {gradientColors[1]});
      transition-duration: {animationDuration}ms;
    "
  ></span>
</button>

<style>
  .gradient-underline-button {
    font-family: var(--font-display, 'Permanent Marker', cursive);
    transition: transform 0.2s ease;
  }

  .gradient-underline-button:hover {
    transform: translateY(-1px);
  }

  .gradient-underline-button:active {
    transform: translateY(0);
  }

  .underline-bar {
    transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
  }
</style>
```

---

### 3.7 AppLogo - Logo Component

**File:** `src/lib/components/AppLogo.svelte`

```svelte
<script lang="ts">
  import { cn } from '$lib/utils';

  interface Props {
    text?: string;
    fontSize?: number;
    color?: string;
    showIcon?: boolean;
    showShadow?: boolean;
    class?: string;
  }

  let {
    text = 'NOFLUXO UNB',
    fontSize = 36,
    color = 'white',
    showIcon = true,
    showShadow = true,
    class: className = ''
  }: Props = $props();

  let shadowStyle = $derived(
    showShadow
      ? 'text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);'
      : ''
  );
</script>

<div
  class={cn(
    'app-logo',
    'flex items-center gap-3',
    'font-display select-none',
    'transition-transform duration-200',
    'hover:scale-105',
    className
  )}
  style="
    font-size: {fontSize}px;
    color: {color};
    {shadowStyle}
  "
>
  {#if showIcon}
    <div
      class="logo-icon flex items-center justify-center
             bg-gradient-to-br from-purple-500 to-pink-500
             rounded-full font-bold text-white"
      style="
        width: {fontSize * 0.8}px;
        height: {fontSize * 0.8}px;
        font-size: {fontSize * 0.4}px;
      "
    >
      N
    </div>
  {/if}

  <span class="logo-text leading-none">
    NO<span class="text-pink-500">FLUXO</span>
    {#if text.includes('UNB')}
      <span class="text-white"> UNB</span>
    {/if}
  </span>
</div>

<style>
  .app-logo {
    font-family: var(--font-display, 'Permanent Marker', cursive);
  }
</style>
```

---

### 3.8 SplashWidget - Loading Splash Screen

**File:** `src/lib/components/SplashWidget.svelte`

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import GraffitiBackground from './GraffitiBackground.svelte';

  // Particle colors
  const particleColors = ['#43CEA2', '#FF5E62', '#F9D423', '#8E44AD', '#36D1C4'];
  const particlePositions = [0.1, 0.3, 0.5, 0.7, 0.85];

  let mounted = $state(false);
  let dotOpacities = $state([0, 0, 0]);

  onMount(() => {
    mounted = true;

    // Animate dots sequentially
    const dotIntervals = [
      setInterval(() => {
        dotOpacities[0] = dotOpacities[0] === 1 ? 0 : 1;
        dotOpacities = [...dotOpacities];
      }, 600),
      setInterval(() => {
        dotOpacities[1] = dotOpacities[1] === 1 ? 0 : 1;
        dotOpacities = [...dotOpacities];
      }, 600),
      setInterval(() => {
        dotOpacities[2] = dotOpacities[2] === 1 ? 0 : 1;
        dotOpacities = [...dotOpacities];
      }, 600),
    ];

    // Stagger the dot animations
    setTimeout(() => dotIntervals[1], 200);
    setTimeout(() => dotIntervals[2], 400);

    return () => dotIntervals.forEach(clearInterval);
  });
</script>

<div class="splash-widget fixed inset-0 flex items-center justify-center">
  <GraffitiBackground />

  <div class="loader-container flex flex-col items-center">
    <!-- Progress Bar Container -->
    <div class="progress-bar-container relative w-80 h-8 mb-8
                bg-white/25 rounded-2xl overflow-hidden
                shadow-[0_2px_16px_rgba(52,152,219,0.1)]">

      <!-- Animated Gradient Bar -->
      <div class="progress-bar absolute inset-0 animate-gradient-flow"></div>

      <!-- Bouncing Particles -->
      {#each particleColors as color, i}
        <div
          class="particle absolute w-[18px] h-[18px] rounded-full
                 shadow-[0_2px_8px_rgba(0,0,0,0.1)]"
          class:animate-bounce-particle={mounted}
          style="
            background: {color};
            left: calc({particlePositions[i] * 100}% - 9px);
            bottom: 8px;
            animation-delay: {i * 0.2}s;
          "
        ></div>
      {/each}
    </div>

    <!-- Loading Text -->
    <div class="loading-text flex items-center
                text-white text-xl font-medium
                drop-shadow-[0_2px_8px_rgba(0,0,0,0.3)]">
      <span class="animate-pulse-text">Carregando</span>
      {#each [0, 1, 2] as dotIndex}
        <span
          class="dot ml-0.5 transition-opacity duration-300"
          style="opacity: {dotOpacities[dotIndex]}"
        >.</span>
      {/each}
    </div>
  </div>
</div>

<style>
  .loading-text {
    font-family: var(--font-primary, 'Poppins', sans-serif);
  }

  .progress-bar {
    background: linear-gradient(
      90deg,
      #43cea2 0%,
      #f9d423 25%,
      #ff5e62 50%,
      #8e44ad 75%,
      #43cea2 100%
    );
    background-size: 400% 100%;
    animation: gradient-flow 2.5s linear infinite;
  }

  @keyframes gradient-flow {
    0% {
      background-position: 100% 0;
    }
    100% {
      background-position: -100% 0;
    }
  }

  @keyframes bounce-particle {
    0%, 100% {
      transform: translateY(0) scale(1);
    }
    30% {
      transform: translateY(-32px) scale(1.15);
    }
    50% {
      transform: translateY(-18px) scale(1.1);
    }
    70% {
      transform: translateY(-32px) scale(1.15);
    }
  }

  .particle.animate-bounce-particle {
    animation: bounce-particle 1.2s ease-in-out infinite;
  }

  @keyframes pulse-text {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: 0.6;
    }
  }

  .animate-pulse-text {
    animation: pulse-text 1.2s ease-in-out infinite alternate;
  }
</style>
```

---

## 4. Responsive Utilities

### 4.1 Breakpoint Hook

**File:** `src/lib/hooks/useBreakpoint.ts`

```typescript
import { readable, derived, type Readable } from 'svelte/store';
import { browser } from '$app/environment';

export type Breakpoint = 'mobile' | 'tablet' | 'desktop' | 'wide';

export interface BreakpointState {
  width: number;
  height: number;
  breakpoint: Breakpoint;
  isMobile: boolean;
  isTablet: boolean;
  isDesktop: boolean;
  isWide: boolean;
}

const BREAKPOINTS = {
  mobile: 0,
  tablet: 640,
  desktop: 1024,
  wide: 1400,
} as const;

function getBreakpoint(width: number): Breakpoint {
  if (width >= BREAKPOINTS.wide) return 'wide';
  if (width >= BREAKPOINTS.desktop) return 'desktop';
  if (width >= BREAKPOINTS.tablet) return 'tablet';
  return 'mobile';
}

export const screenSize: Readable<{ width: number; height: number }> = readable(
  { width: browser ? window.innerWidth : 1200, height: browser ? window.innerHeight : 800 },
  (set) => {
    if (!browser) return;

    const update = () => set({ width: window.innerWidth, height: window.innerHeight });
    window.addEventListener('resize', update);
    return () => window.removeEventListener('resize', update);
  }
);

export const breakpoint: Readable<BreakpointState> = derived(screenSize, ($size) => {
  const bp = getBreakpoint($size.width);
  return {
    width: $size.width,
    height: $size.height,
    breakpoint: bp,
    isMobile: bp === 'mobile',
    isTablet: bp === 'tablet',
    isDesktop: bp === 'desktop' || bp === 'wide',
    isWide: bp === 'wide',
  };
});

// Svelte 5 runes version
export function useBreakpoint() {
  let width = $state(browser ? window.innerWidth : 1200);
  let height = $state(browser ? window.innerHeight : 800);

  $effect(() => {
    if (!browser) return;

    const handleResize = () => {
      width = window.innerWidth;
      height = window.innerHeight;
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  });

  const bp = $derived(getBreakpoint(width));

  return {
    get width() { return width; },
    get height() { return height; },
    get breakpoint() { return bp; },
    get isMobile() { return bp === 'mobile'; },
    get isTablet() { return bp === 'tablet'; },
    get isDesktop() { return bp === 'desktop' || bp === 'wide'; },
    get isWide() { return bp === 'wide'; },
  };
}
```

### 4.2 Tailwind Responsive Classes Reference

```css
/* Breakpoints (same as Flutter's MediaQuery equivalents) */
/* sm: 640px  - Mobile landscape / Small tablet */
/* md: 768px  - Tablet portrait */
/* lg: 1024px - Tablet landscape / Small desktop */
/* xl: 1280px - Desktop */
/* 2xl: 1536px - Large desktop */

/* Usage Examples */
.example {
  /* Mobile first approach */
  @apply text-sm;          /* Mobile: 14px */
  @apply md:text-base;     /* Tablet: 16px */
  @apply lg:text-lg;       /* Desktop: 18px */
  @apply xl:text-xl;       /* Large: 20px */

  /* Spacing */
  @apply p-4;              /* Mobile: 16px */
  @apply md:p-6;           /* Tablet: 24px */
  @apply lg:p-8;           /* Desktop: 32px */

  /* Layout */
  @apply flex flex-col;    /* Mobile: Stack */
  @apply md:flex-row;      /* Tablet+: Row */

  /* Visibility */
  @apply hidden md:block;  /* Hidden on mobile, visible on tablet+ */
  @apply block md:hidden;  /* Visible on mobile, hidden on tablet+ */
}
```

---

## 5. Animation Patterns

### 5.1 Svelte Transitions

**File:** `src/lib/transitions/index.ts`

```typescript
import { cubicOut, cubicInOut, quintOut } from 'svelte/easing';
import type { TransitionConfig } from 'svelte/transition';

// Fade with scale (like Flutter's AnimatedScale)
export function scaleIn(
  node: Element,
  { delay = 0, duration = 300, easing = cubicOut, start = 0.95 } = {}
): TransitionConfig {
  const style = getComputedStyle(node);
  const opacity = +style.opacity;
  const transform = style.transform === 'none' ? '' : style.transform;

  return {
    delay,
    duration,
    easing,
    css: (t) => `
      opacity: ${t * opacity};
      transform: ${transform} scale(${start + (1 - start) * t});
    `
  };
}

// Slide from right (for drawer)
export function slideInRight(
  node: Element,
  { delay = 0, duration = 300, easing = cubicOut } = {}
): TransitionConfig {
  const style = getComputedStyle(node);
  const opacity = +style.opacity;
  const width = parseFloat(style.width);

  return {
    delay,
    duration,
    easing,
    css: (t) => `
      opacity: ${t * opacity};
      transform: translateX(${(1 - t) * width}px);
    `
  };
}

// Slide from bottom (for bottom sheets)
export function slideInBottom(
  node: Element,
  { delay = 0, duration = 300, easing = cubicOut } = {}
): TransitionConfig {
  const style = getComputedStyle(node);
  const opacity = +style.opacity;
  const height = parseFloat(style.height);

  return {
    delay,
    duration,
    easing,
    css: (t) => `
      opacity: ${t * opacity};
      transform: translateY(${(1 - t) * height}px);
    `
  };
}

// Float animation (for hover effects)
export function float(
  node: Element,
  { delay = 0, duration = 600, easing = cubicInOut, y = 10 } = {}
): TransitionConfig {
  return {
    delay,
    duration,
    easing,
    css: (t) => `
      transform: translateY(${Math.sin(t * Math.PI) * y}px);
    `
  };
}

// Stagger children animation helper
export function getStaggerDelay(index: number, baseDelay: number = 50): number {
  return index * baseDelay;
}
```

### 5.2 Usage in Components

```svelte
<script>
  import { fade, fly, slide } from 'svelte/transition';
  import { scaleIn, slideInRight } from '$lib/transitions';

  let isVisible = $state(false);
  let items = $state(['Item 1', 'Item 2', 'Item 3']);
</script>

<!-- Basic fade -->
{#if isVisible}
  <div transition:fade={{ duration: 200 }}>
    Fade content
  </div>
{/if}

<!-- Fly from bottom -->
{#if isVisible}
  <div transition:fly={{ y: 50, duration: 300 }}>
    Fly content
  </div>
{/if}

<!-- Custom scale transition -->
{#if isVisible}
  <div transition:scaleIn={{ duration: 300, start: 0.9 }}>
    Scale content
  </div>
{/if}

<!-- Staggered list -->
{#each items as item, i}
  <div
    in:fly={{ y: 20, duration: 300, delay: i * 50 }}
    out:fade={{ duration: 150 }}
  >
    {item}
  </div>
{/each}
```

### 5.3 CSS Animation Utilities

```css
/* Add to global.css */

/* Pulse animation (like Flutter's breathing effect) */
@keyframes pulse {
  0%, 100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.7;
    transform: scale(1.02);
  }
}

.animate-pulse-soft {
  animation: pulse 2s ease-in-out infinite;
}

/* Shimmer loading effect */
@keyframes shimmer {
  0% {
    background-position: -200% 0;
  }
  100% {
    background-position: 200% 0;
  }
}

.animate-shimmer {
  background: linear-gradient(
    90deg,
    transparent 0%,
    rgba(255, 255, 255, 0.1) 50%,
    transparent 100%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}

/* Float on hover */
.hover-float {
  transition: transform 0.3s ease;
}

.hover-float:hover {
  transform: translateY(-4px);
}

/* Scale on hover */
.hover-scale {
  transition: transform 0.2s ease;
}

.hover-scale:hover {
  transform: scale(1.05);
}

.hover-scale:active {
  transform: scale(0.98);
}
```

---

## 6. Icon System

### 6.1 lucide-svelte Setup

```bash
npm install lucide-svelte
```

### 6.2 Icon Component Wrapper

**File:** `src/lib/components/Icon.svelte`

```svelte
<script lang="ts">
  import type { ComponentType } from 'svelte';
  import * as icons from 'lucide-svelte';

  interface Props {
    name: keyof typeof icons;
    size?: number | string;
    color?: string;
    strokeWidth?: number;
    class?: string;
  }

  let {
    name,
    size = 24,
    color = 'currentColor',
    strokeWidth = 2,
    class: className = ''
  }: Props = $props();

  let IconComponent = $derived(icons[name] as ComponentType);
</script>

{#if IconComponent}
  <svelte:component
    this={IconComponent}
    {size}
    {color}
    {strokeWidth}
    class={className}
  />
{/if}
```

### 6.3 Common Icons Reference

```typescript
// Navigation icons
import {
  Home,
  Menu,
  X,
  ChevronRight,
  ChevronLeft,
  ChevronDown,
  ChevronUp,
  ArrowLeft,
  ArrowRight,
} from 'lucide-svelte';

// Action icons
import {
  Search,
  Plus,
  Minus,
  Edit,
  Trash2,
  Download,
  Upload,
  Share,
  Copy,
  Check,
  X as Close,
} from 'lucide-svelte';

// User icons
import {
  User,
  Users,
  UserPlus,
  LogIn,
  LogOut,
  Settings,
} from 'lucide-svelte';

// App-specific icons
import {
  GitBranch,      // Fluxogramas
  Bot,            // Assistente
  FileText,       // Histórico
  GraduationCap,  // Cursos
  BookOpen,       // Disciplinas
  CheckCircle,    // Concluído
  Clock,          // Em andamento
  Lock,           // Bloqueado
} from 'lucide-svelte';

// Status icons
import {
  AlertCircle,
  AlertTriangle,
  Info,
  HelpCircle,
  CheckCircle2,
  XCircle,
} from 'lucide-svelte';
```

### 6.4 Usage Examples

```svelte
<script>
  import { Home, Menu, GitBranch, Bot } from 'lucide-svelte';
  import Icon from '$lib/components/Icon.svelte';
</script>

<!-- Direct import -->
<Home size={24} class="text-white" />

<!-- With wrapper component -->
<Icon name="Home" size={24} color="white" />

<!-- In a button -->
<button class="flex items-center gap-2">
  <GitBranch size={20} />
  <span>Fluxogramas</span>
</button>

<!-- With dynamic color -->
<Bot size={24} class="text-purple-500 hover:text-pink-500 transition-colors" />
```

---

## 7. Form Components

### 7.1 TextInput Component

**File:** `src/lib/components/forms/TextInput.svelte`

```svelte
<script lang="ts">
  import { cn } from '$lib/utils';
  import { AlertCircle } from 'lucide-svelte';

  interface Props {
    name: string;
    label?: string;
    placeholder?: string;
    type?: 'text' | 'email' | 'password' | 'number' | 'tel' | 'url';
    value?: string;
    error?: string;
    disabled?: boolean;
    required?: boolean;
    autocomplete?: string;
    class?: string;
    onchange?: (value: string) => void;
    oninput?: (value: string) => void;
  }

  let {
    name,
    label,
    placeholder = '',
    type = 'text',
    value = $bindable(''),
    error,
    disabled = false,
    required = false,
    autocomplete,
    class: className = '',
    onchange,
    oninput,
  }: Props = $props();

  let focused = $state(false);

  function handleInput(e: Event) {
    const target = e.target as HTMLInputElement;
    value = target.value;
    oninput?.(value);
  }

  function handleChange(e: Event) {
    const target = e.target as HTMLInputElement;
    value = target.value;
    onchange?.(value);
  }
</script>

<div class={cn('text-input-wrapper', className)}>
  {#if label}
    <label
      for={name}
      class="block text-sm font-medium text-white/80 mb-1.5"
    >
      {label}
      {#if required}
        <span class="text-pink-500">*</span>
      {/if}
    </label>
  {/if}

  <div class="relative">
    <input
      {type}
      {name}
      id={name}
      {placeholder}
      {value}
      {disabled}
      {required}
      {autocomplete}
      class={cn(
        'w-full px-4 py-3 rounded-xl',
        'bg-white/10 border border-white/20',
        'text-white placeholder-white/40',
        'focus:outline-none focus:ring-2 focus:ring-purple-500/50',
        'focus:border-purple-500',
        'transition-all duration-200',
        'disabled:opacity-50 disabled:cursor-not-allowed',
        error && 'border-red-500 focus:ring-red-500/50',
      )}
      on:input={handleInput}
      on:change={handleChange}
      on:focus={() => focused = true}
      on:blur={() => focused = false}
    />

    {#if error}
      <div class="absolute right-3 top-1/2 -translate-y-1/2">
        <AlertCircle size={20} class="text-red-500" />
      </div>
    {/if}
  </div>

  {#if error}
    <p class="mt-1.5 text-sm text-red-400 flex items-center gap-1">
      {error}
    </p>
  {/if}
</div>
```

### 7.2 Select Component

**File:** `src/lib/components/forms/Select.svelte`

```svelte
<script lang="ts">
  import { cn } from '$lib/utils';
  import { ChevronDown } from 'lucide-svelte';

  interface Option {
    value: string;
    label: string;
    disabled?: boolean;
  }

  interface Props {
    name: string;
    label?: string;
    placeholder?: string;
    options: Option[];
    value?: string;
    error?: string;
    disabled?: boolean;
    required?: boolean;
    class?: string;
    onchange?: (value: string) => void;
  }

  let {
    name,
    label,
    placeholder = 'Selecione uma opção',
    options,
    value = $bindable(''),
    error,
    disabled = false,
    required = false,
    class: className = '',
    onchange,
  }: Props = $props();

  function handleChange(e: Event) {
    const target = e.target as HTMLSelectElement;
    value = target.value;
    onchange?.(value);
  }
</script>

<div class={cn('select-wrapper', className)}>
  {#if label}
    <label
      for={name}
      class="block text-sm font-medium text-white/80 mb-1.5"
    >
      {label}
      {#if required}
        <span class="text-pink-500">*</span>
      {/if}
    </label>
  {/if}

  <div class="relative">
    <select
      {name}
      id={name}
      {value}
      {disabled}
      {required}
      class={cn(
        'w-full px-4 py-3 pr-10 rounded-xl appearance-none',
        'bg-white/10 border border-white/20',
        'text-white',
        'focus:outline-none focus:ring-2 focus:ring-purple-500/50',
        'focus:border-purple-500',
        'transition-all duration-200',
        'disabled:opacity-50 disabled:cursor-not-allowed',
        error && 'border-red-500 focus:ring-red-500/50',
        !value && 'text-white/40',
      )}
      on:change={handleChange}
    >
      <option value="" disabled>{placeholder}</option>
      {#each options as option}
        <option
          value={option.value}
          disabled={option.disabled}
          class="bg-gray-900 text-white"
        >
          {option.label}
        </option>
      {/each}
    </select>

    <div class="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
      <ChevronDown size={20} class="text-white/60" />
    </div>
  </div>

  {#if error}
    <p class="mt-1.5 text-sm text-red-400">{error}</p>
  {/if}
</div>
```

### 7.3 Form Validation Hook

**File:** `src/lib/hooks/useForm.ts`

```typescript
import { writable, derived, get, type Readable, type Writable } from 'svelte/store';

type ValidationRule<T> = (value: T, values: Record<string, unknown>) => string | undefined;

interface FieldConfig<T> {
  initialValue: T;
  rules?: ValidationRule<T>[];
}

interface FormConfig {
  [key: string]: FieldConfig<unknown>;
}

interface FormState {
  values: Record<string, unknown>;
  errors: Record<string, string>;
  touched: Record<string, boolean>;
  isValid: boolean;
  isSubmitting: boolean;
}

export function createForm<T extends FormConfig>(config: T) {
  const initialValues: Record<string, unknown> = {};
  const rules: Record<string, ValidationRule<unknown>[]> = {};

  for (const [key, field] of Object.entries(config)) {
    initialValues[key] = field.initialValue;
    rules[key] = field.rules || [];
  }

  const values: Writable<Record<string, unknown>> = writable(initialValues);
  const errors: Writable<Record<string, string>> = writable({});
  const touched: Writable<Record<string, boolean>> = writable({});
  const isSubmitting: Writable<boolean> = writable(false);

  const isValid: Readable<boolean> = derived(
    [errors, touched],
    ([$errors, $touched]) => {
      const hasErrors = Object.values($errors).some(e => !!e);
      const allTouched = Object.keys(config).every(k => $touched[k]);
      return !hasErrors && allTouched;
    }
  );

  function validate(field?: string): boolean {
    const currentValues = get(values);
    const currentErrors: Record<string, string> = {};
    const fieldsToValidate = field ? [field] : Object.keys(rules);

    for (const key of fieldsToValidate) {
      const fieldRules = rules[key] || [];
      for (const rule of fieldRules) {
        const error = rule(currentValues[key], currentValues);
        if (error) {
          currentErrors[key] = error;
          break;
        }
      }
    }

    errors.update(e => ({ ...e, ...currentErrors }));
    return Object.keys(currentErrors).length === 0;
  }

  function setValue(field: string, value: unknown) {
    values.update(v => ({ ...v, [field]: value }));
    touched.update(t => ({ ...t, [field]: true }));
    validate(field);
  }

  function reset() {
    values.set(initialValues);
    errors.set({});
    touched.set({});
    isSubmitting.set(false);
  }

  async function handleSubmit(onSubmit: (values: Record<string, unknown>) => Promise<void>) {
    // Mark all fields as touched
    const allTouched: Record<string, boolean> = {};
    for (const key of Object.keys(config)) {
      allTouched[key] = true;
    }
    touched.set(allTouched);

    if (!validate()) return;

    isSubmitting.set(true);
    try {
      await onSubmit(get(values));
    } finally {
      isSubmitting.set(false);
    }
  }

  return {
    values,
    errors,
    touched,
    isValid,
    isSubmitting,
    setValue,
    validate,
    reset,
    handleSubmit,
  };
}

// Common validation rules
export const required = (message = 'Campo obrigatório'): ValidationRule<unknown> =>
  (value) => (!value || (typeof value === 'string' && !value.trim())) ? message : undefined;

export const email = (message = 'Email inválido'): ValidationRule<string> =>
  (value) => {
    if (!value) return undefined;
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(value) ? undefined : message;
  };

export const minLength = (min: number, message?: string): ValidationRule<string> =>
  (value) => {
    if (!value) return undefined;
    return value.length >= min ? undefined : message || `Mínimo ${min} caracteres`;
  };

export const matches = (fieldName: string, message = 'Os campos não coincidem'): ValidationRule<unknown> =>
  (value, values) => value === values[fieldName] ? undefined : message;
```

---

## 8. Modal/Dialog Patterns

### 8.1 Dialog Component (using shadcn)

**File:** `src/lib/components/ui/ConfirmDialog.svelte`

```svelte
<script lang="ts">
  import * as Dialog from '$lib/components/ui/dialog';
  import { Button } from '$lib/components/ui/button';
  import { AlertTriangle, Info, CheckCircle } from 'lucide-svelte';

  type DialogType = 'info' | 'warning' | 'success' | 'confirm';

  interface Props {
    open: boolean;
    type?: DialogType;
    title: string;
    description?: string;
    confirmText?: string;
    cancelText?: string;
    onConfirm?: () => void;
    onCancel?: () => void;
    children?: import('svelte').Snippet;
  }

  let {
    open = $bindable(false),
    type = 'confirm',
    title,
    description,
    confirmText = 'Confirmar',
    cancelText = 'Cancelar',
    onConfirm,
    onCancel,
    children
  }: Props = $props();

  const icons = {
    info: Info,
    warning: AlertTriangle,
    success: CheckCircle,
    confirm: Info,
  };

  const iconColors = {
    info: 'text-blue-500',
    warning: 'text-amber-500',
    success: 'text-green-500',
    confirm: 'text-purple-500',
  };

  function handleConfirm() {
    onConfirm?.();
    open = false;
  }

  function handleCancel() {
    onCancel?.();
    open = false;
  }
</script>

<Dialog.Root bind:open>
  <Dialog.Content class="bg-gray-900 border-white/10 text-white max-w-md">
    <Dialog.Header>
      <div class="flex items-center gap-3">
        <div class={iconColors[type]}>
          <svelte:component this={icons[type]} size={24} />
        </div>
        <Dialog.Title class="text-xl font-semibold">{title}</Dialog.Title>
      </div>
      {#if description}
        <Dialog.Description class="text-white/70 mt-2">
          {description}
        </Dialog.Description>
      {/if}
    </Dialog.Header>

    {#if children}
      <div class="py-4">
        {@render children()}
      </div>
    {/if}

    <Dialog.Footer class="flex gap-3">
      {#if type === 'confirm'}
        <Button variant="outline" onclick={handleCancel}>
          {cancelText}
        </Button>
      {/if}
      <Button
        class="bg-gradient-to-r from-purple-500 to-pink-500 hover:opacity-90"
        onclick={handleConfirm}
      >
        {confirmText}
      </Button>
    </Dialog.Footer>
  </Dialog.Content>
</Dialog.Root>
```

### 8.2 Sheet Component (Mobile Drawer)

**File:** `src/lib/components/ui/BottomSheet.svelte`

```svelte
<script lang="ts">
  import * as Sheet from '$lib/components/ui/sheet';
  import { X } from 'lucide-svelte';

  interface Props {
    open: boolean;
    title?: string;
    side?: 'top' | 'right' | 'bottom' | 'left';
    class?: string;
    children?: import('svelte').Snippet;
    footer?: import('svelte').Snippet;
  }

  let {
    open = $bindable(false),
    title,
    side = 'bottom',
    class: className = '',
    children,
    footer
  }: Props = $props();
</script>

<Sheet.Root bind:open>
  <Sheet.Content
    {side}
    class="bg-gray-900 border-white/10 text-white {className}"
  >
    {#if title}
      <Sheet.Header class="border-b border-white/10 pb-4">
        <div class="flex items-center justify-between">
          <Sheet.Title class="text-lg font-semibold">{title}</Sheet.Title>
          <button
            onclick={() => open = false}
            class="p-2 hover:bg-white/10 rounded-lg transition-colors"
          >
            <X size={20} />
          </button>
        </div>
      </Sheet.Header>
    {/if}

    <div class="flex-1 overflow-y-auto py-4">
      {@render children?.()}
    </div>

    {#if footer}
      <Sheet.Footer class="border-t border-white/10 pt-4">
        {@render footer()}
      </Sheet.Footer>
    {/if}
  </Sheet.Content>
</Sheet.Root>
```

### 8.3 Modal Store Pattern

**File:** `src/lib/stores/modal.ts`

```typescript
import { writable } from 'svelte/store';

export type ModalType = 'confirm' | 'alert' | 'custom';

interface ModalConfig {
  type: ModalType;
  title: string;
  description?: string;
  confirmText?: string;
  cancelText?: string;
  component?: unknown; // For custom modals
  props?: Record<string, unknown>;
  onConfirm?: () => void | Promise<void>;
  onCancel?: () => void;
}

interface ModalState {
  isOpen: boolean;
  config: ModalConfig | null;
}

function createModalStore() {
  const { subscribe, set, update } = writable<ModalState>({
    isOpen: false,
    config: null,
  });

  return {
    subscribe,
    open: (config: ModalConfig) => {
      set({ isOpen: true, config });
    },
    close: () => {
      set({ isOpen: false, config: null });
    },
    confirm: (options: Omit<ModalConfig, 'type'>) => {
      return new Promise<boolean>((resolve) => {
        set({
          isOpen: true,
          config: {
            type: 'confirm',
            ...options,
            onConfirm: () => {
              options.onConfirm?.();
              resolve(true);
            },
            onCancel: () => {
              options.onCancel?.();
              resolve(false);
            },
          },
        });
      });
    },
    alert: (title: string, description?: string) => {
      return new Promise<void>((resolve) => {
        set({
          isOpen: true,
          config: {
            type: 'alert',
            title,
            description,
            confirmText: 'OK',
            onConfirm: () => resolve(),
          },
        });
      });
    },
  };
}

export const modal = createModalStore();
```

---

## 9. Toast Notifications

### 9.1 Sonner Setup

```bash
npm install svelte-sonner
```

### 9.2 Toast Provider Setup

**File:** `src/routes/+layout.svelte`

```svelte
<script>
  import { Toaster } from 'svelte-sonner';
</script>

<slot />

<Toaster
  position="top-right"
  richColors
  closeButton
  theme="dark"
  toastOptions={{
    style: 'background: rgba(26, 26, 26, 0.95); border: 1px solid rgba(255,255,255,0.1);',
    className: 'font-sans',
  }}
/>
```

### 9.3 Toast Utility Functions

**File:** `src/lib/utils/toast.ts`

```typescript
import { toast as sonnerToast } from 'svelte-sonner';

interface ToastOptions {
  description?: string;
  duration?: number;
  action?: {
    label: string;
    onClick: () => void;
  };
}

export const toast = {
  success: (message: string, options?: ToastOptions) => {
    sonnerToast.success(message, {
      description: options?.description,
      duration: options?.duration || 4000,
      action: options?.action,
    });
  },

  error: (message: string, options?: ToastOptions) => {
    sonnerToast.error(message, {
      description: options?.description,
      duration: options?.duration || 5000,
      action: options?.action,
    });
  },

  warning: (message: string, options?: ToastOptions) => {
    sonnerToast.warning(message, {
      description: options?.description,
      duration: options?.duration || 4000,
      action: options?.action,
    });
  },

  info: (message: string, options?: ToastOptions) => {
    sonnerToast.info(message, {
      description: options?.description,
      duration: options?.duration || 4000,
      action: options?.action,
    });
  },

  loading: (message: string) => {
    return sonnerToast.loading(message);
  },

  promise: <T>(
    promise: Promise<T>,
    messages: {
      loading: string;
      success: string | ((data: T) => string);
      error: string | ((error: Error) => string);
    }
  ) => {
    return sonnerToast.promise(promise, messages);
  },

  dismiss: (toastId?: string | number) => {
    sonnerToast.dismiss(toastId);
  },
};
```

### 9.4 Usage Examples

```svelte
<script>
  import { toast } from '$lib/utils/toast';

  async function handleSave() {
    toast.promise(
      saveData(),
      {
        loading: 'Salvando...',
        success: 'Dados salvos com sucesso!',
        error: (err) => `Erro ao salvar: ${err.message}`,
      }
    );
  }

  function showNotifications() {
    toast.success('Operação concluída!');
    toast.error('Algo deu errado');
    toast.warning('Atenção: verifique os dados');
    toast.info('Nova atualização disponível', {
      action: {
        label: 'Atualizar',
        onClick: () => window.location.reload(),
      },
    });
  }
</script>

<button onclick={showNotifications}>
  Mostrar Notificações
</button>
```

---

## 10. Dark Mode

### 10.1 Theme Store

**File:** `src/lib/stores/theme.ts`

```typescript
import { browser } from '$app/environment';
import { writable } from 'svelte/store';

type Theme = 'light' | 'dark' | 'system';

function getInitialTheme(): Theme {
  if (!browser) return 'system';

  const stored = localStorage.getItem('theme') as Theme | null;
  if (stored && ['light', 'dark', 'system'].includes(stored)) {
    return stored;
  }

  return 'system';
}

function getSystemTheme(): 'light' | 'dark' {
  if (!browser) return 'dark';
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function createThemeStore() {
  const { subscribe, set, update } = writable<Theme>(getInitialTheme());

  let currentTheme: Theme = getInitialTheme();

  subscribe(value => {
    currentTheme = value;
  });

  function applyTheme(theme: Theme) {
    if (!browser) return;

    const effectiveTheme = theme === 'system' ? getSystemTheme() : theme;

    document.documentElement.classList.remove('light', 'dark');
    document.documentElement.classList.add(effectiveTheme);
    localStorage.setItem('theme', theme);
  }

  // Listen for system theme changes
  if (browser) {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    mediaQuery.addEventListener('change', () => {
      if (currentTheme === 'system') {
        applyTheme('system');
      }
    });

    // Apply initial theme
    applyTheme(getInitialTheme());
  }

  return {
    subscribe,
    set: (theme: Theme) => {
      set(theme);
      applyTheme(theme);
    },
    toggle: () => {
      update(current => {
        const newTheme = current === 'dark' ? 'light' : 'dark';
        applyTheme(newTheme);
        return newTheme;
      });
    },
    setSystem: () => {
      set('system');
      applyTheme('system');
    },
  };
}

export const theme = createThemeStore();
```

### 10.2 Theme Toggle Component

**File:** `src/lib/components/ThemeToggle.svelte`

```svelte
<script lang="ts">
  import { theme } from '$lib/stores/theme';
  import { Sun, Moon, Monitor } from 'lucide-svelte';

  interface Props {
    showLabel?: boolean;
    size?: number;
  }

  let { showLabel = false, size = 20 }: Props = $props();

  const options = [
    { value: 'light', icon: Sun, label: 'Claro' },
    { value: 'dark', icon: Moon, label: 'Escuro' },
    { value: 'system', icon: Monitor, label: 'Sistema' },
  ] as const;
</script>

<div class="theme-toggle flex items-center gap-1 p-1 bg-white/10 rounded-lg">
  {#each options as option}
    <button
      onclick={() => theme.set(option.value)}
      class="p-2 rounded-md transition-colors
             {$theme === option.value
               ? 'bg-white/20 text-white'
               : 'text-white/60 hover:text-white hover:bg-white/10'}"
      aria-label={option.label}
    >
      <svelte:component this={option.icon} {size} />
      {#if showLabel}
        <span class="ml-2 text-sm">{option.label}</span>
      {/if}
    </button>
  {/each}
</div>
```

### 10.3 CSS Dark Mode Variables

**File:** Add to `src/app.css` or `tailwind.config.js`

```css
/* In app.css */
:root {
  /* Light mode (default for NoFluxo is dark, but keeping this for reference) */
  --bg-primary: #ffffff;
  --bg-secondary: #f5f5f5;
  --text-primary: #1a1a1a;
  --text-secondary: #666666;
  --border-color: rgba(0, 0, 0, 0.1);
}

:root.dark {
  /* Dark mode (default for NoFluxo) */
  --bg-primary: #000000;
  --bg-secondary: #1a1a1a;
  --text-primary: #ffffff;
  --text-secondary: #a0a0a0;
  --border-color: rgba(255, 255, 255, 0.1);
}

/* Usage with Tailwind */
.example {
  @apply bg-[var(--bg-primary)] text-[var(--text-primary)];
}
```

```javascript
// tailwind.config.js
module.exports = {
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // These work with dark: prefix
        background: {
          DEFAULT: 'var(--bg-primary)',
          secondary: 'var(--bg-secondary)',
        },
        foreground: {
          DEFAULT: 'var(--text-primary)',
          secondary: 'var(--text-secondary)',
        },
      },
    },
  },
};
```

---

## Component File Structure

```
src/
├── lib/
│   ├── components/
│   │   ├── ui/                    # shadcn-svelte components
│   │   │   ├── button/
│   │   │   ├── card/
│   │   │   ├── dialog/
│   │   │   ├── sheet/
│   │   │   └── ...
│   │   ├── forms/                 # Form components
│   │   │   ├── TextInput.svelte
│   │   │   ├── Select.svelte
│   │   │   └── FileUpload.svelte
│   │   ├── layout/                # Layout components
│   │   │   ├── AppNavbar.svelte
│   │   │   ├── Footer.svelte
│   │   │   └── PageContainer.svelte
│   │   ├── backgrounds/           # Background components
│   │   │   ├── AnimatedBackground.svelte
│   │   │   └── GraffitiBackground.svelte
│   │   ├── AppLogo.svelte
│   │   ├── GlassContainer.svelte
│   │   ├── GradientCTAButton.svelte
│   │   ├── GradientUnderlineButton.svelte
│   │   ├── SplashWidget.svelte
│   │   ├── ThemeToggle.svelte
│   │   └── Icon.svelte
│   ├── hooks/
│   │   ├── useBreakpoint.ts
│   │   └── useForm.ts
│   ├── stores/
│   │   ├── auth.ts
│   │   ├── theme.ts
│   │   └── modal.ts
│   ├── transitions/
│   │   └── index.ts
│   ├── utils/
│   │   ├── cn.ts                  # Class name utility (from shadcn)
│   │   └── toast.ts
│   └── styles/
│       ├── colors.css
│       ├── typography.css
│       └── global.css
└── routes/
    └── +layout.svelte             # Root layout with Toaster
```

---

## Migration Checklist

- [x] Install shadcn-svelte and required components
- [x] Set up Tailwind CSS with custom colors
- [x] Install lucide-svelte for icons
- [x] Create base components (GlassContainer, GradientCTAButton, etc.)
- [x] Set up AppNavbar with responsive drawer
- [x] Create background components (AnimatedBackground, GraffitiBackground)
- [x] Implement form components with validation
- [x] Set up toast notifications with svelte-sonner
- [x] Configure dark mode (if needed)
- [x] Create transition utilities
- [x] Add breakpoint hooks
- [ ] Test responsive behavior on all breakpoints
- [ ] Verify animations match Flutter implementation

---

## Next Steps

1. **02-AUTHENTICATION.md** - Auth flow with Supabase
2. **03-ROUTING-LAYOUT.md** - SvelteKit routing setup
3. **04-SERVICES-API.md** - API service layer
4. **05-MODELS-TYPES.md** - TypeScript types/interfaces

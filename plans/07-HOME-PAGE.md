# 07 - Home Page Migration Guide

This document provides comprehensive implementation details for migrating the NoFluxo UNB home page from Flutter to SvelteKit.

## Table of Contents

1. [Layout Structure](#1-layout-structure)
2. [Hero Section](#2-hero-section)
3. [Como Funciona Section](#3-como-funciona-section)
4. [Pronto Para Organizar Section](#4-pronto-para-organizar-section)
5. [Sobre Nós Section](#5-sobre-nós-section)
6. [Footer](#6-footer)
7. [Responsive Design](#7-responsive-design)
8. [Animations](#8-animations)
9. [Assets - SVG Handling](#9-assets---svg-handling)
10. [SEO Implementation](#10-seo-implementation)
11. [Complete Page Implementation](#11-complete-page-implementation)

---

## 1. Layout Structure

### Flutter Original Structure

```dart
Scaffold(
  body: Stack(
    children: [
      GraffitiBackground(),           // Full-screen gradient + brick pattern
      SingleChildScrollView(
        Column([
          HeroSection,                // Title + CTA + Illustration
          ComoFuncionaSection,        // How it works (3 feature cards)
          ProntoParaOrganizarSection, // Secondary CTA
          SobreNosSection,            // About + Team members
        ]),
      ),
      Positioned(AppNavbar),          // Fixed navbar
    ],
  )
)
```

### SvelteKit Page Structure

```
src/routes/(public)/+page.svelte     # Home page route
src/lib/components/
├── home/
│   ├── HeroSection.svelte
│   ├── ComoFuncionaSection.svelte
│   ├── ProntoParaOrganizarSection.svelte
│   ├── SobreNosSection.svelte
│   └── FeatureCard.svelte
├── layout/
│   ├── GraffitiBackground.svelte
│   ├── AppNavbar.svelte
│   └── Footer.svelte
```

---

## 2. Hero Section

### Flutter Implementation Analysis

The Flutter hero section includes:
- Title: "TENHA SEU FLUXOGRAMA MUITO RÁPIDO" (with "RÁPIDO" in pink)
- Subtitle with description
- CTA button "ACESSE NOSSO SISTEMA"
- SVG illustration (computer_phone.svg)
- Responsive layout (column on mobile, row on desktop)

### SvelteKit Implementation

**File: `src/lib/components/home/HeroSection.svelte`**

```svelte
<script lang="ts">
  import { goto } from '$app/navigation';
  import { authStore } from '$lib/stores/auth.svelte';
  
  let isHovered = $state(false);
  
  function handleCTAClick() {
    const user = authStore.user;
    if (user) {
      if (user.dadosFluxograma) {
        goto('/meu-fluxograma');
      } else {
        goto('/upload-historico');
      }
    } else {
      goto('/login');
    }
  }
</script>

<section 
  class="relative min-h-[calc(100vh-80px)] flex items-center bg-black/30 pt-20 md:pt-24"
>
  <div class="container mx-auto px-4 md:px-8 lg:px-12 py-12 md:py-16">
    <div class="flex flex-col lg:flex-row items-center justify-center gap-8 lg:gap-12">
      
      <!-- Text Content -->
      <div class="flex-1 text-center lg:text-left max-w-2xl">
        <h1 class="font-permanentMarker text-3xl sm:text-4xl md:text-5xl lg:text-6xl font-bold leading-tight drop-shadow-lg">
          <span class="text-white">TENHA SEU{'\n'}FLUXOGRAMA{'\n'}MUITO </span>
          <span class="text-pink-400">RÁPIDO</span>
        </h1>
        
        <p class="mt-6 md:mt-8 text-sm md:text-lg lg:text-xl text-white/95 font-poppins max-w-lg mx-auto lg:mx-0 leading-relaxed tracking-wide">
          O NO FLUXO UNB TE AJUDA A VER O FLUXOGRAMA DO SEU CURSO E AINDA TE PERMITE ADICIONAR MATÉRIAS OPTATIVAS DE ACORDO COM SUAS ÁREAS DE INTERESSE!
        </p>
        
        <!-- CTA Button -->
        <div class="mt-6 md:mt-10">
          <button
            onmouseenter={() => isHovered = true}
            onmouseleave={() => isHovered = false}
            onclick={handleCTAClick}
            class="inline-block px-6 py-3 md:px-8 md:py-4 rounded-full font-permanentMarker text-sm md:text-lg text-white tracking-wider
                   bg-gradient-to-r from-blue-400 to-blue-700 
                   shadow-lg shadow-blue-800/30
                   transition-all duration-200 ease-in-out
                   {isHovered ? 'scale-105' : 'scale-100'}"
          >
            ACESSE NOSSO SISTEMA
          </button>
        </div>
      </div>
      
      <!-- Illustration -->
      <div class="flex-1 flex justify-center lg:justify-end max-w-md lg:max-w-lg xl:max-w-xl">
        <img 
          src="/icons/computer_phone.svg" 
          alt="Computador e celular mostrando fluxograma"
          class="w-full max-w-[280px] sm:max-w-[400px] lg:max-w-[500px] xl:max-w-[600px] h-auto"
        />
      </div>
    </div>
  </div>
</section>
```

---

## 3. Como Funciona Section

### Flutter Implementation Analysis

The section displays 3 feature cards with:
- Icon in gradient circle
- Title
- Description
- Hover scale animation
- Horizontal layout on wide screens, vertical on mobile

### SvelteKit Implementation

**File: `src/lib/components/home/FeatureCard.svelte`**

```svelte
<script lang="ts">
  import type { Component } from 'svelte';
  
  interface Props {
    icon: Component;
    title: string;
    description: string;
    gradientFrom: string;
    gradientTo: string;
  }
  
  let { icon: Icon, title, description, gradientFrom, gradientTo }: Props = $props();
  let isHovered = $state(false);
</script>

<div
  onmouseenter={() => isHovered = true}
  onmouseleave={() => isHovered = false}
  class="p-6 rounded-xl bg-white/10 border border-white/10 
         transition-transform duration-200 ease-in-out
         {isHovered ? 'scale-105' : 'scale-100'}"
>
  <!-- Icon Container -->
  <div 
    class="w-16 h-16 mx-auto rounded-full flex items-center justify-center"
    style="background: linear-gradient(135deg, {gradientFrom}, {gradientTo})"
  >
    <Icon class="w-8 h-8 text-white" />
  </div>
  
  <!-- Title -->
  <h3 class="mt-4 text-lg md:text-xl font-permanentMarker text-white text-center">
    {title}
  </h3>
  
  <!-- Description -->
  <p class="mt-2 text-sm md:text-base text-gray-300 text-center">
    {description}
  </p>
</div>
```

**File: `src/lib/components/home/ComoFuncionaSection.svelte`**

```svelte
<script lang="ts">
  import FeatureCard from './FeatureCard.svelte';
  import { ClipboardList, PlusCircle, CheckCircle } from 'lucide-svelte';
  
  const features = [
    {
      icon: ClipboardList,
      title: 'VISUALIZE SEU FLUXO',
      description: 'Veja todas as disciplinas do seu curso organizadas por semestre e pré-requisitos.',
      gradientFrom: '#9333EA',
      gradientTo: '#EC4899'
    },
    {
      icon: PlusCircle,
      title: 'ADICIONE OPTATIVAS',
      description: 'Personalize seu fluxograma adicionando matérias optativas de acordo com seus interesses.',
      gradientFrom: '#EC4899',
      gradientTo: '#F97316'
    },
    {
      icon: CheckCircle,
      title: 'ACOMPANHE SEU PROGRESSO',
      description: 'Marque as disciplinas já cursadas e visualize seu progresso no curso de forma clara.',
      gradientFrom: '#F97316',
      gradientTo: '#EAB308'
    }
  ];
</script>

<section class="py-16 md:py-24 bg-black/50">
  <div class="container mx-auto px-4 md:px-8">
    <!-- Section Title -->
    <h2 class="text-2xl md:text-4xl font-permanentMarker text-white text-center mb-12 md:mb-16">
      COMO FUNCIONA
    </h2>
    
    <!-- Feature Cards Grid -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 md:gap-8 max-w-6xl mx-auto">
      {#each features as feature}
        <FeatureCard 
          icon={feature.icon}
          title={feature.title}
          description={feature.description}
          gradientFrom={feature.gradientFrom}
          gradientTo={feature.gradientTo}
        />
      {/each}
    </div>
  </div>
</section>
```

---

## 4. Pronto Para Organizar Section

### Flutter Implementation Analysis

Secondary CTA section with:
- Title: "PRONTO PARA ORGANIZAR SEU FLUXO?"
- Description text
- "COMEÇAR AGORA" button with gradient and hover animation

### SvelteKit Implementation

**File: `src/lib/components/home/ProntoParaOrganizarSection.svelte`**

```svelte
<script lang="ts">
  import { goto } from '$app/navigation';
  
  let isHovered = $state(false);
  
  function handleClick() {
    goto('/login');
  }
</script>

<section class="py-16 md:py-24 bg-black/30">
  <div class="container mx-auto px-4 md:px-8 text-center">
    <!-- Title -->
    <h2 class="text-xl sm:text-2xl md:text-4xl font-permanentMarker text-white tracking-wide drop-shadow-md">
      PRONTO PARA ORGANIZAR SEU FLUXO?
    </h2>
    
    <!-- Description -->
    <p class="mt-6 max-w-xl mx-auto text-sm md:text-base lg:text-lg text-gray-300 font-poppins tracking-wide leading-relaxed drop-shadow-sm">
      Não perca mais tempo tentando entender seu fluxograma. O NoFluxo UNB torna tudo mais simples e visual para você planejar sua jornada acadêmica.
    </p>
    
    <!-- CTA Button -->
    <div class="mt-8 md:mt-10">
      <button
        onmouseenter={() => isHovered = true}
        onmouseleave={() => isHovered = false}
        onclick={handleClick}
        class="inline-block px-8 py-4 md:px-10 md:py-5 rounded-full font-poppins font-bold text-base md:text-xl text-white tracking-widest
               bg-gradient-to-r from-sky-500 to-blue-700
               shadow-lg shadow-blue-900/20
               transition-all duration-200 ease-in-out
               {isHovered ? 'scale-105' : 'scale-100'}"
      >
        COMEÇAR AGORA
      </button>
    </div>
  </div>
</section>
```

---

## 5. Sobre Nós Section

### Flutter Implementation Analysis

About section with:
- Title: "SOBRE NÓS"
- Description card with hover animation
- Feature items with gradient checkmarks
- Team member grid (8 members)
- Responsive layout (2 per row mobile, 4 per row desktop)

### SvelteKit Implementation

**File: `src/lib/components/home/MemberCard.svelte`**

```svelte
<script lang="ts">
  interface Props {
    name: string;
    githubUsername: string;
  }
  
  let { name, githubUsername }: Props = $props();
  let isHovered = $state(false);
  let imageError = $state(false);
  
  const avatarUrl = `https://avatars.githubusercontent.com/${githubUsername}`;
</script>

<div
  onmouseenter={() => isHovered = true}
  onmouseleave={() => isHovered = false}
  class="p-4 md:p-6 rounded-xl bg-white/10 border border-white/10 
         flex flex-col items-center justify-center
         transition-transform duration-200 ease-in-out
         {isHovered ? 'scale-105' : 'scale-100'}"
>
  <!-- Avatar -->
  <div class="w-20 h-20 md:w-24 md:h-24 rounded-full overflow-hidden bg-gray-800">
    {#if imageError}
      <div class="w-full h-full flex items-center justify-center">
        <svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd" />
        </svg>
      </div>
    {:else}
      <img 
        src={avatarUrl}
        alt={`Foto de ${name}`}
        class="w-full h-full object-cover"
        onerror={() => imageError = true}
      />
    {/if}
  </div>
  
  <!-- Name -->
  <h4 class="mt-4 md:mt-6 text-base md:text-lg font-permanentMarker text-white text-center">
    {name}
  </h4>
  
  <!-- Role -->
  <p class="mt-1 md:mt-2 text-xs md:text-sm text-gray-400 font-poppins">
    Desenvolvedor
  </p>
</div>
```

**File: `src/lib/components/home/SobreNosSection.svelte`**

```svelte
<script lang="ts">
  import { Check } from 'lucide-svelte';
  import MemberCard from './MemberCard.svelte';
  
  let isCardHovered = $state(false);
  
  const teamMembers = [
    { name: 'Guilherme Gusmão', githubUsername: 'gusmoles' },
    { name: 'Vitor Marconi', githubUsername: 'Vitor-Trancoso' },
    { name: 'Gustavo Choueiri', githubUsername: 'staann' },
    { name: 'Felipe Lopes', githubUsername: 'darkymeubem' },
    { name: 'Vinícius Pereira', githubUsername: 'Vinicius-Ribeiro04' },
    { name: 'Arthur Fernandes', githubUsername: 'hisarxt' },
    { name: 'Erick Alves', githubUsername: 'erickaalves' },
    { name: 'Arthur Ramalho', githubUsername: 'ArthurNRamalho' }
  ];
  
  const features = [
    { title: 'UX moderna:', description: 'Interface visual clara, responsiva e fácil de navegar.' },
    { title: 'Inteligência Artificial:', description: 'Sugestão de disciplinas alinhadas aos interesses do estudante.' },
    { title: 'Personalização:', description: 'Planejamento acadêmico inteligente e eficiente, adaptado ao perfil do aluno.' }
  ];
</script>

<section class="py-16 md:py-24 bg-black/50">
  <div class="container mx-auto px-4 md:px-8">
    <!-- Section Title -->
    <h2 class="text-2xl md:text-4xl font-permanentMarker text-white text-center mb-8 md:mb-12 drop-shadow-md tracking-wide">
      SOBRE NÓS
    </h2>
    
    <!-- Description Card -->
    <div 
      onmouseenter={() => isCardHovered = true}
      onmouseleave={() => isCardHovered = false}
      class="max-w-5xl mx-auto mb-12 p-6 md:p-8 rounded-3xl bg-white/10 border border-white/20 
             shadow-lg shadow-black/15
             transition-transform duration-200 ease-in-out
             {isCardHovered ? 'scale-[1.02]' : 'scale-100'}"
    >
      <!-- Main Description -->
      <p class="text-sm md:text-base lg:text-lg text-white font-poppins text-justify leading-relaxed">
        O NoFluxoUnB é criado na disciplina de Métodos de Desenvolvimento de Software ministrada pela professora Carla Rocha, com a proposta de desenvolver um software inovador para a comunidade. Nossa proposta foi desenvolver um software que facilita o planejamento acadêmico dos estudantes da UnB, oferecendo um fluxograma interativo, intuitivo e de fácil uso. Visualize matérias equivalentes, selecione disciplinas futuras e receba recomendações personalizadas com inteligência artificial.
      </p>
      
      <!-- Observation -->
      <div class="mt-4 flex flex-wrap items-center justify-center gap-1.5 text-white/80">
        <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
        </svg>
        <span class="text-xs md:text-sm italic">
          <strong>Observação:</strong> Inicialmente disponível para cursos da FGA/UnB, com perspectiva de expansão!
        </span>
      </div>
      
      <!-- Features List -->
      <div class="mt-6 space-y-3">
        {#each features as feature}
          <div class="flex items-start gap-3">
            <!-- Gradient Checkmark -->
            <div class="shrink-0 w-7 h-7 rounded-full bg-gradient-to-r from-pink-500 to-purple-500 flex items-center justify-center">
              <Check class="w-4 h-4 text-white" />
            </div>
            
            <!-- Feature Text -->
            <p class="text-sm md:text-base text-white font-poppins">
              <strong>{feature.title}</strong> {feature.description}
            </p>
          </div>
        {/each}
      </div>
    </div>
    
    <!-- Team Members Grid -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-6 max-w-5xl mx-auto">
      {#each teamMembers as member}
        <MemberCard 
          name={member.name}
          githubUsername={member.githubUsername}
        />
      {/each}
    </div>
  </div>
</section>
```

---

## 6. Footer

### SvelteKit Implementation

**File: `src/lib/components/layout/Footer.svelte`**

```svelte
<script lang="ts">
  import { Github, Linkedin, Mail } from 'lucide-svelte';
  
  const currentYear = new Date().getFullYear();
  
  const links = [
    { label: 'Home', href: '/' },
    { label: 'Fluxogramas', href: '/fluxogramas' },
    { label: 'Sobre', href: '/#sobre-nos' }
  ];
  
  const socialLinks = [
    { icon: Github, href: 'https://github.com/fga-eps-mds/2024.2-NoFluxoUnB', label: 'GitHub' }
  ];
</script>

<footer class="bg-black/70 border-t border-white/10">
  <div class="container mx-auto px-4 md:px-8 py-8 md:py-12">
    <div class="flex flex-col md:flex-row items-center justify-between gap-6">
      
      <!-- Logo & Copyright -->
      <div class="text-center md:text-left">
        <p class="font-permanentMarker text-xl text-white">
          NoFluxo UNB
        </p>
        <p class="mt-2 text-sm text-gray-400 font-poppins">
          © {currentYear} NoFluxo UNB. Todos os direitos reservados.
        </p>
      </div>
      
      <!-- Links -->
      <nav class="flex flex-wrap justify-center gap-4 md:gap-6">
        {#each links as link}
          <a 
            href={link.href}
            class="text-sm text-gray-300 hover:text-white transition-colors font-poppins"
          >
            {link.label}
          </a>
        {/each}
      </nav>
      
      <!-- Social Links -->
      <div class="flex items-center gap-4">
        {#each socialLinks as social}
          <a 
            href={social.href}
            target="_blank"
            rel="noopener noreferrer"
            aria-label={social.label}
            class="text-gray-400 hover:text-white transition-colors"
          >
            <social.icon class="w-5 h-5" />
          </a>
        {/each}
      </div>
    </div>
  </div>
</footer>
```

---

## 7. Responsive Design

### Breakpoint Mapping (Flutter → Tailwind)

| Flutter | Tailwind | Usage |
|---------|----------|-------|
| `screenWidth < 500` | `sm:` (640px) | Small mobile adjustments |
| `screenWidth < 700` | `md:` (768px) | Mobile breakpoint |
| `screenWidth < 900` | `lg:` (1024px) | Tablet/Desktop switch |
| `screenWidth > 1100` | `xl:` (1280px) | Large desktop |
| `screenWidth > 1300` | `2xl:` (1536px) | Extra large |

### Responsive Utilities

**File: `src/lib/utils/breakpoints.ts`**

```typescript
import { browser } from '$app/environment';

export const breakpoints = {
  sm: 640,
  md: 768,
  lg: 1024,
  xl: 1280,
  '2xl': 1536
} as const;

export function getIsMobile(): boolean {
  if (!browser) return false;
  return window.innerWidth < breakpoints.md;
}

export function getIsTablet(): boolean {
  if (!browser) return false;
  return window.innerWidth >= breakpoints.md && window.innerWidth < breakpoints.lg;
}

export function getIsDesktop(): boolean {
  if (!browser) return false;
  return window.innerWidth >= breakpoints.lg;
}
```

### Responsive Hook

**File: `src/lib/hooks/useMediaQuery.svelte.ts`**

```typescript
import { browser } from '$app/environment';

export function useMediaQuery(query: string) {
  let matches = $state(false);
  
  $effect(() => {
    if (!browser) return;
    
    const mediaQuery = window.matchMedia(query);
    matches = mediaQuery.matches;
    
    const handler = (e: MediaQueryListEvent) => {
      matches = e.matches;
    };
    
    mediaQuery.addEventListener('change', handler);
    return () => mediaQuery.removeEventListener('change', handler);
  });
  
  return {
    get matches() { return matches; }
  };
}

// Preset hooks
export function useIsMobile() {
  return useMediaQuery('(max-width: 767px)');
}

export function useIsDesktop() {
  return useMediaQuery('(min-width: 1024px)');
}
```

---

## 8. Animations

### Scroll-Triggered Animations

**File: `src/lib/actions/inview.ts`**

```typescript
export interface InViewOptions {
  root?: Element | null;
  rootMargin?: string;
  threshold?: number | number[];
  once?: boolean;
}

export function inview(node: HTMLElement, options: InViewOptions = {}) {
  const { once = true, rootMargin = '0px', threshold = 0.1 } = options;
  
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          node.dispatchEvent(new CustomEvent('inview'));
          if (once) {
            observer.unobserve(node);
          }
        } else {
          node.dispatchEvent(new CustomEvent('outview'));
        }
      });
    },
    { rootMargin, threshold }
  );
  
  observer.observe(node);
  
  return {
    destroy() {
      observer.unobserve(node);
    }
  };
}
```

### Animated Section Wrapper

**File: `src/lib/components/ui/AnimatedSection.svelte`**

```svelte
<script lang="ts">
  import { inview } from '$lib/actions/inview';
  import { fly, fade } from 'svelte/transition';
  
  interface Props {
    animation?: 'fade' | 'slide-up' | 'slide-left' | 'slide-right';
    delay?: number;
    duration?: number;
    class?: string;
  }
  
  let { 
    animation = 'slide-up', 
    delay = 0, 
    duration = 600,
    class: className = ''
  }: Props = $props();
  
  let isVisible = $state(false);
  
  function handleInView() {
    isVisible = true;
  }
  
  const animations = {
    'fade': { opacity: 0 },
    'slide-up': { y: 50, opacity: 0 },
    'slide-left': { x: -50, opacity: 0 },
    'slide-right': { x: 50, opacity: 0 }
  };
  
  const flyConfig = animations[animation] || animations['slide-up'];
</script>

<div 
  use:inview
  oninview={handleInView}
  class={className}
>
  {#if isVisible}
    <div
      in:fly={{ ...flyConfig, duration, delay }}
    >
      <slot />
    </div>
  {:else}
    <div class="opacity-0">
      <slot />
    </div>
  {/if}
</div>
```

### Hover Animations (CSS Approach)

```svelte
<!-- Add to global styles or component -->
<style>
  .hover-scale {
    @apply transition-transform duration-200 ease-in-out;
  }
  
  .hover-scale:hover {
    @apply scale-105;
  }
  
  .hover-glow {
    @apply transition-shadow duration-200;
  }
  
  .hover-glow:hover {
    @apply shadow-lg shadow-blue-500/25;
  }
</style>
```

### Button Animation Component

**File: `src/lib/components/ui/AnimatedButton.svelte`**

```svelte
<script lang="ts">
  import type { Snippet } from 'svelte';
  
  interface Props {
    onclick?: () => void;
    href?: string;
    variant?: 'primary' | 'secondary' | 'cta';
    class?: string;
    children: Snippet;
  }
  
  let { onclick, href, variant = 'primary', class: className = '', children }: Props = $props();
  let isHovered = $state(false);
  
  const variants = {
    primary: 'bg-gradient-to-r from-blue-400 to-blue-700',
    secondary: 'bg-gradient-to-r from-purple-500 to-pink-500',
    cta: 'bg-gradient-to-r from-sky-500 to-blue-700'
  };
</script>

{#if href}
  <a 
    {href}
    onmouseenter={() => isHovered = true}
    onmouseleave={() => isHovered = false}
    class="inline-block px-6 py-3 rounded-full text-white font-bold shadow-lg
           transition-all duration-200 ease-in-out
           {variants[variant]}
           {isHovered ? 'scale-105' : 'scale-100'}
           {className}"
  >
    {@render children()}
  </a>
{:else}
  <button 
    {onclick}
    onmouseenter={() => isHovered = true}
    onmouseleave={() => isHovered = false}
    class="inline-block px-6 py-3 rounded-full text-white font-bold shadow-lg
           transition-all duration-200 ease-in-out
           {variants[variant]}
           {isHovered ? 'scale-105' : 'scale-100'}
           {className}"
  >
    {@render children()}
  </button>
{/if}
```

---

## 9. Assets - SVG Handling

### SVG Import Methods in SvelteKit

#### Method 1: Static Assets (Recommended for images)

Place SVGs in `/static/icons/` and reference directly:

```svelte
<img src="/icons/computer_phone.svg" alt="Description" class="w-full h-auto" />
```

#### Method 2: Inline SVG Component (For interactive SVGs)

**File: `src/lib/components/icons/ComputerPhoneIllustration.svelte`**

```svelte
<script lang="ts">
  interface Props {
    class?: string;
  }
  
  let { class: className = '' }: Props = $props();
</script>

<svg 
  class={className}
  viewBox="0 0 800 600" 
  fill="none" 
  xmlns="http://www.w3.org/2000/svg"
>
  <!-- SVG content here -->
</svg>
```

#### Method 3: vite-plugin-svelte-svg (For icons)

Install the plugin:
```bash
npm install -D vite-plugin-svelte-svg
```

Configure in `vite.config.ts`:
```typescript
import { svelteSVG } from 'vite-plugin-svelte-svg';

export default defineConfig({
  plugins: [
    sveltekit(),
    svelteSVG({
      svgoConfig: {},
      requireSuffix: true
    })
  ]
});
```

Use as component:
```svelte
<script>
  import ComputerPhone from '$lib/assets/icons/computer_phone.svg?component';
</script>

<ComputerPhone class="w-full h-auto" />
```

### Graffiti Background SVGs

**File: `src/lib/components/layout/GraffitiBackground.svelte`**

```svelte
<script lang="ts">
  // Generate random positioned decorative elements
  const shapes = [
    { top: '38%', left: '36%', opacity: 0.33, color: '#CA8A04', path: 'M25,0 Q20,28.34 25,56.68 Q30,28.34 25,0 Z' },
    { top: '65%', left: '22%', opacity: 0.32, color: '#E11D48', path: 'M25,0 Q20,29.79 25,59.58 Q30,29.79 25,0 Z' },
    { top: '70%', left: '62%', opacity: 0.30, color: '#EA580C', path: 'M25,0 Q20,29.09 25,58.19 Q30,29.09 25,0 Z' },
    { top: '1%', left: '56%', opacity: 0.32, color: '#4A1D96', path: 'M25,0 Q20,18.40 25,36.81 Q30,18.40 25,0 Z' }
  ];
  
  const circles = [
    { top: '31%', left: '8%', opacity: 0.68, color: '#4ade80', size: 5 },
    { top: '15%', left: '75%', opacity: 0.55, color: '#EC4899', size: 4 },
    { top: '85%', left: '45%', opacity: 0.45, color: '#60A5FA', size: 6 }
  ];
</script>

<div class="fixed inset-0 -z-10 overflow-hidden">
  <!-- Gradient Background -->
  <div 
    class="absolute inset-0"
    style="background: linear-gradient(135deg, #9333EA 0%, #E11D48 30%, #EA580C 50%, #CA8A04 70%, #000000 100%)"
  ></div>
  
  <!-- Brick Wall Pattern Overlay -->
  <svg class="absolute inset-0 w-full h-full opacity-10" preserveAspectRatio="none">
    <defs>
      <pattern id="brick" x="0" y="0" width="60" height="30" patternUnits="userSpaceOnUse">
        <rect x="0" y="0" width="60" height="30" fill="none" stroke="white" stroke-width="1" />
      </pattern>
    </defs>
    <rect width="100%" height="100%" fill="url(#brick)" />
  </svg>
  
  <!-- Decorative Shapes -->
  {#each shapes as shape}
    <svg 
      class="absolute pointer-events-none"
      style="top: {shape.top}; left: {shape.left}; opacity: {shape.opacity}"
      width="50" 
      height="100" 
      viewBox="0 0 50 100"
    >
      <path d={shape.path} fill={shape.color} />
    </svg>
  {/each}
  
  <!-- Decorative Circles -->
  {#each circles as circle}
    <svg 
      class="absolute pointer-events-none"
      style="top: {circle.top}; left: {circle.left}; opacity: {circle.opacity}"
      width="20" 
      height="20" 
      viewBox="0 0 20 20"
    >
      <circle cx="10" cy="10" r={circle.size} fill={circle.color} />
    </svg>
  {/each}
</div>
```

### Copying Assets

Copy the Flutter SVG assets to SvelteKit:

```bash
# From project root
mkdir -p no_fluxo_frontend_svelte/static/icons
cp no_fluxo_frontend/assets/icons/*.svg no_fluxo_frontend_svelte/static/icons/
```

---

## 10. SEO Implementation

### Page-Level SEO

**File: `src/routes/(public)/+page.ts`**

```typescript
import type { MetaTagsProps } from 'svelte-meta-tags';

export const load = () => {
  const pageMetaTags: MetaTagsProps = {
    title: 'NoFluxo UNB - Tenha Seu Fluxograma Muito Mais Fácil',
    titleTemplate: '%s',
    description: 'O NoFluxo UNB te ajuda a ver o fluxograma do seu curso e permite adicionar matérias optativas de acordo com suas áreas de interesse. Planejamento acadêmico inteligente para estudantes da UnB.',
    canonical: 'https://nofluxounb.com.br',
    openGraph: {
      type: 'website',
      url: 'https://nofluxounb.com.br',
      title: 'NoFluxo UNB - Fluxograma Interativo para Estudantes',
      description: 'Visualize seu fluxograma, adicione optativas e acompanhe seu progresso acadêmico na UnB.',
      siteName: 'NoFluxo UNB',
      images: [
        {
          url: 'https://nofluxounb.com.br/og-image.png',
          width: 1200,
          height: 630,
          alt: 'NoFluxo UNB Preview'
        }
      ],
      locale: 'pt_BR'
    },
    twitter: {
      cardType: 'summary_large_image',
      title: 'NoFluxo UNB - Fluxograma Interativo',
      description: 'Planejamento acadêmico inteligente para estudantes da UnB.',
      image: 'https://nofluxounb.com.br/twitter-image.png'
    },
    additionalMetaTags: [
      { name: 'keywords', content: 'UnB, fluxograma, planejamento acadêmico, FGA, disciplinas, grade curricular' },
      { name: 'author', content: 'NoFluxo UNB Team' },
      { name: 'robots', content: 'index, follow' },
      { property: 'og:locale', content: 'pt_BR' }
    ]
  };

  return { pageMetaTags };
};
```

### Structured Data (JSON-LD)

**File: `src/routes/(public)/+page.svelte`**

Add structured data in the page:

```svelte
<script lang="ts">
  import { JsonLd } from 'svelte-meta-tags';
  
  const structuredData = {
    '@context': 'https://schema.org',
    '@type': 'WebApplication',
    name: 'NoFluxo UNB',
    description: 'Ferramenta de planejamento acadêmico para estudantes da UnB',
    url: 'https://nofluxounb.com.br',
    applicationCategory: 'EducationalApplication',
    operatingSystem: 'Web',
    offers: {
      '@type': 'Offer',
      price: '0',
      priceCurrency: 'BRL'
    },
    creator: {
      '@type': 'Organization',
      name: 'NoFluxo UNB Team',
      url: 'https://github.com/fga-eps-mds/2024.2-NoFluxoUnB'
    }
  };
</script>

<JsonLd schema={structuredData} />
```

### Install svelte-meta-tags

```bash
npm install svelte-meta-tags
```

Configure in layout:

**File: `src/routes/+layout.svelte`**

```svelte
<script lang="ts">
  import { MetaTags } from 'svelte-meta-tags';
  import type { LayoutData } from './$types';
  
  let { data, children } = $props();
  
  const defaultMetaTags = {
    title: 'NoFluxo UNB',
    titleTemplate: '%s | NoFluxo UNB',
    description: 'Planejamento acadêmico inteligente para estudantes da UnB'
  };
  
  const metaTags = data.pageMetaTags ?? defaultMetaTags;
</script>

<MetaTags {...metaTags} />

{@render children()}
```

---

## 11. Complete Page Implementation

### Main Page File

**File: `src/routes/(public)/+page.svelte`**

```svelte
<script lang="ts">
  import { JsonLd } from 'svelte-meta-tags';
  import HeroSection from '$lib/components/home/HeroSection.svelte';
  import ComoFuncionaSection from '$lib/components/home/ComoFuncionaSection.svelte';
  import ProntoParaOrganizarSection from '$lib/components/home/ProntoParaOrganizarSection.svelte';
  import SobreNosSection from '$lib/components/home/SobreNosSection.svelte';
  import Footer from '$lib/components/layout/Footer.svelte';
  
  const structuredData = {
    '@context': 'https://schema.org',
    '@type': 'WebApplication',
    name: 'NoFluxo UNB',
    description: 'Ferramenta de planejamento acadêmico para estudantes da UnB',
    url: 'https://nofluxounb.com.br',
    applicationCategory: 'EducationalApplication',
    operatingSystem: 'Web',
    offers: {
      '@type': 'Offer',
      price: '0',
      priceCurrency: 'BRL'
    }
  };
</script>

<JsonLd schema={structuredData} />

<main class="min-h-screen">
  <HeroSection />
  <ComoFuncionaSection />
  <ProntoParaOrganizarSection />
  <SobreNosSection />
  <Footer />
</main>
```

### Layout with Navbar and Background

**File: `src/routes/(public)/+layout.svelte`**

```svelte
<script lang="ts">
  import GraffitiBackground from '$lib/components/layout/GraffitiBackground.svelte';
  import AppNavbar from '$lib/components/layout/AppNavbar.svelte';
  import { MetaTags } from 'svelte-meta-tags';
  
  let { data, children } = $props();
</script>

<MetaTags {...(data.pageMetaTags ?? {})} />

<div class="relative min-h-screen">
  <GraffitiBackground />
  <AppNavbar />
  {@render children()}
</div>
```

### Global Styles

**File: `src/app.css`**

Add the required font imports:

```css
@import url('https://fonts.googleapis.com/css2?family=Permanent+Marker&family=Poppins:wght@300;400;500;600;700&display=swap');

@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --font-permanent-marker: 'Permanent Marker', cursive;
    --font-poppins: 'Poppins', sans-serif;
  }
  
  body {
    @apply font-poppins antialiased;
  }
}

@layer utilities {
  .font-permanentMarker {
    font-family: var(--font-permanent-marker);
  }
  
  .font-poppins {
    font-family: var(--font-poppins);
  }
}
```

### Tailwind Config Extension

**File: `tailwind.config.js`**

```javascript
/** @type {import('tailwindcss').Config} */
export default {
  // ... existing config
  theme: {
    extend: {
      fontFamily: {
        permanentMarker: ['Permanent Marker', 'cursive'],
        poppins: ['Poppins', 'sans-serif']
      },
      colors: {
        'nofluxo': {
          purple: '#9333EA',
          pink: '#E11D48',
          orange: '#EA580C',
          yellow: '#CA8A04',
          blue: '#1D4ED8'
        }
      },
      animation: {
        'fade-in': 'fadeIn 0.5s ease-out',
        'slide-up': 'slideUp 0.5s ease-out',
        'scale-in': 'scaleIn 0.3s ease-out'
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' }
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(20px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' }
        },
        scaleIn: {
          '0%': { opacity: '0', transform: 'scale(0.95)' },
          '100%': { opacity: '1', transform: 'scale(1)' }
        }
      }
    }
  }
};
```

---

## File Structure Summary

```
src/
├── routes/
│   └── (public)/
│       ├── +layout.svelte        # Public layout with navbar & background
│       ├── +layout.ts            # Layout data (optional)
│       ├── +page.svelte          # Home page
│       └── +page.ts              # Home page SEO data
├── lib/
│   ├── components/
│   │   ├── home/
│   │   │   ├── HeroSection.svelte
│   │   │   ├── ComoFuncionaSection.svelte
│   │   │   ├── FeatureCard.svelte
│   │   │   ├── ProntoParaOrganizarSection.svelte
│   │   │   ├── SobreNosSection.svelte
│   │   │   └── MemberCard.svelte
│   │   ├── layout/
│   │   │   ├── GraffitiBackground.svelte
│   │   │   ├── AppNavbar.svelte
│   │   │   └── Footer.svelte
│   │   └── ui/
│   │       ├── AnimatedSection.svelte
│   │       └── AnimatedButton.svelte
│   ├── actions/
│   │   └── inview.ts             # Intersection observer action
│   ├── hooks/
│   │   └── useMediaQuery.svelte.ts
│   ├── utils/
│   │   └── breakpoints.ts
│   └── stores/
│       └── auth.svelte.ts        # Auth store reference
├── app.css                        # Global styles with fonts
└── static/
    └── icons/
        └── computer_phone.svg     # Hero illustration
```

---

## Migration Checklist

- [x] Create folder structure in `src/lib/components/home/`
- [x] Copy SVG assets to `static/icons/`
- [x] Implement `GraffitiBackground.svelte`
- [x] Implement `HeroSection.svelte`
- [x] Implement `FeatureCard.svelte`
- [x] Implement `ComoFuncionaSection.svelte`
- [x] Implement `ProntoParaOrganizarSection.svelte`
- [x] Implement `MemberCard.svelte`
- [x] Implement `SobreNosSection.svelte`
- [x] Implement `HomeFooter.svelte`
- [x] Add fonts to `app.css`
- [x] Update `tailwind.config.js` with custom config
- [x] Create `+page.svelte` with all sections
- [x] Add SEO meta tags in `<svelte:head>`
- [ ] Test responsive design on mobile/tablet/desktop
- [ ] Test hover animations
- [ ] Test scroll animations (optional)
- [ ] Verify all Portuguese text matches Flutter original

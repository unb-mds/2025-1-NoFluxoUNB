# 08 - Auth Pages Migration Guide

This document provides a complete guide for migrating Flutter authentication pages to SvelteKit with Svelte 5, shadcn-svelte, and superforms with Zod validation.

## Table of Contents

1. [Auth Page Layout](#1-auth-page-layout)
2. [Animated Background](#2-animated-background)
3. [Login Page](#3-login-page)
4. [Signup Page](#4-signup-page)
5. [Password Recovery Page](#5-password-recovery-page)
6. [Anonymous Login Page](#6-anonymous-login-page)
7. [Form Validation with Superforms](#7-form-validation-with-superforms)
8. [Loading States](#8-loading-states)
9. [Error Handling](#9-error-handling)
10. [Redirect Logic](#10-redirect-logic)

---

## 1. Auth Page Layout

### 1.1 Flutter Implementation

The Flutter auth pages use a shared layout structure:
- `AnimatedBackground` - Animated smoke effects on black background
- `AppNavbar` - Navigation bar
- Centered white card with form content
- Maximum width constraint of 440px

### 1.2 SvelteKit Implementation

Create `src/routes/(auth)/+layout.svelte`:

```svelte
<script lang="ts">
  import AnimatedBackground from '$lib/components/AnimatedBackground.svelte';
  import AppNavbar from '$lib/components/AppNavbar.svelte';
  import { Toaster } from '$lib/components/ui/sonner';
  
  let { children } = $props();
</script>

<div class="relative min-h-screen">
  <AnimatedBackground />
  
  <div class="relative z-10 flex min-h-screen flex-col">
    <AppNavbar />
    
    <main class="flex flex-1 items-center justify-center px-6 py-8">
      <div class="w-full max-w-[440px]">
        {@render children()}
      </div>
    </main>
  </div>
</div>

<Toaster position="top-right" richColors />
```

Create `src/routes/(auth)/+layout.ts`:

```typescript
import type { LayoutLoad } from './$types';

export const load: LayoutLoad = async ({ parent }) => {
  // Auth pages are public - no session required
  return {};
};
```

### 1.3 Routing Structure

```
src/routes/(auth)/
├── +layout.svelte          # Shared auth layout
├── +layout.ts              # Layout load function
├── login/
│   ├── +page.svelte        # Login page
│   └── +page.server.ts     # Login form actions
├── signup/
│   ├── +page.svelte        # Signup page
│   └── +page.server.ts     # Signup form actions
├── password-recovery/
│   ├── +page.svelte        # Password recovery page
│   └── +page.server.ts     # Recovery form actions
└── login-anonimo/
    ├── +page.svelte        # Anonymous login page
    └── +page.server.ts     # Anonymous login actions
```

---

## 2. Animated Background

### 2.1 Flutter Implementation Analysis

The Flutter `AnimatedBackground` creates:
- Black background
- Multiple animated "smoke" circles with:
  - Different colors (purple `#6B19C9`, pink `#E63783`, yellow `#F0C419`)
  - Blur/glow effects
  - Movement, scale, and opacity animations
  - Different animation durations (38-55 seconds)

### 2.2 SvelteKit Implementation

Create `src/lib/components/AnimatedBackground.svelte`:

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { browser } from '$app/environment';
  
  interface SmokeConfig {
    size: number;
    color: string;
    topPercent: number;
    leftPercent: number;
    duration: number;
  }
  
  const smokeElements: SmokeConfig[] = [
    { size: 180, color: '#6B19C9', topPercent: 0.10, leftPercent: 0.05, duration: 40 },
    { size: 220, color: '#E63783', topPercent: 0.60, leftPercent: 0.70, duration: 50 },
    { size: 200, color: '#F0C419', topPercent: 0.30, leftPercent: 0.60, duration: 45 },
    { size: 140, color: '#6B19C9', topPercent: 0.70, leftPercent: 0.20, duration: 38 },
    { size: 210, color: '#F0C419', topPercent: 0.76, leftPercent: 0.43, duration: 55 },
  ];
</script>

<div class="fixed inset-0 overflow-hidden bg-black">
  {#each smokeElements as smoke, i}
    <div
      class="smoke-element"
      style="
        --size: {smoke.size}px;
        --color: {smoke.color};
        --top: {smoke.topPercent * 100}%;
        --left: {smoke.leftPercent * 100}%;
        --duration: {smoke.duration}s;
        --delay: {i * 2}s;
      "
    ></div>
  {/each}
</div>

<style>
  .smoke-element {
    position: absolute;
    width: var(--size);
    height: var(--size);
    top: var(--top);
    left: var(--left);
    border-radius: 50%;
    background: transparent;
    box-shadow: 
      0 0 calc(var(--size) * 1.2) calc(var(--size) * 0.56) var(--color);
    animation: 
      smoke-move var(--duration) ease-in-out infinite alternate,
      smoke-scale var(--duration) ease-in-out infinite alternate,
      smoke-opacity var(--duration) ease-in-out infinite alternate;
    animation-delay: var(--delay);
    pointer-events: none;
  }
  
  @keyframes smoke-move {
    0% {
      transform: translate(-3%, -3%);
    }
    100% {
      transform: translate(3%, 3%);
    }
  }
  
  @keyframes smoke-scale {
    0% {
      scale: 0.95;
    }
    100% {
      scale: 1.12;
    }
  }
  
  @keyframes smoke-opacity {
    0% {
      opacity: 0.45;
    }
    100% {
      opacity: 0.7;
    }
  }
</style>
```

---

## 3. Login Page

### 3.1 Flutter Implementation Analysis

The Flutter `LoginForm` includes:
- Error alert banner (warning style)
- "Login" title
- Email input with validation
- Password input with show/hide toggle
- "Lembrar-me" checkbox
- "Esqueceu a senha?" link
- "Entrar" submit button with loading state
- "ou" divider
- Google sign-in button
- "Entrar como Visitante" button
- "Não tem uma conta? Cadastre-se" link

### 3.2 Zod Schema

Create `src/lib/schemas/auth.ts`:

```typescript
import { z } from 'zod';

export const loginSchema = z.object({
  email: z
    .string({ required_error: 'Por favor, insira seu e-mail' })
    .min(1, 'Por favor, insira seu e-mail')
    .email('E-mail inválido')
    .refine((email) => {
      const parts = email.split('@');
      if (parts.length !== 2 || !parts[1]) return false;
      if (!parts[1].includes('.')) return false;
      if (parts[1].startsWith('.') || parts[1].endsWith('.')) return false;
      return true;
    }, 'Inclua um domínio válido após o "@" (ex: gmail.com)'),
  password: z
    .string({ required_error: 'Por favor, insira sua senha' })
    .min(1, 'Por favor, insira sua senha'),
  rememberMe: z.boolean().default(false),
});

export const signupSchema = z.object({
  name: z
    .string({ required_error: 'Por favor, insira seu nome' })
    .min(3, 'Nome deve ter pelo menos 3 caracteres')
    .refine((name) => name.trim().split(' ').length >= 2, 'Insira nome e sobrenome'),
  email: z
    .string({ required_error: 'Por favor, insira seu e-mail' })
    .min(1, 'Por favor, insira seu e-mail')
    .email('E-mail inválido')
    .refine((email) => {
      const parts = email.split('@');
      if (parts.length !== 2 || !parts[1]) return false;
      if (!parts[1].includes('.')) return false;
      if (parts[1].startsWith('.') || parts[1].endsWith('.')) return false;
      return true;
    }, 'Inclua um domínio válido após o "@" (ex: gmail.com)'),
  password: z
    .string({ required_error: 'Por favor, insira sua senha' })
    .min(8, 'A senha deve ter pelo menos 8 caracteres')
    .regex(/[A-Z]/, 'A senha deve conter pelo menos uma letra maiúscula')
    .regex(/[a-z]/, 'A senha deve conter pelo menos uma letra minúscula')
    .regex(/[0-9]/, 'A senha deve conter pelo menos um número')
    .regex(/[!@#$&*~]/, 'A senha deve conter pelo menos um caractere especial (!@#$&*~)'),
  confirmPassword: z
    .string({ required_error: 'Por favor, confirme sua senha' })
    .min(1, 'Por favor, confirme sua senha'),
  acceptTerms: z
    .boolean()
    .refine((val) => val === true, 'Você deve aceitar os Termos de Serviço'),
}).refine((data) => data.password === data.confirmPassword, {
  message: 'As senhas não coincidem',
  path: ['confirmPassword'],
});

export const passwordRecoverySchema = z.object({
  email: z
    .string({ required_error: 'Por favor, insira seu e-mail' })
    .min(1, 'Por favor, insira seu e-mail')
    .email('E-mail inválido'),
});

export type LoginSchema = typeof loginSchema;
export type SignupSchema = typeof signupSchema;
export type PasswordRecoverySchema = typeof passwordRecoverySchema;
```

### 3.3 Login Page Server

Create `src/routes/(auth)/login/+page.server.ts`:

```typescript
import type { Actions, PageServerLoad } from './$types';
import { fail, redirect } from '@sveltejs/kit';
import { superValidate, message } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';
import { loginSchema } from '$lib/schemas/auth';

export const load: PageServerLoad = async ({ locals }) => {
  // Redirect if already logged in
  const session = await locals.supabase.auth.getSession();
  if (session.data.session) {
    throw redirect(303, '/upload-historico');
  }
  
  return {
    form: await superValidate(zod(loginSchema)),
  };
};

export const actions: Actions = {
  login: async ({ request, locals }) => {
    const form = await superValidate(request, zod(loginSchema));
    
    if (!form.valid) {
      return fail(400, { form });
    }
    
    const { email, password } = form.data;
    
    const { data, error } = await locals.supabase.auth.signInWithPassword({
      email,
      password,
    });
    
    if (error) {
      // Map Supabase errors to Portuguese
      let errorMessage = 'Erro ao fazer login';
      if (error.message.includes('Invalid login credentials')) {
        errorMessage = 'E-mail ou senha incorretos';
      } else if (error.message.includes('Email not confirmed')) {
        errorMessage = 'E-mail não confirmado. Verifique sua caixa de entrada.';
      }
      
      return message(form, { type: 'error', text: errorMessage }, { status: 400 });
    }
    
    // Sync user with backend
    try {
      const response = await fetch(`${process.env.PUBLIC_API_URL}/users/get-user-by-email?email=${email}`);
      if (!response.ok) {
        console.error('Failed to sync user with backend');
      }
    } catch (e) {
      console.error('Backend sync error:', e);
    }
    
    throw redirect(303, '/upload-historico');
  },
  
  google: async ({ locals, url }) => {
    const { data, error } = await locals.supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${url.origin}/auth/callback`,
        queryParams: {
          prompt: 'consent',
        },
      },
    });
    
    if (error) {
      return fail(500, { message: 'Erro ao iniciar login com Google' });
    }
    
    throw redirect(303, data.url);
  },
};
```

### 3.4 Login Page Component

Create `src/routes/(auth)/login/+page.svelte`:

```svelte
<script lang="ts">
  import { superForm } from 'sveltekit-superforms';
  import { zodClient } from 'sveltekit-superforms/adapters';
  import { loginSchema } from '$lib/schemas/auth';
  import { Button } from '$lib/components/ui/button';
  import { Input } from '$lib/components/ui/input';
  import { Checkbox } from '$lib/components/ui/checkbox';
  import { Label } from '$lib/components/ui/label';
  import { toast } from 'svelte-sonner';
  import { Eye, EyeOff, AlertTriangle, Loader2 } from 'lucide-svelte';
  import GoogleIcon from '$lib/components/icons/GoogleIcon.svelte';
  
  let { data } = $props();
  
  let showPassword = $state(false);
  
  const { form, errors, enhance, submitting, message } = superForm(data.form, {
    validators: zodClient(loginSchema),
    onError: ({ result }) => {
      toast.error(result.error.message || 'Ocorreu um erro');
    },
    onUpdated: ({ form }) => {
      if (form.message?.type === 'error') {
        toast.error(form.message.text);
      }
    },
  });
  
  // Show error when message changes
  $effect(() => {
    if ($message?.type === 'error') {
      toast.error($message.text);
    }
  });
</script>

<svelte:head>
  <title>Login - NoFluxo</title>
</svelte:head>

<div class="rounded-2xl bg-white p-10 shadow-lg">
  <!-- Error Banner -->
  {#if $message?.type === 'error'}
    <div class="mb-4 flex items-start gap-3 rounded-lg border border-amber-400 bg-amber-50 px-4 py-3">
      <AlertTriangle class="mt-0.5 h-6 w-6 flex-shrink-0 text-amber-500" />
      <p class="text-sm text-gray-800">{$message.text}</p>
    </div>
  {/if}
  
  <h1 class="mb-7 text-center font-poppins text-[28px] font-bold text-gray-800">
    Login
  </h1>
  
  <form method="POST" action="?/login" use:enhance class="space-y-4">
    <!-- Email Input -->
    <div class="space-y-1">
      <Input
        type="email"
        name="email"
        placeholder="E-mail"
        bind:value={$form.email}
        disabled={$submitting}
        class="h-[52px] rounded-[14px] border-gray-300 px-[18px] font-poppins text-base 
               focus:border-blue-600 focus:ring-blue-600"
      />
      {#if $errors.email}
        <p class="text-sm text-red-500">{$errors.email[0]}</p>
      {/if}
    </div>
    
    <!-- Password Input -->
    <div class="space-y-1">
      <div class="relative">
        <Input
          type={showPassword ? 'text' : 'password'}
          name="password"
          placeholder="Senha"
          bind:value={$form.password}
          disabled={$submitting}
          class="h-[52px] rounded-[14px] border-gray-300 px-[18px] pr-12 font-poppins text-base
                 focus:border-blue-600 focus:ring-blue-600"
        />
        <button
          type="button"
          onclick={() => showPassword = !showPassword}
          class="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-gray-500 hover:text-gray-700"
          aria-label={showPassword ? 'Esconder senha' : 'Mostrar senha'}
        >
          {#if showPassword}
            <EyeOff class="h-5 w-5" />
          {:else}
            <Eye class="h-5 w-5" />
          {/if}
        </button>
      </div>
      {#if $errors.password}
        <p class="text-sm text-red-500">{$errors.password[0]}</p>
      {/if}
    </div>
    
    <!-- Remember Me & Forgot Password -->
    <div class="flex items-center justify-between py-1">
      <div class="flex items-center gap-2">
        <Checkbox 
          id="rememberMe" 
          name="rememberMe"
          bind:checked={$form.rememberMe}
          disabled={$submitting}
          class="rounded"
        />
        <Label for="rememberMe" class="cursor-pointer font-poppins text-sm text-gray-600">
          Lembrar-me
        </Label>
      </div>
      
      <a 
        href="/password-recovery" 
        class="font-poppins text-sm text-indigo-500 underline hover:text-indigo-600
               {$submitting ? 'pointer-events-none opacity-50' : ''}"
      >
        Esqueceu a senha?
      </a>
    </div>
    
    <!-- Submit Button -->
    <Button
      type="submit"
      disabled={$submitting}
      class="h-[52px] w-full rounded-[14px] bg-blue-600 font-poppins text-lg font-semibold
             hover:bg-blue-700 disabled:opacity-50"
    >
      {#if $submitting}
        <Loader2 class="mr-2 h-5 w-5 animate-spin" />
      {:else}
        Entrar
      {/if}
    </Button>
  </form>
  
  <!-- Divider -->
  <div class="my-5 flex items-center gap-3">
    <div class="h-px flex-1 bg-gray-300"></div>
    <span class="font-poppins text-sm text-gray-500">ou</span>
    <div class="h-px flex-1 bg-gray-300"></div>
  </div>
  
  <!-- Google Sign In -->
  <form method="POST" action="?/google" use:enhance>
    <Button
      type="submit"
      variant="outline"
      disabled={$submitting}
      class="h-[52px] w-full rounded-[14px] border-gray-300 bg-white font-poppins text-base
             font-semibold text-gray-700 hover:bg-gray-50"
    >
      {#if $submitting}
        <Loader2 class="mr-2 h-5 w-5 animate-spin" />
      {:else}
        <GoogleIcon class="mr-2 h-6 w-6" />
      {/if}
      Entrar com o Google
    </Button>
  </form>
  
  <!-- Anonymous Login -->
  <Button
    href="/login-anonimo"
    variant="default"
    disabled={$submitting}
    class="mt-3 h-[52px] w-full rounded-[14px] bg-gray-800 font-poppins text-[17px] font-medium
           hover:bg-gray-900"
  >
    Entrar como Visitante
  </Button>
  
  <!-- Sign Up Link -->
  <div class="mt-5 text-center">
    <a 
      href="/signup" 
      class="font-poppins text-[15px] font-medium text-gray-800 underline hover:text-gray-900
             {$submitting ? 'pointer-events-none opacity-50' : ''}"
    >
      Não tem uma conta? Cadastre-se
    </a>
  </div>
</div>
```

### 3.5 Google Icon Component

Create `src/lib/components/icons/GoogleIcon.svelte`:

```svelte
<script lang="ts">
  let { class: className = '' } = $props();
</script>

<svg 
  class={className} 
  viewBox="0 0 24 24" 
  xmlns="http://www.w3.org/2000/svg"
>
  <path
    d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
    fill="#4285F4"
  />
  <path
    d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
    fill="#34A853"
  />
  <path
    d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
    fill="#FBBC05"
  />
  <path
    d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
    fill="#EA4335"
  />
</svg>
```

---

## 4. Signup Page

### 4.1 Flutter Implementation Analysis

The Flutter `SignupForm` includes:
- Error banners for email and terms errors
- "Criar Conta" title
- Full name input with validation (first + last name)
- Email input with validation
- Password input with show/hide and strength indicators
- Confirm password input with show/hide
- Terms acceptance checkbox with links
- "Criar conta" submit button (disabled until form valid)
- "ou" divider
- Google sign-up button
- "Já tem uma conta? Faça login" link
- Missing requirements list

### 4.2 Signup Page Server

Create `src/routes/(auth)/signup/+page.server.ts`:

```typescript
import type { Actions, PageServerLoad } from './$types';
import { fail, redirect } from '@sveltejs/kit';
import { superValidate, message } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';
import { signupSchema } from '$lib/schemas/auth';
import { PUBLIC_API_URL } from '$env/static/public';

export const load: PageServerLoad = async ({ locals }) => {
  // Redirect if already logged in
  const session = await locals.supabase.auth.getSession();
  if (session.data.session) {
    throw redirect(303, '/upload-historico');
  }
  
  return {
    form: await superValidate(zod(signupSchema)),
  };
};

export const actions: Actions = {
  signup: async ({ request, locals }) => {
    const form = await superValidate(request, zod(signupSchema));
    
    if (!form.valid) {
      return fail(400, { form });
    }
    
    const { name, email, password } = form.data;
    
    // Create user in Supabase Auth
    const { data: authData, error: authError } = await locals.supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          display_name: name,
        },
      },
    });
    
    if (authError) {
      let errorMessage = 'Erro ao criar conta';
      if (authError.message.includes('already registered')) {
        errorMessage = 'Este e-mail já está em uso. Tente fazer login ou use outro e-mail.';
      } else if (authError.message.includes('weak password')) {
        errorMessage = 'A senha é muito fraca. Use pelo menos 8 caracteres.';
      } else if (authError.message.includes('invalid email')) {
        errorMessage = 'E-mail inválido. Verifique se está correto.';
      }
      
      return message(form, { type: 'error', text: errorMessage }, { status: 400 });
    }
    
    // Register user in backend
    try {
      const response = await fetch(`${PUBLIC_API_URL}/users/registrar-user-with-email`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          email,
          nome_completo: name,
        }),
      });
      
      if (!response.ok) {
        console.error('Failed to register user in backend');
      }
    } catch (e) {
      console.error('Backend registration error:', e);
    }
    
    throw redirect(303, '/upload-historico');
  },
  
  google: async ({ locals, url }) => {
    const { data, error } = await locals.supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${url.origin}/auth/callback`,
        queryParams: {
          prompt: 'consent',
        },
      },
    });
    
    if (error) {
      return fail(500, { message: 'Erro ao iniciar cadastro com Google' });
    }
    
    throw redirect(303, data.url);
  },
};
```

### 4.3 Signup Page Component

Create `src/routes/(auth)/signup/+page.svelte`:

```svelte
<script lang="ts">
  import { superForm } from 'sveltekit-superforms';
  import { zodClient } from 'sveltekit-superforms/adapters';
  import { signupSchema } from '$lib/schemas/auth';
  import { Button } from '$lib/components/ui/button';
  import { Input } from '$lib/components/ui/input';
  import { Checkbox } from '$lib/components/ui/checkbox';
  import { Label } from '$lib/components/ui/label';
  import { toast } from 'svelte-sonner';
  import { Eye, EyeOff, AlertTriangle, Loader2, Check, X, AlertCircle } from 'lucide-svelte';
  import GoogleIcon from '$lib/components/icons/GoogleIcon.svelte';
  
  let { data } = $props();
  
  let showPassword = $state(false);
  let showConfirmPassword = $state(false);
  
  const { form, errors, enhance, submitting, message } = superForm(data.form, {
    validators: zodClient(signupSchema),
    onError: ({ result }) => {
      toast.error(result.error.message || 'Ocorreu um erro');
    },
    onUpdated: ({ form }) => {
      if (form.message?.type === 'error') {
        toast.error(form.message.text);
      }
    },
  });
  
  // Password strength checks
  const passwordChecks = $derived([
    { label: 'Mínimo de 8 caracteres', met: $form.password.length >= 8 },
    { label: 'Letra maiúscula', met: /[A-Z]/.test($form.password) },
    { label: 'Letra minúscula', met: /[a-z]/.test($form.password) },
    { label: 'Número', met: /[0-9]/.test($form.password) },
    { label: 'Caractere especial (!@#$&*~)', met: /[!@#$&*~]/.test($form.password) },
  ]);
  
  // Form validity checks
  const isNameValid = $derived(
    $form.name.trim().split(' ').length >= 2 && $form.name.trim().length >= 3
  );
  const isEmailValid = $derived(
    /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test($form.email)
  );
  const isPasswordValid = $derived(passwordChecks.every(c => c.met));
  const isConfirmPasswordValid = $derived(
    $form.confirmPassword === $form.password && $form.confirmPassword.length > 0
  );
  
  const isFormValid = $derived(
    isNameValid && isEmailValid && isPasswordValid && isConfirmPasswordValid && $form.acceptTerms
  );
  
  const missingRequirements = $derived(() => {
    const missing: string[] = [];
    if (!isNameValid) missing.push('Nome completo válido');
    if (!isEmailValid) missing.push('Email válido');
    if (!isPasswordValid) missing.push('Senha que atenda aos requisitos');
    if (!isConfirmPasswordValid) missing.push('Confirmação de senha');
    if (!$form.acceptTerms) missing.push('Aceitar os termos');
    return missing;
  });
</script>

<svelte:head>
  <title>Criar Conta - NoFluxo</title>
</svelte:head>

<div class="rounded-2xl bg-white px-10 py-4 shadow-lg">
  <!-- Error Banners -->
  {#if $message?.type === 'error'}
    <div class="mb-4 flex items-start gap-3 rounded-lg border border-amber-400 bg-amber-50 px-4 py-3">
      <AlertTriangle class="mt-0.5 h-6 w-6 flex-shrink-0 text-amber-500" />
      <p class="text-sm text-gray-800">{$message.text}</p>
    </div>
  {/if}
  
  <h1 class="mb-7 text-center font-poppins text-[28px] font-bold text-gray-800">
    Criar Conta
  </h1>
  
  <form method="POST" action="?/signup" use:enhance class="space-y-4">
    <!-- Name Input -->
    <div class="space-y-1">
      <Input
        type="text"
        name="name"
        placeholder="Nome completo"
        bind:value={$form.name}
        disabled={$submitting}
        class="h-[52px] rounded-[14px] border-gray-300 px-[18px] font-poppins text-base
               focus:border-blue-600 focus:ring-blue-600
               {$form.name && !isNameValid ? 'border-red-400' : ''}"
      />
      {#if $form.name && !isNameValid}
        <p class="text-sm text-red-500">Insira nome e sobrenome</p>
      {:else if $errors.name}
        <p class="text-sm text-red-500">{$errors.name[0]}</p>
      {/if}
    </div>
    
    <!-- Email Input -->
    <div class="space-y-1">
      <Input
        type="email"
        name="email"
        placeholder="E-mail"
        bind:value={$form.email}
        disabled={$submitting}
        class="h-[52px] rounded-[14px] border-gray-300 px-[18px] font-poppins text-base
               focus:border-blue-600 focus:ring-blue-600
               {$form.email && !isEmailValid ? 'border-red-400' : ''}"
      />
      {#if $form.email && !isEmailValid}
        <p class="text-sm text-red-500">Email inválido</p>
      {:else if $errors.email}
        <p class="text-sm text-red-500">{$errors.email[0]}</p>
      {/if}
    </div>
    
    <!-- Password Input -->
    <div class="space-y-1">
      <div class="relative">
        <Input
          type={showPassword ? 'text' : 'password'}
          name="password"
          placeholder="Senha"
          bind:value={$form.password}
          disabled={$submitting}
          class="h-[52px] rounded-[14px] border-gray-300 px-[18px] pr-12 font-poppins text-base
                 focus:border-blue-600 focus:ring-blue-600
                 {$form.password && !isPasswordValid ? 'border-red-400' : ''}"
        />
        <button
          type="button"
          onclick={() => showPassword = !showPassword}
          class="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-gray-500 hover:text-gray-700"
          aria-label={showPassword ? 'Esconder senha' : 'Mostrar senha'}
        >
          {#if showPassword}
            <EyeOff class="h-5 w-5" />
          {:else}
            <Eye class="h-5 w-5" />
          {/if}
        </button>
      </div>
      {#if $form.password && !isPasswordValid}
        <p class="text-sm text-red-500">Senha não atende aos requisitos</p>
      {:else if $errors.password}
        <p class="text-sm text-red-500">{$errors.password[0]}</p>
      {/if}
    </div>
    
    <!-- Password Strength Indicators -->
    <div class="space-y-1 py-1">
      {#each passwordChecks as check}
        <div class="flex items-center gap-2">
          {#if check.met}
            <Check class="h-4 w-4 text-green-500" />
          {:else}
            <X class="h-4 w-4 text-gray-400" />
          {/if}
          <span class="font-poppins text-xs {check.met ? 'text-green-500' : 'text-gray-500'}">
            {check.label}
          </span>
        </div>
      {/each}
    </div>
    
    <!-- Confirm Password Input -->
    <div class="space-y-1">
      <div class="relative">
        <Input
          type={showConfirmPassword ? 'text' : 'password'}
          name="confirmPassword"
          placeholder="Confirmar senha"
          bind:value={$form.confirmPassword}
          disabled={$submitting}
          class="h-[52px] rounded-[14px] border-gray-300 px-[18px] pr-12 font-poppins text-base
                 focus:border-blue-600 focus:ring-blue-600
                 {$form.confirmPassword && !isConfirmPasswordValid ? 'border-red-400' : ''}"
        />
        <button
          type="button"
          onclick={() => showConfirmPassword = !showConfirmPassword}
          class="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-gray-500 hover:text-gray-700"
          aria-label={showConfirmPassword ? 'Esconder senha' : 'Mostrar senha'}
        >
          {#if showConfirmPassword}
            <EyeOff class="h-5 w-5" />
          {:else}
            <Eye class="h-5 w-5" />
          {/if}
        </button>
      </div>
      {#if $form.confirmPassword && !isConfirmPasswordValid}
        <p class="text-sm text-red-500">As senhas não coincidem</p>
      {:else if $errors.confirmPassword}
        <p class="text-sm text-red-500">{$errors.confirmPassword[0]}</p>
      {/if}
    </div>
    
    <!-- Terms Checkbox -->
    <div class="flex items-start gap-2 py-2">
      <Checkbox 
        id="acceptTerms" 
        name="acceptTerms"
        bind:checked={$form.acceptTerms}
        disabled={$submitting}
        class="mt-1 rounded"
      />
      <Label for="acceptTerms" class="cursor-pointer font-poppins text-[13px] leading-tight text-gray-600">
        Eu concordo com os 
        <a href="/termos" class="text-indigo-500 underline hover:text-indigo-600">Termos de Serviço</a> 
        e 
        <a href="/privacidade" class="text-indigo-500 underline hover:text-indigo-600">Política de Privacidade</a>
      </Label>
    </div>
    {#if $errors.acceptTerms}
      <p class="-mt-2 text-sm text-red-500">{$errors.acceptTerms[0]}</p>
    {/if}
    
    <!-- Submit Button -->
    <Button
      type="submit"
      disabled={!isFormValid || $submitting}
      class="h-[52px] w-full rounded-[14px] bg-blue-600 font-poppins text-lg font-semibold
             hover:bg-blue-700 disabled:bg-gray-300 disabled:opacity-100"
    >
      {#if $submitting}
        <Loader2 class="mr-2 h-5 w-5 animate-spin" />
      {:else}
        Criar conta
      {/if}
    </Button>
  </form>
  
  <!-- Divider -->
  <div class="my-5 flex items-center gap-3">
    <div class="h-px flex-1 bg-gray-300"></div>
    <span class="font-poppins text-sm text-gray-500">ou</span>
    <div class="h-px flex-1 bg-gray-300"></div>
  </div>
  
  <!-- Google Sign Up -->
  <form method="POST" action="?/google" use:enhance>
    <Button
      type="submit"
      variant="outline"
      disabled={$submitting}
      class="h-[52px] w-full rounded-[14px] border-gray-300 bg-white font-poppins text-base
             font-semibold text-gray-700 hover:bg-gray-50"
    >
      {#if $submitting}
        <Loader2 class="mr-2 h-5 w-5 animate-spin" />
      {:else}
        <GoogleIcon class="mr-2 h-6 w-6" />
      {/if}
      Cadastrar com o Google
    </Button>
  </form>
  
  <!-- Login Link -->
  <div class="mt-5 text-center">
    <a 
      href="/login" 
      class="font-poppins text-[15px] font-medium text-gray-800 underline hover:text-gray-900
             {$submitting ? 'pointer-events-none opacity-50' : ''}"
    >
      Já tem uma conta? Faça login
    </a>
  </div>
  
  <!-- Missing Requirements -->
  {#if missingRequirements().length > 0 && ($form.name || $form.email || $form.password)}
    <div class="mt-4 rounded-lg bg-gray-100 p-3">
      <p class="mb-2 font-poppins text-sm font-semibold text-gray-600">Falta preencher:</p>
      <div class="space-y-1">
        {#each missingRequirements() as req}
          <div class="flex items-center gap-2">
            <AlertCircle class="h-4 w-4 text-gray-500" />
            <span class="font-poppins text-xs text-gray-500">{req}</span>
          </div>
        {/each}
      </div>
    </div>
  {/if}
</div>
```

---

## 5. Password Recovery Page

### 5.1 Flutter Implementation Analysis

The Flutter `PasswordRecoveryScreen` includes:
- "Recuperar Senha" title
- Description text
- Email input
- "Enviar link de recuperação" button
- "Voltar para o login" link

### 5.2 Password Recovery Server

Create `src/routes/(auth)/password-recovery/+page.server.ts`:

```typescript
import type { Actions, PageServerLoad } from './$types';
import { fail, redirect } from '@sveltejs/kit';
import { superValidate, message } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';
import { passwordRecoverySchema } from '$lib/schemas/auth';

export const load: PageServerLoad = async ({ locals }) => {
  // Redirect if already logged in
  const session = await locals.supabase.auth.getSession();
  if (session.data.session) {
    throw redirect(303, '/upload-historico');
  }
  
  return {
    form: await superValidate(zod(passwordRecoverySchema)),
  };
};

export const actions: Actions = {
  recover: async ({ request, locals, url }) => {
    const form = await superValidate(request, zod(passwordRecoverySchema));
    
    if (!form.valid) {
      return fail(400, { form });
    }
    
    const { email } = form.data;
    
    const { error } = await locals.supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${url.origin}/auth/reset-password`,
    });
    
    if (error) {
      return message(
        form, 
        { type: 'error', text: 'Erro ao enviar e-mail de recuperação. Tente novamente.' }, 
        { status: 400 }
      );
    }
    
    return message(
      form, 
      { type: 'success', text: `E-mail de recuperação enviado para ${email}` }
    );
  },
};
```

### 5.3 Password Recovery Page Component

Create `src/routes/(auth)/password-recovery/+page.svelte`:

```svelte
<script lang="ts">
  import { superForm } from 'sveltekit-superforms';
  import { zodClient } from 'sveltekit-superforms/adapters';
  import { passwordRecoverySchema } from '$lib/schemas/auth';
  import { Button } from '$lib/components/ui/button';
  import { Input } from '$lib/components/ui/input';
  import { toast } from 'svelte-sonner';
  import { Loader2, CheckCircle, AlertTriangle } from 'lucide-svelte';
  
  let { data } = $props();
  
  const { form, errors, enhance, submitting, message } = superForm(data.form, {
    validators: zodClient(passwordRecoverySchema),
    onError: ({ result }) => {
      toast.error(result.error.message || 'Ocorreu um erro');
    },
    onUpdated: ({ form }) => {
      if (form.message?.type === 'success') {
        toast.success(form.message.text);
      } else if (form.message?.type === 'error') {
        toast.error(form.message.text);
      }
    },
  });
  
  const isSuccess = $derived($message?.type === 'success');
</script>

<svelte:head>
  <title>Recuperar Senha - NoFluxo</title>
</svelte:head>

<div class="rounded-2xl bg-white p-10 shadow-lg">
  {#if isSuccess}
    <!-- Success State -->
    <div class="text-center">
      <div class="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-green-100">
        <CheckCircle class="h-6 w-6 text-green-600" />
      </div>
      <h1 class="mb-2 font-poppins text-xl font-bold text-gray-800">
        E-mail enviado!
      </h1>
      <p class="mb-6 font-poppins text-sm text-gray-500">
        {$message?.text}
      </p>
      <a 
        href="/login" 
        class="font-poppins text-[15px] font-medium text-gray-800 underline hover:text-gray-900"
      >
        Voltar para o login
      </a>
    </div>
  {:else}
    <!-- Form State -->
    {#if $message?.type === 'error'}
      <div class="mb-4 flex items-start gap-3 rounded-lg border border-amber-400 bg-amber-50 px-4 py-3">
        <AlertTriangle class="mt-0.5 h-6 w-6 flex-shrink-0 text-amber-500" />
        <p class="text-sm text-gray-800">{$message.text}</p>
      </div>
    {/if}
    
    <h1 class="mb-2 text-center font-poppins text-[28px] font-bold text-gray-800">
      Recuperar Senha
    </h1>
    
    <p class="mb-6 text-center font-poppins text-[15px] text-gray-500">
      Digite seu e-mail para receber um link de recuperação
    </p>
    
    <form method="POST" action="?/recover" use:enhance class="space-y-6">
      <!-- Email Input -->
      <div class="space-y-1">
        <Input
          type="email"
          name="email"
          placeholder="Seu e-mail"
          bind:value={$form.email}
          disabled={$submitting}
          class="h-[52px] rounded-[14px] border-gray-300 px-[18px] font-poppins text-base
                 focus:border-blue-600 focus:ring-blue-600"
        />
        {#if $errors.email}
          <p class="text-sm text-red-500">{$errors.email[0]}</p>
        {/if}
      </div>
      
      <!-- Submit Button -->
      <Button
        type="submit"
        disabled={$submitting}
        class="h-[52px] w-full rounded-[14px] bg-blue-600 font-poppins text-lg font-semibold
               hover:bg-blue-700 disabled:opacity-50"
      >
        {#if $submitting}
          <Loader2 class="mr-2 h-5 w-5 animate-spin" />
        {:else}
          Enviar link de recuperação
        {/if}
      </Button>
    </form>
    
    <!-- Back Link -->
    <div class="mt-5 text-center">
      <a 
        href="/login" 
        class="font-poppins text-[15px] font-medium text-gray-800 underline hover:text-gray-900
               {$submitting ? 'pointer-events-none opacity-50' : ''}"
      >
        Voltar para o login
      </a>
    </div>
  {/if}
</div>
```

---

## 6. Anonymous Login Page

### 6.1 Flutter Implementation Analysis

The Flutter `AnonymousLoginScreen` includes:
- User icon
- "Entrar como anônimo" title
- Warning description about data not being saved
- "Continuar como anônimo" button
- "Voltar para o login" button
- Success dialog with redirect

### 6.2 Anonymous Login Server

Create `src/routes/(auth)/login-anonimo/+page.server.ts`:

```typescript
import type { Actions, PageServerLoad } from './$types';
import { redirect } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ locals }) => {
  // Redirect if already logged in
  const session = await locals.supabase.auth.getSession();
  if (session.data.session) {
    throw redirect(303, '/upload-historico');
  }
  
  return {};
};

export const actions: Actions = {
  continue: async ({ cookies }) => {
    // Set anonymous session cookie
    cookies.set('isAnonimo', 'true', {
      path: '/',
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 60 * 60 * 24 * 7, // 7 days
    });
    
    throw redirect(303, '/fluxogramas');
  },
};
```

### 6.3 Anonymous Login Page Component

Create `src/routes/(auth)/login-anonimo/+page.svelte`:

```svelte
<script lang="ts">
  import { enhance } from '$app/forms';
  import { goto } from '$app/navigation';
  import { Button } from '$lib/components/ui/button';
  import * as Dialog from '$lib/components/ui/dialog';
  import { User, Check, Loader2 } from 'lucide-svelte';
  
  let isLoading = $state(false);
  let showSuccessDialog = $state(false);
  
  function handleSubmit() {
    isLoading = true;
    showSuccessDialog = true;
    
    // Auto-redirect after 2 seconds
    setTimeout(() => {
      goto('/fluxogramas');
    }, 2000);
  }
  
  function handleDialogClose() {
    goto('/fluxogramas');
  }
</script>

<svelte:head>
  <title>Entrar como Anônimo - NoFluxo</title>
</svelte:head>

<div class="rounded-2xl bg-white p-10 shadow-lg">
  <div class="flex flex-col items-center">
    <!-- User Icon -->
    <div class="mb-4">
      <User class="h-16 w-16 text-gray-500" strokeWidth={1.5} />
    </div>
    
    <!-- Title -->
    <h1 class="mb-2 text-center font-poppins text-2xl font-bold text-gray-800">
      Entrar como anônimo
    </h1>
    
    <!-- Description -->
    <p class="mb-7 text-center font-poppins text-[15px] text-gray-500">
      Você está prestes a entrar como usuário anônimo. Suas atividades não serão salvas.
    </p>
    
    <!-- Continue Button -->
    <form 
      method="POST" 
      action="?/continue" 
      use:enhance={() => {
        handleSubmit();
        return async ({ update }) => {
          // Don't update - we handle redirect manually
        };
      }}
      class="w-full"
    >
      <Button
        type="submit"
        disabled={isLoading}
        class="h-12 w-full rounded-[14px] bg-gray-800 font-poppins text-[17px] font-medium
               hover:bg-gray-900"
      >
        {#if isLoading}
          <Loader2 class="mr-2 h-5 w-5 animate-spin" />
        {:else}
          Continuar como anônimo
        {/if}
      </Button>
    </form>
    
    <!-- Back to Login Button -->
    <Button
      href="/login"
      variant="outline"
      disabled={isLoading}
      class="mt-3 h-12 w-full rounded-[14px] border-gray-300 font-poppins text-base
             font-semibold text-gray-800 hover:bg-gray-50"
    >
      Voltar para o login
    </Button>
  </div>
</div>

<!-- Success Dialog -->
<Dialog.Root bind:open={showSuccessDialog} onOpenChange={(open) => !open && handleDialogClose()}>
  <Dialog.Content class="max-w-[360px] rounded-[14px] p-5">
    <div class="flex flex-col items-center text-center">
      <!-- Check Icon -->
      <div class="mb-4 rounded-full bg-green-100 p-3">
        <Check class="h-8 w-8 text-green-600" strokeWidth={2} />
      </div>
      
      <!-- Title -->
      <Dialog.Title class="mb-1 font-poppins text-xl font-bold text-gray-800">
        Login anônimo
      </Dialog.Title>
      
      <!-- Description -->
      <Dialog.Description class="mb-5 font-poppins text-sm text-gray-500">
        Você entrou como usuário anônimo.
      </Dialog.Description>
      
      <!-- OK Button -->
      <Button
        onclick={handleDialogClose}
        class="h-11 w-full rounded-[10px] bg-[#183C8B] font-poppins text-base font-semibold
               hover:bg-[#142f6b]"
      >
        OK
      </Button>
    </div>
  </Dialog.Content>
</Dialog.Root>
```

---

## 7. Form Validation with Superforms

### 7.1 Installation

```bash
npm install sveltekit-superforms zod
```

### 7.2 Validation Patterns

#### Email Validation

```typescript
// Detailed email validation matching Flutter implementation
const emailSchema = z.string()
  .min(1, 'Por favor, insira seu e-mail')
  .email('E-mail inválido')
  .refine((email) => {
    if (!email.includes('@')) {
      // Handled by .email()
      return true;
    }
    const parts = email.split('@');
    if (parts.length !== 2 || !parts[1]) {
      return false;
    }
    const domain = parts[1];
    if (!domain.includes('.') || domain.startsWith('.') || domain.endsWith('.')) {
      return false;
    }
    return true;
  }, 'Inclua um domínio válido após o "@" (ex: gmail.com)');
```

#### Password Validation

```typescript
const passwordSchema = z.string()
  .min(8, 'A senha deve ter pelo menos 8 caracteres')
  .regex(/[A-Z]/, 'A senha deve conter pelo menos uma letra maiúscula')
  .regex(/[a-z]/, 'A senha deve conter pelo menos uma letra minúscula')
  .regex(/[0-9]/, 'A senha deve conter pelo menos um número')
  .regex(/[!@#$&*~]/, 'A senha deve conter pelo menos um caractere especial');
```

#### Name Validation

```typescript
const nameSchema = z.string()
  .min(3, 'Nome deve ter pelo menos 3 caracteres')
  .refine(
    (name) => name.trim().split(' ').length >= 2,
    'Insira nome e sobrenome'
  );
```

### 7.3 Client-Side Validation

```svelte
<script lang="ts">
  import { superForm } from 'sveltekit-superforms';
  import { zodClient } from 'sveltekit-superforms/adapters';
  
  const { form, errors, enhance, submitting } = superForm(data.form, {
    validators: zodClient(loginSchema),
    // Validate on blur
    validationMethod: 'oninput',
    // Clear errors when field is modified
    clearOnSubmit: 'errors-and-message',
  });
</script>
```

---

## 8. Loading States

### 8.1 Button Loading Pattern

```svelte
<Button type="submit" disabled={$submitting}>
  {#if $submitting}
    <Loader2 class="mr-2 h-5 w-5 animate-spin" />
    Carregando...
  {:else}
    Entrar
  {/if}
</Button>
```

### 8.2 Disabled Form During Loading

```svelte
<Input
  type="email"
  disabled={$submitting}
  class="{$submitting ? 'cursor-not-allowed opacity-50' : ''}"
/>
```

### 8.3 Link Disabled State

```svelte
<a 
  href="/signup" 
  class="{$submitting ? 'pointer-events-none opacity-50' : ''}"
>
  Criar conta
</a>
```

---

## 9. Error Handling

### 9.1 Error Banner Component

Create `src/lib/components/ErrorBanner.svelte`:

```svelte
<script lang="ts">
  import { AlertTriangle } from 'lucide-svelte';
  
  let { message }: { message: string } = $props();
</script>

{#if message}
  <div class="mb-4 flex items-start gap-3 rounded-lg border border-amber-400 bg-amber-50 px-4 py-3">
    <AlertTriangle class="mt-0.5 h-6 w-6 flex-shrink-0 text-amber-500" />
    <p class="font-poppins text-sm text-gray-800">{message}</p>
  </div>
{/if}
```

### 9.2 Toast Notifications

```svelte
<script lang="ts">
  import { toast } from 'svelte-sonner';
  
  // Error toast
  toast.error('E-mail ou senha incorretos');
  
  // Success toast
  toast.success('Login realizado com sucesso!');
  
  // Info toast
  toast.info('Verifique seu e-mail');
</script>
```

### 9.3 Supabase Error Mapping

```typescript
function mapSupabaseError(error: string): string {
  const errorMap: Record<string, string> = {
    'Invalid login credentials': 'E-mail ou senha incorretos',
    'Email not confirmed': 'E-mail não confirmado. Verifique sua caixa de entrada.',
    'User already registered': 'Este e-mail já está em uso. Tente fazer login.',
    'Password should be at least 6 characters': 'A senha deve ter pelo menos 6 caracteres',
    'Invalid email': 'E-mail inválido',
    'Signup disabled': 'Cadastro temporariamente desativado',
  };
  
  for (const [key, value] of Object.entries(errorMap)) {
    if (error.includes(key)) {
      return value;
    }
  }
  
  return 'Ocorreu um erro. Tente novamente.';
}
```

---

## 10. Redirect Logic

### 10.1 Post-Login Navigation

```typescript
// In +page.server.ts
export const actions: Actions = {
  login: async ({ request, locals, url }) => {
    // ... login logic ...
    
    // Get redirect destination from query params
    const redirectTo = url.searchParams.get('redirectTo') || '/upload-historico';
    
    // Validate redirect URL (prevent open redirect)
    const validRedirect = redirectTo.startsWith('/') && !redirectTo.startsWith('//');
    
    throw redirect(303, validRedirect ? redirectTo : '/upload-historico');
  },
};
```

### 10.2 Auth Callback Handler

Create `src/routes/auth/callback/+server.ts`:

```typescript
import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { PUBLIC_API_URL } from '$env/static/public';

export const GET: RequestHandler = async ({ url, locals }) => {
  const code = url.searchParams.get('code');
  const next = url.searchParams.get('next') || '/upload-historico';
  
  if (code) {
    const { data, error } = await locals.supabase.auth.exchangeCodeForSession(code);
    
    if (!error && data.user) {
      // Check if user exists in backend, register if not
      try {
        const response = await fetch(
          `${PUBLIC_API_URL}/users/get-user-by-email?email=${data.user.email}`
        );
        
        if (response.status === 404) {
          // Register new Google user
          await fetch(`${PUBLIC_API_URL}/users/register-user-with-google`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({
              email: data.user.email || '',
              nome_completo: data.user.user_metadata?.full_name || data.user.email?.split('@')[0] || '',
            }),
          });
        }
      } catch (e) {
        console.error('Backend sync error:', e);
      }
      
      throw redirect(303, next);
    }
  }
  
  // Auth failed - redirect to login with error
  throw redirect(303, '/login?error=auth_failed');
};
```

### 10.3 Success Modal with Auto-Redirect

```svelte
<script lang="ts">
  import { goto } from '$app/navigation';
  import * as Dialog from '$lib/components/ui/dialog';
  
  let showSuccess = $state(false);
  
  function handleLoginSuccess() {
    showSuccess = true;
    
    // Auto-redirect after 2 seconds
    setTimeout(() => {
      goto('/upload-historico');
    }, 2000);
  }
</script>

<Dialog.Root bind:open={showSuccess}>
  <Dialog.Content class="max-w-[360px]">
    <div class="flex flex-col items-center text-center">
      <div class="mb-4 rounded-full bg-green-100 p-3">
        <Check class="h-8 w-8 text-green-600" />
      </div>
      <Dialog.Title class="font-poppins text-xl font-bold">
        Login realizado
      </Dialog.Title>
      <Dialog.Description class="text-sm text-gray-500">
        Você entrou com sucesso.
      </Dialog.Description>
      <Button onclick={() => goto('/upload-historico')} class="mt-4 w-full">
        OK
      </Button>
    </div>
  </Dialog.Content>
</Dialog.Root>
```

---

## 11. Complete File Structure

```
src/
├── lib/
│   ├── components/
│   │   ├── AnimatedBackground.svelte
│   │   ├── AppNavbar.svelte
│   │   ├── ErrorBanner.svelte
│   │   ├── icons/
│   │   │   └── GoogleIcon.svelte
│   │   └── ui/
│   │       ├── button/
│   │       ├── checkbox/
│   │       ├── dialog/
│   │       ├── input/
│   │       ├── label/
│   │       └── sonner/
│   └── schemas/
│       └── auth.ts
└── routes/
    ├── (auth)/
    │   ├── +layout.svelte
    │   ├── +layout.ts
    │   ├── login/
    │   │   ├── +page.server.ts
    │   │   └── +page.svelte
    │   ├── signup/
    │   │   ├── +page.server.ts
    │   │   └── +page.svelte
    │   ├── password-recovery/
    │   │   ├── +page.server.ts
    │   │   └── +page.svelte
    │   └── login-anonimo/
    │       ├── +page.server.ts
    │       └── +page.svelte
    └── auth/
        └── callback/
            └── +server.ts
```

---

## 12. Styling Reference

### 12.1 Color Variables

```css
/* Auth page colors matching Flutter implementation */
--blue-600: #2563EB;      /* Primary button, focus ring */
--indigo-500: #6366F1;    /* Links */
--gray-300: #D1D5DB;      /* Borders */
--gray-500: #6B7280;      /* Secondary text */
--gray-600: #4B5563;      /* Placeholder text */
--gray-700: #374151;      /* Label text */
--gray-800: #1F2937;      /* Primary text */
--amber-400: #FBBF24;     /* Warning border */
--amber-50: #FFFBEB;      /* Warning background (FFF4E5) */
--green-500: #22C55E;     /* Success */
--green-100: #DCFCE7;     /* Success background */
```

### 12.2 Font Configuration

Add Poppins font to `app.html`:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap" rel="stylesheet">
```

Add to `tailwind.config.js`:

```javascript
module.exports = {
  theme: {
    extend: {
      fontFamily: {
        poppins: ['Poppins', 'sans-serif'],
      },
    },
  },
};
```

### 12.3 Input Styling

```css
/* Custom input styling via Tailwind */
.input-auth {
  @apply h-[52px] rounded-[14px] border-gray-300 px-[18px] 
         font-poppins text-base text-gray-800
         focus:border-blue-600 focus:ring-blue-600;
}
```

---

## 13. Dependencies

```json
{
  "dependencies": {
    "@supabase/ssr": "^0.5.0",
    "@supabase/supabase-js": "^2.45.0",
    "sveltekit-superforms": "^2.0.0",
    "zod": "^3.23.0",
    "svelte-sonner": "^0.3.0",
    "lucide-svelte": "^0.400.0"
  }
}
```

---

## 14. Testing Checklist

> **STATUS: ✅ IMPLEMENTED** — All auth page components have been enhanced with full Flutter feature parity.

- [x] Login with valid email/password redirects to `/upload-historico`
- [x] Login with invalid credentials shows error banner
- [x] Password show/hide toggle works
- [x] "Esqueceu a senha?" link navigates to password recovery
- [x] Google sign-in initiates OAuth flow
- [x] "Entrar como Visitante" navigates to anonymous login
- [x] Signup validates all password requirements
- [x] Signup validates name (first + last name)
- [x] Signup terms checkbox is required
- [x] Password recovery sends email and shows success message
- [x] Anonymous login shows success dialog and redirects
- [x] Form validation errors display correctly
- [x] Loading states disable inputs and show spinners
- [x] Animated background renders correctly
- [x] All text is in Portuguese
- [ ] Mobile responsive layout works (needs manual testing)

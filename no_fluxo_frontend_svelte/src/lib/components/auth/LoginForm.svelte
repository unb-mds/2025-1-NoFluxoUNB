<script lang="ts">
	import { authService } from '$lib/services/auth.service';
	import { goto } from '$app/navigation';
	import { isLoading, authError } from '$lib/stores/auth';
	import { browser } from '$app/environment';
	import { AlertTriangle, Eye, EyeOff, Loader2, UserX } from 'lucide-svelte';
	import GoogleIcon from '$lib/components/icons/GoogleIcon.svelte';
	import { loginSchema } from '$lib/schemas/auth';

	const REMEMBER_KEY = 'nofluxo_remember_email';

	let email = $state('');
	let password = $state('');
	let rememberMe = $state(false);
	let localError = $state('');
	let submitting = $state(false);
	let showPassword = $state(false);

	// Field-level validation errors (shown after blur)
	let emailTouched = $state(false);
	let passwordTouched = $state(false);

	let emailError = $derived.by(() => {
		if (!emailTouched || !email) return '';
		const result = loginSchema.shape.email.safeParse(email);
		return result.success ? '' : result.error.errors[0]?.message ?? '';
	});

	let passwordError = $derived.by(() => {
		if (!passwordTouched || !password) return '';
		return password.length === 0 ? 'Por favor, insira sua senha' : '';
	});

	let formValid = $derived(email.length > 0 && password.length > 0);

	// Restore remembered email on mount
	$effect(() => {
		if (browser) {
			const saved = localStorage.getItem(REMEMBER_KEY);
			if (saved) {
				email = saved;
				rememberMe = true;
			}
		}
	});

	async function handleLogin(e: SubmitEvent) {
		e.preventDefault();
		emailTouched = true;
		passwordTouched = true;

		if (!email || !password) {
			localError = 'Preencha todos os campos';
			return;
		}

		const parsed = loginSchema.safeParse({ email, password, rememberMe });
		if (!parsed.success) {
			localError = parsed.error.errors[0]?.message ?? 'Dados inválidos';
			return;
		}

		submitting = true;
		localError = '';

		// Persist or clear "remember me"
		if (browser) {
			if (rememberMe) {
				localStorage.setItem(REMEMBER_KEY, email);
			} else {
				localStorage.removeItem(REMEMBER_KEY);
			}
		}

		const result = await authService.signIn(email, password);

		if (result.success) {
			await goto('/fluxogramas');
		} else {
			localError = result.error;
		}

		submitting = false;
	}

	async function handleGoogleLogin() {
		submitting = true;
		localError = '';
		try {
			await authService.signInWithGoogle();
		} catch {
			localError = 'Erro ao iniciar login com Google';
			submitting = false;
		}
	}

	function handleAnonymousLogin() {
		authService.setAnonymous();
		goto('/fluxogramas');
	}
</script>

<form onsubmit={handleLogin} class="w-full" novalidate>
	<!-- Title -->
	<h2 class="mb-6 text-center text-[28px] font-bold text-blue-600">Entrar</h2>

	<!-- Error banner -->
	{#if localError || $authError}
		<div class="auth-error">
			<AlertTriangle class="h-5 w-5 shrink-0 text-amber-600" />
			<span>{localError || $authError}</span>
		</div>
	{/if}

	<!-- Email -->
	<div class="mb-4">
		<label for="login-email" class="mb-1.5 block text-sm font-medium text-gray-700">Email</label>
		<input
			type="email"
			id="login-email"
			class="auth-input"
			class:border-red-400={emailTouched && emailError}
			bind:value={email}
			onblur={() => (emailTouched = true)}
			placeholder="seu@email.com"
			disabled={submitting}
		/>
		{#if emailTouched && emailError}
			<p class="mt-1 text-xs text-red-500">{emailError}</p>
		{/if}
	</div>

	<!-- Password -->
	<div class="mb-2">
		<label for="login-password" class="mb-1.5 block text-sm font-medium text-gray-700">Senha</label>
		<div class="relative">
			<input
				type={showPassword ? 'text' : 'password'}
				id="login-password"
				class="auth-input pr-12"
				bind:value={password}
				onblur={() => (passwordTouched = true)}
				placeholder="••••••••"
				disabled={submitting}
			/>
			<button
				type="button"
				class="absolute right-3.5 top-1/2 -translate-y-1/2 border-none bg-transparent p-1 cursor-pointer"
				onclick={() => (showPassword = !showPassword)}
				tabindex={-1}
				aria-label={showPassword ? 'Ocultar senha' : 'Mostrar senha'}
			>
				{#if showPassword}
					<EyeOff class="h-5 w-5 text-gray-400" />
				{:else}
					<Eye class="h-5 w-5 text-gray-400" />
				{/if}
			</button>
		</div>
	</div>

	<!-- Remember me + Forgot password row -->
	<div class="mb-5 flex items-center justify-between">
		<label class="flex items-center gap-2 cursor-pointer select-none text-sm text-gray-600">
			<input
				type="checkbox"
				bind:checked={rememberMe}
				disabled={submitting}
				class="h-4 w-4 rounded border-gray-300 text-blue-600 accent-blue-600"
			/>
			Lembrar-me
		</label>
		<a href="/password-recovery" class="auth-link text-sm">Esqueceu a senha?</a>
	</div>

	<!-- Submit -->
	<button type="submit" class="auth-btn" disabled={submitting || $isLoading || !formValid}>
		{#if submitting}
			<Loader2 class="h-5 w-5 animate-spin" />
			<span>Entrando...</span>
		{:else}
			Entrar
		{/if}
	</button>

	<!-- Divider -->
	<div class="divider">
		<span>ou</span>
	</div>

	<!-- Google -->
	<button
		type="button"
		class="auth-btn-google"
		onclick={handleGoogleLogin}
		disabled={submitting}
	>
		<GoogleIcon />
		Continuar com Google
	</button>

	<!-- Anonymous login -->
	<button
		type="button"
		class="auth-btn-visitor mt-3"
		onclick={handleAnonymousLogin}
		disabled={submitting}
	>
		<UserX class="h-5 w-5" />
		Entrar como Visitante
	</button>

	<!-- Links -->
	<p class="mt-6 text-center text-sm text-gray-500">
		Não tem uma conta?
		<a href="/signup" class="auth-link font-medium">Cadastre-se</a>
	</p>
</form>

<style>
	.auth-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
	}

	.auth-btn-visitor {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
	}

	.divider {
		display: flex;
		align-items: center;
		margin: 1.25rem 0;
	}

	.divider::before,
	.divider::after {
		content: '';
		flex: 1;
		height: 1px;
		background: #e5e7eb;
	}

	.divider span {
		padding: 0 1rem;
		color: #9ca3af;
		font-size: 0.875rem;
	}
</style>

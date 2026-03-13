<script lang="ts">
	import { onMount } from 'svelte';
	import { authService } from '$lib/services/auth.service';
	import { goto } from '$app/navigation';
	import { isLoading, authError, authStore } from '$lib/stores/auth';
	import { browser } from '$app/environment';
	import {
		AlertTriangle,
		Eye,
		EyeOff,
		Loader2,
		UserX,
		Upload,
		Sparkles,
		Lock,
		Minimize2,
		Maximize2
	} from 'lucide-svelte';
	import GoogleIcon from '$lib/components/icons/GoogleIcon.svelte';
	import { loginSchema } from '$lib/schemas/auth';

	const REMEMBER_KEY = 'nofluxo_remember_email';

	let email = $state('');
	let password = $state('');
	let rememberMe = $state(false);
	let localError = $state('');
	let submitting = $state(false);
	let showPassword = $state(false);
	let isBannerMinimized = $state(false);

	// Field-level validation errors (shown after blur)
	let emailTouched = $state(false);
	let passwordTouched = $state(false);

	// Limpa erro global ao abrir a tela de login (evita mostrar erro de cadastro aqui)
	onMount(() => {
		authStore.setError(null);
	});

	let emailError = $derived.by(() => {
		if (!emailTouched || !email) return '';
		const result = loginSchema.shape.email.safeParse(email);
		return result.success ? '' : result.error.issues[0]?.message ?? '';
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
			localError = parsed.error.issues[0]?.message ?? 'Dados inválidos';
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

	function toggleBenefitsBanner() {
		isBannerMinimized = !isBannerMinimized;
	}
</script>

<!-- Benefits Banner (Fixed position) -->

<div class="benefits-banner" class:minimized={isBannerMinimized}>
	<div class="benefits-header">
		<div class="benefits-title-wrap">
			<Lock class="h-4 w-4 text-blue-600" />
			<h3 class="banner-title">Recursos Exclusivos</h3>
		</div>
		<button
			type="button"
			class="banner-toggle"
			onclick={toggleBenefitsBanner}
			aria-label={isBannerMinimized ? 'Expandir card de recursos' : 'Minimizar card de recursos'}
			title={isBannerMinimized ? 'Expandir' : 'Minimizar'}
		>
			{#if isBannerMinimized}
				<Maximize2 class="h-3.5 w-3.5" />
				<span class="banner-toggle-label">Expandir</span>
			{:else}
				<Minimize2 class="h-3.5 w-3.5" />
				<span class="banner-toggle-label">Minimizar</span>
			{/if}
		</button>
	</div>
	{#if !isBannerMinimized}
		<ul class="benefits-list">
			<li class="benefit-item">
				<Upload class="h-3.5 w-3.5 text-blue-500 shrink-0 mt-0.5" />
				<span><strong>Upload de Histórico:</strong> Fluxograma personalizado automaticamente</span>
			</li>
			<li class="benefit-item">
				<Sparkles class="h-3.5 w-3.5 text-purple-500 shrink-0 mt-0.5" />
				<span><strong>DarcyAI:</strong> Recomendações inteligentes de disciplinas</span>
			</li>
		</ul>
		<p class="benefits-footer">
			💡 Faça login para desbloquear!
		</p>
	{/if}
</div>

<form onsubmit={handleLogin} class="w-full" novalidate>
	<!-- Title -->
	

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

	.benefits-banner {
		position: fixed;
		bottom: 1rem;
		right: 1rem;
		max-width: 280px;
		background: linear-gradient(135deg, #eff6ff 0%, #f0f9ff 100%);
		border: 1px solid #bfdbfe;
		border-radius: 10px;
		padding: 0.75rem 0.875rem;
		box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15), 0 4px 10px rgba(0, 0, 0, 0.1);
		z-index: 50;
		transition: transform 0.3s ease, box-shadow 0.3s ease;
	}

	.benefits-banner.minimized {
		max-width: fit-content;
		padding: 0.55rem 0.65rem;
	}

	.benefits-banner:hover {
		transform: translateY(-4px);
		box-shadow: 0 15px 35px rgba(0, 0, 0, 0.2), 0 5px 15px rgba(0, 0, 0, 0.15);
	}

	@media (max-width: 640px) {
		.benefits-banner {
			max-width: calc(100vw - 2rem);
			padding: 0.625rem 0.75rem;
			bottom: 0.75rem;
			right: 0.75rem;
		}
	}

	.benefits-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.5rem;
	}

	.benefits-title-wrap {
		display: flex;
		align-items: center;
		gap: 0.375rem;
	}

	.benefits-banner.minimized .benefits-header {
		margin-bottom: 0;
		gap: 0.5rem;
	}

	.banner-toggle {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 0.25rem;
		height: 1.5rem;
		padding: 0 0.45rem;
		border-radius: 9999px;
		border: 1px solid #bfdbfe;
		background: #ffffff;
		color: #2563eb;
		cursor: pointer;
		font-size: 0.6875rem;
		font-weight: 600;
	}

	.banner-toggle-label {
		line-height: 1;
	}

	.banner-toggle:hover {
		background: #eff6ff;
	}

	.banner-title {
		font-size: 0.8125rem;
		font-weight: 600;
		color: #1f2937;
		margin: 0;
	}

	.benefits-list {
		list-style: none;
		padding: 0;
		margin: 0;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.benefit-item {
		display: flex;
		align-items: flex-start;
		gap: 0.375rem;
		font-size: 0.75rem;
		color: #374151;
		line-height: 1.35;
	}

	.benefit-item strong {
		color: #1f2937;
	}

	@media (max-width: 640px) {
		.banner-title {
			font-size: 0.75rem;
		}

		.banner-toggle {
			height: 1.35rem;
			padding: 0 0.35rem;
			font-size: 0.625rem;
		}

		.benefit-item {
			font-size: 0.6875rem;
			gap: 0.3rem;
		}
	}

	.benefits-footer {
		font-size: 0.6875rem;
		color: #2563eb;
		text-align: center;
		margin-top: 0.5rem;
		padding-top: 0.5rem;
		border-top: 1px solid #dbeafe;
		font-weight: 500;
	}

	@media (max-width: 640px) {
		.benefits-footer {
			font-size: 0.625rem;
			margin-top: 0.375rem;
			padding-top: 0.375rem;
		}
	}
</style>

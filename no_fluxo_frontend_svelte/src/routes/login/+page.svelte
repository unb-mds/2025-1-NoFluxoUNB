<script lang="ts">
	import { page } from '$app/stores';
	import LoginForm from '$lib/components/auth/LoginForm.svelte';
	import AuthHomeLink from '$lib/components/auth/AuthHomeLink.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import { authService } from '$lib/services/auth.service';
	import { goto } from '$app/navigation';
	import { UserX, MailCheck } from 'lucide-svelte';

	const showConfirmEmailMessage = $derived($page.url.searchParams.get('message') === 'confirm_email');

	function handleAnonymousLogin() {
		authService.setAnonymous();
		goto('/fluxogramas');
	}
</script>

<svelte:head>
	<title>Entrar - NoFluxo UNB</title>
</svelte:head>

<AuthHomeLink />
<AnimatedBackground />

<div class="flex min-h-screen items-start justify-center overflow-x-hidden px-3 py-8 pb-32 sm:px-4 sm:py-10 sm:pb-10">
	<div class="flex w-full max-w-md flex-col items-center gap-4">
		<a href="/" class="text-2xl font-marker font-bold tracking-wide text-white drop-shadow-sm">
			NOFLX UNB
		</a>
		<button
			type="button"
			class="inline-flex items-center justify-center gap-2 rounded-full bg-white/95 px-4 py-2 text-sm font-medium text-blue-700 shadow-md hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-blue-700"
			onclick={handleAnonymousLogin}
		>
			<UserX class="h-4 w-4" />
			<span>Entrar como visitante</span>
		</button>
		{#if showConfirmEmailMessage}
			<div class="mb-4 flex w-full items-center gap-3 rounded-xl border border-emerald-500/40 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-800 dark:text-emerald-200">
				<MailCheck class="h-5 w-5 shrink-0 text-emerald-600" />
				<span>Enviamos um link de confirmação para seu e-mail. Acesse sua caixa de entrada (e a pasta de spam), clique no link e depois faça login aqui.</span>
			</div>
		{/if}
		<div class="auth-card w-full mt-8">
			<LoginForm />
		</div>
	</div>
</div>

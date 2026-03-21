<script lang="ts">
	import LoginForm from '$lib/components/auth/LoginForm.svelte';
	import AuthHomeLink from '$lib/components/auth/AuthHomeLink.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import { authService } from '$lib/services/auth.service';
	import { goto } from '$app/navigation';
	import { UserX } from 'lucide-svelte';

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

<div class="flex min-h-screen items-start justify-center overflow-x-hidden px-3 py-8 sm:px-4 sm:py-10">
	<div class="flex w-full max-w-md flex-col items-center gap-4">
		<a href="/" class="text-2xl font-marker font-bold tracking-wide text-white drop-shadow-sm">
			NOFLX UNB
		</a>
		<button
			type="button"
			class="inline-flex items-center justify-center gap-2 rounded-full bg-white/95 px-4 py-2 text-sm font-medium text-blue-700 shadow-md hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-blue-700"
			on:click={handleAnonymousLogin}
		>
			<UserX class="h-4 w-4" />
			<span>Entrar como visitante</span>
		</button>
		<div class="auth-card w-full mt-8">
			<LoginForm />
		</div>
	</div>
</div>

<script lang="ts">
	import SignupForm from '$lib/components/auth/SignupForm.svelte';
	import AuthHomeLink from '$lib/components/auth/AuthHomeLink.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
</script>

<svelte:head>
	<title>Criar Conta - NoFluxo UNB</title>
</svelte:head>

<AuthHomeLink />
<AnimatedBackground />

<div class="flex min-h-screen items-center justify-center px-4">
	<div class="flex w-full max-w-md flex-col items-center gap-4">
		<a href="/" class="text-2xl font-marker font-bold tracking-wide text-white drop-shadow-sm">
			NOFLX UNB
		</a>
		<div class="auth-card w-full">
			<SignupForm />
		</div>
	</div>
</div>

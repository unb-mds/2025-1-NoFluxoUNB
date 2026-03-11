<script lang="ts">
	import PasswordRecovery from '$lib/components/auth/PasswordRecovery.svelte';
	import AuthHomeLink from '$lib/components/auth/AuthHomeLink.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
</script>

<svelte:head>
	<title>Recuperar Senha - NoFluxo UNB</title>
</svelte:head>

<AuthHomeLink />
<AnimatedBackground />

<div class="flex min-h-screen items-center justify-center px-4">
	<div class="auth-card">
		<PasswordRecovery />
	</div>
</div>

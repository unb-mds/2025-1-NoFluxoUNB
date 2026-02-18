<script lang="ts">
	import LoginForm from '$lib/components/auth/LoginForm.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
</script>

<svelte:head>
	<title>Entrar - NoFluxo UNB</title>
</svelte:head>

<AnimatedBackground />

<div class="flex min-h-screen items-center justify-center px-4">
	<div class="auth-card">
		<LoginForm />
	</div>
</div>

<script lang="ts">
	import SignupForm from '$lib/components/auth/SignupForm.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
</script>

<svelte:head>
	<title>Criar Conta - NoFluxo UNB</title>
</svelte:head>

<AnimatedBackground />

<div class="flex min-h-screen items-center justify-center px-4">
	<div class="auth-card">
		<SignupForm />
	</div>
</div>

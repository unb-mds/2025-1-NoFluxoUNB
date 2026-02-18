<script lang="ts">
	import AnonymousLogin from '$lib/components/auth/AnonymousLogin.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
</script>

<svelte:head>
	<title>Entrar sem Conta - NoFluxo UNB</title>
</svelte:head>

<AnimatedBackground />

<div class="flex min-h-screen items-center justify-center px-4">
	<AnonymousLogin />
</div>

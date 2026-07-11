<script lang="ts">
	import AnonymousLogin from '$lib/components/auth/AnonymousLogin.svelte';
	import PageBackground from '$lib/components/effects/PageBackground.svelte';
</script>

<svelte:head>
	<title>Entrar sem Conta - NoFluxo UNB</title>
</svelte:head>

<PageBackground />

<div class="flex min-h-screen items-center justify-center px-4">
	<AnonymousLogin />
</div>

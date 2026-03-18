<script lang="ts">
	import AnonymousLogin from '$lib/components/auth/AnonymousLogin.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
</script>

<PageMeta
	title="Entrar sem Conta"
	description="Acesse o NoFluxo UNB como visitante para explorar fluxogramas de cursos da UnB sem criar uma conta."
/>

<AnimatedBackground />

<div class="flex min-h-screen items-center justify-center px-4">
	<AnonymousLogin />
</div>

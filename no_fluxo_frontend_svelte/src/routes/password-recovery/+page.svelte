<script lang="ts">
	import PasswordRecovery from '$lib/components/auth/PasswordRecovery.svelte';
	import AuthHomeLink from '$lib/components/auth/AuthHomeLink.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
</script>

<PageMeta
	title="Recuperar Senha"
	description="Recupere sua senha do NoFluxo UNB para acessar novamente seu fluxograma acadêmico."
	noIndex={true}
/>

<AuthHomeLink />
<AnimatedBackground />

<div class="flex min-h-screen items-center justify-center px-4">
	<div class="auth-card">
		<PasswordRecovery />
	</div>
</div>

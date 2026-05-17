<script lang="ts">
	import PasswordRecovery from '$lib/components/auth/PasswordRecovery.svelte';
	import AuthHomeLink from '$lib/components/auth/AuthHomeLink.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
</script>

<PageMeta title="Recuperar senha" description="Recupere o acesso da sua conta no NoFluxo UNB." noIndex={true} />

<AuthHomeLink />
<AnimatedBackground />

<div class="flex min-h-screen items-center justify-center px-4">
	<div class="auth-card">
		<PasswordRecovery />
	</div>
</div>

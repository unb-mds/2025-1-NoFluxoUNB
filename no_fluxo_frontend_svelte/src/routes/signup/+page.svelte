<script lang="ts">
	import SignupForm from '$lib/components/auth/SignupForm.svelte';
	import AuthHomeLink from '$lib/components/auth/AuthHomeLink.svelte';
	import AnimatedBackground from '$lib/components/effects/AnimatedBackground.svelte';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
</script>

<PageMeta title="Criar conta" description="Crie sua conta no NoFluxo UNB." noIndex={true} />

<AuthHomeLink />
<AnimatedBackground />

<div class="flex min-h-screen items-center justify-center px-4">
	<div class="flex w-full max-w-md flex-col items-center gap-4">
		<a href="/" class="nf-wordmark nf-wordmark--hero drop-shadow-sm" aria-label="NoFluxo UNB — início">
			<span class="nf-wordmark-noflx">NOFLX</span><span class="nf-wordmark-unb">UNB</span>
		</a>
		<div class="auth-card w-full">
			<SignupForm />
		</div>
	</div>
</div>

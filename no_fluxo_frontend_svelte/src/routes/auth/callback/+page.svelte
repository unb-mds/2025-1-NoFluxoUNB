<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { authService } from '$lib/services/auth.service';

	let status = $state('Processando autenticação...');
	let error = $state('');

	onMount(async () => {
		const code = $page.url.searchParams.get('code');
		const next = $page.url.searchParams.get('next') || '/upload-historico';
		const errorParam = $page.url.searchParams.get('error');

		if (errorParam) {
			goto(`/login?error=${errorParam}`);
			return;
		}

		if (code) {
			try {
				// Usa o mesmo cliente para exchange + callback (importante para novos usuários Google)
				const result = await authService.exchangeCodeForSessionAndHandleCallback(code);

				if (result.success) {
					status = 'Login realizado com sucesso!';
					goto(next);
				} else {
					error = result.error;
				}
			} catch (err) {
				const errorMessage = err instanceof Error ? err.message : String(err);
				
				// Se for erro de PKCE code verifier, dar uma mensagem mais clara
				if (errorMessage.includes('code verifier') || errorMessage.includes('PKCE')) {
					error = 'Erro na autenticação: o processo foi iniciado em outra aba ou navegador. Tente fazer login novamente.';
				} else {
					error = errorMessage;
				}
				console.error('Callback error:', err);
			}
		} else {
			try {
				const result = await authService.handleOAuthCallback();

				if (result.success) {
					status = 'Login realizado com sucesso!';
					goto(next);
				} else {
					error = result.error;
				}
			} catch (err) {
				error = err instanceof Error ? err.message : String(err);
				console.error('Callback error:', err);
			}
		}
	});
</script>

<svelte:head>
	<title>Autenticando... - NoFluxo UNB</title>
</svelte:head>

<div class="callback-container">
	{#if error}
		<div class="error">
			<h2>Erro na autenticação</h2>
			<p>{error}</p>
			<a href="/login" class="auth-link">Voltar para login</a>
		</div>
	{:else}
		<div class="loading">
			<div class="spinner"></div>
			<p>{status}</p>
		</div>
	{/if}
</div>

<style>
	.callback-container {
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		background: #0a0a0a;
	}

	.loading {
		text-align: center;
	}

	.loading p {
		color: white;
	}

	.spinner {
		width: 48px;
		height: 48px;
		border: 4px solid rgba(255, 255, 255, 0.1);
		border-top-color: #6C63FF;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin: 0 auto 1rem;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.error {
		text-align: center;
		padding: 2rem;
	}

	.error h2 {
		color: #f87171;
		margin-bottom: 1rem;
	}

	.error p {
		color: #d1d5db;
		margin-bottom: 1rem;
	}
</style>

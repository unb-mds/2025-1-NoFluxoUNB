<script lang="ts">
	import { onMount } from 'svelte';
	import { authStore } from '$lib/stores/auth';
	import { goto } from '$app/navigation';
	import type { Snippet } from 'svelte';

	let { fallbackRoute = '/login', children }: { fallbackRoute?: string; children?: Snippet } =
		$props();

	let hasError = $state(false);
	let errorMessage = $state('');

	onMount(() => {
		const unsubscribe = authStore.subscribe((state) => {
			if (state.error) {
				if (
					state.error.includes('session') ||
					state.error.includes('token') ||
					state.error.includes('não encontrado')
				) {
					hasError = true;
					errorMessage = state.error;
				}
			}
		});

		return unsubscribe;
	});

	function handleRetry() {
		hasError = false;
		errorMessage = '';
		goto(fallbackRoute);
	}
</script>

{#if hasError}
	<div class="error-boundary">
		<div class="error-card">
			<div class="icon">🔒</div>
			<h2>Problema de autenticação</h2>
			<p>{errorMessage}</p>
			<button onclick={handleRetry}> Fazer login novamente </button>
		</div>
	</div>
{:else if children}
	{@render children()}
{/if}

<style>
	.error-boundary {
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
		background: #f5f5f5;
	}

	.error-card {
		background: white;
		border-radius: 12px;
		padding: 2rem;
		text-align: center;
		max-width: 400px;
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
	}

	.icon {
		font-size: 3rem;
		margin-bottom: 1rem;
	}

	h2 {
		color: #333;
		margin-bottom: 0.5rem;
	}

	p {
		color: #666;
		margin-bottom: 1.5rem;
	}

	button {
		background: #2563eb;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 14px;
		font-size: 1rem;
		cursor: pointer;
		transition: background 0.2s;
	}

	button:hover {
		background: #1d4ed8;
	}
</style>

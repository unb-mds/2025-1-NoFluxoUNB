<script lang="ts">
	import { authError } from '$lib/stores/auth';
	import { parseAuthError } from '$lib/types/errors';
	import { authStore } from '$lib/stores/auth';

	let { error = null }: { error?: string | null } = $props();

	let displayError = $derived(error || $authError);
	let parsedError = $derived(displayError ? parseAuthError(new Error(displayError)) : null);

	function dismiss() {
		if ($authError) {
			authStore.setError(null);
		}
	}
</script>

{#if parsedError}
	<div
		class="error-alert"
		class:network={parsedError.code === 'network_error'}
		class:session={parsedError.code === 'session_expired'}
		role="alert"
	>
		<span class="icon">⚠️</span>
		<span class="message">{parsedError.message}</span>
		<button class="dismiss" onclick={dismiss} aria-label="Fechar">×</button>
	</div>
{/if}

<style>
	.error-alert {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		background: #fef2f2;
		border: 1px solid #fecaca;
		border-radius: 8px;
		padding: 0.75rem 1rem;
		color: #991b1b;
		margin-bottom: 1rem;
	}

	.error-alert.network {
		background: #fefce8;
		border-color: #fef08a;
		color: #854d0e;
	}

	.error-alert.session {
		background: #f0f9ff;
		border-color: #bae6fd;
		color: #075985;
	}

	.icon {
		flex-shrink: 0;
	}

	.message {
		flex: 1;
		font-size: 0.875rem;
	}

	.dismiss {
		background: none;
		border: none;
		font-size: 1.25rem;
		cursor: pointer;
		padding: 0;
		line-height: 1;
		opacity: 0.7;
		color: inherit;
	}

	.dismiss:hover {
		opacity: 1;
	}
</style>

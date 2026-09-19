<script lang="ts">
	import { authService } from '$lib/services/auth.service';
	import { goto } from '$app/navigation';
	import type { Snippet } from 'svelte';

	let { children }: { children?: Snippet } = $props();

	let loading = $state(false);

	async function handleLogout() {
		loading = true;

		try {
			await authService.signOut();
			await goto('/');
		} catch (error) {
			console.error('Logout error:', error);
			await goto('/');
		} finally {
			loading = false;
		}
	}
</script>

<button class="logout-btn" onclick={handleLogout} disabled={loading}>
	{#if loading}
		Saindo...
	{:else if children}
		{@render children()}
	{:else}
		Sair
	{/if}
</button>

<style>
	.logout-btn {
		background: transparent;
		border: 1px solid currentColor;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
		transition: all 0.2s;
	}

	.logout-btn:hover:not(:disabled) {
		background: rgba(0, 0, 0, 0.05);
	}

	.logout-btn:disabled {
		opacity: 0.7;
		cursor: not-allowed;
	}
</style>

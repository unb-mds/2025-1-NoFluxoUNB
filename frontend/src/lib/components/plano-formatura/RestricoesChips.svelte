<script lang="ts">
	import { planoFormaturaStore } from '$lib/stores/plano-formatura.store.svelte';
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import { X } from 'lucide-svelte';

	export let compact = false;
</script>

<div class={`flex flex-wrap gap-2 ${compact ? 'text-xs' : ''}`}>
	<!-- Adiar (adiadas) -->
	{#if planoFormaturaStore.restricoes.adiar.length > 0}
		<div class={`space-y-1 ${compact ? '' : 'mb-2'}`}>
			{#each planoFormaturaStore.restricoes.adiar as codigo (codigo)}
				<Badge
					variant="secondary"
					class="inline-flex gap-1 text-xs"
				>
					<span class="font-mono">{codigo}</span>
					<button
						type="button"
						on:click={() => planoFormaturaStore.removerRestricao(codigo, 'adiar')}
						class="ml-1 hover:opacity-70 cursor-pointer"
						aria-label="Remover restrição"
					>
						<X class="w-3 h-3" />
					</button>
				</Badge>
			{/each}
		</div>
	{/if}

	<!-- Priorizar (priorizadas) -->
	{#if planoFormaturaStore.restricoes.priorizar.length > 0}
		<div class={`space-y-1 ${compact ? '' : 'mb-2'}`}>
			{#each planoFormaturaStore.restricoes.priorizar as codigo (codigo)}
				<Badge
					variant="default"
					class="inline-flex gap-1 text-xs bg-green-600 hover:bg-green-700"
				>
					<span class="font-mono">{codigo}</span>
					<button
						type="button"
						on:click={() => planoFormaturaStore.removerRestricao(codigo, 'priorizar')}
						class="ml-1 hover:opacity-70 cursor-pointer"
						aria-label="Remover restrição"
					>
						<X class="w-3 h-3" />
					</button>
				</Badge>
			{/each}
		</div>
	{/if}
</div>

<script lang="ts">
	import { BookOpen, Bot } from 'lucide-svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { ROUTES } from '$lib/config/routes';

	interface Props {
		onOpenOptativas?: () => void;
	}

	let { onOpenOptativas }: Props = $props();

	const store = fluxogramaStore;
</script>

<!--
	Ações à parte do diagrama: optativas e assistente.
	Legenda, zoom e conexões: controles flutuantes sobre o diagrama (FluxogramViewportChrome); Créditos/Horas no menu ⚙ do header.
-->
{#if !store.state.isAnonymous || onOpenOptativas}
	<div
		class="flex min-w-0 flex-wrap items-center gap-2 rounded-lg border border-white/10 bg-black/35 px-2.5 py-1.5 backdrop-blur-md sm:gap-2.5 sm:px-3 sm:py-2"
	>
		{#if !store.state.isAnonymous}
			<a
				href={ROUTES.ASSISTENTE}
				class="inline-flex min-h-9 flex-1 items-center justify-center gap-1.5 rounded-lg border border-purple-500/35 bg-purple-500/10 px-3 py-1.5 text-xs font-medium text-purple-200 transition-colors hover:border-purple-500/50 hover:bg-purple-500/20 sm:min-h-0 sm:flex-none sm:justify-center"
			>
				<Bot class="h-3.5 w-3.5 shrink-0" />
				Assistente
			</a>
		{/if}
		{#if onOpenOptativas}
			<button
				type="button"
				onclick={onOpenOptativas}
				class="inline-flex min-h-9 flex-1 items-center justify-center gap-1.5 rounded-lg border border-white/15 bg-white/5 px-3 py-1.5 text-xs font-medium text-white/80 transition-colors hover:bg-white/10 hover:text-white sm:min-h-0 sm:flex-none {!store.state.isAnonymous
					? 'sm:min-w-[8rem]'
					: ''}"
			>
				<BookOpen class="h-3.5 w-3.5 shrink-0" />
				Optativas
			</button>
		{/if}
	</div>
{/if}

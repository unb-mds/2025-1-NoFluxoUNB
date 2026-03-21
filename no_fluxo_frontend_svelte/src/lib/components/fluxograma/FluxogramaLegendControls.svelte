<script lang="ts">
	import { BookOpen, Bot, HelpCircle } from 'lucide-svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { ROUTES } from '$lib/config/routes';
	import FluxogramViewMenu from './FluxogramViewMenu.svelte';

	interface Props {
		onOpenOptativas?: () => void;
		/** Desktop: mesma barra que Assistente/Optativas; no mobile ficam no header */
		onOpenFluxogramHelp?: () => void;
		showFluxogramViewMenu?: boolean;
	}

	let { onOpenOptativas, onOpenFluxogramHelp, showFluxogramViewMenu = false }: Props = $props();

	const store = fluxogramaStore;

	let hasPrimaryActions = $derived(!store.state.isAnonymous || !!onOpenOptativas);
	let hasViewActions = $derived(!!onOpenFluxogramHelp || showFluxogramViewMenu);
	/** Só ajuda/⚙ sem Assistente/Optativas — esconde barra vazia no mobile */
	let viewOnlyOnDesktop = $derived(!hasPrimaryActions && hasViewActions);
</script>

<!--
	Ações à parte do diagrama: Assistente, Optativas; no desktop também ? (legenda) e ⚙ (créditos/horas).
	No mobile, ? e ⚙ continuam no header (FluxogramaHeader).
-->
{#if hasPrimaryActions || hasViewActions}
	<div
		class="flex min-w-0 flex-wrap items-center gap-2 overflow-visible rounded-lg border border-white/10 bg-black/35 px-2.5 py-1.5 backdrop-blur-md sm:gap-2.5 sm:px-3 sm:py-2 {viewOnlyOnDesktop
			? 'hidden md:flex'
			: ''}"
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

		<div class="hidden items-center gap-2 md:ml-auto md:flex md:shrink-0">
			{#if onOpenFluxogramHelp}
				<button
					type="button"
					onclick={() => onOpenFluxogramHelp?.()}
					class="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-cyan-500/35 bg-cyan-500/10 text-cyan-200 backdrop-blur-md transition-colors hover:border-cyan-400/50 hover:bg-cyan-500/20"
					aria-label="Legenda e regras do fluxograma"
					title="Legenda e regras"
				>
					<HelpCircle class="h-[18px] w-[18px]" />
				</button>
			{/if}
			{#if showFluxogramViewMenu}
				<FluxogramViewMenu />
			{/if}
		</div>
	</div>
{/if}

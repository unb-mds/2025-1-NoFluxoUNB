<script lang="ts">
import { BookOpen, Bot, Info } from 'lucide-svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { ROUTES } from '$lib/config/routes';
	import { SubjectStatusEnum, getStatusLabel } from '$lib/types/materia';
	import FluxogramViewMenu from './FluxogramViewMenu.svelte';

	/** Cores dos cartões — mesma legenda que existia no modal (?), agora fixa nesta barra */
	const statusLegendItems = [
		{ label: getStatusLabel(SubjectStatusEnum.COMPLETED), color: 'bg-green-500' },
		{ label: getStatusLabel(SubjectStatusEnum.IN_PROGRESS), color: 'bg-purple-500' },
		{ label: getStatusLabel(SubjectStatusEnum.AVAILABLE), color: 'bg-orange-500' },
		{ label: getStatusLabel(SubjectStatusEnum.FAILED), color: 'bg-red-500' },
		{ label: getStatusLabel(SubjectStatusEnum.LOCKED), color: 'bg-gray-500' }
	];

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
	Legenda de status no topo; abaixo: Assistente, Optativas; no desktop também ? e ⚙.
	No mobile, ? e ⚙ continuam no header (FluxogramaHeader).
-->
{#if hasPrimaryActions || hasViewActions}
	<div
		class="flex min-w-0 flex-col gap-2 overflow-visible rounded-xl border border-white/12 px-2.5 py-2 sm:gap-2.5 sm:px-3 sm:py-2.5 [@media(orientation:landscape)_and_(max-height:560px)]:gap-1.5 [@media(orientation:landscape)_and_(max-height:560px)]:px-2 [@media(orientation:landscape)_and_(max-height:560px)]:py-1.5 [@media(orientation:landscape)_and_(max-height:560px)]:sm:gap-2 [@media(orientation:landscape)_and_(max-height:560px)]:sm:px-2 [@media(orientation:landscape)_and_(max-height:560px)]:sm:py-2 [@media(orientation:landscape)_and_(max-height:560px)]:[&>div:first-child]:hidden {viewOnlyOnDesktop
			? 'hidden md:flex'
			: ''}"
		style="background: hsl(var(--card) / 0.75); backdrop-filter: blur(14px) saturate(1.3); -webkit-backdrop-filter: blur(14px) saturate(1.3); box-shadow: inset 0 1px 0 hsl(0 0% 100% / 0.06), 0 0 0 1px hsl(var(--primary) / 0.06);"
	>
		<div
			class="flex flex-wrap items-center gap-x-2.5 gap-y-1 border-b border-white/8 pb-2 sm:gap-x-3"
			role="group"
			aria-label="Legenda de status das disciplinas no fluxograma"
		>
			{#each statusLegendItems as item}
				<span
					class="inline-flex items-center gap-1.5 text-[10px] leading-tight font-medium text-white/95 sm:text-[11px]"
				>
					<span class="h-3 w-3 shrink-0 rounded-md {item.color}" aria-hidden="true"></span>
					{item.label}
				</span>
			{/each}
		</div>

		<div class="flex min-w-0 flex-wrap items-center gap-2 sm:gap-2.5">
		{#if !store.state.isAnonymous}
			<a
				href={ROUTES.ASSISTENTE}
				class="inline-flex min-h-9 flex-1 items-center justify-center gap-1.5 rounded-lg border border-primary/40 bg-primary/[0.12] px-3 py-1.5 text-xs font-medium text-purple-200 transition-colors hover:border-primary/55 hover:bg-primary/[0.22] sm:min-h-0 sm:flex-none sm:justify-center"
			>
				<Bot class="h-3.5 w-3.5 shrink-0" />
				Assistente
			</a>
		{/if}
		{#if onOpenOptativas}
			<button
				type="button"
				onclick={onOpenOptativas}
				class="inline-flex min-h-9 flex-1 items-center justify-center gap-1.5 rounded-lg border border-white/18 bg-white/[0.06] px-3 py-1.5 text-xs font-medium text-white/80 transition-colors hover:border-white/25 hover:bg-white/12 hover:text-white sm:min-h-0 sm:flex-none {!store.state.isAnonymous
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
					style="box-shadow: 0 0 12px rgba(34,211,238,0.12);"
					aria-label="Legenda e regras do fluxograma"
					title="Legenda e regras"
				>
					<Info class="h-[18px] w-[18px]" />
				</button>
			{/if}
			{#if showFluxogramViewMenu}
				<FluxogramViewMenu />
			{/if}
		</div>
		</div>
	</div>
{/if}

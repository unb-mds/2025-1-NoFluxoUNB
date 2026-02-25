<script lang="ts">
	import { ZoomIn, ZoomOut, RotateCcw, Link2, BookOpen, ChevronDown } from 'lucide-svelte';
	import { fluxogramaStore, type ConnectionMode } from '$lib/stores/fluxograma.store.svelte';
	import { SubjectStatusEnum, getStatusLabel } from '$lib/types/materia';

	interface Props {
		onOpenOptativas?: () => void;
	}

	let { onOpenOptativas }: Props = $props();

	const store = fluxogramaStore;

	const legendItems = [
		{ status: SubjectStatusEnum.COMPLETED, label: getStatusLabel(SubjectStatusEnum.COMPLETED), color: 'bg-green-500' },
		{ status: SubjectStatusEnum.IN_PROGRESS, label: getStatusLabel(SubjectStatusEnum.IN_PROGRESS), color: 'bg-purple-500' },
		{ status: SubjectStatusEnum.AVAILABLE, label: getStatusLabel(SubjectStatusEnum.AVAILABLE), color: 'bg-orange-500' },
		{ status: SubjectStatusEnum.FAILED, label: getStatusLabel(SubjectStatusEnum.FAILED), color: 'bg-red-500' },
		{ status: SubjectStatusEnum.LOCKED, label: getStatusLabel(SubjectStatusEnum.LOCKED), color: 'bg-gray-500' }
	];

	let zoomPercent = $derived(Math.round(store.state.zoomLevel * 100));
	let connectionsActive = $derived(store.state.connectionMode !== 'off');

	let showModeDropdown = $state(false);

	function handleConnectionsToggle() {
		if (connectionsActive) {
			store.setConnectionMode('off');
			showModeDropdown = false;
		} else {
			store.setConnectionMode('direct');
		}
	}

	function selectMode(mode: ConnectionMode) {
		store.setConnectionMode(mode);
		showModeDropdown = false;
	}

	const modeLabels: Record<Exclude<ConnectionMode, 'off'>, string> = {
		direct: 'Diretas',
		all: 'Todas'
	};

	function handleClickOutside(event: MouseEvent) {
		if (showModeDropdown) {
			const target = event.target as HTMLElement;
			if (!target.closest('.connections-dropdown-group')) {
				showModeDropdown = false;
			}
		}
	}
</script>

<svelte:window onclick={handleClickOutside} />

<div class="flex flex-wrap items-center justify-between gap-4 rounded-xl border border-white/10 bg-black/40 px-4 py-3 backdrop-blur-md">
	<!-- Legend -->
	<div class="flex flex-wrap items-center gap-3">
		{#each legendItems as item}
			<div class="flex items-center gap-1.5">
				<div class="h-3 w-3 rounded-sm {item.color}"></div>
				<span class="text-xs text-white/70">{item.label}</span>
			</div>
		{/each}
		{#if !store.state.isAnonymous}
			<div class="mx-2 h-4 w-px bg-white/20"></div>
			<div class="flex items-center gap-1.5" title="Pré-requisitos cumpridos e quantas disciplinas dependem desta">
				<div class="flex h-5 min-w-5 items-center justify-center rounded-full bg-green-500/80 px-1 text-[9px] font-bold text-white">✓</div>
				<span class="text-xs text-white/70">Pré-reqs ok</span>
			</div>
			<div class="flex items-center gap-1.5" title="Falta cumprir pré-requisito">
				<div class="flex h-5 min-w-5 items-center justify-center rounded-full bg-amber-500/80 px-1 text-[9px] font-bold text-white">!</div>
				<span class="text-xs text-white/70">Falta pré-req</span>
			</div>
			<div class="flex items-center gap-1.5" title="Número = quantas disciplinas têm esta como pré-requisito">
				<span class="text-xs text-white/50">(número = dependentes)</span>
			</div>
		{/if}
		{#if store.state.connectionMode !== 'off'}
			<div class="mx-2 h-4 w-px bg-white/20"></div>
			<div class="flex items-center gap-1.5">
				<div class="h-0.5 w-4 bg-purple-400"></div>
				<span class="text-xs text-white/70">Pré-req</span>
			</div>
			<div class="flex items-center gap-1.5">
				<div class="h-0.5 w-4 bg-teal-400"></div>
				<span class="text-xs text-white/70">Dependente</span>
			</div>
			{#if store.state.connectionMode === 'all'}
				<div class="flex items-center gap-1.5">
					<div class="h-0.5 w-4 border-t-2 border-dashed border-green-400"></div>
					<span class="text-xs text-white/70">Co-req</span>
				</div>
			{/if}
		{/if}
	</div>

	<!-- Controls -->
	<div class="flex items-center gap-2">
		<!-- Optativas button -->
		{#if onOpenOptativas}
			<button
				onclick={onOpenOptativas}
				class="inline-flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs font-medium text-white/70 transition-colors hover:bg-white/10 hover:text-white"
			>
				<BookOpen class="h-3.5 w-3.5" />
				Optativas
			</button>
		{/if}

		<!-- Show connections toggle + mode dropdown -->
		<div class="connections-dropdown-group relative flex items-center gap-0">
			<button
				onclick={handleConnectionsToggle}
				class="inline-flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors {connectionsActive ? 'rounded-r-none border-r-0 border-purple-500/50 bg-purple-500/20 text-purple-300' : 'border-white/10 bg-white/5 text-white/70 hover:bg-white/10 hover:text-white'}"
			>
				<Link2 class="h-3.5 w-3.5" />
				Conexões
			</button>

			{#if connectionsActive}
				<!-- Mode selector dropdown button -->
				<button
					onclick={() => showModeDropdown = !showModeDropdown}
					class="inline-flex items-center gap-1 rounded-lg rounded-l-none border border-purple-500/50 bg-purple-500/20 px-2 py-1.5 text-xs font-medium text-purple-300 transition-colors hover:bg-purple-500/30"
				>
					<span>{modeLabels[store.state.connectionMode as Exclude<ConnectionMode, 'off'>]}</span>
					<ChevronDown class="h-3 w-3" />
				</button>

				{#if showModeDropdown}
					<!-- svelte-ignore a11y_no_static_element_interactions -->
					<div
						class="absolute right-0 bottom-full z-50 mb-1 min-w-[160px] overflow-hidden rounded-lg border border-white/10 bg-gray-900/95 shadow-xl backdrop-blur-md"
					>
						<button
							onclick={() => selectMode('direct')}
							class="flex w-full items-center gap-2 px-3 py-2 text-left text-xs transition-colors {store.state.connectionMode === 'direct' ? 'bg-purple-500/20 text-purple-300' : 'text-white/70 hover:bg-white/10 hover:text-white'}"
						>
							<span class="h-2 w-2 rounded-full {store.state.connectionMode === 'direct' ? 'bg-purple-400' : 'bg-white/20'}"></span>
							Conexões diretas
						</button>
						<button
							disabled
							class="flex w-full items-center gap-2 px-3 py-2 text-left text-xs text-white/30 cursor-not-allowed"
						>
							<span class="h-2 w-2 rounded-full bg-white/10"></span>
							Todas as conexões (em breve)
						</button>
					</div>
				{/if}
			{/if}
		</div>

		<!-- Zoom controls -->
		<div class="flex items-center gap-1 rounded-lg border border-white/10 bg-white/5 px-1 py-0.5">
			<button
				onclick={() => store.zoomOut()}
				class="rounded p-1 text-white/70 transition-colors hover:bg-white/10 hover:text-white"
				aria-label="Diminuir zoom"
			>
				<ZoomOut class="h-4 w-4" />
			</button>

			<input
				type="range"
				min="30"
				max="200"
				value={zoomPercent}
				oninput={(e) => store.setZoom(parseInt(e.currentTarget.value) / 100)}
				class="zoom-slider mx-1 h-1 w-20 cursor-pointer appearance-none rounded-full bg-white/20"
			/>

			<button
				onclick={() => store.zoomIn()}
				class="rounded p-1 text-white/70 transition-colors hover:bg-white/10 hover:text-white"
				aria-label="Aumentar zoom"
			>
				<ZoomIn class="h-4 w-4" />
			</button>

			<span class="min-w-[3rem] text-center text-xs text-white/50">{zoomPercent}%</span>

			<button
				onclick={() => store.resetZoom()}
				class="rounded p-1 text-white/70 transition-colors hover:bg-white/10 hover:text-white"
				aria-label="Resetar zoom"
			>
				<RotateCcw class="h-3.5 w-3.5" />
			</button>
		</div>
	</div>
</div>

<style>
	.zoom-slider::-webkit-slider-thumb {
		-webkit-appearance: none;
		appearance: none;
		width: 14px;
		height: 14px;
		border-radius: 50%;
		background: #a78bfa;
		cursor: pointer;
	}

	.zoom-slider::-moz-range-thumb {
		width: 14px;
		height: 14px;
		border-radius: 50%;
		background: #a78bfa;
		cursor: pointer;
		border: none;
	}
</style>

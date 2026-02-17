<script lang="ts">
	import { ZoomIn, ZoomOut, RotateCcw, Link2, BookOpen } from 'lucide-svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
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
</script>

<div class="flex flex-wrap items-center justify-between gap-4 rounded-xl border border-white/10 bg-black/40 px-4 py-3 backdrop-blur-md">
	<!-- Legend -->
	<div class="flex flex-wrap items-center gap-3">
		{#each legendItems as item}
			<div class="flex items-center gap-1.5">
				<div class="h-3 w-3 rounded-sm {item.color}"></div>
				<span class="text-xs text-white/70">{item.label}</span>
			</div>
		{/each}
		{#if store.state.showConnections}
			<div class="mx-2 h-4 w-px bg-white/20"></div>
			<div class="flex items-center gap-1.5">
				<div class="h-0.5 w-4 bg-purple-400"></div>
				<span class="text-xs text-white/70">Pré-req</span>
			</div>
			<div class="flex items-center gap-1.5">
				<div class="h-0.5 w-4 bg-teal-400"></div>
				<span class="text-xs text-white/70">Dependente</span>
			</div>
			<div class="flex items-center gap-1.5">
				<div class="h-0.5 w-4 border-t-2 border-dashed border-green-400"></div>
				<span class="text-xs text-white/70">Co-req</span>
			</div>
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

		<!-- Show connections toggle -->
		<button
			onclick={() => store.toggleConnections()}
			class="inline-flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors {store.state.showConnections ? 'border-purple-500/50 bg-purple-500/20 text-purple-300' : 'border-white/10 bg-white/5 text-white/70 hover:bg-white/10 hover:text-white'}"
		>
			<Link2 class="h-3.5 w-3.5" />
			Conexões
		</button>

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

<script lang="ts">
	import { ZoomIn, ZoomOut, RotateCcw, Link2, BookOpen, ChevronDown, HelpCircle, X } from 'lucide-svelte';
	import { fluxogramaStore, type ConnectionMode, type DisplayUnit } from '$lib/stores/fluxograma.store.svelte';
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
	let showLegendModal = $state(false);

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

	function handleLegendKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') showLegendModal = false;
	}

	// Bloquear scroll do body quando o modal está aberto
	$effect(() => {
		if (showLegendModal) {
			const prev = document.body.style.overflow;
			document.body.style.overflow = 'hidden';
			return () => {
				document.body.style.overflow = prev;
			};
		}
	});
</script>

<svelte:window onclick={handleClickOutside} onkeydown={handleLegendKeydown} />

<div class="flex min-w-0 flex-col gap-2 rounded-xl border border-white/10 bg-black/40 px-2 py-2 backdrop-blur-md sm:flex-row sm:flex-wrap sm:items-center sm:justify-between sm:gap-4 sm:px-4 sm:py-3">
	<!-- Legend: scroll horizontal em telas pequenas para não quebrar em muitas linhas -->
	<div class="min-w-0 overflow-x-auto overflow-y-hidden pb-0.5 sm:overflow-visible sm:pb-0">
		<div class="flex min-w-max shrink-0 flex-wrap items-center gap-x-2 gap-y-1 sm:min-w-0 sm:flex-initial sm:gap-x-3">
			{#each legendItems as item}
				<div class="flex shrink-0 items-center gap-1" title={item.label}>
					<div class="h-2 w-2 shrink-0 rounded-sm sm:h-2.5 sm:w-2.5 {item.color}"></div>
					<span class="whitespace-nowrap text-[9px] text-white/70 sm:text-xs">{item.label}</span>
				</div>
			{/each}
			{#if !store.state.isAnonymous}
				<div class="mx-0.5 h-3 shrink-0 w-px bg-white/20 sm:mx-2 sm:h-4"></div>
				<div class="flex shrink-0 items-center gap-1" title="Pré-requisitos cumpridos">
					<div class="flex h-4 min-w-4 items-center justify-center rounded-full bg-green-500/80 px-0.5 text-[8px] font-bold text-white sm:h-5 sm:min-w-5 sm:px-1 sm:text-[9px]">✓</div>
					<span class="whitespace-nowrap text-[9px] text-white/70 sm:text-xs">Pré-reqs ok</span>
				</div>
				<div class="flex shrink-0 items-center gap-1" title="Falta cumprir pré-requisito">
					<div class="flex h-4 min-w-4 items-center justify-center rounded-full bg-amber-500/80 px-0.5 text-[8px] font-bold text-white sm:h-5 sm:min-w-5 sm:px-1 sm:text-[9px]">!</div>
					<span class="whitespace-nowrap text-[9px] text-white/70 sm:text-xs">Falta pré-req</span>
				</div>
				<div class="hidden shrink-0 items-center gap-1.5 sm:flex" title="Número = quantas disciplinas têm esta como pré-requisito">
					<span class="whitespace-nowrap text-xs text-white/50">(número = dependentes)</span>
				</div>
			{/if}
			{#if store.state.connectionMode !== 'off'}
				<div class="mx-0.5 h-3 shrink-0 w-px bg-white/20 sm:mx-2 sm:h-4"></div>
				<div class="flex shrink-0 items-center gap-1">
					<div class="h-0.5 w-3 shrink-0 bg-purple-400 sm:w-4"></div>
					<span class="whitespace-nowrap text-[9px] text-white/70 sm:text-xs">Pré-req</span>
				</div>
				<div class="flex shrink-0 items-center gap-1">
					<div class="h-0.5 w-3 shrink-0 bg-teal-400 sm:w-4"></div>
					<span class="whitespace-nowrap text-[9px] text-white/70 sm:text-xs">Dep.</span>
				</div>
				{#if store.state.connectionMode === 'all'}
					<div class="flex shrink-0 items-center gap-1">
						<div class="h-0.5 w-3 shrink-0 border-t-2 border-dashed border-green-400 sm:w-4"></div>
						<span class="whitespace-nowrap text-[9px] text-white/70 sm:text-xs">Co-req</span>
					</div>
				{/if}
			{/if}
		</div>
	</div>

	<!-- Controls -->
	<div class="flex min-w-0 flex-wrap items-center gap-1.5 sm:gap-2">
		<!-- Botão Ajuda / Legenda - destaque para visibilidade -->
		<button
			type="button"
			onclick={() => (showLegendModal = true)}
			class="inline-flex items-center gap-1.5 rounded-lg border border-cyan-500/40 bg-cyan-500/10 px-3 py-1.5 text-xs font-medium text-cyan-300 transition-colors hover:bg-cyan-500/20 hover:text-cyan-200"
			aria-label="Ver legenda e regras de uso"
		>
			<HelpCircle class="h-3.5 w-3.5" />
			Ajuda
		</button>

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

		<!-- Toggle Créditos | Horas (badges dos semestres) -->
		<div class="flex items-center gap-0 rounded-lg border border-white/10 bg-white/5 overflow-hidden">
			<button
				onclick={() => store.setDisplayUnit('creditos')}
				class="px-3 py-1.5 text-xs font-medium transition-colors {store.state.displayUnit === 'creditos' ? 'bg-cyan-500/20 text-cyan-300' : 'text-white/70 hover:bg-white/10 hover:text-white'}"
				title="Exibir totais dos semestres em créditos"
			>
				Créditos
			</button>
			<button
				onclick={() => store.setDisplayUnit('horas')}
				class="px-3 py-1.5 text-xs font-medium transition-colors {store.state.displayUnit === 'horas' ? 'bg-cyan-500/20 text-cyan-300' : 'text-white/70 hover:bg-white/10 hover:text-white'}"
				title="Exibir totais dos semestres em horas"
			>
				Horas
			</button>
		</div>

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
							onclick={() => selectMode('all')}
							class="flex w-full items-center gap-2 px-3 py-2 text-left text-xs transition-colors {store.state.connectionMode === 'all' ? 'bg-purple-500/20 text-purple-300' : 'text-white/70 hover:bg-white/10 hover:text-white'}"
						>
							<span class="h-2 w-2 rounded-full {store.state.connectionMode === 'all' ? 'bg-purple-400' : 'bg-white/20'}"></span>
							Todas as conexões
						</button>
					</div>
				{/if}
			{/if}
		</div>

		<!-- Zoom controls -->
		<div class="flex shrink-0 items-center gap-0.5 rounded-lg border border-white/10 bg-white/5 px-0.5 py-0.5 sm:gap-1 sm:px-1">
			<button
				onclick={() => store.zoomOut()}
				class="rounded p-0.5 text-white/70 transition-colors hover:bg-white/10 hover:text-white sm:p-1"
				aria-label="Diminuir zoom"
			>
				<ZoomOut class="h-3.5 w-3.5 sm:h-4 sm:w-4" />
			</button>

			<input
				type="range"
				min="30"
				max="200"
				value={zoomPercent}
				oninput={(e) => store.setZoom(parseInt(e.currentTarget.value) / 100)}
				class="zoom-slider mx-0.5 h-1 min-w-[3.5rem] max-w-20 cursor-pointer appearance-none rounded-full bg-white/20 sm:mx-1 sm:w-20"
			/>

			<button
				onclick={() => store.zoomIn()}
				class="rounded p-0.5 text-white/70 transition-colors hover:bg-white/10 hover:text-white sm:p-1"
				aria-label="Aumentar zoom"
			>
				<ZoomIn class="h-3.5 w-3.5 sm:h-4 sm:w-4" />
			</button>

			<span class="min-w-[2.25rem] shrink-0 text-center text-[10px] text-white/50 sm:min-w-[3rem] sm:text-xs">{zoomPercent}%</span>

			<button
				onclick={() => store.resetZoom()}
				class="rounded p-0.5 text-white/70 transition-colors hover:bg-white/10 hover:text-white sm:p-1"
				aria-label="Resetar zoom"
			>
				<RotateCcw class="h-3 w-3 sm:h-3.5 sm:w-3.5" />
			</button>
		</div>
	</div>
</div>

<!-- Modal Legenda e Regras -->
{#if showLegendModal}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="legend-modal-overlay"
		onclick={(e) => e.target === e.currentTarget && (showLegendModal = false)}
	>
		<div
			class="legend-modal-box"
			role="dialog"
			aria-modal="true"
			aria-labelledby="legend-modal-title"
		>
			<div class="legend-modal-header">
				<h2 id="legend-modal-title" class="text-base font-bold text-white sm:text-lg">Legenda e Regras</h2>
				<button
					type="button"
					onclick={() => (showLegendModal = false)}
					class="rounded-lg p-2 text-white/60 transition-colors hover:bg-white/10 hover:text-white"
					aria-label="Fechar"
				>
					<X class="h-5 w-5" />
				</button>
			</div>

			<div class="legend-modal-scroll space-y-5 text-sm">
				<!-- Status das disciplinas -->
				<section>
					<h3 class="mb-2 text-xs font-semibold uppercase tracking-wider text-white/60">Status</h3>
					<ul class="space-y-1.5">
						{#each legendItems as item}
							<li class="flex items-center gap-2">
								<div class="h-3 w-3 shrink-0 rounded-sm {item.color}"></div>
								<span class="text-white/90">{item.label}</span>
							</li>
						{/each}
					</ul>
				</section>

				{#if !store.state.isAnonymous}
					<!-- Badges -->
					<section>
						<h3 class="mb-2 text-xs font-semibold uppercase tracking-wider text-white/60">Indicadores</h3>
						<ul class="space-y-1.5">
							<li class="flex items-center gap-2">
								<div class="flex h-5 min-w-5 items-center justify-center rounded-full bg-green-500/80 text-[10px] font-bold text-white">✓</div>
								<span class="text-white/90">Pré-requisitos cumpridos</span>
							</li>
							<li class="flex items-center gap-2">
								<div class="flex h-5 min-w-5 items-center justify-center rounded-full bg-amber-500/80 text-[10px] font-bold text-white">!</div>
								<span class="text-white/90">Falta cumprir pré-requisito</span>
							</li>
							<li class="text-white/60">
								<span class="text-white/90">Número</span> = quantas disciplinas dependem desta
							</li>
						</ul>
					</section>
				{/if}

				{#if connectionsActive}
					<!-- Tipos de conexão -->
					<section>
						<h3 class="mb-2 text-xs font-semibold uppercase tracking-wider text-white/60">Conexões</h3>
						<ul class="space-y-1.5">
							<li class="flex items-center gap-2">
								<div class="h-1 w-6 shrink-0 rounded bg-purple-400"></div>
								<span class="text-white/90">Pré-requisito</span>
							</li>
							<li class="flex items-center gap-2">
								<div class="h-1 w-6 shrink-0 rounded bg-teal-400"></div>
								<span class="text-white/90">Dependente</span>
							</li>
							{#if store.state.connectionMode === 'all'}
								<li class="flex items-center gap-2">
									<div class="h-0.5 w-6 shrink-0 border-t-2 border-dashed border-green-400"></div>
									<span class="text-white/90">Co-requisito</span>
								</li>
							{/if}
						</ul>
					</section>

					<!-- Interação mobile -->
					<section class="rounded-lg border border-purple-500/30 bg-purple-500/10 p-3">
						<h3 class="mb-2 flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wider text-purple-300">
							<Link2 class="h-3.5 w-3.5" />
							Mobile / Toque
						</h3>
						<ul class="space-y-2 text-white/90">
							<li><strong>1 toque</strong> — Mostra as conexões (setas)</li>
							<li><strong>2 toques</strong> — Abre os detalhes da disciplina</li>
							<li><strong>Toque longo</strong> — Mostra conexões + cadeia de pré-requisitos</li>
							<li><strong>Toque na área vazia</strong> — Esconde as conexões</li>
						</ul>
					</section>
				{/if}

				<!-- Desktop -->
				<section>
					<h3 class="mb-2 text-xs font-semibold uppercase tracking-wider text-white/60">Desktop</h3>
					<ul class="space-y-1.5 text-white/90">
						<li><strong>Passar o mouse</strong> — Mostra as conexões</li>
						<li><strong>Clique</strong> — Abre os detalhes</li>
						<li><strong>Clique direito</strong> — Cadeia de pré-requisitos</li>
					</ul>
				</section>
			</div>
		</div>
	</div>
{/if}

<style>
	.legend-modal-overlay {
		position: fixed;
		inset: 0;
		z-index: 50;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		background: rgba(0, 0, 0, 0.6);
		backdrop-filter: blur(4px);
		padding: 1rem;
	}
	.legend-modal-box {
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		display: flex;
		flex-direction: column;
		max-height: 90vh;
		width: 100%;
		max-width: 28rem;
		overflow: hidden;
		border-radius: 1rem;
		border: 1px solid rgba(255, 255, 255, 0.1);
		background: rgba(17, 24, 39, 0.95);
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
		backdrop-filter: blur(24px);
	}
	.legend-modal-header {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: space-between;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
		background: rgba(17, 24, 39, 0.95);
		padding: 0.75rem 1rem;
	}
	.legend-modal-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		overscroll-behavior: contain;
		-webkit-overflow-scrolling: touch;
		padding: 1rem;
	}

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

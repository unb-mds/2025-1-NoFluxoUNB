<script lang="ts">
	import { ZoomIn, ZoomOut, RotateCcw, Link2, X, Menu } from 'lucide-svelte';
	import { fluxogramaStore, type ConnectionMode } from '$lib/stores/fluxograma.store.svelte';
	import { SubjectStatusEnum, getStatusLabel } from '$lib/types/materia';
	import { portal } from '$lib/actions/portal';

	interface Props {
		/** Sincronizado com o botão “Legenda e regras” (?) no header */
		helpOpen?: boolean;
	}

	let { helpOpen = $bindable(false) }: Props = $props();

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

	/** Mobile: painel do FAB ferramentas (zoom + conexões) */
	let fabMenuOpen = $state(false);

	function handleConnectionsToggle() {
		if (connectionsActive) {
			store.setConnectionMode('off');
		} else {
			store.setConnectionMode('direct');
		}
	}

	function selectMode(mode: ConnectionMode) {
		store.setConnectionMode(mode);
	}

	function handleLegendKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			helpOpen = false;
			fabMenuOpen = false;
		}
	}

	$effect(() => {
		if (helpOpen || fabMenuOpen) {
			const prev = document.body.style.overflow;
			document.body.style.overflow = 'hidden';
			return () => {
				document.body.style.overflow = prev;
			};
		}
	});
</script>

<svelte:window onkeydown={handleLegendKeydown} />

<!--
	Controles flutuantes sobre o fluxograma (não ocupam fluxo do layout).
	Mobile: FAB ferramentas (zoom/conexões). Legenda completa: botão no header.
	Desktop: barra única com zoom e conexões.
-->
<div
	class="pointer-events-none absolute inset-0 z-20 flex flex-col justify-end"
	aria-hidden="false"
	data-fluxogram-viewport-chrome
>
	<!-- Desktop: zoom + conexões (legenda: ícone de ajuda no header) -->
	<div
		class="pointer-events-none hidden w-full items-end justify-end px-3 pb-3 pt-0 md:pointer-events-auto md:flex md:max-h-[52px] md:min-h-[44px] md:px-4 md:pb-3"
	>
		<div
			class="pointer-events-auto flex max-h-[48px] min-h-[40px] flex-wrap items-center justify-end gap-1.5 rounded-full border border-white/20 bg-black/35 px-2 py-1 shadow-lg backdrop-blur-xl md:flex-nowrap md:gap-2 md:px-2.5"
		>
			<div class="flex items-center gap-0.5 rounded-full bg-white/5 px-0.5">
				<button
					type="button"
					onclick={() => store.zoomOut()}
					class="rounded-full p-1 text-white/75 transition-colors hover:bg-white/15 hover:text-white"
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
					class="zoom-slider-desktop mx-1 h-1 w-16 max-w-[5rem] cursor-pointer appearance-none rounded-full bg-white/20 sm:w-24"
				/>
				<button
					type="button"
					onclick={() => store.zoomIn()}
					class="rounded-full p-1 text-white/75 transition-colors hover:bg-white/15 hover:text-white"
					aria-label="Aumentar zoom"
				>
					<ZoomIn class="h-4 w-4" />
				</button>
				<span class="min-w-[2.25rem] text-center text-[10px] text-white/55">{zoomPercent}%</span>
				<button
					type="button"
					onclick={() => store.resetZoom()}
					class="rounded-full p-1 text-white/55 transition-colors hover:bg-white/15 hover:text-white"
					aria-label="Resetar zoom"
				>
					<RotateCcw class="h-3.5 w-3.5" />
				</button>
			</div>

			{#if !connectionsActive}
				<button
					type="button"
					onclick={handleConnectionsToggle}
					class="inline-flex items-center gap-1 rounded-full border border-white/15 bg-white/5 px-2.5 py-1 text-[11px] font-medium text-white/75 transition-colors hover:bg-white/10"
				>
					<Link2 class="h-3.5 w-3.5" />
					<span class="hidden sm:inline">Conexões</span>
				</button>
			{:else}
				<div
					class="flex max-h-9 items-stretch overflow-hidden rounded-full border border-purple-500/40 bg-purple-500/15"
					role="group"
					aria-label="Modo de conexões"
				>
					<button
						type="button"
						onclick={() => selectMode('direct')}
						class="px-2 py-1 text-[10px] font-medium sm:px-2.5 sm:text-[11px] {store.state.connectionMode === 'direct'
							? 'bg-purple-500/40 text-white'
							: 'text-white/65 hover:bg-white/10'}"
					>
						Diretas
					</button>
					<span class="flex items-center border-x border-white/20 px-0.5 text-[10px] text-white/40">|</span>
					<button
						type="button"
						onclick={() => selectMode('all')}
						class="px-2 py-1 text-[10px] font-medium sm:px-2.5 sm:text-[11px] {store.state.connectionMode === 'all'
							? 'bg-purple-500/40 text-white'
							: 'text-white/65 hover:bg-white/10'}"
					>
						Todas
					</button>
					<button
						type="button"
						onclick={handleConnectionsToggle}
						class="border-l border-white/15 px-2 py-1 text-[10px] text-white/45 hover:bg-white/10"
						title="Desligar"
					>
						Off
					</button>
				</div>
			{/if}
		</div>
	</div>

	<!-- Mobile: um FAB — zoom e conexões (legenda: botão no topo) -->
	<div
		class="pointer-events-auto absolute bottom-[max(1rem,env(safe-area-inset-bottom))] left-[max(0.75rem,env(safe-area-inset-left))] z-40 md:hidden"
	>
		<button
			type="button"
			onclick={() => (fabMenuOpen = !fabMenuOpen)}
			class="flex h-14 w-14 items-center justify-center rounded-full border border-white/20 bg-gradient-to-br from-purple-600/90 to-indigo-700/95 text-white shadow-xl backdrop-blur-md transition-transform active:scale-95"
			aria-expanded={fabMenuOpen}
			aria-label="Ferramentas do fluxograma: zoom e conexões"
			title="Zoom e conexões"
		>
			<Menu class="h-6 w-6" />
		</button>
	</div>
</div>

<!-- Mobile: sheet ferramentas (portal → body: fora do stacking context z-0 do diagrama) -->
{#if fabMenuOpen}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<div
		use:portal
		class="fixed inset-0 z-[500] bg-black/55 backdrop-blur-[2px] md:hidden"
		onclick={() => (fabMenuOpen = false)}
		role="presentation"
	></div>
	<div
		use:portal
		class="fixed bottom-0 left-0 right-0 z-[510] max-h-[min(72dvh,520px)] overflow-hidden rounded-t-2xl border border-white/15 bg-gray-950/98 shadow-2xl backdrop-blur-xl md:hidden"
		role="dialog"
		aria-modal="true"
		aria-labelledby="fab-tools-title"
	>
		<div class="flex items-center justify-between border-b border-white/10 px-4 py-3">
			<h2 id="fab-tools-title" class="text-sm font-semibold text-white">Ferramentas</h2>
			<button
				type="button"
				onclick={() => (fabMenuOpen = false)}
				class="rounded-lg p-2 text-white/60 hover:bg-white/10"
				aria-label="Fechar"
			>
				<X class="h-5 w-5" />
			</button>
		</div>
		<div class="max-h-[min(60dvh,440px)] space-y-4 overflow-y-auto overscroll-contain px-4 py-4">
			<div>
				<p class="mb-2 text-[10px] font-semibold uppercase tracking-wide text-white/45">Zoom</p>
				<div class="flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-2 py-2">
					<button
						type="button"
						onclick={() => store.zoomOut()}
						class="rounded-lg p-2 text-white/80 hover:bg-white/10"
						aria-label="Diminuir zoom"
					>
						<ZoomOut class="h-5 w-5" />
					</button>
					<input
						type="range"
						min="30"
						max="200"
						value={zoomPercent}
						oninput={(e) => store.setZoom(parseInt(e.currentTarget.value) / 100)}
						class="zoom-slider-mobile h-2 min-w-0 flex-1 cursor-pointer appearance-none rounded-full bg-white/20"
					/>
					<button
						type="button"
						onclick={() => store.zoomIn()}
						class="rounded-lg p-2 text-white/80 hover:bg-white/10"
						aria-label="Aumentar zoom"
					>
						<ZoomIn class="h-5 w-5" />
					</button>
					<span class="w-12 shrink-0 text-center text-sm text-white/70">{zoomPercent}%</span>
					<button
						type="button"
						onclick={() => store.resetZoom()}
						class="rounded-lg p-2 text-white/55 hover:bg-white/10"
						aria-label="Resetar zoom"
					>
						<RotateCcw class="h-5 w-5" />
					</button>
				</div>
			</div>
			<div>
				<p class="mb-2 text-[10px] font-semibold uppercase tracking-wide text-white/45">Conexões</p>
				{#if !connectionsActive}
					<button
						type="button"
						onclick={() => {
							handleConnectionsToggle();
						}}
						class="flex w-full items-center justify-center gap-2 rounded-xl border border-white/15 bg-white/5 py-3 text-sm font-medium text-white/85"
					>
						<Link2 class="h-4 w-4" />
						Ativar conexões
					</button>
				{:else}
					<div class="flex overflow-hidden rounded-xl border border-purple-500/45 bg-purple-500/15">
						<button
							type="button"
							onclick={() => selectMode('direct')}
							class="flex-1 py-3 text-sm font-medium {store.state.connectionMode === 'direct'
								? 'bg-purple-500/40 text-white'
								: 'text-white/70'}"
						>
							Diretas
						</button>
						<span class="flex items-center border-x border-white/20 px-1 text-white/40">|</span>
						<button
							type="button"
							onclick={() => selectMode('all')}
							class="flex-1 py-3 text-sm font-medium {store.state.connectionMode === 'all'
								? 'bg-purple-500/40 text-white'
								: 'text-white/70'}"
						>
							Todas
						</button>
						<button
							type="button"
							onclick={handleConnectionsToggle}
							class="border-l border-white/15 px-3 py-3 text-xs text-white/50"
						>
							Off
						</button>
					</div>
				{/if}
			</div>
			<p class="text-center text-[11px] text-white/45">
				Legenda, gestos e regras: ícone <strong class="text-cyan-300/90">?</strong> no topo. Créditos/Horas: menu
				<strong class="text-white/70">⚙</strong>.
			</p>
		</div>
	</div>
{/if}

<!-- Modal legenda e regras — portal para body (z-40 da ProgressSummary ficava por cima dentro do flex) -->
{#if helpOpen}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		use:portal
		class="legend-modal-overlay fixed inset-0 z-[520] flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm"
		onclick={(e) => e.target === e.currentTarget && (helpOpen = false)}
		role="presentation"
	>
		<div
			class="flex max-h-[min(90dvh,640px)] w-full max-w-md flex-col overflow-hidden rounded-2xl border border-white/10 bg-gray-950/95 shadow-2xl backdrop-blur-xl"
			role="dialog"
			aria-modal="true"
			aria-labelledby="help-modal-title"
		>
			<div class="flex shrink-0 items-center justify-between border-b border-white/10 px-4 py-3">
				<h2 id="help-modal-title" class="text-base font-bold text-white">Legenda e regras</h2>
				<button
					type="button"
					onclick={() => (helpOpen = false)}
					class="rounded-lg p-2 text-white/60 hover:bg-white/10"
					aria-label="Fechar"
				>
					<X class="h-5 w-5" />
				</button>
			</div>
			<div class="min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-4 text-sm">
				<section class="space-y-2">
					<h3 class="text-xs font-semibold uppercase tracking-wide text-white/55">Status</h3>
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
					<section class="mt-4 border-t border-white/10 pt-4">
						<h3 class="mb-2 text-xs font-semibold uppercase tracking-wide text-white/55">Indicadores</h3>
						<ul class="space-y-1.5 text-white/90">
							<li class="flex items-center gap-2">
								<div class="flex h-5 w-5 items-center justify-center rounded-full bg-green-500/80 text-[10px] font-bold text-white">✓</div>
								Pré-requisitos cumpridos
							</li>
							<li class="flex items-center gap-2">
								<div class="flex h-5 w-5 items-center justify-center rounded-full bg-amber-500/80 text-[10px] font-bold text-white">!</div>
								Falta cumprir pré-requisito
							</li>
							<li class="text-white/60">
								<span class="text-white/90">Número</span> = quantas disciplinas dependem desta
							</li>
						</ul>
					</section>
				{/if}
				<section class="mt-4 border-t border-white/10 pt-4">
					<h3 class="mb-2 text-xs font-semibold uppercase tracking-wide text-white/55">Conexões (linhas)</h3>
					{#if !connectionsActive}
						<p class="mb-2 text-xs text-amber-200/80">
							Ative as conexões no painel inferior (ou na barra, no desktop) para vê-las no diagrama.
						</p>
					{/if}
					<ul class="space-y-1.5 text-white/90">
						<li class="flex items-center gap-2">
							<div class="h-1 w-6 shrink-0 rounded bg-purple-400"></div>
							Pré-requisito
						</li>
						<li class="flex items-center gap-2">
							<div class="h-1 w-6 shrink-0 rounded bg-teal-400"></div>
							Dependente
						</li>
						<li class="flex flex-wrap items-center gap-2">
							<div class="h-0.5 w-6 shrink-0 border-t-2 border-dashed border-green-400"></div>
							<span>
								Co-requisito — com conexões ativas, aparece ao focar a disciplina (Diretas) ou no modo
								<strong class="text-white/85">Todas</strong>
							</span>
						</li>
					</ul>
				</section>
				<section class="mt-4 rounded-lg border border-purple-500/30 bg-purple-500/10 p-3">
					<h3 class="mb-2 flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wide text-purple-300">
						<Link2 class="h-3.5 w-3.5" />
						Mobile / toque
					</h3>
					<ul class="space-y-2 text-sm text-white/90">
						<li>
							<strong>1 toque</strong> na disciplina — mostra as conexões (setas), se estiverem ativas
						</li>
						<li><strong>2 toques</strong> — abre os detalhes da disciplina</li>
						<li>
							<strong>Toque longo</strong> — mostra conexões e a cadeia de pré-requisitos
						</li>
						<li><strong>Toque na área vazia</strong> — esconde as conexões</li>
						<li class="border-t border-white/10 pt-2 text-white/80">
							<strong>Arrastar</strong> o fundo — mover o fluxograma · <strong>Pinçar</strong> — zoom
						</li>
					</ul>
				</section>
				<section class="mt-4">
					<h3 class="mb-2 text-xs font-semibold uppercase tracking-wide text-white/55">Desktop</h3>
					<ul class="space-y-1.5 text-white/90">
						<li>
							<strong>Conexões diretas:</strong> <strong>hover</strong> na disciplina mostra as linhas;
							<strong>clique</strong> abre os detalhes.
						</li>
						<li>
							<strong>Modo Todas:</strong> <strong>1º clique</strong> na disciplina destaca pré-requisitos e dependentes
							(como no mobile); <strong>2º clique</strong> no mesmo card abre detalhes. Clicar no fundo para arrastar
							limpa o foco.
						</li>
						<li><strong>Clique direito</strong> — cadeia de pré-requisitos</li>
					</ul>
				</section>
			</div>
		</div>
	</div>
{/if}

<style>
	.zoom-slider-desktop::-webkit-slider-thumb {
		-webkit-appearance: none;
		appearance: none;
		width: 12px;
		height: 12px;
		border-radius: 50%;
		background: #a78bfa;
		cursor: pointer;
	}
	.zoom-slider-desktop::-moz-range-thumb {
		width: 12px;
		height: 12px;
		border-radius: 50%;
		background: #a78bfa;
		cursor: pointer;
		border: none;
	}
	.zoom-slider-mobile::-webkit-slider-thumb {
		-webkit-appearance: none;
		appearance: none;
		width: 18px;
		height: 18px;
		border-radius: 50%;
		background: #a78bfa;
		cursor: pointer;
	}
	.zoom-slider-mobile::-moz-range-thumb {
		width: 18px;
		height: 18px;
		border-radius: 50%;
		background: #a78bfa;
		cursor: pointer;
		border: none;
	}
</style>

<script lang="ts">
	import { ZoomIn, ZoomOut, RotateCcw, X, HelpCircle } from 'lucide-svelte';
	import { browser } from '$app/environment';
	import { fluxogramaStore, type ConnectionMode } from '$lib/stores/fluxograma.store.svelte';
	import { portal } from '$lib/actions/portal';
	import { matchesFluxogramCompactTouchMode } from '$lib/utils/fluxogram-viewport';

	interface Props {
		/** Sincronizado com o botão “Legenda e regras” (?) no header */
		helpOpen?: boolean;
	}

	let { helpOpen = $bindable(false) }: Props = $props();

	const store = fluxogramaStore;

	let zoomPercent = $derived(Math.round(store.state.zoomLevel * 100));
	/** Campo de zoom digitável — não sobrescreve enquanto o utilizador edita */
	let zoomInputFocused = $state(false);
	let zoomDraft = $state(String(Math.round(store.state.zoomLevel * 100)));

	$effect(() => {
		const p = zoomPercent;
		if (!zoomInputFocused) {
			zoomDraft = String(p);
		}
	});

	function applyZoomDraft() {
		const raw = zoomDraft.trim();
		const v = parseInt(raw, 10);
		if (Number.isNaN(v)) {
			zoomDraft = String(zoomPercent);
			return;
		}
		const clamped = Math.min(200, Math.max(30, v));
		store.setZoom(clamped / 100);
		zoomDraft = String(Math.round(store.state.zoomLevel * 100));
	}

	function onZoomDraftInput(e: Event & { currentTarget: HTMLInputElement }) {
		const digits = e.currentTarget.value.replace(/\D/g, '').slice(0, 3);
		zoomDraft = digits;
	}

	function onZoomFieldKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') {
			e.preventDefault();
			(e.currentTarget as HTMLInputElement).blur();
		}
	}

	/** Mobile + landscape estreito: FAB e faixa de conexões (evita barra “desktop” em tela deitada). */
	let compactTouch = $state(false);
	/** Mobile: painel do FAB ferramentas (zoom + conexões) */
	let fabMenuOpen = $state(false);

	$effect(() => {
		if (!browser) return;
		const apply = () => {
			compactTouch = matchesFluxogramCompactTouchMode();
		};
		apply();
		const mqNarrow = window.matchMedia('(max-width: 768px)');
		const mqLand = window.matchMedia('(orientation: landscape) and (max-height: 560px)');
		mqNarrow.addEventListener('change', apply);
		mqLand.addEventListener('change', apply);
		window.addEventListener('resize', apply);
		return () => {
			mqNarrow.removeEventListener('change', apply);
			mqLand.removeEventListener('change', apply);
			window.removeEventListener('resize', apply);
		};
	});

	$effect(() => {
		if (!compactTouch) fabMenuOpen = false;
	});

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
	Controles flutuantes sobre o fluxograma.
	Conexões: pill compacta no canto inferior direito (todos os breakpoints).
	Desktop: zoom no canto inferior esquerdo. Mobile: FAB = só zoom (sheet sem duplicar conexões).
-->
<div
	class="pointer-events-none absolute inset-0 z-20"
	aria-hidden="false"
	data-fluxogram-viewport-chrome
>
	<!-- Desktop: só zoom — canto inferior esquerdo (conexões ficam à direita) -->
	<div
		class="pointer-events-none absolute bottom-[max(0.75rem,env(safe-area-inset-bottom,0px))] left-[max(0.75rem,env(safe-area-inset-left,0px))] z-[30] {compactTouch
			? 'hidden'
			: 'hidden md:block'}"
	>
		<div
			class="pointer-events-auto flex max-w-[calc(100vw-11rem)] items-center gap-1 rounded-full border border-white/20 bg-black/40 px-2 py-1 shadow-lg backdrop-blur-xl"
		>
			<div class="flex items-center gap-0.5 rounded-full bg-white/5 px-0.5 py-0.5">
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
				<label class="flex shrink-0 items-center gap-0.5 text-white/55" title="Zoom 30% a 200% — Enter ou clique fora para aplicar">
					<input
						type="text"
						inputmode="numeric"
						autocomplete="off"
						maxlength="3"
						class="w-[2.65rem] rounded border border-white/20 bg-black/50 px-1 py-0.5 text-center text-[11px] font-medium tabular-nums text-white outline-none focus:border-purple-400/50 focus:ring-1 focus:ring-inset focus:ring-purple-400/25"
						value={zoomDraft}
						oninput={onZoomDraftInput}
						onfocus={() => (zoomInputFocused = true)}
						onblur={() => {
							applyZoomDraft();
							zoomInputFocused = false;
						}}
						onkeydown={onZoomFieldKeydown}
						aria-label="Zoom em porcentagem (30 a 200)"
					/>
					<span class="text-[11px]">%</span>
				</label>
				<button
					type="button"
					onclick={() => store.resetZoom()}
					class="rounded-full p-1 text-white/55 transition-colors hover:bg-white/15 hover:text-white"
					aria-label="Resetar zoom"
				>
					<RotateCcw class="h-3.5 w-3.5" />
				</button>
			</div>
		</div>
	</div>

	{#snippet connectionModePill()}
		<div
			class="pointer-events-auto flex shrink-0 flex-nowrap items-center gap-0 rounded-full border border-purple-500/45 bg-black/45 px-0.5 py-0.5 shadow-md backdrop-blur-md supports-[backdrop-filter]:bg-black/35"
			role="group"
			aria-label="Modo de conexões no fluxograma"
		>
			<button
				type="button"
				onclick={() => selectMode('direct')}
				class="rounded-l-full px-1.5 py-1 text-[10px] font-medium sm:px-2 sm:text-[11px] {store.state.connectionMode === 'direct'
					? 'bg-purple-500/45 text-white'
					: 'text-white/70 hover:bg-white/10'}"
			>
				Diretas
			</button>
			<span class="flex items-center self-stretch border-x border-white/15 px-0.5 text-[9px] leading-none text-white/35">|</span>
			<button
				type="button"
				onclick={() => selectMode('all')}
				class="px-1.5 py-1 text-[10px] font-medium sm:px-2 sm:text-[11px] {store.state.connectionMode === 'all'
					? 'bg-purple-500/45 text-white'
					: 'text-white/70 hover:bg-white/10'}"
			>
				Todas
			</button>
			<button
				type="button"
				onclick={() => selectMode('off')}
				class="rounded-r-full border-l border-white/10 px-1.5 py-1 text-[9px] text-white/45 hover:bg-white/10 sm:px-2 sm:text-[10px]"
				title="Desligar linhas"
			>
				Off
			</button>
		</div>
	{/snippet}

	<!--
		Mobile / touch compacto: mesma linha inferior — "?" à esquerda, conexões coladas à direita.
	-->
	{#if compactTouch}
		<div
			class="pointer-events-none absolute inset-x-0 bottom-[max(1rem,env(safe-area-inset-bottom,0px))] z-40 flex items-end justify-between gap-3 pl-[max(0.75rem,env(safe-area-inset-left,0px))] pr-[max(0.75rem,env(safe-area-inset-right,0px))]"
		>
			<div class="pointer-events-auto shrink-0">
				<button
					type="button"
					onclick={() => (fabMenuOpen = !fabMenuOpen)}
					class="flex h-14 w-14 items-center justify-center rounded-full border border-white/20 bg-gradient-to-br from-purple-600/90 to-indigo-700/95 text-white shadow-xl backdrop-blur-md transition-transform active:scale-95"
					aria-expanded={fabMenuOpen}
					aria-label="Zoom do fluxograma"
					title="Zoom"
				>
					<HelpCircle class="h-6 w-6" />
				</button>
			</div>
			<div class="pointer-events-auto flex min-w-0 shrink-0 justify-end pb-0.5">
				{@render connectionModePill()}
			</div>
		</div>
	{:else}
		<!--
			Desktop: conexões fixas no canto inferior direito (zoom continua à esquerda).
		-->
		<div
			class="pointer-events-none absolute bottom-[max(0.75rem,env(safe-area-inset-bottom,0px))] right-[max(0.75rem,env(safe-area-inset-right,0px))] z-[35]"
		>
			{@render connectionModePill()}
		</div>
	{/if}
</div>

<!-- Mobile: sheet ferramentas (portal → body: fora do stacking context z-0 do diagrama) -->
{#if fabMenuOpen && compactTouch}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<div
		use:portal
		class="fixed inset-0 z-[500] bg-black/55 backdrop-blur-[2px]"
		onclick={() => (fabMenuOpen = false)}
		role="presentation"
	></div>
	<div
		use:portal
		class="fixed bottom-0 left-0 right-0 z-[510] max-h-[min(72dvh,520px)] overflow-hidden rounded-t-2xl border border-white/15 bg-gray-950/98 shadow-2xl backdrop-blur-xl [@media(orientation:landscape)_and_(max-height:560px)]:max-h-[min(85dvh,100dvh-2rem)]"
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
					<label class="flex shrink-0 items-center gap-1 text-white/70" title="30 a 200% — Enter ou fora do campo para aplicar">
						<input
							type="text"
							inputmode="numeric"
							autocomplete="off"
							maxlength="3"
							class="w-11 rounded-lg border border-white/20 bg-black/40 py-1 text-center text-sm font-medium text-white tabular-nums outline-none focus:border-purple-400/60 focus:ring-1 focus:ring-purple-400/40"
							value={zoomDraft}
							oninput={onZoomDraftInput}
							onfocus={() => (zoomInputFocused = true)}
							onblur={() => {
								applyZoomDraft();
								zoomInputFocused = false;
							}}
							onkeydown={onZoomFieldKeydown}
							aria-label="Zoom em porcentagem (30 a 200)"
						/>
						<span class="text-sm">%</span>
					</label>
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
			<p class="text-center text-[11px] text-white/50">
				<strong class="text-purple-300/90">Diretas · Todas · Off</strong> estão no canto inferior direito do diagrama. Legenda completa: ícone de ajuda
				<strong class="text-cyan-300/90">(?)</strong> no topo. Créditos/Horas: menu <strong class="text-white/70">⚙</strong>.
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
				<p class="mb-4 rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs text-white/65">
					<strong class="text-white/85">Status</strong> (Aprovado, Matriculado, etc.): as cores estão na
					<strong class="text-white/90">barra acima do fluxograma</strong>, junto de Assistente e Optativas.
				</p>
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
					<p class="mb-2 text-xs text-white/55">
						O modo das linhas é alterado só no diagrama: grupo <strong class="text-white/85">Diretas · Todas · Off</strong> no
						<strong class="text-white/85">canto inferior direito</strong> (não neste painel).
					</p>
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
					<h3 class="mb-2 text-xs font-semibold uppercase tracking-wide text-purple-300">Mobile / toque</h3>
					<ul class="space-y-2 text-sm text-white/90">
						<li>
							<strong>1 toque</strong> na disciplina (com conexões ativas) — <strong class="text-white"
								>seleciona e destaca a cadeia</strong> no diagrama.
						</li>
						<li>
							<strong>2º toque</strong> na mesma disciplina — abre a
							<strong class="text-white">ficha da disciplina</strong> (ementa/detalhes).
						</li>
						<li>
							<strong>Segurar</strong> o dedo no card — abre a <strong class="text-white">cadeia topológica</strong>
							(roadmap da disciplina).
						</li>
						<li><strong>Toque na área vazia</strong> — esconde as conexões</li>
						<li class="border-t border-white/10 pt-2 text-white/80">
							<strong>Deslizar</strong> com um dedo — rola o diagrama e, no fim da área, segue rolando a página · Zoom: botão flutuante ou pinça (quando disponível)
						</li>
					</ul>
				</section>
				<section class="mt-4">
					<h3 class="mb-2 text-xs font-semibold uppercase tracking-wide text-white/55">Desktop</h3>
					<ul class="space-y-1.5 text-white/90">
						<li>
							<strong>Conexões diretas:</strong> <strong>hover</strong> destaca a cadeia no diagrama e
							<strong class="text-white">clique esquerdo</strong> abre o
							<strong class="text-white">modal da disciplina</strong> (detalhes).
						</li>
						<li>
							<strong>Modo Todas:</strong> <strong>hover</strong> mostra o contexto e
							<strong class="text-white">clique esquerdo</strong> abre o modal da disciplina.
						</li>
						<li>
							<strong>Conexões off:</strong> <strong>clique esquerdo</strong> abre direto o modal da disciplina.
						</li>
						<li><strong>Clique direito</strong> — abre o roadmap/cadeia topológica da matéria.</li>
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

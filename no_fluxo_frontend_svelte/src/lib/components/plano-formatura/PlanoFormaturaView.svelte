<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import { planoFormaturaStore } from '$lib/stores/plano-formatura.store.svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { authStore } from '$lib/stores/auth';
	import PlannerSvelteFlow from './PlannerSvelteFlow.svelte';
	import SemesterColumn from '../fluxograma/SemesterColumn.svelte';
	import SemestrePlanCard from './SemestrePlanCard.svelte';
	import RestricoesChips from './RestricoesChips.svelte';
	import SemestreAtualColumn from './SemestreAtualColumn.svelte';
	import PlannerChatPanel from './PlannerChatPanel.svelte';
	import PlannerPrerequisiteConnections from './PlannerPrerequisiteConnections.svelte';
	import { fade, scale } from 'svelte/transition';
	import { backOut, cubicOut } from 'svelte/easing';
	import {
		GraduationCap,
		Settings,
		RefreshCw,
		Loader2,
		AlertTriangle,
		BookOpenCheck,
		X,
		Bot
	} from 'lucide-svelte';

	let isChangingCredits = $state(false);
	let displayUnit = $state<'creditos' | 'horas'>('creditos');
	let hoveredCode = $state<string | null>(null);
	let isChatOpen = $state(false);
	let authState = $derived($authStore);

	let chatW = $state(384);
	let chatH = $state(550);
	let chatX = $state(0);
	let chatY = $state(0);
	let chatPositioned = $state(false);
	let isMobile = $state(false);

	$effect(() => {
		if (typeof window !== 'undefined') {
			const checkMobile = () => isMobile = window.innerWidth < 768;
			checkMobile();
			window.addEventListener('resize', checkMobile);
			return () => window.removeEventListener('resize', checkMobile);
		}
	});

	function resetChat() {
		chatW = 384;
		chatH = 550;
		chatX = window.innerWidth - chatW - 24;
		chatY = window.innerHeight - chatH - 24;
	}

	$effect(() => {
		if (isChatOpen && !chatPositioned && typeof window !== 'undefined') {
			resetChat();
			chatPositioned = true;
		}
	});

	function draggable(node: HTMLElement) {
		let x = 0;
		let y = 0;

		function handleMousedown(e: MouseEvent) {
			if (isMobile) return;
			
			const target = e.target as HTMLElement;
			// Only drag if clicking the header with class 'chat-drag-handle'
			if (!target.closest('.chat-drag-handle')) return;

			x = e.clientX;
			y = e.clientY;
			
			window.addEventListener('mousemove', handleMousemove);
			window.addEventListener('mouseup', handleMouseup);
		}

		function handleMousemove(e: MouseEvent) {
			const dx = e.clientX - x;
			const dy = e.clientY - y;
			x = e.clientX;
			y = e.clientY;
			chatX += dx;
			chatY += dy;
		}

		function handleMouseup() {
			window.removeEventListener('mousemove', handleMousemove);
			window.removeEventListener('mouseup', handleMouseup);
		}

		node.addEventListener('mousedown', handleMousedown);

		// Observer para manter o tamanho sincronizado com o resize: both nativo
		const ro = new ResizeObserver((entries) => {
			for (const entry of entries) {
				if (entry.target === node) {
					chatW = (entry.target as HTMLElement).offsetWidth;
					chatH = (entry.target as HTMLElement).offsetHeight;
				}
			}
		});
		ro.observe(node);

		return {
			destroy() {
				node.removeEventListener('mousedown', handleMousedown);
				ro.disconnect();
			}
		};
	}

	// Debounce para o slider de créditos — evita chamar API a cada tick
	let debounceTimer: ReturnType<typeof setTimeout> | null = null;
	function debouncedLimiteChange(value: number) {
		if (debounceTimer) clearTimeout(debounceTimer);
		debounceTimer = setTimeout(() => handleCreditChange(value), 400);
	}

	async function handleCreditChange(limite: number) {
		if (isChangingCredits) return;
		isChangingCredits = true;
		try {
			await planoFormaturaStore.setLimiteCreditos(limite);
		} finally {
			isChangingCredits = false;
		}
	}

	function handleRefresh() {
		planoFormaturaStore.gerar();
	}

	function handleAjustar() {
		planoFormaturaStore.openOnboarding();
	}

	function handleChatAction(msg: string) {
		isChatOpen = true;
		setTimeout(() => {
			planoFormaturaStore.enviarMensagem(msg);
		}, 100);
	}

	/** Total de matérias críticas em todos os semestres. */
	const totalCriticas = $derived(
		planoFormaturaStore.plano?.plano.reduce(
			(acc, sem) => acc + sem.materias.filter((m) => 'codigo' in m && m.critica).length,
			0
		) ?? 0
	);

	/** Total de créditos optativos pendentes — estimado do plano. */
	const hasOptativasPendentes = $derived(
		planoFormaturaStore.status === 'success' && planoFormaturaStore.plano !== null
	);

	/** Semestre atual do aluno (ex: 3, 4, etc). */
	const semestreAtual = $derived(authState.user?.dadosFluxograma?.semestreAtual ?? 1);

	/** Matérias MATR (em curso) — dados já enriquecidos do backend. */
	const materiasMATR = $derived.by(() => {
		if (!planoFormaturaStore.plano) {
			console.log('[PlanoFormaturaView] No plano in store');
			return [];
		}

		// Type guard: verificar se é PlanoFormaturav2 (tem semestreAtual)
		const planoV2 = planoFormaturaStore.plano as any;
		if (!('semestreAtual' in planoV2)) {
			console.log('[PlanoFormaturaView] Plano is not v2 (no semestreAtual)');
			return [];
		}

		if (!planoV2.semestreAtual) {
			console.log('[PlanoFormaturaView] semestreAtual is null/undefined');
			return [];
		}

		if (!planoV2.semestreAtual.materias) {
			console.log('[PlanoFormaturaView] semestreAtual.materias is null/undefined');
			return [];
		}

		console.log(`[PlanoFormaturaView] Found ${planoV2.semestreAtual.materias.length} MATR disciplines`, planoV2.semestreAtual.materias);
		return planoV2.semestreAtual.materias;
	});
</script>

<div class="flex h-full gap-0 bg-[#090c12] text-white">
	<!-- Main content (plano scroll area) -->
	<div class="flex-1 flex flex-col gap-5 px-6 py-6 overflow-hidden">

	<!-- ─── Page header ──────────────────────────────────────────────────── -->
	<div class="flex flex-wrap items-start justify-between gap-4">
		<div>
			<div class="flex items-center gap-2.5">
				<div class="flex h-8 w-8 items-center justify-center rounded-xl bg-blue-600/20">
					<GraduationCap class="h-4.5 w-4.5 text-blue-400" />
				</div>
				<h1 class="text-xl font-bold tracking-tight text-white">Plano de Formatura</h1>
			</div>
			<p class="mt-1.5 text-sm text-white/40">
				Sequência personalizada de matérias para você se formar.
			</p>
		</div>

		<div class="flex items-center gap-2">
			<button
				type="button"
				onclick={handleAjustar}
				class="flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs font-medium text-white/60 transition-colors hover:border-white/20 hover:bg-white/8 hover:text-white/85"
			>
				<Settings class="h-3.5 w-3.5" />
				Preferências
			</button>
			<button
				type="button"
				onclick={handleRefresh}
				disabled={planoFormaturaStore.status === 'loading'}
				class="flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs font-medium text-white/60 transition-colors hover:border-white/20 hover:bg-white/8 hover:text-white/85 disabled:opacity-40"
			>
				<RefreshCw class="h-3.5 w-3.5 {planoFormaturaStore.status === 'loading' ? 'animate-spin' : ''}" />
				Atualizar
			</button>
		</div>
	</div>

	<!-- ─── Summary stats ────────────────────────────────────────────────── -->
	{#if planoFormaturaStore.status === 'success' && planoFormaturaStore.plano}
		<div class="grid grid-cols-3 gap-3" transition:fade={{ duration: 200 }}>
			<!-- Formatura estimada -->
			<div class="rounded-xl border border-blue-500/20 bg-blue-600/8 px-4 py-3.5">
				<p class="text-[11px] font-medium uppercase tracking-wider text-blue-400/70">Formatura</p>
				<p class="mt-1 text-xl font-bold text-blue-200">
					{planoFormaturaStore.formaturaEstimada ?? '—'}
				</p>
				<p class="mt-0.5 text-[10px] text-blue-400/45">semestre previsto</p>
			</div>

			<!-- Semestres restantes -->
			<div class="rounded-xl border border-white/10 bg-white/4 px-4 py-3.5">
				<p class="text-[11px] font-medium uppercase tracking-wider text-white/40">Semestres</p>
				<p class="mt-1 text-xl font-bold text-white/85">
					{planoFormaturaStore.semestresRestantes ?? '—'}
				</p>
				<p class="mt-0.5 text-[10px] text-white/30">restantes até formatura</p>
			</div>

			<!-- Matérias críticas -->
			<div class="rounded-xl border border-orange-500/20 bg-orange-600/8 px-4 py-3.5">
				<p class="text-[11px] font-medium uppercase tracking-wider text-orange-400/70">Críticas</p>
				<p class="mt-1 text-xl font-bold text-orange-200">{totalCriticas}</p>
				<p class="mt-0.5 text-[10px] text-orange-400/45">matérias estratégicas</p>
			</div>
		</div>
	{/if}

	<!-- ─── Credit limit toggle ───────────────────────────────────────────── -->
	<div class="flex flex-wrap items-center justify-between gap-4">
		<div class="flex items-center gap-3">
			<span class="shrink-0 text-xs font-medium text-white/40">Créditos / semestre:</span>
			<input
				type="range"
				min={8}
				max={32}
				step={1}
				disabled={isChangingCredits}
				value={planoFormaturaStore.preferencias.limiteCreditos}
				oninput={(e) => debouncedLimiteChange(Number((e.target as HTMLInputElement).value))}
				class="w-36 accent-blue-500 disabled:opacity-40"
			/>
			<div class="flex items-center gap-1">
				<input
					type="number"
					min={8}
					max={40}
					disabled={isChangingCredits}
					value={planoFormaturaStore.preferencias.limiteCreditos}
					onchange={(e) => debouncedLimiteChange(Number((e.target as HTMLInputElement).value))}
					class="w-12 bg-[#161625] border border-white/10 rounded px-1.5 py-0.5 text-xs font-semibold text-white/90 text-right focus:outline-none focus:ring-1 focus:ring-blue-500/50 disabled:opacity-40 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
				/>
				<span class="text-xs font-semibold tabular-nums text-white/70">
					cr <span class="text-white/35">({planoFormaturaStore.preferencias.limiteCreditos * 15}h)</span>
				</span>
			</div>
		</div>

		<!-- Display unit toggle -->
		<div class="flex items-center gap-2">
			<button
				type="button"
				onclick={() => { displayUnit = 'creditos'; }}
				class="rounded-lg px-3 py-1.5 text-xs font-semibold transition-all
					{displayUnit === 'creditos'
						? 'border border-blue-500/60 bg-blue-600/20 text-blue-200 ring-1 ring-blue-500/30'
						: 'border border-white/10 bg-white/4 text-white/50 hover:border-white/20 hover:bg-white/7 hover:text-white/75'}"
			>
				Créditos
			</button>
			<button
				type="button"
				onclick={() => { displayUnit = 'horas'; }}
				class="rounded-lg px-3 py-1.5 text-xs font-semibold transition-all
					{displayUnit === 'horas'
						? 'border border-blue-500/60 bg-blue-600/20 text-blue-200 ring-1 ring-blue-500/30'
						: 'border border-white/10 bg-white/4 text-white/50 hover:border-white/20 hover:bg-white/7 hover:text-white/75'}"
			>
				Horas
			</button>
		</div>
	</div>

	<!-- Restrições ativas -->
	{#if planoFormaturaStore.restricoes.adiar.length > 0 || planoFormaturaStore.restricoes.priorizar.length > 0}
		<div class="rounded-xl border border-white/5 bg-black/20 backdrop-blur-xl px-4 py-3 shadow-inner">
			<p class="text-[10px] font-bold text-white/40 uppercase tracking-widest mb-2">Restrições ativas</p>
			<RestricoesChips />
		</div>
	{/if}

	<!-- ─── Loading state ────────────────────────────────────────────────── -->
	{#if planoFormaturaStore.status === 'loading'}
		<div class="flex flex-1 flex-col items-center justify-center gap-3 py-16" transition:fade={{ duration: 150 }}>
			<div class="flex h-12 w-12 items-center justify-center rounded-full border border-blue-500/30 bg-blue-600/10">
				<Loader2 class="h-6 w-6 animate-spin text-blue-400" />
			</div>
			<p class="text-sm text-white/40">Gerando seu plano de formatura…</p>
		</div>

	<!-- ─── Error state ───────────────────────────────────────────────────── -->
	{:else if planoFormaturaStore.status === 'error'}
		<div class="flex flex-1 flex-col items-center justify-center gap-4 py-16" transition:fade={{ duration: 150 }}>
			<div class="flex h-12 w-12 items-center justify-center rounded-full border border-amber-500/30 bg-amber-600/10">
				<AlertTriangle class="h-6 w-6 text-amber-400" />
			</div>
			<div class="text-center">
				<p class="text-sm font-medium text-white/70">Não foi possível gerar o plano</p>
				<p class="mt-1.5 max-w-sm text-xs text-white/35 leading-relaxed">
					{planoFormaturaStore.error ?? 'Verifique se seu histórico está importado e tente novamente.'}
				</p>
			</div>
			<button
				type="button"
				onclick={handleRefresh}
				class="flex items-center gap-1.5 rounded-lg bg-white/8 px-4 py-2 text-sm font-medium text-white/70 transition-colors hover:bg-white/12 hover:text-white/90"
			>
				<RefreshCw class="h-4 w-4" />
				Tentar novamente
			</button>
		</div>

	<!-- ─── Idle state ────────────────────────────────────────────────────── -->
	{:else if planoFormaturaStore.status === 'idle'}
		<div class="flex flex-1 flex-col items-center justify-center gap-3 py-16" transition:fade={{ duration: 150 }}>
			<div class="flex h-12 w-12 items-center justify-center rounded-full border border-white/10 bg-white/4">
				<GraduationCap class="h-6 w-6 text-white/40" />
			</div>
			<p class="text-sm text-white/40">Configurando seu plano…</p>
		</div>

	<!-- ─── Success: horizontal scroll of semester cards ──────────────────── -->
	{:else if planoFormaturaStore.status === 'success' && planoFormaturaStore.plano}
		<div class="flex flex-1 flex-col gap-4 overflow-hidden" transition:fade={{ duration: 200 }}>

			<!-- Notice about elective credits -->
			{#if hasOptativasPendentes}
				<div class="flex items-start gap-2.5 rounded-xl border border-amber-500/20 bg-amber-600/8 px-4 py-3">
					<BookOpenCheck class="mt-0.5 h-4 w-4 shrink-0 text-amber-400" />
					<p class="text-xs text-amber-200/70 leading-relaxed">
						O plano cobre as matérias <strong class="text-amber-200/90">obrigatórias</strong>.
						Créditos optativos e complementares devem ser planejados separadamente.
					</p>
				</div>
			{/if}

			<!-- Fluxo interativo Svelte Flow (Substitui scroll horizontal antigo) -->
			<PlannerSvelteFlow 
				plano={planoFormaturaStore.plano} 
				curso={fluxogramaStore.state.courseData} 
				{materiasMATR}
				{semestreAtual}
				onChatAction={handleChatAction}
				{displayUnit}
			/>

			{#if planoFormaturaStore.plano.plano.length === 0 && materiasMATR.length === 0}
				<div class="flex flex-1 flex-col items-center justify-center gap-3 py-12 text-center">
					<GraduationCap class="h-10 w-10 text-white/20" />
					<p class="text-sm text-white/40">
							Nenhum semestre no plano — você pode estar prestes a se formar!
						</p>
					</div>
				{/if}
		</div>
	{/if}
	</div>

	<!-- Chat panel (floating fixed) -->
	{#if isChatOpen}
		<div 
			class="fixed z-[100] flex flex-col bg-[#090c12]/90 sm:bg-[#090c12]/60 backdrop-blur-3xl overflow-hidden border border-white/10 shadow-[0_8px_30px_rgb(0,0,0,0.5)] origin-bottom-right
				{isMobile ? 'bottom-0 left-0 right-0 w-full h-[85vh] rounded-t-3xl rounded-b-none' : 'rounded-2xl'}" 
			style={isMobile ? '' : `left: ${chatX}px; top: ${chatY}px; width: ${chatW}px; height: ${chatH}px; resize: both;`}
			use:draggable
			in:scale={{ start: 0.6, duration: 400, easing: backOut }}
			out:scale={{ start: 0.8, duration: 200, easing: cubicOut }}
		>
			<div class="absolute top-4 right-4 z-50 flex items-center gap-1">
				{#if !isMobile}
					<button 
						type="button" 
						onclick={resetChat} 
						class="p-1 rounded-md text-white/40 hover:text-white/80 hover:bg-white/5 transition-colors cursor-pointer"
						aria-label="Restaurar tamanho e posição"
						title="Restaurar tamanho e posição"
					>
						<RefreshCw class="h-4 w-4" />
					</button>
				{/if}
				<button 
					type="button" 
					onclick={() => isChatOpen = false} 
					class="p-1 rounded-md text-white/40 hover:text-white/80 hover:bg-white/5 transition-colors cursor-pointer"
					aria-label="Fechar chat"
				>
					<X class="h-4 w-4" />
				</button>
			</div>
			<PlannerChatPanel />
		</div>
	{/if}

	<!-- Floating Toggle Button -->
	{#if !isChatOpen}
		<button
			type="button"
			onclick={() => isChatOpen = true}
			class="fixed z-[90] flex items-center justify-center bg-[#1e1e24]/80 backdrop-blur-md shadow-[0_8px_30px_rgba(236,72,153,0.3)] transition-all duration-300 hover:bg-[#2a2a32] hover:scale-105 active:scale-95 cursor-pointer border border-pink-500/50 hover:border-pink-400
				{isMobile ? 'bottom-4 right-4 h-14 w-14 rounded-full' : 'bottom-6 right-6 h-12 w-12 rounded-xl'}"
			aria-label="Toggle IA"
			in:scale={{ start: 0.5, duration: 400, easing: backOut, delay: 100 }}
			out:scale={{ start: 0.5, duration: 200, easing: cubicOut }}
		>
			<Bot class="{isMobile ? 'h-7 w-7' : 'h-6 w-6'} text-pink-400" />
		</button>
	{/if}
</div>

<style>
	:global(.overflow-x-auto::-webkit-scrollbar) {
		height: 4px;
	}
	:global(.overflow-x-auto::-webkit-scrollbar-track) {
		background: transparent;
	}
	:global(.overflow-x-auto::-webkit-scrollbar-thumb) {
		background: hsl(0 0% 100% / 0.12);
		border-radius: 999px;
	}
	:global(.overflow-x-auto::-webkit-scrollbar-thumb:hover) {
		background: hsl(0 0% 100% / 0.2);
	}
</style>

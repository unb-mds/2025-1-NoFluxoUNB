<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import { planoFormaturaStore } from '$lib/stores/plano-formatura.store.svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { authStore } from '$lib/stores/auth';
	import SemesterColumn from '../fluxograma/SemesterColumn.svelte';
	import SemestrePlanCard from './SemestrePlanCard.svelte';
	import SemestreAtualColumn from './SemestreAtualColumn.svelte';
	import PlannerPrerequisiteConnections from './PlannerPrerequisiteConnections.svelte';
	import { GraduationCap, Loader2, RefreshCw, Settings, AlertTriangle, BookOpenCheck } from 'lucide-svelte';
	import { fade } from 'svelte/transition';

	const CREDIT_OPTIONS = [16, 24, 32] as const;

	let isChangingCredits = $state(false);
	let displayUnit = $state<'creditos' | 'horas'>('creditos');
	let authState = $state({ user: null, isAuthenticated: false, isAnonymous: false, isLoading: true, error: null });
	authStore.subscribe((value) => {
		authState = value;
	});

	async function handleCreditChange(limite: 16 | 24 | 32) {
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

<div class="flex h-full flex-col gap-5 bg-[#090c12] px-6 py-6 text-white">

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
			</div>

			<!-- Semestres restantes -->
			<div class="rounded-xl border border-white/10 bg-white/4 px-4 py-3.5">
				<p class="text-[11px] font-medium uppercase tracking-wider text-white/40">Semestres</p>
				<p class="mt-1 text-xl font-bold text-white/85">
					{planoFormaturaStore.semestresRestantes ?? '—'}
				</p>
			</div>

			<!-- Matérias críticas -->
			<div class="rounded-xl border border-orange-500/20 bg-orange-600/8 px-4 py-3.5">
				<p class="text-[11px] font-medium uppercase tracking-wider text-orange-400/70">Críticas</p>
				<p class="mt-1 text-xl font-bold text-orange-200">{totalCriticas}</p>
			</div>
		</div>
	{/if}

	<!-- ─── Credit limit toggle ───────────────────────────────────────────── -->
	<div class="flex flex-wrap items-center justify-between gap-4">
		<div class="flex items-center gap-3">
			<span class="shrink-0 text-xs font-medium text-white/40">Créditos / semestre:</span>
			<div class="flex gap-1.5">
				{#each CREDIT_OPTIONS as limite}
					<button
						type="button"
						onclick={() => handleCreditChange(limite)}
						disabled={isChangingCredits}
						class="min-w-[52px] rounded-lg border px-3 py-1.5 text-xs font-semibold transition-all duration-150 disabled:opacity-50
							{planoFormaturaStore.preferencias.limiteCreditos === limite
								? 'border-blue-500/60 bg-blue-600/20 text-blue-200 ring-1 ring-blue-500/30'
								: 'border-white/10 bg-white/4 text-white/50 hover:border-white/20 hover:bg-white/7 hover:text-white/75'}"
					>
						{limite}
					</button>
				{/each}
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

			<!-- Horizontal scroll container -->
			<PlannerPrerequisiteConnections plano={planoFormaturaStore.plano} curso={fluxogramaStore.state.courseData}>
				<!-- Coluna do semestre atual (MATR) como primeira coluna -->
				{#if materiasMATR.length > 0}
					<SemestreAtualColumn
						materias={materiasMATR}
						{semestreAtual}
					/>
				{/if}

				{#each planoFormaturaStore.plano.plano as semestre, i (semestre.indice)}
					<SemestrePlanCard {semestre} index={i} {displayUnit} {semestreAtual} />
				{/each}

				{#if planoFormaturaStore.plano.plano.length === 0 && materiasMATR.length === 0}
					<div class="flex flex-1 flex-col items-center justify-center gap-3 py-12 text-center">
						<GraduationCap class="h-10 w-10 text-white/20" />
						<p class="text-sm text-white/40">
							Nenhum semestre no plano — você pode estar prestes a se formar!
						</p>
					</div>
				{/if}
			</PlannerPrerequisiteConnections>
		</div>
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

<script lang="ts">
	import type { CursoModel } from '$lib/types/curso';
	import type { IntegralizacaoResult } from '$lib/types/matriz';
	import { isOptativa } from '$lib/types/materia';
	import type { DadosFluxogramaUser } from '$lib/types/user';
	import { getTotalCreditsCompleted, getCurrentSubjectCodes } from '$lib/types/user';
	import { GraduationCap, Calendar, MessageSquare, X, Loader2 } from 'lucide-svelte';
	import { goto } from '$app/navigation';
	import { ROUTES } from '$lib/config/routes';
	import IntegralizacaoSection from './IntegralizacaoSection.svelte';

	interface Props {
		courseData: CursoModel;
		userFluxograma: DadosFluxogramaUser | null;
		integralizacao?: IntegralizacaoResult | null;
		integralizacaoLoading?: boolean;
		matrizes?: Array<{ curriculoCompleto: string }>;
		curriculoCompletoAtual?: string | null;
		onMatrizChange?: (curriculoCompleto: string) => void;
	}

	let {
		courseData,
		userFluxograma,
		integralizacao,
		integralizacaoLoading = false,
		matrizes = [],
		curriculoCompletoAtual = null,
		onMatrizChange
	}: Props = $props();

	let showChModal = $state(false);

	let totalCredits = $derived.by(() => {
		if (courseData.totalCreditos != null && courseData.totalCreditos > 0) {
			return courseData.totalCreditos;
		}
		return courseData.materias
			.filter((m) => !isOptativa(m))
			.reduce((sum, m) => sum + m.creditos, 0);
	});

	let completedCredits = $derived.by(() => {
		if (!userFluxograma) return 0;
		const creditsMap = new Map(courseData.materias.map((m) => [m.codigoMateria, m.creditos]));
		return getTotalCreditsCompleted(userFluxograma, creditsMap);
	});

	let progressLabel = $derived(
		integralizacaoLoading ? 'Carregando...' : integralizacao ? 'Carga horária (SIGAA)' : 'Créditos'
	);
	let progressValue = $derived(
		integralizacaoLoading
			? '—'
			: integralizacao && integralizacao.exigido.chTotal > 0
				? `${integralizacao.realizado.chTotal.toLocaleString('pt-BR')}h / ${integralizacao.exigido.chTotal.toLocaleString('pt-BR')}h`
				: `${completedCredits}/${totalCredits}`
	);
	let progressPct = $derived(
		integralizacaoLoading
			? null
			: integralizacao && integralizacao.exigido.chTotal > 0
				? Math.round((integralizacao.realizado.chTotal / integralizacao.exigido.chTotal) * 100)
				: totalCredits > 0
					? Math.round((completedCredits / totalCredits) * 100)
					: null
	);
	let progressSublabel = $derived(
		integralizacaoLoading ? 'aguarde' : integralizacao ? 'horas integralizadas' : 'créditos integralizados'
	);

	let currentSemester = $derived(userFluxograma?.semestreAtual ?? 1);

	/** CH das disciplinas matriculadas (MATR): simulação de +Xh se aprovado em todas. */
	let simulacaoMatr = $derived.by(() => {
		if (!userFluxograma || !courseData || !integralizacao || integralizacao.exigido.chTotal <= 0) return null;
		const matrCodes = getCurrentSubjectCodes(userFluxograma);
		if (matrCodes.size === 0) return null;
		const codigoToCreditos = new Map(
			courseData.materias.map((m) => [m.codigoMateria.trim().toUpperCase(), m.creditos])
		);
		let chHoras = 0;
		for (const code of matrCodes) {
			const cr = codigoToCreditos.get(code?.trim().toUpperCase() ?? '');
			if (cr != null && cr > 0) chHoras += Math.round(cr * 15);
		}
		if (chHoras <= 0) return null;
		return {
			chMatriculadas: chHoras,
			totalSimulado: integralizacao.realizado.chTotal + chHoras
		};
	});

	let podeAbrirModal = $derived(!!integralizacao && !integralizacaoLoading);

	function circleProgress(percent: number, radius: number) {
		const circumference = 2 * Math.PI * radius;
		const offset = circumference - (percent / 100) * circumference;
		return { circumference, offset };
	}

	let circleData = $derived(
		progressPct != null ? circleProgress(progressPct, 28) : null
	);

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') showChModal = false;
	}

	function handleBackdropClick(e: MouseEvent) {
		if (e.target === e.currentTarget) showChModal = false;
	}

	// Bloquear scroll do body quando o modal está aberto
	$effect(() => {
		if (showChModal) {
			const prev = document.body.style.overflow;
			document.body.style.overflow = 'hidden';
			return () => {
				document.body.style.overflow = prev;
			};
		}
	});
</script>

<svelte:window onkeydown={handleKeydown} />

{#if userFluxograma}
	<div class="grid min-w-0 grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4">
		<!-- Card CH: botão que abre modal (sem círculo de progresso) -->
		<button
			type="button"
			onclick={() => (podeAbrirModal ? (showChModal = true) : null)}
			class="rounded-xl border border-white/10 bg-black/40 p-4 text-left backdrop-blur-md transition-colors hover:border-white/20 hover:bg-black/50 {!podeAbrirModal
				? 'cursor-default'
				: 'cursor-pointer'}"
		>
			<div class="flex items-center justify-between gap-4">
				<div class="flex min-w-0 items-center gap-4">
					<div class="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-green-500/20">
						{#if integralizacaoLoading}
							<Loader2 class="h-7 w-7 animate-spin text-green-400" />
						{:else}
							<GraduationCap class="h-7 w-7 text-green-400" />
						{/if}
					</div>
					<div class="min-w-0">
						<div class="flex items-center gap-1.5 text-green-400">
							<span class="text-xs font-semibold uppercase tracking-wider">{progressLabel}</span>
						</div>
						<p class="text-xs text-white/50">{progressSublabel}</p>
						{#if podeAbrirModal}
							<p class="mt-1 text-xs text-cyan-400">Clique para ver detalhes</p>
						{/if}
					</div>
				</div>
				<div class="shrink-0 flex items-center gap-3">
					{#if progressPct != null && circleData}
						<div class="relative h-16 w-16 flex-shrink-0">
							<svg class="h-16 w-16 -rotate-90" viewBox="0 0 64 64" aria-hidden="true">
								<circle
									cx="32"
									cy="32"
									r="28"
									stroke="rgba(255,255,255,0.12)"
									stroke-width="5"
									fill="none"
								/>
								<circle
									cx="32"
									cy="32"
									r="28"
									stroke="#22c55e"
									stroke-width="5"
									fill="none"
									stroke-linecap="round"
									stroke-dasharray={circleData.circumference}
									stroke-dashoffset={circleData.offset}
									class="transition-all duration-600"
								/>
							</svg>
							<div class="absolute inset-0 flex items-center justify-center">
								<span class="text-lg font-bold text-white">{progressPct}%</span>
							</div>
						</div>
					{:else if progressPct != null}
						<div class="text-right">
							<p class="text-2xl font-bold text-white">{progressPct}%</p>
							<p class="text-xs text-white/50">integralização</p>
						</div>
					{/if}
					<div class="text-right">
						<p class="text-base font-semibold text-white">{progressValue}</p>
						<p class="text-xs text-white/50">{progressSublabel}</p>
						{#if simulacaoMatr}
							{@const pctSimulado = integralizacao && integralizacao.exigido.chTotal > 0 ? Math.round((simulacaoMatr.totalSimulado / integralizacao.exigido.chTotal) * 100) : null}
							<div
								class="mt-2 flex flex-col items-center gap-0.5"
								title="Se você for aprovado em todas as disciplinas em que está matriculado neste semestre, sua integralização passará a ser {simulacaoMatr.totalSimulado.toLocaleString('pt-BR')}h ({pctSimulado}%)."
							>
								<div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border-2 border-cyan-400/50 bg-cyan-500/10">
									<span class="text-sm font-bold text-cyan-200">
										{pctSimulado ?? '—'}%
									</span>
								</div>
								<span class="text-[10px] text-white/50">Próximo sem. (se aprovar nas atuais)</span>
							</div>
						{/if}
					</div>
				</div>
			</div>
		</button>

		<!-- Semestre atual -->
		<div class="rounded-xl border border-white/10 bg-black/40 p-4 backdrop-blur-md">
			<div class="flex items-center gap-1.5 text-amber-400">
				<Calendar class="h-4 w-4" />
				<span class="text-xs font-semibold uppercase tracking-wider">Semestre Atual</span>
			</div>
			<p class="mt-2 text-2xl font-bold text-white">{currentSemester}º</p>
			<p class="text-xs text-white/50">semestre</p>
			{#if userFluxograma.ira}
				<div class="mt-2 rounded-lg bg-white/5 px-2.5 py-1">
					<span class="text-xs text-white/50">IRA: </span>
					<span class="text-sm font-semibold text-white">{userFluxograma.ira.toFixed(1)}</span>
				</div>
			{/if}
		</div>

		<!-- Assistente CTA -->
		<div class="col-span-full">
			<button
				onclick={() => goto(ROUTES.ASSISTENTE)}
				class="group flex w-full flex-col items-stretch gap-2 rounded-xl border border-purple-500/20 bg-gradient-to-r from-purple-500/10 to-pink-500/10 px-4 py-3 transition-colors hover:border-purple-500/30 hover:shadow-lg sm:flex-row sm:items-center sm:justify-between sm:gap-0 sm:px-5"
			>
				<div class="flex items-center gap-3">
					<MessageSquare class="h-4 w-4 shrink-0 text-purple-400 sm:h-5 sm:w-5" />
					<div class="min-w-0 text-left">
						<p class="text-sm font-semibold text-white">Precisa de ajuda?</p>
						<p class="text-xs text-white/50">Converse com o assistente sobre seu fluxograma</p>
					</div>
				</div>
				<span class="rounded-full bg-purple-600 px-4 py-1.5 text-center text-xs font-medium text-white transition-colors group-hover:bg-purple-500 sm:text-left">
					Falar com Assistente
				</span>
			</button>
		</div>
	</div>

	<!-- Modal Carga Horária -->
	{#if showChModal && integralizacao}
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div
			class="modal-overlay"
			onclick={handleBackdropClick}
		>
			<div
				class="modal-box"
				role="dialog"
				aria-modal="true"
				aria-label="Detalhes da carga horária"
			>
				<div class="modal-header">
					<h2 class="text-base font-bold text-white sm:text-lg">Carga Horária (SIGAA)</h2>
					<button
						type="button"
						onclick={() => (showChModal = false)}
						class="rounded-lg p-2 text-white/60 transition-colors hover:bg-white/10 hover:text-white"
						aria-label="Fechar"
					>
						<X class="h-5 w-5" />
					</button>
				</div>
				<div class="modal-scroll-area">
					<IntegralizacaoSection
						{integralizacao}
						{matrizes}
						curriculoCompletoAtual={curriculoCompletoAtual ?? integralizacao.curriculoCompleto}
						onMatrizChange={onMatrizChange}
						simulacaoMatr={simulacaoMatr}
					/>
				</div>
			</div>
		</div>
	{/if}
{/if}

<style>
	.modal-overlay {
		position: fixed;
		inset: 0;
		z-index: 50;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		background: rgba(0, 0, 0, 0.6);
		backdrop-filter: blur(4px);
		padding: 0.5rem;
	}
	@media (min-width: 640px) {
		.modal-overlay { padding: 1rem; }
	}
	.modal-box {
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		display: flex;
		flex-direction: column;
		max-height: 92vh;
		width: 100%;
		max-width: 42rem;
		overflow: hidden;
		border-radius: 0.75rem;
		border: 1px solid rgba(255, 255, 255, 0.1);
		background: rgba(17, 24, 39, 0.95);
		box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
		backdrop-filter: blur(24px);
	}
	.modal-header {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: space-between;
		border-bottom: 1px solid rgba(255, 255, 255, 0.1);
		background: rgba(17, 24, 39, 0.95);
		padding: 0.75rem 1rem;
	}
	@media (min-width: 640px) {
		.modal-header { padding: 1rem 1.5rem; }
	}
	.modal-scroll-area {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		overscroll-behavior: contain;
		-webkit-overflow-scrolling: touch;
		padding: 1rem;
	}
	@media (min-width: 640px) {
		.modal-scroll-area { padding: 1.5rem; }
	}
</style>

<script lang="ts">
	import { page } from '$app/stores';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import GraffitiBackground from '$lib/components/effects/GraffitiBackground.svelte';
	import FluxogramaHeader from '$lib/components/fluxograma/FluxogramaHeader.svelte';
	import FluxogramaLegendControls from '$lib/components/fluxograma/FluxogramaLegendControls.svelte';
	import FluxogramViewportChrome from '$lib/components/fluxograma/FluxogramViewportChrome.svelte';
	import FluxogramContainer from '$lib/components/fluxograma/FluxogramContainer.svelte';
	import SubjectDetailsModal from '$lib/components/fluxograma/SubjectDetailsModal.svelte';
	import OptativasModal from '$lib/components/fluxograma/OptativasModal.svelte';
	import ProgressSummarySection from '$lib/components/fluxograma/ProgressSummarySection.svelte';
	import ProgressToolsSection from '$lib/components/fluxograma/ProgressToolsSection.svelte';
	import OptativasAdicionadasSection from '$lib/components/fluxograma/OptativasAdicionadasSection.svelte';
	import PrerequisiteChainDialog from '$lib/components/fluxograma/PrerequisiteChainDialog.svelte';
	import RequisitosMudancaCursoBanner from '$lib/components/fluxograma/RequisitosMudancaCursoBanner.svelte';
	import MateriasConcluidasModal from '$lib/components/fluxograma/MateriasConcluidasModal.svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { authStore } from '$lib/stores/auth';
	import { getIntegralizacao } from '$lib/services/integralizacao.service';
	import { supabaseDataService } from '$lib/services/supabase-data.service';
	import { onMount, tick } from 'svelte';
	import { Loader2, AlertTriangle, ArrowRightLeft, ListChecks } from 'lucide-svelte';
	import { isOptativa, type MateriaModel } from '$lib/types/materia';
	import type { IntegralizacaoResult } from '$lib/types/matriz';
import { getCompletedSubjectCodes } from '$lib/types/user';
import { getCompletedByEquivalenceCodes } from '$lib/types/equivalencia';
import {
	evaluateExpressionWithTracking,
	evaluateExpressaoLogica,
	getMatchingCodesFromExpressao
} from '$lib/utils/expressao-logica';

	const store = fluxogramaStore;

	let courseName = $derived(decodeURIComponent($page.params.courseName || ''));
	let containerRef: HTMLElement | null = $state(null);
	let fluxogramaViewportRef: HTMLElement | null = $state(null);
	let selectedSubject = $state<MateriaModel | null>(null);
	let chainDialogSubject = $state<MateriaModel | null>(null);
	let showOptativas = $state(false);
	let integralizacao = $state<IntegralizacaoResult | null>(null);
	let integralizacaoLoading = $state(false);
	let matrizes = $state<Array<{ curriculoCompleto: string }>>([]);
	let fluxogramHelpOpen = $state(false);
	let showMateriasConcluidasModal = $state(false);
	let fluxogramaFocusMode = $state(false);

type EquivalenciaSimulacaoItem = {
	origem: string;
	nomeOrigem: string;
	categoriaNaMatriz: 'obrigatoria' | 'optativa' | 'fora_da_matriz';
	materiasQueSatisfizeram: string[];
	viaCadeia: boolean;
	expressao: string | null;
};

	let userFluxograma = $derived(store.userFluxograma);
	let curriculoCompletoAtual = $derived(store.state.courseData?.curriculoCompleto ?? null);

	function normalizarChaveMatriz(valor: string | null | undefined): string {
		const s = (valor ?? '').trim().toUpperCase();
		if (!s) return '';
		const m = s.match(/^(\d+\/-?\d+)/);
		return (m?.[1] ?? s).trim();
	}

	/** True quando está vendo outro curso (mudança de curso) — recalcular integralização por disciplinas casadas. */
	let eSimulacaoOutroCurso = $derived.by(() => {
		const fluxo = userFluxograma;
		const course = store.state.courseData;
		if (!fluxo || !course) return false;
		const matrizOrigem = normalizarChaveMatriz(fluxo.matrizCurricular);
		const matrizExibida = normalizarChaveMatriz(course.curriculoCompleto);
		if (matrizOrigem && matrizExibida) return matrizOrigem !== matrizExibida;
		// Fallback defensivo quando faltar matriz no dado do usuário.
		const nomeUsuario = (fluxo.nomeCurso ?? '').trim().toLowerCase();
		const nomeExibido = (course.nomeCurso ?? '').trim().toLowerCase();
		return nomeUsuario !== nomeExibido;
	});

	let ultimaAssinaturaDebugSimulacao = $state('');
	$effect(() => {
		const fluxo = userFluxograma;
		const course = store.state.courseData;
		if (!fluxo || !course) return;
		const matrizOrigem = normalizarChaveMatriz(fluxo.matrizCurricular);
		const matrizExibida = normalizarChaveMatriz(course.curriculoCompleto);
		const assinatura = `${matrizOrigem}|${matrizExibida}|${String(eSimulacaoOutroCurso)}`;
		if (assinatura === ultimaAssinaturaDebugSimulacao) return;
		ultimaAssinaturaDebugSimulacao = assinatura;
		console.log('[MudancaCurso:DebugSimulacao]', {
			matrizOrigem,
			matrizExibida,
			modoSimulacao: eSimulacaoOutroCurso,
			nomeCursoOrigem: fluxo.nomeCurso ?? '',
			nomeCursoExibido: course.nomeCurso ?? ''
		});
	});

	// Count only completed codes that match subjects in this course's curriculum
	let matchingCompletedCount = $derived.by(() => {
		if (!store.state.courseData) return 0;
		const courseSubjectCodes = new Set(
			store.state.courseData.materias
				.filter((m) => !isOptativa(m))
				.map((m) => m.codigoMateria)
		);
		let count = 0;
		for (const code of store.completedCodes) {
			if (courseSubjectCodes.has(code)) count++;
		}
		return count;
	});

	// Optativas do curso (modal); sem coluna pool no fluxograma.
	let optativas = $derived.by(() => {
		if (!store.state.courseData) return [];
		return store.state.courseData.materias.filter((m) => isOptativa(m));
	});

let equivalenciasSimulacao = $derived.by((): EquivalenciaSimulacaoItem[] => {
	const course = store.state.courseData;
	const fluxo = userFluxograma;
	if (!course || !fluxo) return [];
	const equivalencias = course.equivalencias ?? [];
	if (equivalencias.length === 0) return [];

	const baseNorm = new Set(
		[...getCompletedSubjectCodes(fluxo)]
			.map((c) => String(c ?? '').trim().toUpperCase())
			.filter(Boolean)
	);

	const completedByEquiv = getCompletedByEquivalenceCodes(equivalencias, baseNorm);
	const completedByEquivNorm = new Set(
		[...completedByEquiv]
			.map((c) => String(c ?? '').trim().toUpperCase())
			.filter(Boolean)
	);

	const categoriaByCode = new Map<string, 'obrigatoria' | 'optativa'>();
	for (const m of course.materias) {
		const cod = String(m.codigoMateria ?? '').trim().toUpperCase();
		if (!cod) continue;
		categoriaByCode.set(cod, isOptativa(m) ? 'optativa' : 'obrigatoria');
	}

	const workNorm = new Set(baseNorm);
	const out = new Map<string, EquivalenciaSimulacaoItem>();
	let changed = true;
	let guard = 0;
	while (changed && guard++ < 64) {
		changed = false;
		for (const eq of equivalencias) {
			const origem = String(eq.codigoMateriaOrigem ?? '').trim().toUpperCase();
			if (!origem || !completedByEquivNorm.has(origem) || workNorm.has(origem)) continue;
			const snap = new Set(workNorm);
			const satisfaz =
				eq.expressaoLogica != null
					? evaluateExpressaoLogica(eq.expressaoLogica, snap)
					: evaluateExpressionWithTracking((eq.expressao ?? '').trim(), snap).isTrue;
			if (!satisfaz) continue;

			const matching =
				eq.expressaoLogica != null
					? [...getMatchingCodesFromExpressao(eq.expressaoLogica, snap)].map((c) =>
							String(c ?? '').trim().toUpperCase()
						)
					: [...evaluateExpressionWithTracking((eq.expressao ?? '').trim(), snap).matchingMaterias].map(
							(c) => String(c ?? '').trim().toUpperCase()
						);
			const matchingUnicos = [...new Set(matching)].filter(Boolean);
			const viaCadeia = matchingUnicos.some((m) => !baseNorm.has(m));
			const categoriaNaMatriz = categoriaByCode.get(origem) ?? 'fora_da_matriz';
			out.set(origem, {
				origem,
				nomeOrigem: eq.nomeMateriaOrigem ?? '',
				categoriaNaMatriz,
				materiasQueSatisfizeram: matchingUnicos,
				viaCadeia,
				expressao: eq.expressao ?? null
			});
			workNorm.add(origem);
			changed = true;
		}
	}

	return [...out.values()].sort((a, b) => a.origem.localeCompare(b.origem, 'pt-BR'));
});

	// Compute integralização when course data loads (for logged-in users)
	$effect(() => {
		const course = store.state.courseData;
		const fluxo = userFluxograma;
		const cc = course?.curriculoCompleto;
		void store.diagramLayoutRevision;
		if (!cc || !fluxo) {
			if (course?.idCurso && !cc) {
				supabaseDataService.getMatrizesByCurso(course.idCurso).then((m) => {
					matrizes = m.map((x) => ({ curriculoCompleto: x.curriculoCompleto }));
				});
			}
			integralizacao = null;
			integralizacaoLoading = false;
			return;
		}
		integralizacaoLoading = true;
		getIntegralizacao({
			curriculoCompleto: cc,
			dadosFluxograma: fluxo,
			cargaHorariaIntegralizada: store.cargaHorariaIntegralizada,
			equivalencias: course?.equivalencias,
			recalcularPorDisciplinas: eSimulacaoOutroCurso
		}).then((r) => {
			integralizacao = r;
			integralizacaoLoading = false;
		});
		if (course?.idCurso) {
			supabaseDataService.getMatrizesByCurso(course.idCurso).then((m) => {
				matrizes = m.map((x) => ({ curriculoCompleto: x.curriculoCompleto }));
			});
		}
	});

	onMount(() => {
		if (courseName) {
			store.setConnectionMode('all');
			const user = authStore.getUser();
			const anonymous = !user?.dadosFluxograma;
			// If a specific matriz was requested via query param, load it directly
			const matrizParam = $page.url.searchParams.get('matriz');
			if (matrizParam) {
				store.loadCourseDataByCurriculoCompleto(matrizParam, anonymous);
			} else {
				store.loadCourseData(courseName, anonymous);
			}
		}

		return () => {
			store.reset();
		};
	});

	async function handleMatrizChange(curriculoCompleto: string) {
		await store.loadCourseDataByCurriculoCompleto(curriculoCompleto);
		if (userFluxograma) {
			integralizacaoLoading = true;
			try {
				const course = store.state.courseData;
				const recalc = course != null
					? (() => {
							const matrizOrigem = normalizarChaveMatriz(userFluxograma.matrizCurricular);
							const matrizExibida = normalizarChaveMatriz(course.curriculoCompleto);
							if (matrizOrigem && matrizExibida) return matrizOrigem !== matrizExibida;
							return (userFluxograma.nomeCurso ?? '').trim().toLowerCase() !==
								(course.nomeCurso ?? '').trim().toLowerCase();
						})()
					: false;
				const r = await getIntegralizacao({
					curriculoCompleto,
					dadosFluxograma: userFluxograma,
					cargaHorariaIntegralizada: store.cargaHorariaIntegralizada,
					equivalencias: course?.equivalencias,
					recalcularPorDisciplinas: recalc
				});
				integralizacao = r;
			} finally {
				integralizacaoLoading = false;
			}
		}
	}

	function handleSubjectClick(materia: MateriaModel) {
		chainDialogSubject = null;
		selectedSubject = materia;
		store.setSelectedSubject(materia.codigoMateria);
	}

	function handleSubjectOpenChain(materia: MateriaModel) {
		selectedSubject = null;
		store.setSelectedSubject(null);
		chainDialogSubject = materia;
	}

	function closeSubjectModal() {
		selectedSubject = null;
		store.setSelectedSubject(null);
	}

	function closeChainDialog() {
		chainDialogSubject = null;
	}

	function centerFluxogramaViewport() {
		const viewport = fluxogramaViewportRef;
		if (!viewport) return;
		const scrollRoot = viewport.querySelector<HTMLElement>('[data-fluxogram-scroll-root]');
		if (!scrollRoot) return;
		const columns = [...scrollRoot.querySelectorAll<HTMLElement>('.semester-column')];
		if (columns.length === 0) {
			scrollRoot.scrollLeft = 0;
			return;
		}
		const sorted = [...columns].sort((a, b) => a.offsetLeft - b.offsetLeft);
		const primeiraColuna = sorted[0];
		const margemEsquerda = Math.max(16, Math.round(scrollRoot.clientWidth * 0.08));
		const targetLeft = primeiraColuna.offsetLeft - margemEsquerda;
		scrollRoot.scrollLeft = Math.max(0, targetLeft);
	}

	function scheduleCenterFluxogramaViewport(): () => void {
		let cancelled = false;
		const timers: ReturnType<typeof setTimeout>[] = [];
		const run = () => {
			if (cancelled) return;
			centerFluxogramaViewport();
		};
		requestAnimationFrame(run);
		timers.push(setTimeout(run, 220));
		timers.push(setTimeout(run, 520));
		return () => {
			cancelled = true;
			for (const t of timers) clearTimeout(t);
		};
	}

	$effect(() => {
		if (fluxogramaFocusMode) {
			const prev = document.body.style.overflow;
			document.body.dataset.fluxogramaFocusMode = 'true';
			document.body.style.overflow = 'hidden';
			return () => {
				delete document.body.dataset.fluxogramaFocusMode;
				document.body.style.overflow = prev;
			};
		}
		delete document.body.dataset.fluxogramaFocusMode;
	});

	$effect(() => {
		if (!fluxogramaFocusMode) return;
		void store.diagramLayoutRevision;
		let cancel = false;
		let cancelSchedule: (() => void) | null = null;
		(async () => {
			await tick();
			if (cancel) return;
			requestAnimationFrame(() => {
				if (cancel) return;
				cancelSchedule = scheduleCenterFluxogramaViewport();
			});
		})();
		return () => {
			cancel = true;
			cancelSchedule?.();
		};
	});
</script>

<PageMeta
	title="Fluxograma - {courseName}"
	description="Visualize o fluxograma do curso {courseName} na UnB"
	noIndex={true}
/>

<GraffitiBackground />

<div
	class="relative z-10 container mx-auto w-full min-w-0 max-w-full px-3 pb-2 sm:px-4 sm:pb-3 [@media(orientation:landscape)_and_(max-height:560px)]:px-2 [@media(orientation:landscape)_and_(max-height:560px)]:pb-1 [@media(orientation:landscape)_and_(max-height:560px)]:sm:px-3 [@media(orientation:landscape)_and_(max-height:560px)]:sm:pb-2"
>
	{#if store.state.loading}
		<div class="flex flex-col items-center justify-center gap-4 py-20">
			<Loader2 class="h-10 w-10 animate-spin text-purple-400" />
			<p class="text-sm text-white/60">Carregando fluxograma de {courseName}...</p>
		</div>
	{:else if store.state.error}
		<div class="mx-auto max-w-md rounded-2xl border border-red-500/20 bg-red-500/10 p-8 text-center backdrop-blur-md">
			<AlertTriangle class="mx-auto mb-3 h-8 w-8 text-red-400" />
			<h2 class="mb-2 text-lg font-semibold text-white">Erro ao carregar fluxograma</h2>
			<p class="mb-4 text-sm text-red-300/80">{store.state.error}</p>
			<button
				onclick={() => {
				if (courseName) {
					const u = authStore.getUser();
					store.loadCourseData(courseName, !u?.dadosFluxograma);
				}
			}}
				class="rounded-full bg-white/10 px-6 py-2 text-sm font-medium text-white transition-colors hover:bg-white/20"
			>
				Tentar novamente
			</button>
		</div>
	{:else if store.state.courseData}
		<div class="flex flex-col gap-2 pb-6">
			{#if !fluxogramaFocusMode && (store.precisaSalvarPerfil || store.optativasAdicionadas.length > 0)}
				<div class="relative z-50 shrink-0">
					<OptativasAdicionadasSection />
				</div>
			{/if}
			<div
				class="{fluxogramaFocusMode
					? 'fluxograma-focus-shell fixed inset-0 z-[2147483000] flex min-h-0 flex-col overflow-hidden rounded-none'
					: 'flex h-[calc(100dvh-3.25rem)] max-h-[calc(100dvh-3.25rem)] min-h-0 flex-col gap-1 overflow-hidden [overflow-anchor:none] sm:h-[calc(100dvh-3.75rem)] sm:max-h-[calc(100dvh-3.75rem)] sm:gap-1.5 [@media(orientation:landscape)_and_(max-height:560px)]:h-[calc(100dvh-0.5rem)] [@media(orientation:landscape)_and_(max-height:560px)]:max-h-[calc(100dvh-0.5rem)] [@media(orientation:landscape)_and_(max-height:560px)]:gap-0.5 [@media(orientation:landscape)_and_(max-height:560px)]:sm:h-[calc(100dvh-0.5rem)] [@media(orientation:landscape)_and_(max-height:560px)]:sm:max-h-[calc(100dvh-0.5rem)]'}"
			>
				{#if !fluxogramaFocusMode}
					<div
						class="shrink-0 space-y-3 sm:space-y-3.5 md:space-y-4 [@media(orientation:landscape)_and_(max-height:560px)]:space-y-1.5 [@media(orientation:landscape)_and_(max-height:560px)]:sm:space-y-2"
					>
						<FluxogramaHeader
							courseName={store.state.courseData.nomeCurso}
							matrizCurricular={store.state.courseData.matrizCurricular}
							tipoCurso={store.state.courseData.tipoCurso}
							turno={store.state.courseData.turno}
							{matrizes}
							{curriculoCompletoAtual}
							onMatrizChange={handleMatrizChange}
							{containerRef}
							showBackToMyFluxogram={eSimulacaoOutroCurso}
							showFluxogramViewMenu={true}
							onOpenFluxogramHelp={() => (fluxogramHelpOpen = true)}
						/>

						<FluxogramaLegendControls
							onOpenOptativas={optativas.length > 0 ? () => (showOptativas = true) : undefined}
							showFluxogramViewMenu={true}
							onOpenFluxogramHelp={() => (fluxogramHelpOpen = true)}
						/>
						{#if userFluxograma}
							<div class="flex items-center justify-start">
								<button
									type="button"
									onclick={() => (showMateriasConcluidasModal = true)}
									class="inline-flex items-center gap-1.5 rounded-full border border-cyan-500/35 bg-cyan-500/10 px-3 py-1.5 text-xs font-medium text-cyan-200 transition-colors hover:bg-cyan-500/20 sm:text-sm"
								>
									<ListChecks class="h-4 w-4" />
									Concluidas do historico
								</button>
							</div>
						{/if}
					</div>
				{/if}

				<div class="relative z-0 min-h-0 flex-1 basis-0 overflow-hidden" bind:this={fluxogramaViewportRef}>
					<FluxogramContainer
						onSubjectClick={handleSubjectClick}
						onSubjectOpenChain={handleSubjectOpenChain}
						focusMode={fluxogramaFocusMode}
						bind:bind_container={containerRef}
					/>
					<FluxogramViewportChrome
						bind:helpOpen={fluxogramHelpOpen}
						focusMode={fluxogramaFocusMode}
						toggleFocusMode={() => (fluxogramaFocusMode = !fluxogramaFocusMode)}
					/>
				</div>
			</div>

			{#if !fluxogramaFocusMode && !store.state.isAnonymous}
				<div class="relative z-40 mt-2 shrink-0 space-y-4 border-t border-white/10 pt-4">
					{#if userFluxograma && store.state.courseData}
						<div class="space-y-2">
							{#if eSimulacaoOutroCurso}
								<RequisitosMudancaCursoBanner
									dadosFluxograma={userFluxograma}
									{integralizacao}
									integralizacaoLoading={integralizacaoLoading}
								/>
							{/if}
							<p class="flex items-center gap-1.5 text-xs text-white/70 sm:text-sm">
								<ArrowRightLeft class="h-4 w-4 shrink-0 text-cyan-400" />
								<span
									><span class="font-medium text-white/90">Progresso neste curso</span>
									<span class="text-white/45"> · simulação pelo histórico</span></span
								>
							</p>
							<ProgressSummarySection
								courseData={store.state.courseData}
								{userFluxograma}
								{integralizacao}
								integralizacaoLoading={integralizacaoLoading}
								{matrizes}
								{curriculoCompletoAtual}
								onMatrizChange={handleMatrizChange}
							/>
						</div>
					{/if}
					<ProgressToolsSection />
				</div>
			{:else if !fluxogramaFocusMode && userFluxograma && store.state.courseData}
				<div class="relative z-40 mt-2 space-y-2 border-t border-white/10 pt-4">
					{#if eSimulacaoOutroCurso}
						<RequisitosMudancaCursoBanner
							dadosFluxograma={userFluxograma}
							{integralizacao}
							integralizacaoLoading={integralizacaoLoading}
						/>
					{/if}
					<p class="flex items-center gap-1.5 text-xs text-white/70">
						<ArrowRightLeft class="h-4 w-4 shrink-0 text-cyan-400" />
						<span
							><span class="font-medium text-white/90">Progresso neste curso</span>
							<span class="text-white/45"> · simulação pelo histórico</span></span
						>
					</p>
					<ProgressSummarySection
						courseData={store.state.courseData}
						{userFluxograma}
						{integralizacao}
						integralizacaoLoading={integralizacaoLoading}
						{matrizes}
						{curriculoCompletoAtual}
						onMatrizChange={handleMatrizChange}
					/>
				</div>
			{/if}
		</div>

		<!-- Subject details modal -->
		{#if selectedSubject && store.state.courseData}
			<SubjectDetailsModal
				materia={selectedSubject}
				courseData={store.state.courseData}
				onclose={closeSubjectModal}
			/>
		{/if}

		{#if chainDialogSubject && store.state.courseData}
			<PrerequisiteChainDialog
				materia={chainDialogSubject}
				courseData={store.state.courseData}
				onclose={closeChainDialog}
			/>
		{/if}

		<!-- Optativas modal -->
		{#if showOptativas}
			<OptativasModal
				{optativas}
				onclose={() => (showOptativas = false)}
			/>
		{/if}

		{#if showMateriasConcluidasModal && userFluxograma}
			<MateriasConcluidasModal
				dadosFluxograma={userFluxograma}
				materiasCurso={store.state.courseData?.materias ?? []}
				equivalenciasSimulacao={equivalenciasSimulacao}
				mostrarEquivalenciasSimulacao={equivalenciasSimulacao.length > 0}
				onclose={() => (showMateriasConcluidasModal = false)}
			/>
		{/if}
	{/if}
</div>

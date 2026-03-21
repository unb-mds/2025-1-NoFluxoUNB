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
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { authStore } from '$lib/stores/auth';
	import { getIntegralizacao } from '$lib/services/integralizacao.service';
	import { supabaseDataService } from '$lib/services/supabase-data.service';
	import { onMount } from 'svelte';
	import { Loader2, AlertTriangle, ArrowRightLeft } from 'lucide-svelte';
	import { isOptativa, type MateriaModel } from '$lib/types/materia';
	import type { IntegralizacaoResult } from '$lib/types/matriz';

	const store = fluxogramaStore;

	let courseName = $derived(decodeURIComponent($page.params.courseName || ''));
	let containerRef: HTMLElement | null = $state(null);
	let selectedSubject = $state<MateriaModel | null>(null);
	let showOptativas = $state(false);
	let integralizacao = $state<IntegralizacaoResult | null>(null);
	let integralizacaoLoading = $state(false);
	let matrizes = $state<Array<{ curriculoCompleto: string }>>([]);
	let fluxogramHelpOpen = $state(false);

	let userFluxograma = $derived(store.userFluxograma);
	let curriculoCompletoAtual = $derived(store.state.courseData?.curriculoCompleto ?? null);

	/** True quando está vendo outro curso (mudança de curso) — recalcular integralização por disciplinas casadas. */
	let eSimulacaoOutroCurso = $derived.by(() => {
		const fluxo = userFluxograma;
		const course = store.state.courseData;
		if (!fluxo || !course) return false;
		const nomeUsuario = (fluxo.nomeCurso ?? '').trim().toLowerCase();
		const nomeExibido = (course.nomeCurso ?? '').trim().toLowerCase();
		return nomeUsuario !== nomeExibido;
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

	// Optativas = semester 0
	let optativas = $derived.by(() => {
		if (!store.state.courseData) return [];
		return store.state.courseData.materias.filter((m) => isOptativa(m));
	});

	// Compute integralização when course data loads (for logged-in users)
	$effect(() => {
		const course = store.state.courseData;
		const fluxo = userFluxograma;
		const cc = course?.curriculoCompleto;
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
			const r = await getIntegralizacao({
				curriculoCompleto,
				dadosFluxograma: userFluxograma,
				cargaHorariaIntegralizada: store.cargaHorariaIntegralizada,
				equivalencias: store.state.courseData?.equivalencias,
				recalcularPorDisciplinas: eSimulacaoOutroCurso
			});
				integralizacao = r;
			} finally {
				integralizacaoLoading = false;
			}
		}
	}

	function handleSubjectClick(materia: MateriaModel) {
		selectedSubject = materia;
		store.setSelectedSubject(materia.codigoMateria);
	}

	function closeSubjectModal() {
		selectedSubject = null;
		store.setSelectedSubject(null);
	}
</script>

<PageMeta
	title="Fluxograma - {courseName}"
	description="Visualize o fluxograma do curso {courseName} na UnB"
/>

<GraffitiBackground />

<div class="relative z-10 container mx-auto w-full min-w-0 max-w-full px-3 py-2 sm:px-4 sm:py-3">
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
			<div
				class="flex h-[calc(100dvh-3.25rem)] max-h-[calc(100dvh-3.25rem)] min-h-0 flex-col gap-1 overflow-hidden sm:h-[calc(100dvh-3.75rem)] sm:max-h-[calc(100dvh-3.75rem)] sm:gap-1.5"
			>
				<div class="shrink-0 space-y-3 sm:space-y-3.5 md:space-y-4">
					<FluxogramaHeader
						courseName={store.state.courseData.nomeCurso}
						matrizCurricular={store.state.courseData.matrizCurricular}
						tipoCurso={store.state.courseData.tipoCurso}
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
				</div>

				<div class="relative z-0 min-h-0 flex-1 basis-0 overflow-hidden">
					<FluxogramContainer
						onSubjectClick={handleSubjectClick}
						bind:bind_container={containerRef}
					/>
					<FluxogramViewportChrome bind:helpOpen={fluxogramHelpOpen} />
				</div>
			</div>

			{#if !store.state.isAnonymous}
				<div class="relative z-40 mt-2 shrink-0 space-y-4 border-t border-white/10 pt-4">
					{#if userFluxograma && store.state.courseData}
						<div class="space-y-2">
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
			{:else if userFluxograma && store.state.courseData}
				<div class="relative z-40 mt-2 space-y-2 border-t border-white/10 pt-4">
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

		<!-- Optativas modal -->
		{#if showOptativas}
			<OptativasModal
				{optativas}
				onclose={() => (showOptativas = false)}
			/>
		{/if}
	{/if}
</div>

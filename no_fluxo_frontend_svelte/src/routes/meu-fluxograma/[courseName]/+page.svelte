<script lang="ts">
	import { page } from '$app/stores';
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import GraffitiBackground from '$lib/components/effects/GraffitiBackground.svelte';
	import FluxogramaHeader from '$lib/components/fluxograma/FluxogramaHeader.svelte';
	import FluxogramaLegendControls from '$lib/components/fluxograma/FluxogramaLegendControls.svelte';
	import FluxogramContainer from '$lib/components/fluxograma/FluxogramContainer.svelte';
	import SubjectDetailsModal from '$lib/components/fluxograma/SubjectDetailsModal.svelte';
	import OptativasModal from '$lib/components/fluxograma/OptativasModal.svelte';
	import ProgressSummarySection from '$lib/components/fluxograma/ProgressSummarySection.svelte';
	import IntegralizacaoSection from '$lib/components/fluxograma/IntegralizacaoSection.svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { authStore } from '$lib/stores/auth';
	import { getIntegralizacao } from '$lib/services/integralizacao.service';
	import { supabaseDataService } from '$lib/services/supabase-data.service';
	import { onMount } from 'svelte';
	import { Loader2, AlertTriangle, ArrowRightLeft } from 'lucide-svelte';
	import type { MateriaModel } from '$lib/types/materia';
	import type { IntegralizacaoResult } from '$lib/types/matriz';

	const store = fluxogramaStore;

	let courseName = $derived(decodeURIComponent($page.params.courseName || ''));
	let containerRef: HTMLElement | null = $state(null);
	let selectedSubject = $state<MateriaModel | null>(null);
	let showOptativas = $state(false);
	let integralizacao = $state<IntegralizacaoResult | null>(null);
	let matrizes = $state<Array<{ curriculoCompleto: string }>>([]);

	let userFluxograma = $derived(store.userFluxograma);
	let curriculoCompletoAtual = $derived(store.state.courseData?.curriculoCompleto ?? null);

	// Count only completed codes that match subjects in this course's curriculum
	let matchingCompletedCount = $derived.by(() => {
		if (!store.state.courseData) return 0;
		const courseSubjectCodes = new Set(
			store.state.courseData.materias
				.filter((m) => m.nivel > 0)
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
		return store.state.courseData.materias.filter((m) => m.nivel === 0);
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
			return;
		}
		getIntegralizacao({
			curriculoCompleto: cc,
			dadosFluxograma: fluxo,
			equivalencias: course?.equivalencias
		}).then((r) => {
			integralizacao = r;
		});
		if (course?.idCurso) {
			supabaseDataService.getMatrizesByCurso(course.idCurso).then((m) => {
				matrizes = m.map((x) => ({ curriculoCompleto: x.curriculoCompleto }));
			});
		}
	});

	onMount(() => {
		if (courseName) {
			// If the user is logged in with fluxograma data, show their progress
			// on this course (completed subjects carry over by matching codes).
			const user = authStore.getUser();
			const anonymous = !user?.dadosFluxograma;
			store.loadCourseData(courseName, anonymous);
		}

		return () => {
			store.reset();
		};
	});

	async function handleMatrizChange(curriculoCompleto: string) {
		await store.loadCourseDataByCurriculoCompleto(curriculoCompleto);
		if (userFluxograma) {
			const r = await getIntegralizacao({
				curriculoCompleto,
				dadosFluxograma: userFluxograma,
				equivalencias: store.state.courseData?.equivalencias
			});
			integralizacao = r;
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

<div class="relative z-10 container mx-auto max-w-[95vw] px-4 py-6">
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
		<div class="space-y-4">
			<!-- Header -->
			<FluxogramaHeader
				courseName={store.state.courseData.nomeCurso}
				matrizCurricular={store.state.courseData.matrizCurricular}
				{containerRef}
			/>

			<!-- Progress simulation (only for logged-in users with history) -->
			{#if userFluxograma && store.state.courseData}
				<div class="space-y-4">
					<div class="flex items-center gap-2 text-white/80">
						<ArrowRightLeft class="h-5 w-5 text-cyan-400" />
						<div>
							<h3 class="text-sm font-semibold">Seu progresso neste curso</h3>
							<p class="text-xs text-white/50">Simulação com base no seu histórico atual</p>
						</div>
					</div>

					<ProgressSummarySection
						courseData={store.state.courseData}
						{userFluxograma}
						effectiveCompletedCount={matchingCompletedCount}
					/>

					<IntegralizacaoSection
						{integralizacao}
						{matrizes}
						{curriculoCompletoAtual}
						onMatrizChange={handleMatrizChange}
					/>
				</div>
			{/if}

			<!-- Legend and controls -->
			<FluxogramaLegendControls
				onOpenOptativas={optativas.length > 0 ? () => (showOptativas = true) : undefined}
			/>

			<!-- Fluxogram grid -->
			<FluxogramContainer
				onSubjectClick={handleSubjectClick}
				bind:bind_container={containerRef}
			/>
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

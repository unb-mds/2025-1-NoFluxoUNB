<script lang="ts">
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import GraffitiBackground from '$lib/components/effects/GraffitiBackground.svelte';
	import FluxogramaHeader from '$lib/components/fluxograma/FluxogramaHeader.svelte';
	import FluxogramaLegendControls from '$lib/components/fluxograma/FluxogramaLegendControls.svelte';
	import FluxogramContainer from '$lib/components/fluxograma/FluxogramContainer.svelte';
	import ProgressSummarySection from '$lib/components/fluxograma/ProgressSummarySection.svelte';
	import IntegralizacaoSection from '$lib/components/fluxograma/IntegralizacaoSection.svelte';
	import SubjectDetailsModal from '$lib/components/fluxograma/SubjectDetailsModal.svelte';
	import OptativasModal from '$lib/components/fluxograma/OptativasModal.svelte';
	import OptativasAdicionadasSection from '$lib/components/fluxograma/OptativasAdicionadasSection.svelte';
	import ProgressToolsSection from '$lib/components/fluxograma/ProgressToolsSection.svelte';
	import PrerequisiteChainDialog from '$lib/components/fluxograma/PrerequisiteChainDialog.svelte';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { authStore } from '$lib/stores/auth';
	import { getIntegralizacao } from '$lib/services/integralizacao.service';
	import { supabaseDataService } from '$lib/services/supabase-data.service';
	import { goto } from '$app/navigation';
	import { ROUTES } from '$lib/config/routes';
	import { onMount } from 'svelte';
	import { Upload, Loader2, AlertTriangle } from 'lucide-svelte';
	import type { MateriaModel } from '$lib/types/materia';
	import type { IntegralizacaoResult } from '$lib/types/matriz';

	const store = fluxogramaStore;

	let containerRef: HTMLElement | null = $state(null);
	let selectedSubject = $state<MateriaModel | null>(null);
	let chainDialogSubject = $state<MateriaModel | null>(null);
	let showOptativas = $state(false);
	let integralizacao = $state<IntegralizacaoResult | null>(null);
	let matrizes = $state<Array<{ curriculoCompleto: string }>>([]);

	let user = $derived(authStore.getUser());
	let userFluxograma = $derived(user?.dadosFluxograma ?? null);
	let courseName = $derived(userFluxograma?.nomeCurso ?? '');
	/** Currículo salvo no casamento (ex.: "60810/1") — mesma regra do casar-disciplinas para achar a matriz. */
	let matrizCurricular = $derived((userFluxograma as { matrizCurricular?: string } | null)?.matrizCurricular ?? '');
	let curriculoCompletoAtual = $derived(store.state.courseData?.curriculoCompleto ?? null);

	// Optativas = semester 0
	let optativas = $derived.by(() => {
		if (!store.state.courseData) return [];
		return store.state.courseData.materias.filter((m) => m.nivel === 0);
	});

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
		if (!userFluxograma) {
			goto(ROUTES.UPLOAD_HISTORICO);
			return;
		}
		// Mesma regra do casamento: priorizar curriculo (codigo/versao) para achar a matriz correta
		if (matrizCurricular?.trim()) {
			store.loadCourseDataByCurriculoCompleto(matrizCurricular.trim(), false);
		} else if (courseName) {
			store.loadCourseData(courseName, false);
		}

		return () => {
			store.reset();
		};
	});

	async function handleMatrizChange(curriculoCompleto: string) {
		await store.loadCourseDataByCurriculoCompleto(curriculoCompleto, false);
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

	function handleSubjectLongPress(materia: MateriaModel) {
		chainDialogSubject = materia;
	}

	function closeChainDialog() {
		chainDialogSubject = null;
	}
</script>

<PageMeta
	title="Meu Fluxograma"
	description="Visualize e gerencie seu progresso acadêmico na UnB"
/>

<GraffitiBackground />

<div class="relative z-10 container mx-auto max-w-[95vw] px-4 py-6">
	{#if store.state.loading}
		<div class="flex flex-col items-center justify-center gap-4 py-20">
			<Loader2 class="h-10 w-10 animate-spin text-purple-400" />
			<p class="text-sm text-white/60">Carregando fluxograma...</p>
		</div>
	{:else if store.state.error}
		<div class="mx-auto max-w-md rounded-2xl border border-red-500/20 bg-red-500/10 p-8 text-center backdrop-blur-md">
			<AlertTriangle class="mx-auto mb-3 h-8 w-8 text-red-400" />
			<h2 class="mb-2 text-lg font-semibold text-white">Erro ao carregar fluxograma</h2>
			<p class="mb-4 text-sm text-red-300/80">{store.state.error}</p>
			<button
				onclick={() =>
					matrizCurricular?.trim()
						? store.loadCourseDataByCurriculoCompleto(matrizCurricular.trim())
						: courseName && store.loadCourseData(courseName)
				}
				class="rounded-full bg-white/10 px-6 py-2 text-sm font-medium text-white transition-colors hover:bg-white/20"
			>
				Tentar novamente
			</button>
		</div>
	{:else if !userFluxograma}
		<div class="mx-auto max-w-md rounded-2xl border border-white/10 bg-black/40 p-8 text-center backdrop-blur-md">
			<Upload class="mx-auto mb-3 h-8 w-8 text-purple-400" />
			<h2 class="mb-2 text-lg font-semibold text-white">Nenhum Fluxograma Encontrado</h2>
			<p class="mb-4 text-sm text-white/50">
				Importe seu histórico acadêmico para gerar seu fluxograma personalizado.
			</p>
			<button
				onclick={() => goto(ROUTES.UPLOAD_HISTORICO)}
				class="inline-flex items-center gap-2 rounded-full bg-gradient-to-r from-blue-500 to-blue-700 px-6 py-3 font-semibold text-white transition-transform hover:scale-105"
			>
				<Upload class="h-4 w-4" />
				Importar Histórico
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

			<!-- Progress summary -->
			<ProgressSummarySection
				courseData={store.state.courseData}
				userFluxograma={store.userFluxograma}
				effectiveCompletedCount={store.completedCodes.size}
			/>

			<!-- Integralização (exigido vs realizado por CH da matriz) -->
			{#if store.state.courseData && !store.state.isAnonymous}
				<IntegralizacaoSection
					integralizacao={integralizacao}
					matrizes={matrizes}
					curriculoCompletoAtual={curriculoCompletoAtual}
					onMatrizChange={handleMatrizChange}
				/>
			{/if}

			<!-- Legend and controls -->
			<FluxogramaLegendControls
				onOpenOptativas={() => (showOptativas = true)}
			/>

			<!-- Fluxogram grid -->
			<FluxogramContainer
				onSubjectClick={handleSubjectClick}
				onSubjectLongPress={handleSubjectLongPress}
				bind:bind_container={containerRef}
			/>

			<!-- Optativas added -->
			{#if !store.state.isAnonymous}
				<OptativasAdicionadasSection />
			{/if}

			<!-- Tools section -->
			{#if !store.state.isAnonymous}
				<ProgressToolsSection />
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

		<!-- Prerequisite chain dialog -->
		{#if chainDialogSubject && store.state.courseData}
			<PrerequisiteChainDialog
				materia={chainDialogSubject}
				courseData={store.state.courseData}
				onclose={closeChainDialog}
			/>
		{/if}
	{/if}
</div>

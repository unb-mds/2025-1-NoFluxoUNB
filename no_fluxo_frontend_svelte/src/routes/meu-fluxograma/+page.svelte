<script lang="ts">
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import GraffitiBackground from '$lib/components/effects/GraffitiBackground.svelte';
	import FluxogramaHeader from '$lib/components/fluxograma/FluxogramaHeader.svelte';
	import FluxogramaLegendControls from '$lib/components/fluxograma/FluxogramaLegendControls.svelte';
	import FluxogramViewportChrome from '$lib/components/fluxograma/FluxogramViewportChrome.svelte';
	import FluxogramContainer from '$lib/components/fluxograma/FluxogramContainer.svelte';
	import ProgressSummarySection from '$lib/components/fluxograma/ProgressSummarySection.svelte';
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
	import { isOptativa, type MateriaModel } from '$lib/types/materia';
	import type { IntegralizacaoResult } from '$lib/types/matriz';

	const store = fluxogramaStore;

	let containerRef: HTMLElement | null = $state(null);
	let selectedSubject = $state<MateriaModel | null>(null);
	let chainDialogSubject = $state<MateriaModel | null>(null);
	let showOptativas = $state(false);
	let integralizacao = $state<IntegralizacaoResult | null>(null);
	let integralizacaoLoading = $state(false);
	let matrizes = $state<Array<{ curriculoCompleto: string }>>([]);
	/** Modal “Legenda e regras” (ícone ? no header) */
	let fluxogramHelpOpen = $state(false);

	let user = $derived(authStore.getUser());
	let userFluxograma = $derived(user?.dadosFluxograma ?? null);
	let courseName = $derived(userFluxograma?.nomeCurso ?? '');
	/** Currículo salvo no casamento (ex.: "60810/1") — mesma regra do casar-disciplinas para achar a matriz. */
	let matrizCurricular = $derived((userFluxograma as { matrizCurricular?: string } | null)?.matrizCurricular ?? '');
	let curriculoCompletoAtual = $derived(store.state.courseData?.curriculoCompleto ?? null);

	// Optativas = semester 0
	let optativas = $derived.by(() => {
		if (!store.state.courseData) return [];
		return store.state.courseData.materias.filter((m) => isOptativa(m));
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
			integralizacaoLoading = false;
			return;
		}
		integralizacaoLoading = true;
		getIntegralizacao({
			curriculoCompleto: cc,
			dadosFluxograma: fluxo,
			cargaHorariaIntegralizada: store.cargaHorariaIntegralizada,
			equivalencias: course?.equivalencias
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
			integralizacaoLoading = true;
			try {
				const r = await getIntegralizacao({
					curriculoCompleto,
					dadosFluxograma: userFluxograma,
					cargaHorariaIntegralizada: store.cargaHorariaIntegralizada,
					equivalencias: store.state.courseData?.equivalencias
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

<div class="relative z-10 container mx-auto w-full min-w-0 max-w-full px-3 py-2 sm:px-4 sm:py-3">
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
			<div class="flex flex-col items-center gap-3">
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
				<button
					onclick={() => goto(ROUTES.UPLOAD_HISTORICO)}
					class="inline-flex items-center gap-2 rounded-full bg-gradient-to-r from-blue-500 to-blue-700 px-6 py-2 text-sm font-semibold text-white transition-transform hover:scale-105"
				>
					<Upload class="h-4 w-4" />
					Enviar histórico novamente
				</button>
			</div>
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
		<!--
			Bloco 1: ocupa a viewport (menos navbar). Só topo + fluxograma — a rolagem fica DENTRO do fluxograma.
			Bloco 2: ferramentas/optativas ficam abaixo da dobra e não comprimem o diagrama.
		-->
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
						showFluxogramViewMenu={true}
						onOpenFluxogramHelp={() => (fluxogramHelpOpen = true)}
					/>
					<FluxogramaLegendControls
						onOpenOptativas={() => (showOptativas = true)}
						showFluxogramViewMenu={true}
						onOpenFluxogramHelp={() => (fluxogramHelpOpen = true)}
					/>
				</div>

				<!-- z-0: diagrama na base; modais ficam em z-[500]+ e a faixa de progresso em z-40 para não ficarem sob o transform dos cards -->
				<div class="relative z-0 min-h-0 flex-1 basis-0 overflow-hidden">
					<FluxogramContainer
						onSubjectClick={handleSubjectClick}
						onSubjectLongPress={handleSubjectLongPress}
						bind:bind_container={containerRef}
					/>
					<FluxogramViewportChrome bind:helpOpen={fluxogramHelpOpen} />
				</div>
			</div>

			{#if !store.state.isAnonymous}
				<div class="relative z-40 shrink-0 space-y-4 border-t border-white/10 pt-4">
					<ProgressSummarySection
						courseData={store.state.courseData}
						userFluxograma={store.userFluxograma}
						{integralizacao}
						integralizacaoLoading={integralizacaoLoading}
						{matrizes}
						{curriculoCompletoAtual}
						onMatrizChange={handleMatrizChange}
					/>
					<OptativasAdicionadasSection />
					<ProgressToolsSection />
				</div>
			{:else}
				<div class="relative z-40 border-t border-white/10 pt-4">
					<ProgressSummarySection
						courseData={store.state.courseData}
						userFluxograma={store.userFluxograma}
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

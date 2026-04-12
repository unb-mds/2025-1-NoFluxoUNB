<script lang="ts">
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import GraffitiBackground from '$lib/components/effects/GraffitiBackground.svelte';
	import SubjectChainView from '$lib/components/disciplinas/SubjectChainView.svelte';
	import { fluxogramaService } from '$lib/services/fluxograma.service';
	import type { CursoModel, MinimalCursoModel } from '$lib/types/curso';
	import type { MateriaModel } from '$lib/types/materia';
	import { onMount } from 'svelte';
	import {
		clearCurriculumAnalysisCache,
		materiaMatchesNormalizedQuery,
		normalizeSearchQuery
	} from '$lib/utils/curriculum-utils';
	import { Loader2 } from 'lucide-svelte';

	let matrizesOpcoes = $state<MinimalCursoModel[]>([]);
	let curriculoSelecionado = $state('');
	let curso = $state<CursoModel | null>(null);
	let carregandoMatrizes = $state(true);
	let carregandoCurso = $state(false);
	let erroCurso = $state<string | null>(null);

	let termoBusca = $state('');
	let selecionada = $state<MateriaModel | null>(null);

	let termoNorm = $derived(normalizeSearchQuery(termoBusca));

	let materiasOrdenadas = $derived.by(() => {
		const c = curso;
		if (!c?.materias?.length) return [];
		return [...c.materias].sort(
			(a, b) => a.codigoMateria.localeCompare(b.codigoMateria, 'pt-BR') || a.nivel - b.nivel
		);
	});

	let resultadosBusca = $derived.by(() => {
		const q = termoNorm;
		const base = materiasOrdenadas;
		if (q.length < 2) return base.slice(0, 120);
		return base.filter((m) => materiaMatchesNormalizedQuery(m, q)).slice(0, 120);
	});

	async function carregarListaMatrizes() {
		carregandoMatrizes = true;
		try {
			matrizesOpcoes = await fluxogramaService.getAllMatrizesIndex();
		} catch (e: unknown) {
			erroCurso = e instanceof Error ? e.message : 'Erro ao listar matrizes.';
		} finally {
			carregandoMatrizes = false;
		}
	}

	async function aoEscolherMatriz(curriculo: string) {
		curriculoSelecionado = curriculo;
		selecionada = null;
		termoBusca = '';
		curso = null;
		erroCurso = null;
		if (!curriculo?.trim()) return;

		carregandoCurso = true;
		clearCurriculumAnalysisCache();
		try {
			curso = await fluxogramaService.getCourseDataByCurriculoCompleto(curriculo.trim());
		} catch (e: unknown) {
			erroCurso = e instanceof Error ? e.message : 'Erro ao carregar currículo.';
			curso = null;
		} finally {
			carregandoCurso = false;
		}
	}

	function selecionarMateria(m: MateriaModel) {
		selecionada = m;
	}

	function aoNavegarCadeia(codigo: string) {
		const c = curso;
		if (!c) return;
		const u = codigo.trim().toUpperCase();
		const m = c.materias.find((x) => x.codigoMateria.trim().toUpperCase() === u);
		if (m) selecionada = m;
	}

	onMount(() => {
		carregarListaMatrizes();
	});
</script>

<PageMeta
	title="Disciplinas"
	description="Busque disciplinas na matriz curricular e visualize a cadeia de pré-requisitos no contexto do curso."
/>

<GraffitiBackground />

<div class="relative z-10 flex h-[calc(100dvh-3.5rem)] flex-col overflow-hidden">
	<header class="flex h-14 shrink-0 items-center gap-3 border-b border-white/10 bg-black/55 px-4 backdrop-blur-md">
		<div class="font-mono text-xs font-medium tracking-wider text-lime-300">NOFLUXO</div>
		<div class="flex-1"></div>
		{#if carregandoMatrizes}
			<p class="flex items-center gap-2 text-xs text-white/55">
				<Loader2 class="h-3.5 w-3.5 animate-spin" /> Carregando matrizes…
			</p>
		{:else}
			<select
				id="matriz-select"
				class="max-w-[360px] rounded-xl border border-white/15 bg-zinc-900/80 px-3 py-1.5 text-xs text-white sm:text-sm"
				bind:value={curriculoSelecionado}
				onchange={() => aoEscolherMatriz(curriculoSelecionado)}
			>
				<option value="">Selecione a matriz</option>
				{#each matrizesOpcoes as op}
					<option value={op.matrizCurricular}>
						{op.nomeCurso} · {op.matrizCurricular}
					</option>
				{/each}
			</select>
		{/if}
	</header>

	<div class="grid min-h-0 flex-1 grid-cols-1 md:grid-cols-[270px_minmax(0,1fr)]">
		<aside class="min-h-0 border-r border-white/10 bg-zinc-950/75">
			<div class="border-b border-white/10 p-3">
				<input
					type="text"
					bind:value={termoBusca}
					placeholder="Buscar por código ou nome..."
					class="w-full rounded-xl border border-white/10 bg-zinc-900/70 px-3 py-2 text-sm text-white placeholder:text-white/40 focus:outline-none focus:ring-2 focus:ring-lime-500/30"
				/>
			</div>

			{#if !curso && !carregandoCurso}
				<p class="p-3 text-xs text-white/45">Escolha uma matriz para listar as disciplinas.</p>
			{:else if carregandoCurso}
				<p class="flex items-center gap-2 p-3 text-xs text-white/55">
					<Loader2 class="h-3.5 w-3.5 animate-spin" /> Carregando disciplinas...
				</p>
			{:else}
				<div class="h-[calc(100%-3.25rem)] space-y-1 overflow-y-auto p-2">
					{#if resultadosBusca.length === 0}
						<p class="p-2 text-xs text-white/45">Nenhuma disciplina para esse termo.</p>
					{/if}
					{#each resultadosBusca as m}
						<button
							type="button"
							onclick={() => selecionarMateria(m)}
							class="w-full rounded-xl border px-2.5 py-2 text-left transition-colors {selecionada &&
							selecionada.idMateria === m.idMateria
								? 'border-lime-300/40 bg-lime-400/12'
								: 'border-transparent hover:border-white/10 hover:bg-white/5'}"
						>
							<p class="font-mono text-xs font-medium text-lime-300">{m.codigoMateria}</p>
							<p class="line-clamp-2 text-sm text-white/75">{m.nomeMateria}</p>
						</button>
					{/each}
				</div>
			{/if}
		</aside>

		<main class="min-h-0 overflow-y-auto p-4 sm:p-6">
			{#if erroCurso}
				<p class="mb-3 text-sm text-red-400">{erroCurso}</p>
			{/if}

			{#if !selecionada}
				<div class="flex h-full items-center justify-center rounded-2xl border border-white/10 bg-black/20">
					<p class="text-sm text-white/45">Selecione uma matéria para ver a cadeia.</p>
				</div>
			{:else if curso}
				<SubjectChainView
					courseData={curso}
					focusCode={selecionada.codigoMateria}
					onNavigate={aoNavegarCadeia}
				/>
			{/if}
		</main>
	</div>
</div>

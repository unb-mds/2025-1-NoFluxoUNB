<script lang="ts">
	import type { CursoModel } from '$lib/types/curso';
	import type { MateriaModel } from '$lib/types/materia';
	import { getCurriculumAnalysis, type CurriculumAnalysis } from '$lib/utils/curriculum-utils';
	import { CHAIN_VISUAL } from '$lib/utils/curriculum-graph';
	import { ChevronDown, ChevronUp, Link2 } from 'lucide-svelte';

	interface Props {
		courseData: CursoModel;
		focusCode: string;
		onNavigate?: (codigoMateria: string) => void;
		showSemesterBadge?: boolean;
	}

	let { courseData, focusCode, onNavigate, showSemesterBadge = true }: Props = $props();

	let analysis = $derived.by((): CurriculumAnalysis | null => {
		void courseData;
		void focusCode;
		return getCurriculumAnalysis(courseData, focusCode);
	});

	const C = CHAIN_VISUAL;
	let openPre = $state(true);
	let openDep = $state(false);
	let openEq = $state(false);
	let openCoreq = $state(false);
	let currentCurriculo = $derived(
		(courseData.curriculoCompleto ?? courseData.matrizCurricular ?? '').trim()
	);

	let graphColumns = $derived.by(() => {
		if (!analysis) return [] as MateriaModel[][];
		const cols: MateriaModel[][] = analysis.topologicalLayers.map((l) => l.materias);
		if (analysis.dependencies.length > 0) {
			cols.push(analysis.dependencies.slice(0, 2));
		}
		return cols;
	});

	function normCurriculo(v: string | null | undefined): string {
		return (v ?? '').trim().toLowerCase().replace(/\s+/g, '');
	}

	function isSpecificEqMatch(eqCurriculo: string | null | undefined, selectedCurriculo: string): boolean {
		const a = normCurriculo(eqCurriculo);
		const b = normCurriculo(selectedCurriculo);
		if (!a || !b) return false;
		return a === b || a.includes(b) || b.includes(a);
	}

	let eqGeneral = $derived.by(() => {
		if (!analysis) return [];
		return analysis.equivalencies.filter((eq) => !eq.curriculo?.trim());
	});

	let eqSpecificThisMatrix = $derived.by(() => {
		if (!analysis || !currentCurriculo) return [];
		return analysis.equivalencies.filter((eq) =>
			eq.curriculo?.trim() ? isSpecificEqMatch(eq.curriculo, currentCurriculo) : false
		);
	});

	function navigateTo(m: MateriaModel) {
		onNavigate?.(m.codigoMateria);
	}

	function isFocusMateria(m: MateriaModel, focus: string): boolean {
		return m.codigoMateria.trim().toUpperCase() === focus.trim().toUpperCase();
	}
</script>

{#if analysis}
	<div class="space-y-5">
		<section class="relative overflow-hidden rounded-2xl border border-purple-300/20 bg-gradient-to-r from-zinc-950/95 via-purple-950/45 to-zinc-950/90 p-4 shadow-[0_14px_34px_rgba(0,0,0,0.45)] sm:p-6">
			<div class="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_20%_15%,rgba(167,139,250,0.15),transparent_42%)]"></div>
			<div class="pointer-events-none absolute inset-0 bg-[linear-gradient(180deg,rgba(255,255,255,0.03),transparent_45%)]"></div>
			<p class="relative mb-2 inline-flex rounded-md border border-purple-300/35 bg-purple-500/12 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.14em] text-purple-100">
				Matéria atual
			</p>
			{#if analysis.focusMateria}
				<h2 class="relative text-2xl font-bold leading-tight text-white drop-shadow-[0_2px_10px_rgba(0,0,0,0.4)] sm:text-[2.1rem]">
					{analysis.focusMateria.nomeMateria}
				</h2>
				<p class="relative mt-1 font-mono text-xs text-purple-100/80 sm:text-sm">{analysis.focusMateria.codigoMateria}</p>
				<div class="relative mt-4 flex flex-wrap gap-2">
					{#if showSemesterBadge}
						<span class="rounded-lg border border-white/20 bg-violet-950/35 px-2.5 py-1 font-mono text-xs text-white/85">
							Semestre {analysis.focusMateria.nivel || '—'}
						</span>
					{/if}
					<span class="rounded-lg border border-white/20 bg-violet-950/35 px-2.5 py-1 font-mono text-xs text-white/85">
						{analysis.focusMateria.creditos ?? '—'} créditos
					</span>
					<span class="rounded-lg border border-amber-300/45 bg-amber-500/18 px-2.5 py-1 font-mono text-xs font-semibold text-amber-100">
						{analysis.preRequisites.length} pré-req.
					</span>
					<span class="rounded-lg border border-cyan-300/45 bg-cyan-500/18 px-2.5 py-1 font-mono text-xs font-semibold text-cyan-100">
						{analysis.dependencies.length} dependentes
					</span>
				</div>
			{:else}
				<p class="text-sm text-amber-200/90">
					Código <span class="font-mono">{analysis.focusCode}</span> não está nesta matriz curricular.
				</p>
			{/if}
		</section>

		<section class="rounded-2xl border border-white/10 bg-gradient-to-b from-violet-900/20 to-black/20 p-4 sm:p-5">
			<p class="mb-3 text-xs font-medium uppercase tracking-[0.12em] text-white/45">
				Ordem no grafo — cadeia topológica
			</p>
			<div class="overflow-x-auto pb-1">
				<div class="flex min-w-max items-center gap-0">
					{#each graphColumns as col, ci}
						<div class="flex flex-col items-center gap-2">
							{#each col as m}
								<button
									type="button"
									onclick={() => navigateTo(m)}
									class="w-[162px] rounded-xl border px-3 py-2 text-left transition-colors {isFocusMateria(m, analysis.focusCode)
										? 'border-purple-300/45 bg-purple-500/14'
										: ci === graphColumns.length - 1 && analysis.dependencies.length > 0
											? 'border-[#f6ad55]/30 bg-[#f6ad55]/10 hover:bg-[#f6ad55]/20'
											: 'border-[#7f9cf5]/30 bg-[#7f9cf5]/8 hover:bg-[#7f9cf5]/18'}"
								>
									<p class="font-mono text-xs {isFocusMateria(m, analysis.focusCode) ? 'text-purple-200' : 'text-cyan-200'}">
										{m.codigoMateria}
									</p>
									<p class="line-clamp-2 text-xs text-white/65">{m.nomeMateria}</p>
								</button>
							{/each}
						</div>
						{#if ci < graphColumns.length - 1}
							<div class="px-3 text-white/35" aria-hidden="true">→</div>
						{/if}
					{/each}
				</div>
			</div>
		</section>

		<section class="overflow-hidden rounded-2xl border border-white/10 bg-violet-950/20">
			<button
				type="button"
				class="flex w-full items-center justify-between px-4 py-3 hover:bg-white/5"
				onclick={() => (openPre = !openPre)}
			>
				<span class="flex items-center gap-2 text-sm font-medium text-white">
					<span class="h-2 w-2 rounded-full" style="background: {C.corequisite};"></span>
					Precisa cursar antes
					<span class="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 font-mono text-[11px] text-white/65">
						{analysis.preRequisites.length}
					</span>
				</span>
				{#if openPre}<ChevronUp class="h-4 w-4 text-white/55" />{:else}<ChevronDown class="h-4 w-4 text-white/55" />{/if}
			</button>
			{#if openPre}
				<div class="border-t border-white/10 px-4 py-3">
					{#if analysis.preRequisites.length === 0}
						<p class="text-xs text-white/45">Nenhuma encontrada nesta matriz.</p>
					{:else}
						<div class="flex flex-wrap gap-2">
							{#each analysis.preRequisites as m}
								<button
									type="button"
									onclick={() => navigateTo(m)}
									class="rounded-lg border border-[#7f9cf5]/35 bg-[#7f9cf5]/10 px-2.5 py-1 text-left text-xs text-[#b8adff] hover:bg-[#7f9cf5]/20"
								>
									<span class="font-mono">{m.codigoMateria}</span>
									<span class="text-white/60"> · {m.nomeMateria}</span>
								</button>
							{/each}
						</div>
					{/if}
				</div>
			{/if}
		</section>

		<section class="overflow-hidden rounded-2xl border border-white/10 bg-violet-950/20">
			<button
				type="button"
				class="flex w-full items-center justify-between px-4 py-3 hover:bg-white/5"
				onclick={() => (openDep = !openDep)}
			>
				<span class="flex items-center gap-2 text-sm font-medium text-white">
					<span class="h-2 w-2 rounded-full" style="background: {C.descendant};"></span>
					Desbloqueia depois (transitivo)
					<span class="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 font-mono text-[11px] text-white/65">
						{analysis.dependencies.length}
					</span>
				</span>
				{#if openDep}<ChevronUp class="h-4 w-4 text-white/55" />{:else}<ChevronDown class="h-4 w-4 text-white/55" />{/if}
			</button>
			{#if openDep}
				<div class="border-t border-white/10 px-4 py-3">
					{#if analysis.dependencies.length === 0}
						<p class="text-xs text-white/45">Nenhuma encontrada nesta matriz.</p>
					{:else}
						<div class="flex flex-wrap gap-2">
							{#each analysis.dependencies as m}
								<button
									type="button"
									onclick={() => navigateTo(m)}
									class="rounded-lg border border-[#f6ad55]/35 bg-[#f6ad55]/10 px-2.5 py-1 text-left text-xs text-[#ffd09d] hover:bg-[#f6ad55]/20"
								>
									<span class="font-mono">{m.codigoMateria}</span>
									<span class="text-white/60"> · {m.nomeMateria}</span>
								</button>
							{/each}
						</div>
					{/if}
				</div>
			{/if}
		</section>

		<section class="overflow-hidden rounded-2xl border border-white/10 bg-violet-950/20">
			<button
				type="button"
				class="flex w-full items-center justify-between px-4 py-3 hover:bg-white/5"
				onclick={() => (openEq = !openEq)}
			>
				<span class="flex items-center gap-2 text-sm font-medium text-white">
					<Link2 class="h-3.5 w-3.5 text-amber-300/90" />
					Equivalências (regras desta matriz)
					<span class="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 font-mono text-[11px] text-white/65">
						{eqGeneral.length + eqSpecificThisMatrix.length}
					</span>
				</span>
				{#if openEq}<ChevronUp class="h-4 w-4 text-white/55" />{:else}<ChevronDown class="h-4 w-4 text-white/55" />{/if}
			</button>
			{#if openEq}
				<div class="border-t border-white/10 px-4 py-3">
					{#if eqGeneral.length === 0 && eqSpecificThisMatrix.length === 0}
						<p class="text-xs text-white/45">Nenhuma equivalência aplicável nesta matriz.</p>
					{/if}

					{#if eqGeneral.length > 0}
						<p class="mb-1 text-[11px] font-semibold uppercase tracking-wide text-white/55">Gerais</p>
						<ul class="space-y-2">
							{#each eqGeneral as eq}
								<li class="rounded-lg border border-amber-400/20 bg-amber-500/8 px-3 py-2 text-xs text-amber-100/95">
									<p>
										<span class="font-mono">{eq.codigoMateriaOrigem}</span>
										↔
										<span class="font-mono">{eq.codigoMateriaEquivalente}</span>
									</p>
									{#if eq.expressao?.trim()}
										<p class="mt-1 text-[11px] text-white/65">{eq.expressao}</p>
									{/if}
								</li>
							{/each}
						</ul>
					{/if}

					{#if eqSpecificThisMatrix.length > 0}
						<p class="mt-3 mb-1 text-[11px] font-semibold uppercase tracking-wide text-white/55">
							Específicas desta matriz
						</p>
						<ul class="space-y-2">
							{#each eqSpecificThisMatrix as eq}
								<li class="rounded-lg border border-purple-300/25 bg-purple-500/10 px-3 py-2 text-xs text-purple-100">
									<p>
										<span class="font-mono">{eq.codigoMateriaOrigem}</span>
										↔
										<span class="font-mono">{eq.codigoMateriaEquivalente}</span>
									</p>
									{#if eq.curriculo}
										<p class="mt-1 text-[11px] text-amber-200/85">Currículo: {eq.curriculo}</p>
									{/if}
									{#if eq.expressao?.trim()}
										<p class="mt-1 text-[11px] text-white/65">{eq.expressao}</p>
									{/if}
								</li>
							{/each}
						</ul>
					{/if}
				</div>
			{/if}
		</section>

		{#if analysis.corequisites.length > 0}
			<section class="overflow-hidden rounded-2xl border border-white/10 bg-violet-950/20">
				<button
					type="button"
					class="flex w-full items-center justify-between px-4 py-3 hover:bg-white/5"
					onclick={() => (openCoreq = !openCoreq)}
				>
					<span class="flex items-center gap-2 text-sm font-medium text-white">
						<span class="h-2 w-2 rounded-full" style="background: {C.corequisite};"></span>
						Co-requisitos (grade)
						<span class="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 font-mono text-[11px] text-white/65">
							{analysis.corequisites.length}
						</span>
					</span>
					{#if openCoreq}<ChevronUp class="h-4 w-4 text-white/55" />{:else}<ChevronDown class="h-4 w-4 text-white/55" />{/if}
				</button>
				{#if openCoreq}
					<div class="border-t border-white/10 px-4 py-3">
						<div class="flex flex-wrap gap-2">
							{#each analysis.corequisites as m}
								<button
									type="button"
									onclick={() => navigateTo(m)}
									class="rounded-lg border border-[#7f9cf5]/35 bg-[#7f9cf5]/10 px-2.5 py-1 text-left text-xs text-indigo-100 hover:bg-[#7f9cf5]/20"
								>
									<span class="font-mono">{m.codigoMateria}</span>
									<span class="text-white/60"> · {m.nomeMateria}</span>
								</button>
							{/each}
						</div>
					</div>
				{/if}
			</section>
		{/if}
	</div>
{:else}
	<p class="text-sm text-white/50">Não foi possível calcular a cadeia.</p>
{/if}

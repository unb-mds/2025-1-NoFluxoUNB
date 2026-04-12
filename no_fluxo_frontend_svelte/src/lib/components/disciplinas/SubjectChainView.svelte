<script lang="ts">
	import type { CursoModel } from '$lib/types/curso';
	import type { MateriaModel } from '$lib/types/materia';
	import { getCurriculumAnalysis, type CurriculumAnalysis } from '$lib/utils/curriculum-utils';
	import { CHAIN_VISUAL } from '$lib/utils/curriculum-graph';
import {
	extractSubjectCodesFromExpression,
	type EquivalenciaModel
} from '$lib/types/equivalencia';
import { getCodigosFromExpressaoLogica, getLogicalCodeGroups } from '$lib/utils/expressao-logica';
	import { ChevronDown, ChevronUp, Link2 } from 'lucide-svelte';

	interface Props {
		courseData: CursoModel;
		focusCode: string;
		onNavigate?: (codigoMateria: string) => void;
		showSemesterBadge?: boolean;
	getCourseInfoByCurriculo?: (
		curriculo: string | null | undefined
	) => { nomeCurso: string; tipoCurso: string | null } | null;
	}

let {
	courseData,
	focusCode,
	onNavigate,
	showSemesterBadge = true,
	getCourseInfoByCurriculo
}: Props = $props();

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

let prereqRules = $derived.by(() => {
	const foco = analysis?.focusMateria;
	if (!foco) return [] as string[];
	const rows = courseData.preRequisitos?.filter((pr) => pr.idMateria === foco.idMateria) ?? [];
	const out = rows
		.map((r) => (r.expressaoOriginal ?? '').trim())
		.filter((s) => s.length > 0);
	return [...new Set(out)];
});

let materiaNameByCode = $derived.by(() => {
	const out = new Map<string, string>();
	for (const m of courseData.materias) {
		out.set(m.codigoMateria.trim().toUpperCase(), m.nomeMateria);
	}
	return out;
});

function nomeMateriaPorCodigo(codigo: string, fallback = ''): string {
	const key = (codigo || '').trim().toUpperCase();
	return materiaNameByCode.get(key) ?? fallback;
}

function courseInfoLabel(curriculo: string | null | undefined): string | null {
	const ci = getCourseInfoByCurriculo?.(curriculo);
	if (!ci?.nomeCurso) return null;
	return ci.tipoCurso ? `${ci.nomeCurso} · ${ci.tipoCurso}` : ci.nomeCurso;
}

function uniqueCodes(codes: string[]): string[] {
	return [...new Set(codes.map((c) => (c || '').trim().toUpperCase()).filter(Boolean))];
}

function equivalenciaCodes(eq: EquivalenciaModel): string[] {
	const fromGroups = equivalenciaGroups(eq).flatMap((g) => g);
	let fromText: string[] = [];
	if (fromGroups.length === 0 && eq.expressao?.trim()) {
		fromText = extractSubjectCodesFromExpression(eq.expressao);
	}
	const all = uniqueCodes([...fromGroups, ...fromText]);
	const origem = (eq.codigoMateriaOrigem || '').trim().toUpperCase();
	return all.filter((c) => c !== origem);
}

function equivalenciaGroups(eq: EquivalenciaModel): string[][] {
	const origem = (eq.codigoMateriaOrigem || '').trim().toUpperCase();
	const groups = getLogicalCodeGroups(eq.expressaoLogica ?? null, eq.expressao ?? null);
	return groups
		.map((g) => uniqueCodes(g).filter((c) => c !== origem))
		.filter((g) => g.length > 0);
}

function equivalenciaDisplayItems(eq: EquivalenciaModel): Array<{ codigo: string; nome: string }> {
	const parsed = equivalenciaCodes(eq);
	if (parsed.length > 0) {
		return parsed.map((codigo) => ({
			codigo,
			nome: nomeMateriaPorCodigo(codigo, 'sem nome')
		}));
	}
	const fallbackCode = (eq.codigoMateriaEquivalente || '').trim().toUpperCase();
	if (!fallbackCode) return [];
	return [
		{
			codigo: fallbackCode,
			nome: eq.nomeMateriaEquivalente || nomeMateriaPorCodigo(fallbackCode, 'sem nome')
		}
	];
}

function equivalenciaDisplayGroups(eq: EquivalenciaModel): Array<Array<{ codigo: string; nome: string }>> {
	const groups = equivalenciaGroups(eq);
	if (groups.length > 0) {
		return groups.map((group) =>
			group.map((codigo) => ({
				codigo,
				nome: nomeMateriaPorCodigo(codigo, 'sem nome')
			}))
		);
	}
	const fallback = equivalenciaDisplayItems(eq);
	return fallback.length > 0 ? [fallback] : [];
}

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
					{#if analysis.focusMateria.tipoNatureza != null}
						<span class="rounded-lg border px-2.5 py-1 font-mono text-xs font-semibold {analysis.focusMateria.tipoNatureza === 1
							? 'border-amber-300/45 bg-amber-500/18 text-amber-100'
							: 'border-cyan-300/45 bg-cyan-500/18 text-cyan-100'}">
							{analysis.focusMateria.tipoNatureza === 1 ? 'Optativa' : 'Obrigatória'}
						</span>
					{/if}
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
					{#if prereqRules.length > 0}
						<div class="mb-2 space-y-1.5">
							<p class="text-[11px] font-semibold uppercase tracking-wide text-white/55">
								Regras (expressão)
							</p>
							{#each prereqRules as rule}
								<p class="rounded-md border border-purple-300/20 bg-purple-500/8 px-2.5 py-1 text-[11px] text-purple-100/90">
									{rule}
								</p>
							{/each}
						</div>
					{/if}
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
									<div class="mb-1 flex items-center justify-between gap-2">
										<span class="rounded-full border border-cyan-200/60 bg-cyan-300/25 px-2 py-0.5 text-[10px] font-extrabold uppercase tracking-wide text-cyan-50 shadow-[0_0_0_1px_rgba(34,211,238,0.25)]">
											Geral
										</span>
									</div>
									<p>
										<span class="font-semibold text-amber-50">Origem:</span>
										<span class="ml-1 font-mono">{eq.codigoMateriaOrigem || '—'}</span>
										<span class="text-white/70">
											· {eq.nomeMateriaOrigem || nomeMateriaPorCodigo(eq.codigoMateriaOrigem, 'sem nome')}
										</span>
									</p>
									<p class="mt-1">
										<span class="font-semibold text-amber-50">Equivalência lógica:</span>
									</p>
									{#if equivalenciaDisplayGroups(eq).length > 0}
										<div class="mt-1 space-y-1.5">
											{#each equivalenciaDisplayGroups(eq) as group, gi}
												<div class="rounded-lg border border-amber-300/25 bg-amber-500/8 p-2">
													<div class="flex flex-wrap items-center gap-1.5">
														{#each group as item, ii}
															<span class="rounded-md border border-amber-300/30 bg-amber-500/10 px-2 py-0.5 text-[11px] text-amber-100/95">
																<span class="font-mono">{item.codigo}</span>
																<span class="text-white/70"> · {item.nome}</span>
															</span>
															{#if ii < group.length - 1}
																<span class="text-[10px] font-bold uppercase tracking-wide text-amber-200/85">E</span>
															{/if}
														{/each}
													</div>
												</div>
												{#if gi < equivalenciaDisplayGroups(eq).length - 1}
													<div class="text-[10px] font-extrabold uppercase tracking-[0.12em] text-amber-200/80">OU</div>
												{/if}
											{/each}
										</div>
									{:else}
										<p class="mt-1 text-[11px] text-white/60">Sem códigos equivalentes identificados.</p>
									{/if}
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
									<div class="mb-1 flex items-center justify-between gap-2">
										<p class="font-mono text-[11px] text-purple-100/90">EQ específica</p>
										<span class="rounded-full border border-fuchsia-200/65 bg-fuchsia-300/30 px-2 py-0.5 text-[10px] font-extrabold uppercase tracking-wide text-fuchsia-50 shadow-[0_0_0_1px_rgba(244,114,182,0.3)]">
											Específica
										</span>
									</div>
									<p>
										<span class="font-semibold text-purple-50">Origem:</span>
										<span class="ml-1 font-mono">{eq.codigoMateriaOrigem || '—'}</span>
										<span class="text-white/70">
											· {eq.nomeMateriaOrigem || nomeMateriaPorCodigo(eq.codigoMateriaOrigem, 'sem nome')}
										</span>
									</p>
									<p class="mt-1">
										<span class="font-semibold text-purple-50">Equivalência lógica:</span>
									</p>
									{#if equivalenciaDisplayGroups(eq).length > 0}
										<div class="mt-1 space-y-1.5">
											{#each equivalenciaDisplayGroups(eq) as group, gi}
												<div class="rounded-lg border border-purple-300/30 bg-purple-500/10 p-2">
													<div class="flex flex-wrap items-center gap-1.5">
														{#each group as item, ii}
															<span class="rounded-md border border-purple-300/35 bg-purple-500/12 px-2 py-0.5 text-[11px] text-purple-100/95">
																<span class="font-mono">{item.codigo}</span>
																<span class="text-white/70"> · {item.nome}</span>
															</span>
															{#if ii < group.length - 1}
																<span class="text-[10px] font-bold uppercase tracking-wide text-purple-200/85">E</span>
															{/if}
														{/each}
													</div>
												</div>
												{#if gi < equivalenciaDisplayGroups(eq).length - 1}
													<div class="text-[10px] font-extrabold uppercase tracking-[0.12em] text-purple-200/80">OU</div>
												{/if}
											{/each}
										</div>
									{:else}
										<p class="mt-1 text-[11px] text-white/60">Sem códigos equivalentes identificados.</p>
									{/if}
									{#if eq.curriculo}
										<p class="mt-1 text-[11px] text-amber-200/85">Currículo: {eq.curriculo}</p>
									{/if}
									{#if courseInfoLabel(eq.curriculo)}
										<p class="mt-1 text-[11px] text-cyan-100/85">
											Curso: {courseInfoLabel(eq.curriculo)}
										</p>
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

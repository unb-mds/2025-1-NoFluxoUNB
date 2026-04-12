<script lang="ts">
	import PageMeta from '$lib/components/seo/PageMeta.svelte';
	import GraffitiBackground from '$lib/components/effects/GraffitiBackground.svelte';
	import SubjectChainView from '$lib/components/disciplinas/SubjectChainView.svelte';
	import { createSupabaseBrowserClient } from '$lib/supabase/client';
	import { fluxogramaService } from '$lib/services/fluxograma.service';
import {
	getCodigosFromExpressaoLogica,
	extractSubjectCodesFromExpression
} from '$lib/utils/expressao-logica';
	import type { CursoModel, MinimalCursoModel } from '$lib/types/curso';
	import { onMount } from 'svelte';
	import {
		clearCurriculumAnalysisCache,
		normalizeSearchQuery
	} from '$lib/utils/curriculum-utils';
	import { Loader2 } from 'lucide-svelte';

	const supabase = createSupabaseBrowserClient();

	interface SearchItem {
		idMateria: number;
		codigoMateria: string;
		nomeMateria: string;
		nivel: number | null;
		creditos: number | null;
		source: 'matrix' | 'global';
	}

	type MateriaRow = {
		id_materia: number;
		codigo_materia: string;
		nome_materia: string;
		carga_horaria?: number | null;
	};

	type PreReqRow = {
		id_materia: number;
		id_materia_requisito: number | null;
		expressao_logica: unknown | null;
	expressao_original?: string | null;
	};

type GlobalEquivItem = {
	idMateria: number;
	codigoOrigem: string;
	nomeOrigem: string;
	codigoEquivalente: string;
	expressaoOriginal: string | null;
	curriculo: string | null;
	isSpecific: boolean;
};

	let matrizesOpcoes = $state<MinimalCursoModel[]>([]);
	let matrizBusca = $state('');
	let curriculoSelecionado = $state('');
	let curso = $state<CursoModel | null>(null);
	let carregandoMatrizes = $state(true);
	let carregandoCurso = $state(false);
	let erroCurso = $state<string | null>(null);

	let termoBusca = $state('');
	let selecionada = $state<SearchItem | null>(null);
	let resultadosGlobais = $state<SearchItem[]>([]);
	let carregandoBuscaGlobal = $state(false);
	let erroBuscaGlobal = $state<string | null>(null);
	let globalSearchReq = 0;
	let globalChainLoading = $state(false);
	let globalChainError = $state<string | null>(null);
	let globalPreReqs = $state<SearchItem[]>([]);
	let globalDeps = $state<SearchItem[]>([]);
let globalEquivsGeneral = $state<GlobalEquivItem[]>([]);
let globalEquivsSpecific = $state<GlobalEquivItem[]>([]);
	let globalCoreqs = $state<SearchItem[]>([]);
	let openGlobalPre = $state(true);
	let openGlobalDep = $state(false);
	let openGlobalEq = $state(false);
	let openGlobalCoreq = $state(false);
	let materiasCache = $state<Map<number, SearchItem> | null>(null);
	let preReqRowsCache = $state<PreReqRow[] | null>(null);
	let coreqRowsCache = $state<Array<{ id_materia: number; id_materia_corequisito: number | null }> | null>(null);
let idToCodeCache = $state<Map<number, string> | null>(null);
let codePrimaryItemCache = $state<Map<string, SearchItem> | null>(null);

let globalRoadmapColumns = $derived.by(() => {
	if (!selecionada || selecionada.source !== 'global') return [] as SearchItem[][];
	const pre = globalPreReqs.slice(0, 3);
	const dep = globalDeps.slice(0, 3);
	const cols: SearchItem[][] = [];
	if (pre.length > 0) cols.push(pre);
	cols.push([selecionada]);
	if (dep.length > 0) cols.push(dep);
	return cols;
});

	let termoNorm = $derived(normalizeSearchQuery(termoBusca));

	function normalizeForSearch(raw: string): string {
		return normalizeSearchQuery(raw).replace(/[^a-z0-9]/g, '');
	}

function sanitizeForDb(raw: string): {
	trimmed: string;
	noAccents: string;
	collapsed: string;
	compact: string;
} {
	const trimmed = raw.trim();
	const noAccents = trimmed
		.normalize('NFD')
		.replace(/[\u0300-\u036f]/g, '')
		.replace(/ç/g, 'c')
		.replace(/Ç/g, 'C');
	const collapsed = noAccents.replace(/\s+/g, ' ').trim();
	const compact = collapsed.replace(/\s+/g, '');
	return { trimmed, noAccents, collapsed, compact };
}

	function matchesCodigoNome(codigo: string, nome: string, rawQuery: string): boolean {
		const qNorm = normalizeSearchQuery(rawQuery);
		if (!qNorm) return true;
		const qCompact = normalizeForSearch(rawQuery);
		const codeNorm = normalizeSearchQuery(codigo);
		const nameNorm = normalizeSearchQuery(nome);
		const fullNorm = `${codeNorm} ${nameNorm}`;
		const fullCompact = normalizeForSearch(`${codigo} ${nome}`);

		if (fullNorm.includes(qNorm)) return true;
		if (qCompact.length >= 2 && fullCompact.includes(qCompact)) return true;

		// Tokenização resiliente para nomes com múltiplas palavras (ordem livre)
		const tokens = qNorm.split(/\s+/).filter((t) => t.length >= 2);
		if (tokens.length > 0) {
			return tokens.every((t) => fullNorm.includes(t));
		}
		return false;
	}

	function labelMatriz(op: MinimalCursoModel): string {
		return `${op.nomeCurso} · ${op.matrizCurricular}`;
	}

	function limparMatrizSelecionada() {
		curriculoSelecionado = '';
		curso = null;
		selecionada = null;
		clearCurriculumAnalysisCache();
	}

	let materiasOrdenadas = $derived.by(() => {
		const c = curso;
		if (!c?.materias?.length) return [] as SearchItem[];
		return [...c.materias]
			.sort(
			(a, b) => a.codigoMateria.localeCompare(b.codigoMateria, 'pt-BR') || a.nivel - b.nivel
			)
			.map(
				(m): SearchItem => ({
					idMateria: m.idMateria,
					codigoMateria: m.codigoMateria,
					nomeMateria: m.nomeMateria,
					nivel: m.nivel ?? null,
					creditos: m.creditos ?? null,
					source: 'matrix'
				})
			);
	});

	let resultadosBusca = $derived.by(() => {
		const q = termoNorm;
		if (curso) {
			const base = materiasOrdenadas;
			if (q.length < 2) return base.slice(0, 120);
			return base.filter((m) => matchesCodigoNome(m.codigoMateria, m.nomeMateria, termoBusca)).slice(0, 120);
		}
		return resultadosGlobais;
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

	async function buscarMateriasGlobais(queryNorm: string) {
	const sanitized = sanitizeForDb(termoBusca);
	const raw = sanitized.collapsed;
	const compact = sanitized.compact.toUpperCase();
	if (queryNorm.length < 2 || raw.length < 2 || curso) {
			resultadosGlobais = [];
			erroBuscaGlobal = null;
			carregandoBuscaGlobal = false;
			return;
		}
		const req = ++globalSearchReq;
		carregandoBuscaGlobal = true;
		erroBuscaGlobal = null;
	const safe = raw.replace(/[,]/g, ' ').replace(/[%]/g, '').trim();
	const safeCompact = compact.replace(/[%]/g, '').trim();
		try {
			const codeOr =
			safeCompact.length >= 2
				? `codigo_materia.ilike.%${safeCompact}%`
					: `codigo_materia.ilike.%${safe.toUpperCase()}%`;
			const { data, error } = await supabase
				.from('materias')
				.select('id_materia, codigo_materia, nome_materia, carga_horaria')
				.or(`${codeOr},codigo_materia.ilike.%${safe.toUpperCase()}%,nome_materia.ilike.%${safe}%`)
				.order('codigo_materia')
				.limit(120);
			if (req !== globalSearchReq) return;
			if (error) {
				erroBuscaGlobal = error.message;
				resultadosGlobais = [];
				return;
			}
			const mapped: SearchItem[] = ((data as MateriaRow[] | null) ?? []).map((m) => ({
				idMateria: Number(m.id_materia),
				codigoMateria: String(m.codigo_materia),
				nomeMateria: String(m.nome_materia),
				nivel: null,
				creditos:
					m.carga_horaria != null && Number.isFinite(Number(m.carga_horaria))
						? Number(m.carga_horaria) / 15
						: null,
				source: 'global'
			}));
			resultadosGlobais = mapped.filter((m) => matchesCodigoNome(m.codigoMateria, m.nomeMateria, raw));
		} catch (e: unknown) {
			if (req !== globalSearchReq) return;
			erroBuscaGlobal = e instanceof Error ? e.message : 'Erro ao buscar matérias.';
			resultadosGlobais = [];
		} finally {
			if (req === globalSearchReq) carregandoBuscaGlobal = false;
		}
	}

	async function ensureGlobalGraphData() {
	if (materiasCache && preReqRowsCache && coreqRowsCache && idToCodeCache && codePrimaryItemCache) return;

	async function fetchAllRows<T>(table: string, columns: string, step = 1000): Promise<T[]> {
		let from = 0;
		const all: T[] = [];
		while (true) {
			const to = from + step - 1;
			const { data, error } = await supabase
				.from(table)
				.select(columns)
				.range(from, to);
			if (error) throw new Error(error.message);
			const chunk = (data as T[] | null) ?? [];
			all.push(...chunk);
			if (chunk.length < step) break;
			from += step;
		}
		return all;
	}

	const [mats, prs, crs] = await Promise.all([
		fetchAllRows<MateriaRow>('materias', 'id_materia, codigo_materia, nome_materia, carga_horaria'),
		fetchAllRows<PreReqRow>(
			'pre_requisitos',
			'id_materia, id_materia_requisito, expressao_logica, expressao_original'
		),
		fetchAllRows<{ id_materia: number; id_materia_corequisito: number | null }>(
			'co_requisitos',
			'id_materia, id_materia_corequisito'
		)
	]);

	const mMap = new Map<number, SearchItem>();
	const i2c = new Map<number, string>();
	const cPrimary = new Map<string, SearchItem>();
	for (const row of mats ?? []) {
		const code = String(row.codigo_materia).trim().toUpperCase();
			const item: SearchItem = {
				idMateria: Number(row.id_materia),
			codigoMateria: code,
				nomeMateria: String(row.nome_materia),
				nivel: null,
				creditos:
					row.carga_horaria != null && Number.isFinite(Number(row.carga_horaria))
						? Number(row.carga_horaria) / 15
						: null,
				source: 'global'
			};
			mMap.set(item.idMateria, item);
		i2c.set(item.idMateria, code);
		if (!cPrimary.has(code)) cPrimary.set(code, item);
		}
		materiasCache = mMap;
	preReqRowsCache = (prs ?? []).map((r) => ({
			id_materia: Number(r.id_materia),
			id_materia_requisito: r.id_materia_requisito != null ? Number(r.id_materia_requisito) : null,
		expressao_logica: r.expressao_logica,
		expressao_original: r.expressao_original != null ? String(r.expressao_original) : null
		}));
	coreqRowsCache = (crs ?? []).map(
			(r) => ({
				id_materia: Number(r.id_materia),
				id_materia_corequisito:
					r.id_materia_corequisito != null ? Number(r.id_materia_corequisito) : null
			})
		);
	idToCodeCache = i2c;
	codePrimaryItemCache = cPrimary;
	}

	async function carregarCadeiaGlobal(selected: SearchItem) {
		globalChainLoading = true;
		globalChainError = null;
		globalPreReqs = [];
		globalDeps = [];
	globalEquivsGeneral = [];
	globalEquivsSpecific = [];
		globalCoreqs = [];
		try {
			await ensureGlobalGraphData();
			const mats = materiasCache ?? new Map<number, SearchItem>();
			const preRows = preReqRowsCache ?? [];
			const coreqRows = coreqRowsCache ?? [];
		const idToCode = idToCodeCache ?? new Map<number, string>();
		const codePrimary = codePrimaryItemCache ?? new Map<string, SearchItem>();

		const adj = new Map<string, Set<string>>(); // reqCode -> dependentCode
		const rev = new Map<string, Set<string>>();
		const addEdge = (u: string, v: string) => {
			if (!u || !v || u === v) return;
			if (!adj.has(u)) adj.set(u, new Set());
			if (!rev.has(v)) rev.set(v, new Set());
			adj.get(u)!.add(v);
			rev.get(v)!.add(u);
			};

			for (const r of preRows) {
			const targetCode = idToCode.get(r.id_materia);
			if (!targetCode) continue;
			let parsedFromLogic: string[] = [];
			if (r.id_materia_requisito != null) {
				const reqCodeById = idToCode.get(r.id_materia_requisito);
				if (reqCodeById) addEdge(reqCodeById, targetCode);
				}
				if (r.expressao_logica) {
					try {
					parsedFromLogic = getCodigosFromExpressaoLogica(r.expressao_logica as never);
					for (const code of parsedFromLogic) {
						const reqCode = code.trim().toUpperCase();
						if (reqCode) addEdge(reqCode, targetCode);
						}
					} catch {
						// ignora expressão inválida e segue
					}
				}
			// Fallback: quando a expressão lógica não veio estruturada, usar expressão textual.
			if (parsedFromLogic.length === 0 && r.expressao_original) {
				for (const code of extractSubjectCodesFromExpression(String(r.expressao_original))) {
					const reqCode = code.trim().toUpperCase();
					if (reqCode) addEdge(reqCode, targetCode);
				}
			}
			}

		const focusCode = selected.codigoMateria.trim().toUpperCase();
		const visitedPre = new Set<string>([focusCode]);
		const stackPre = [focusCode];
			while (stackPre.length) {
				const v = stackPre.pop()!;
				for (const u of rev.get(v) ?? []) {
					if (!visitedPre.has(u)) {
						visitedPre.add(u);
						stackPre.push(u);
					}
				}
			}
		visitedPre.delete(focusCode);

		const visitedDep = new Set<string>([focusCode]);
		const queueDep = [focusCode];
			while (queueDep.length) {
				const u = queueDep.shift()!;
				for (const v of adj.get(u) ?? []) {
					if (!visitedDep.has(v)) {
						visitedDep.add(v);
						queueDep.push(v);
					}
				}
			}
		visitedDep.delete(focusCode);

			const pre = [...visitedPre]
			.map((code) => codePrimary.get(code) ?? { idMateria: -1, codigoMateria: code, nomeMateria: 'Disciplina', nivel: null, creditos: null, source: 'global' as const })
				.sort((a, b) => a.codigoMateria.localeCompare(b.codigoMateria, 'pt-BR'));
			const dep = [...visitedDep]
			.map((code) => codePrimary.get(code) ?? { idMateria: -1, codigoMateria: code, nomeMateria: 'Disciplina', nivel: null, creditos: null, source: 'global' as const })
				.sort((a, b) => a.codigoMateria.localeCompare(b.codigoMateria, 'pt-BR'));

		const coreqSet = new Set<string>();
			for (const row of coreqRows) {
				const a = row.id_materia;
				const b = row.id_materia_corequisito;
				if (b == null) continue;
			const ca = idToCode.get(a);
			const cb = idToCode.get(b);
			if (!ca || !cb) continue;
			if (ca === focusCode) coreqSet.add(cb);
			if (cb === focusCode) coreqSet.add(ca);
			}
			const coreq = [...coreqSet]
			.map((code) => codePrimary.get(code) ?? { idMateria: -1, codigoMateria: code, nomeMateria: 'Disciplina', nivel: null, creditos: null, source: 'global' as const })
				.sort((a, b) => a.codigoMateria.localeCompare(b.codigoMateria, 'pt-BR'));

		const { data: eqRows, error: eqErr } = await supabase
			.from('equivalencias')
			.select(
				'id_equivalencia, id_materia, expressao_original, expressao_logica, curriculo, materias!equivalencias_id_materia_fkey(codigo_materia, nome_materia)'
			)
			.eq('materias.codigo_materia', focusCode)
				.limit(200);
			if (eqErr) throw new Error(eqErr.message);

		const mappedEq: GlobalEquivItem[] = ((eqRows as Array<Record<string, unknown>> | null) ?? []).map((eq) => {
			const mat = (eq.materias as { codigo_materia?: string; nome_materia?: string } | null) ?? null;
			let codigosEq: string[] = [];
			try {
				codigosEq = getCodigosFromExpressaoLogica(
					(eq.expressao_logica as never) ?? null
				);
			} catch {
				codigosEq = [];
			}
			const primeiro = codigosEq[0] ?? '';
			const curr = eq.curriculo != null ? String(eq.curriculo) : null;
			return {
				idMateria: Number(eq.id_materia ?? 0),
				codigoOrigem: String(mat?.codigo_materia ?? ''),
				nomeOrigem: String(mat?.nome_materia ?? ''),
				codigoEquivalente: primeiro,
				expressaoOriginal: eq.expressao_original != null ? String(eq.expressao_original) : null,
				curriculo: curr,
				isSpecific: !!curr?.trim()
			};
		});

		globalPreReqs = pre;
		globalDeps = dep;
		globalCoreqs = coreq;
		globalEquivsGeneral = mappedEq.filter((e) => !e.isSpecific);
		globalEquivsSpecific = mappedEq.filter((e) => e.isSpecific);
		} catch (e: unknown) {
			globalChainError = e instanceof Error ? e.message : 'Erro ao calcular cadeia global.';
		} finally {
			globalChainLoading = false;
		}
	}

	async function aoEscolherMatriz(curriculo: string) {
	const sanitized = sanitizeForDb(curriculo);
	curriculoSelecionado = sanitized.trimmed;
		selecionada = null;
		curso = null;
		erroCurso = null;
	if (!sanitized.trimmed) return;

		carregandoCurso = true;
		clearCurriculumAnalysisCache();
		try {
		const matched = matrizesOpcoes.find((op) => {
			const optionCurriculoNorm = normalizeSearchQuery(op.matrizCurricular);
			const optionCurriculoCompact = normalizeForSearch(op.matrizCurricular);
			const optionLabelNorm = normalizeSearchQuery(labelMatriz(op));
			const optionLabelCompact = normalizeForSearch(labelMatriz(op));
			const inNorm = normalizeSearchQuery(sanitized.trimmed);
			const inCompact = normalizeForSearch(sanitized.trimmed);
			return (
				optionCurriculoNorm === inNorm ||
				optionCurriculoCompact === inCompact ||
				optionLabelNorm === inNorm ||
				optionLabelCompact === inCompact
			);
		});
		const curriculoQuery = matched?.matrizCurricular ?? sanitized.trimmed;
		matrizBusca = matched ? labelMatriz(matched) : curriculoQuery;
		curriculoSelecionado = curriculoQuery;
		curso = await fluxogramaService.getCourseDataByCurriculoCompleto(curriculoQuery);
		} catch (e: unknown) {
			erroCurso = e instanceof Error ? e.message : 'Erro ao carregar currículo.';
			curso = null;
		} finally {
			carregandoCurso = false;
		}
	}

	function handleMatrizInput(value: string) {
		matrizBusca = value;
		const normInput = normalizeSearchQuery(value);
		if (!normInput) {
			limparMatrizSelecionada();
			return;
		}
		const match = matrizesOpcoes.find((op) => {
			const byLabel = normalizeSearchQuery(labelMatriz(op)) === normInput;
			const byCurriculo = normalizeSearchQuery(op.matrizCurricular) === normInput;
			return byLabel || byCurriculo;
		});
		if (match) {
			if (curriculoSelecionado !== match.matrizCurricular) {
				aoEscolherMatriz(match.matrizCurricular);
			}
			return;
		}
		if (curriculoSelecionado) limparMatrizSelecionada();
	}

	function selecionarMateria(m: SearchItem) {
		selecionada = m;
		if (m.source === 'global') {
			carregarCadeiaGlobal(m);
		}
	}

	function aoNavegarCadeia(codigo: string) {
		const c = curso;
		if (!c) return;
		const u = codigo.trim().toUpperCase();
		const m = c.materias.find((x) => x.codigoMateria.trim().toUpperCase() === u);
		if (m) {
			selecionada = {
				idMateria: m.idMateria,
				codigoMateria: m.codigoMateria,
				nomeMateria: m.nomeMateria,
				nivel: m.nivel ?? null,
				creditos: m.creditos ?? null,
				source: 'matrix'
			};
		}
	}

	$effect(() => {
		const q = termoNorm;
		const hasMatrix = !!curso;
		if (hasMatrix) {
			resultadosGlobais = [];
			erroBuscaGlobal = null;
			carregandoBuscaGlobal = false;
			return;
		}
		if (q.length < 2) {
			resultadosGlobais = [];
			erroBuscaGlobal = null;
			carregandoBuscaGlobal = false;
			return;
		}
		const t = setTimeout(() => {
			buscarMateriasGlobais(q);
		}, 220);
		return () => clearTimeout(t);
	});

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
		<div class="font-mono text-xs font-medium tracking-wider text-purple-300">NOFLUXO</div>
		<div class="flex-1"></div>
		{#if carregandoMatrizes}
			<p class="flex items-center gap-2 text-xs text-white/55">
				<Loader2 class="h-3.5 w-3.5 animate-spin" /> Carregando matrizes…
			</p>
		{:else}
			<div class="w-full max-w-[420px]">
				<input
					list="matrizes-sugestoes"
					value={matrizBusca}
					oninput={(e) => handleMatrizInput((e.currentTarget as HTMLInputElement).value)}
					placeholder="Matriz (opcional) — digite para sugerir"
					class="w-full rounded-xl border border-white/15 bg-zinc-900/80 px-3 py-1.5 text-xs text-white placeholder:text-white/45 sm:text-sm"
				/>
				<datalist id="matrizes-sugestoes">
					{#each matrizesOpcoes as op}
						<option value={labelMatriz(op)}></option>
					{/each}
				</datalist>
			</div>
		{/if}
	</header>

	<div class="grid min-h-0 flex-1 grid-cols-1 md:grid-cols-[270px_minmax(0,1fr)]">
		<aside class="min-h-0 border-r border-white/10 bg-zinc-950/75">
			<div class="border-b border-white/10 p-3">
				<input
					type="text"
					bind:value={termoBusca}
					placeholder="Buscar por código ou nome..."
					class="w-full rounded-xl border border-white/10 bg-zinc-900/70 px-3 py-2 text-sm text-white placeholder:text-white/40 focus:outline-none focus:ring-2 focus:ring-purple-500/30"
				/>
			</div>

			{#if carregandoCurso}
				<p class="flex items-center gap-2 p-3 text-xs text-white/55">
					<Loader2 class="h-3.5 w-3.5 animate-spin" /> Carregando disciplinas...
				</p>
			{:else}
				<div class="h-[calc(100%-3.25rem)] space-y-1 overflow-y-auto p-2">
					{#if !curso && termoNorm.length < 2}
						<p class="p-2 text-xs text-white/45">Digite pelo menos 2 caracteres para buscar globalmente.</p>
					{:else if resultadosBusca.length === 0}
						<p class="p-2 text-xs text-white/45">Nenhuma disciplina para esse termo.</p>
					{/if}
					{#each resultadosBusca as m}
						<button
							type="button"
							onclick={() => selecionarMateria(m)}
							class="w-full rounded-xl border px-2.5 py-2 text-left transition-colors {selecionada &&
							selecionada.idMateria === m.idMateria
								? 'border-purple-300/40 bg-purple-500/15'
								: 'border-transparent hover:border-white/10 hover:bg-white/5'}"
						>
							<p class="font-mono text-xs font-medium text-purple-300">{m.codigoMateria}</p>
							<p class="line-clamp-2 text-sm text-white/75">{m.nomeMateria}</p>
						</button>
					{/each}
					{#if !curso && carregandoBuscaGlobal}
						<p class="flex items-center gap-2 p-2 text-xs text-white/55">
							<Loader2 class="h-3.5 w-3.5 animate-spin" /> Buscando matérias...
						</p>
					{/if}
					{#if !curso && erroBuscaGlobal}
						<p class="p-2 text-xs text-red-300/85">{erroBuscaGlobal}</p>
					{/if}
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
			{:else if curso && selecionada.source === 'matrix'}
				<SubjectChainView
					courseData={curso}
					focusCode={selecionada.codigoMateria}
					onNavigate={aoNavegarCadeia}
					showSemesterBadge={!!curriculoSelecionado}
				/>
			{:else}
				<div class="space-y-4">
					<div class="rounded-2xl border border-white/10 bg-gradient-to-b from-zinc-900/92 to-black/78 p-5 sm:p-6">
					<p class="mb-2 inline-flex rounded-md border border-purple-300/30 bg-purple-500/10 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.14em] text-purple-200">
						Matéria global
					</p>
					<h2 class="text-2xl font-bold text-white">{selecionada.nomeMateria}</h2>
					<p class="mt-1 font-mono text-sm text-purple-200/80">{selecionada.codigoMateria}</p>
					<p class="mt-4 text-sm text-white/65">
						Cadeia global: pré-requisitos e dependências são calculados sem precisar de matriz. Equivalências
						específicas podem variar por currículo.
					</p>
				</div>
					{#if globalChainError}
						<p class="text-sm text-red-300/90">{globalChainError}</p>
					{/if}
					{#if globalChainLoading}
						<p class="flex items-center gap-2 text-sm text-white/60">
							<Loader2 class="h-4 w-4 animate-spin" /> Calculando cadeia global...
						</p>
					{:else}
						<section class="rounded-2xl border border-white/10 bg-gradient-to-b from-violet-900/20 to-black/20 p-4 sm:p-5">
							<p class="mb-3 text-xs font-medium uppercase tracking-[0.12em] text-white/45">
								Ordem no grafo — cadeia topológica
							</p>
							<div class="overflow-x-auto pb-1">
								<div class="flex min-w-max items-center gap-0">
									{#each globalRoadmapColumns as col, ci}
										<div class="flex flex-col items-center gap-2">
											{#each col as m}
												<button
													type="button"
													onclick={() => selecionarMateria(m)}
													class="w-[172px] rounded-xl border px-3 py-2 text-left transition-colors {m.idMateria === selecionada.idMateria
														? 'border-purple-300/45 bg-purple-500/14'
														: ci === globalRoadmapColumns.length - 1
															? 'border-cyan-300/35 bg-cyan-500/10 hover:bg-cyan-500/20'
															: 'border-amber-300/35 bg-amber-500/10 hover:bg-amber-500/20'}"
												>
													<p class="font-mono text-xs {m.idMateria === selecionada.idMateria ? 'text-purple-200' : 'text-white/80'}">
														{m.codigoMateria}
													</p>
													<p class="line-clamp-2 text-xs text-white/65">{m.nomeMateria}</p>
												</button>
											{/each}
										</div>
										{#if ci < globalRoadmapColumns.length - 1}
											<div class="px-3 text-white/35" aria-hidden="true">→</div>
										{/if}
									{/each}
								</div>
							</div>
						</section>

						<section class="overflow-hidden rounded-2xl border border-white/10 bg-zinc-900/45">
							<button type="button" class="flex w-full items-center justify-between px-4 py-3 hover:bg-white/5" onclick={() => (openGlobalPre = !openGlobalPre)}>
								<span class="flex items-center gap-2 text-sm font-medium text-white">
									<span class="h-2 w-2 rounded-full bg-amber-300"></span>
									Precisa cursar antes
									<span class="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 font-mono text-[11px] text-white/65">{globalPreReqs.length}</span>
								</span>
								{#if openGlobalPre}<span class="text-white/50">▲</span>{:else}<span class="text-white/50">▼</span>{/if}
							</button>
							{#if openGlobalPre}
								<div class="border-t border-white/10 px-4 py-3">
									{#if globalPreReqs.length === 0}
										<p class="text-xs text-white/45">Nenhuma encontrada.</p>
									{:else}
										<div class="flex flex-wrap gap-2">
											{#each globalPreReqs as m}
												<button type="button" class="rounded-lg border border-amber-300/35 bg-amber-500/10 px-2.5 py-1 text-left text-xs text-amber-100 hover:bg-amber-500/20" onclick={() => selecionarMateria(m)}>
													<span class="font-mono">{m.codigoMateria}</span><span class="text-white/60"> · {m.nomeMateria}</span>
												</button>
											{/each}
										</div>
									{/if}
								</div>
							{/if}
						</section>
						<section class="overflow-hidden rounded-2xl border border-white/10 bg-zinc-900/45">
							<button type="button" class="flex w-full items-center justify-between px-4 py-3 hover:bg-white/5" onclick={() => (openGlobalDep = !openGlobalDep)}>
								<span class="flex items-center gap-2 text-sm font-medium text-white">
									<span class="h-2 w-2 rounded-full bg-cyan-300"></span>
									Desbloqueia depois (transitivo)
									<span class="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 font-mono text-[11px] text-white/65">{globalDeps.length}</span>
								</span>
								{#if openGlobalDep}<span class="text-white/50">▲</span>{:else}<span class="text-white/50">▼</span>{/if}
							</button>
							{#if openGlobalDep}
								<div class="border-t border-white/10 px-4 py-3">
									{#if globalDeps.length === 0}
										<p class="text-xs text-white/45">Nenhuma encontrada.</p>
									{:else}
										<div class="flex flex-wrap gap-2">
											{#each globalDeps as m}
												<button type="button" class="rounded-lg border border-cyan-300/35 bg-cyan-500/10 px-2.5 py-1 text-left text-xs text-cyan-100 hover:bg-cyan-500/20" onclick={() => selecionarMateria(m)}>
													<span class="font-mono">{m.codigoMateria}</span><span class="text-white/60"> · {m.nomeMateria}</span>
												</button>
											{/each}
										</div>
									{/if}
								</div>
							{/if}
						</section>
						{#if globalCoreqs.length > 0}
							<section class="overflow-hidden rounded-2xl border border-white/10 bg-zinc-900/45">
								<button type="button" class="flex w-full items-center justify-between px-4 py-3 hover:bg-white/5" onclick={() => (openGlobalCoreq = !openGlobalCoreq)}>
									<span class="flex items-center gap-2 text-sm font-medium text-white">
										<span class="h-2 w-2 rounded-full bg-indigo-300"></span>
										Co-requisitos
										<span class="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 font-mono text-[11px] text-white/65">{globalCoreqs.length}</span>
									</span>
									{#if openGlobalCoreq}<span class="text-white/50">▲</span>{:else}<span class="text-white/50">▼</span>{/if}
								</button>
								{#if openGlobalCoreq}
									<div class="border-t border-white/10 px-4 py-3">
										<div class="flex flex-wrap gap-2">
											{#each globalCoreqs as m}
												<button type="button" class="rounded-lg border border-indigo-300/35 bg-indigo-500/10 px-2.5 py-1 text-left text-xs text-indigo-100 hover:bg-indigo-500/20" onclick={() => selecionarMateria(m)}>
													<span class="font-mono">{m.codigoMateria}</span><span class="text-white/60"> · {m.nomeMateria}</span>
												</button>
											{/each}
										</div>
									</div>
								{/if}
							</section>
						{/if}
						<section class="overflow-hidden rounded-2xl border border-white/10 bg-zinc-900/45">
							<button type="button" class="flex w-full items-center justify-between px-4 py-3 hover:bg-white/5" onclick={() => (openGlobalEq = !openGlobalEq)}>
								<span class="flex items-center gap-2 text-sm font-medium text-white">
									<span class="h-2 w-2 rounded-full bg-purple-300"></span>
									Equivalências
									<span class="rounded-full border border-white/10 bg-white/5 px-2 py-0.5 font-mono text-[11px] text-white/65">{globalEquivsGeneral.length}</span>
								</span>
								{#if openGlobalEq}<span class="text-white/50">▲</span>{:else}<span class="text-white/50">▼</span>{/if}
							</button>
							{#if openGlobalEq}
								<div class="border-t border-white/10 px-4 py-3">
									{#if globalEquivsGeneral.length === 0}
										<p class="text-xs text-white/45">Nenhuma equivalência geral encontrada para esta disciplina.</p>
									{:else}
										<p class="mb-2 text-[11px] font-semibold uppercase tracking-wide text-white/55">Gerais</p>
										<ul class="space-y-2">
											{#each globalEquivsGeneral as eq}
												<li class="rounded-lg border border-purple-300/25 bg-purple-500/10 px-3 py-2 text-xs text-purple-100">
													<p>
														<span class="font-mono">{eq.codigoOrigem || '—'}</span>
														↔
														<span class="font-mono">{eq.codigoEquivalente || '—'}</span>
													</p>
													{#if eq.expressaoOriginal}
														<p class="mt-1 text-[11px] text-white/65">{eq.expressaoOriginal}</p>
													{/if}
												</li>
											{/each}
										</ul>
									{/if}
									{#if globalEquivsSpecific.length > 0}
										<p class="mt-3 text-[11px] text-amber-200/85">
											{globalEquivsSpecific.length} equivalência(s) específica(s) de currículo ocultas neste modo.
											Selecione uma matriz para visualizar as específicas.
										</p>
									{/if}
								</div>
							{/if}
						</section>
					{/if}
				</div>
			{/if}
		</main>
	</div>
</div>

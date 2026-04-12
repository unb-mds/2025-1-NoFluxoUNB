/**
 * Grafo de dependências do currículo: pré-requisitos (arestas u→v) e co-requisitos
 * como arestas bidirecionais (componentes fortemente conexos = turmas no mesmo “nível”).
 *
 * Ordenação topológica aplicada ao DAG condensado (SCCs) para exibir a cadeia até a matéria alvo.
 *
 * **Hover contextual (`getSubjectChain`):** pré-requisitos transitivos = DFS reverso no DAG;
 * dependentes transitivos = BFS a partir do foco; co-requisitos = fecho fixo sobre pares em
 * `coRequisitos` ligados à cadeia. Cache por `(idCurso, matriz, código foco)` evita recomputar
 * em cada card; invalidação automática ao mudar o curso (nova chave).
 */

import type { CursoModel } from '$lib/types/curso';
import type { MateriaModel } from '$lib/types/materia';

function normCode(c: string): string {
	return (c || '').trim().toUpperCase();
}

export interface CurriculumChainLayer {
	/** Índice do SCC na ordenação topológica do grafo condensado (0 = mais cedo). */
	topoIndex: number;
	/** Códigos neste componente (co-requisitos compartilham o mesmo SCC). */
	codes: string[];
	materias: MateriaModel[];
	/** true se este SCC tem mais de uma matéria (tipicamente co-requisitos). */
	isCoReqCluster: boolean;
}

export interface TopologicalPrerequisiteChainResult {
	/** Camadas da raiz até a camada que contém a matéria alvo (inclusiva), em ordem topológica. */
	layers: CurriculumChainLayer[];
	/** Mapa código → id do SCC. */
	sccIdByCode: Map<string, number>;
	/** Total de SCCs no grafo completo do curso. */
	totalSccCount: number;
}

function getMateriaCodeById(materias: MateriaModel[], id: number): string | null {
	const m = materias.find((x) => x.idMateria === id);
	return m?.codigoMateria ? normCode(m.codigoMateria) : null;
}

/**
 * Monta adjacência direta (u → v): cursar u antes de v.
 * - Pré-requisitos: cada aresta do pré-requisito para a matéria dependente.
 * - Co-requisitos: arestas mútuas entre os dois códigos (formam SCC).
 */
function buildForwardAdjacency(curso: CursoModel): Map<string, Set<string>> {
	const adj = new Map<string, Set<string>>();
	const ensure = (u: string) => {
		if (!adj.has(u)) adj.set(u, new Set());
		return adj.get(u)!;
	};

	const codesInCourse = new Set(curso.materias.map((m) => normCode(m.codigoMateria)));

	for (const m of curso.materias) {
		const v = normCode(m.codigoMateria);
		if (!codesInCourse.has(v)) continue;
		for (const p of m.preRequisitos ?? []) {
			const u = normCode(p.codigoMateria);
			if (u && codesInCourse.has(u) && u !== v) {
				ensure(u).add(v);
			}
		}
	}

	for (const cr of curso.coRequisitos) {
		const a = getMateriaCodeById(curso.materias, cr.idMateria);
		const b = (cr.codigoMateriaCoRequisito && normCode(cr.codigoMateriaCoRequisito)) || null;
		if (!a || !b || a === b) continue;
		if (!codesInCourse.has(a) || !codesInCourse.has(b)) continue;
		ensure(a).add(b);
		ensure(b).add(a);
	}

	return adj;
}

function buildReverseAdjacency(adj: Map<string, Set<string>>): Map<string, Set<string>> {
	const rev = new Map<string, Set<string>>();
	for (const u of adj.keys()) {
		if (!rev.has(u)) rev.set(u, new Set());
		for (const v of adj.get(u)!) {
			if (!rev.has(v)) rev.set(v, new Set());
			rev.get(v)!.add(u);
		}
	}
	return rev;
}

/** Todos os nós X tais que existe caminho X → target (pré-requisitos transitivos + target). */
function prerequisiteClosure(
	adj: Map<string, Set<string>>,
	target: string
): Set<string> {
	const rev = buildReverseAdjacency(adj);
	const out = new Set<string>();
	const stack = [target];
	out.add(target);
	while (stack.length) {
		const v = stack.pop()!;
		for (const u of rev.get(v) ?? []) {
			if (!out.has(u)) {
				out.add(u);
				stack.push(u);
			}
		}
	}
	return out;
}

/** Tarjan — retorna componente (array de SCCs, cada uma lista de vértices). */
function tarjanScc(vertices: string[], adj: Map<string, Set<string>>): string[][] {
	const index = new Map<string, number>();
	const lowlink = new Map<string, number>();
	const onStack = new Set<string>();
	const stack: string[] = [];
	let idx = 0;
	const sccs: string[][] = [];

	function strongConnect(v: string): void {
		index.set(v, idx);
		lowlink.set(v, idx);
		idx++;
		stack.push(v);
		onStack.add(v);

		for (const w of adj.get(v) ?? []) {
			if (!index.has(w)) {
				strongConnect(w);
				lowlink.set(v, Math.min(lowlink.get(v)!, lowlink.get(w)!));
			} else if (onStack.has(w)) {
				lowlink.set(v, Math.min(lowlink.get(v)!, index.get(w)!));
			}
		}

		if (lowlink.get(v) === index.get(v)) {
			const comp: string[] = [];
			let w: string;
			do {
				w = stack.pop()!;
				onStack.delete(w);
				comp.push(w);
			} while (w !== v);
			sccs.push(comp);
		}
	}

	for (const v of vertices) {
		if (!index.has(v)) strongConnect(v);
	}

	return sccs;
}

/** Ordenação topológica do grafo condensado (ids 0..k-1). */
function topologicalOrderCondensation(
	sccCount: number,
	condEdges: Set<string>
): number[] | null {
	const indeg = new Array(sccCount).fill(0);
	const outAdj = Array.from({ length: sccCount }, () => new Set<number>());
	for (const key of condEdges) {
		const [a, b] = key.split(':').map(Number);
		if (!outAdj[a].has(b)) {
			outAdj[a].add(b);
			indeg[b]++;
		}
	}
	const q: number[] = [];
	for (let i = 0; i < sccCount; i++) {
		if (indeg[i] === 0) q.push(i);
	}
	const order: number[] = [];
	while (q.length) {
		const u = q.shift()!;
		order.push(u);
		for (const v of outAdj[u]) {
			indeg[v]--;
			if (indeg[v] === 0) q.push(v);
		}
	}
	if (order.length !== sccCount) return null;
	return order;
}

const codeToMateriaMap = (curso: CursoModel): Map<string, MateriaModel> =>
	new Map(curso.materias.map((m) => [normCode(m.codigoMateria), m]));

/**
 * Cadeia de pré-requisitos em ordem topológica do DAG condensado.
 * Co-requisitos aparecem no mesmo SCC (mesma camada, `isCoReqCluster` quando |SCC|>1).
 */
export function getTopologicalPrerequisiteChain(
	curso: CursoModel,
	targetCode: string
): TopologicalPrerequisiteChainResult {
	const target = normCode(targetCode);
	const codeMap = codeToMateriaMap(curso);
	if (!codeMap.has(target)) {
		return { layers: [], sccIdByCode: new Map(), totalSccCount: 0 };
	}

	const adj = buildForwardAdjacency(curso);
	const vertices = [...codeMap.keys()];
	for (const c of vertices) {
		if (!adj.has(c)) adj.set(c, new Set());
	}

	const sccs = tarjanScc(vertices, adj);
	const sccIdByCode = new Map<string, number>();
	sccs.forEach((comp, id) => {
		for (const c of comp) sccIdByCode.set(c, id);
	});

	const condEdges = new Set<string>();
	for (const u of vertices) {
		const su = sccIdByCode.get(u)!;
		for (const v of adj.get(u) ?? []) {
			const sv = sccIdByCode.get(v)!;
			if (su !== sv) condEdges.add(`${su}:${sv}`);
		}
	}

	const topoScc = topologicalOrderCondensation(sccs.length, condEdges);
	if (!topoScc) {
		// Ciclo estranho no condensado — fallback: ordem por menor código em cada SCC
		return {
			layers: [],
			sccIdByCode,
			totalSccCount: sccs.length
		};
	}

	const posInTopo = new Map<number, number>();
	topoScc.forEach((sccId, i) => posInTopo.set(sccId, i));

	const closure = prerequisiteClosure(adj, target);
	const targetScc = sccIdByCode.get(target)!;
	const targetPos = posInTopo.get(targetScc)!;

	const relevantSccIds = new Set<number>();
	for (const code of closure) {
		const sid = sccIdByCode.get(code)!;
		const p = posInTopo.get(sid)!;
		if (p <= targetPos) relevantSccIds.add(sid);
	}

	const orderedLayers: CurriculumChainLayer[] = [];
	for (const sccId of topoScc) {
		if (!relevantSccIds.has(sccId)) continue;
		const codes = [...sccs[sccId]].sort((a, b) => a.localeCompare(b, 'pt-BR'));
		const materias = codes
			.map((c) => codeMap.get(c))
			.filter((m): m is MateriaModel => m != null);
		orderedLayers.push({
			topoIndex: posInTopo.get(sccId)!,
			codes,
			materias,
			isCoReqCluster: codes.length > 1
		});
	}

	return {
		layers: orderedLayers,
		sccIdByCode,
		totalSccCount: sccs.length
	};
}

/** Cache por (curso + matéria em foco) para não recalcular em todo SubjectCard. */
let hoverHighlightCache: { key: string; ancestors: Set<string>; descendants: Set<string> } | null =
	null;

/** Cores do modo “cadeia contextual” (hover): pré-requisitos, desbloqueios, co-req. */
export const CHAIN_VISUAL = {
	precursor: '#4fd1c5',
	descendant: '#f6ad55',
	corequisite: '#7f9cf5',
	dimOpacity: 0.14
} as const;

export interface SubjectChainResult {
	focusCode: string;
	/** Pré-requisitos transitivos (exclui M). */
	precursors: ReadonlySet<string>;
	/** Dependências transitivas (exclui M). */
	descendants: ReadonlySet<string>;
	/**
	 * Matérias alcançadas só por expansão de co-requisito a partir de P∪{M}∪D
	 * (não são pré nem sucessoras diretos no sentido do DAG de pré-req).
	 */
	corequisites: ReadonlySet<string>;
	/** Todos os nós destacados (P ∪ {M} ∪ D ∪ expansão co-req). */
	chainNodeSet: ReadonlySet<string>;
}

let subjectChainCache: { key: string; result: SubjectChainResult } | null = null;

/**
 * Expande por pontos fixos: repetidamente adiciona parceiros de co-requisito de quem já está no conjunto.
 */
function expandCoReqClosure(curso: CursoModel, seed: Set<string>): Set<string> {
	const codesInCourse = new Set(curso.materias.map((m) => normCode(m.codigoMateria)));
	const materiaById = new Map(curso.materias.map((m) => [m.idMateria, m]));
	const out = new Set(seed);
	let changed = true;
	while (changed) {
		changed = false;
		for (const cr of curso.coRequisitos ?? []) {
			const a = materiaById.get(cr.idMateria)?.codigoMateria;
			const b = cr.codigoMateriaCoRequisito ? normCode(cr.codigoMateriaCoRequisito) : null;
			const na = a ? normCode(a) : null;
			if (!na || !b || na === b) continue;
			if (!codesInCourse.has(na) || !codesInCourse.has(b)) continue;
			if (out.has(na) && !out.has(b)) {
				out.add(b);
				changed = true;
			}
			if (out.has(b) && !out.has(na)) {
				out.add(na);
				changed = true;
			}
		}
	}
	return out;
}

/**
 * Cadeia contextual para hover: pré-requisitos e desbloqueios transitivos no DAG (pré-req + co-req na adjacência),
 * mais fecho de co-requisitos ligados a qualquer nó já na cadeia.
 *
 * Transitividade: DFS reverso para P, BFS para D (`getAncestorAndDescendantCodes`), memoizado por (curso, foco).
 * Co-requisitos: fecho iterativo sobre pares em `curso.coRequisitos` (O(|co-req| × iterações)).
 */
export function getSubjectChain(
	curso: CursoModel,
	targetCode: string | null | undefined
): SubjectChainResult | null {
	if (!targetCode?.trim()) {
		return null;
	}
	const f = normCode(targetCode);
	const key = `${curso.idCurso}\0${curso.matrizCurricular ?? ''}\0${f}`;
	if (subjectChainCache?.key === key) {
		return subjectChainCache.result;
	}

	const { ancestors: P, descendants: D } = getAncestorAndDescendantCodes(curso, f);
	const seed = new Set<string>([f, ...P, ...D]);
	const chainNodeSet = expandCoReqClosure(curso, seed);

	const corequisites = new Set<string>();
	for (const c of chainNodeSet) {
		if (c !== f && !P.has(c) && !D.has(c)) {
			corequisites.add(c);
		}
	}

	const result: SubjectChainResult = {
		focusCode: f,
		precursors: P,
		descendants: D,
		corequisites,
		chainNodeSet
	};
	subjectChainCache = { key, result };
	return result;
}

/** Classifica aresta de pré-requisito u→v (v depende de u) para cor no modo cadeia. */
export function classifyChainPrereqStroke(
	u: string,
	v: string,
	focus: string,
	precursors: ReadonlySet<string>,
	descendants: ReadonlySet<string>
): 'pre' | 'desc' {
	const nu = normCode(u);
	const nv = normCode(v);
	const M = normCode(focus);
	/** Tudo que flui “para frente” a partir de M (inclui dependentes). */
	if (descendants.has(nv) && (nu === M || descendants.has(nu))) {
		return 'desc';
	}
	return 'pre';
}

/**
 * Conjuntos para destaque no fluxograma: antecessores e descendentes transitivos
 * no grafo pré-requisito + co-requisito (mesma adjacência de `buildForwardAdjacency`).
 */
export function getAncestorAndDescendantCodes(
	curso: CursoModel,
	focusCode: string | null
): { ancestors: Set<string>; descendants: Set<string> } {
	if (!focusCode?.trim()) {
		return { ancestors: new Set(), descendants: new Set() };
	}
	const f = normCode(focusCode);
	const key = `${curso.idCurso}\0${curso.matrizCurricular ?? ''}\0${f}`;
	if (hoverHighlightCache?.key === key) {
		return {
			ancestors: hoverHighlightCache.ancestors,
			descendants: hoverHighlightCache.descendants
		};
	}

	const adj = buildForwardAdjacency(curso);
	const codesInCourse = new Set(curso.materias.map((m) => normCode(m.codigoMateria)));
	if (!codesInCourse.has(f)) {
		const empty = { ancestors: new Set<string>(), descendants: new Set<string>() };
		hoverHighlightCache = { key, ...empty };
		return empty;
	}

	for (const c of codesInCourse) {
		if (!adj.has(c)) adj.set(c, new Set());
	}

	const pred = prerequisiteClosure(adj, f);
	pred.delete(f);

	const descendants = new Set<string>();
	const vis = new Set<string>([f]);
	const q = [f];
	while (q.length) {
		const u = q.shift()!;
		for (const v of adj.get(u) ?? []) {
			if (!vis.has(v)) {
				vis.add(v);
				descendants.add(v);
				q.push(v);
			}
		}
	}

	hoverHighlightCache = { key, ancestors: pred, descendants };
	return { ancestors: pred, descendants };
}

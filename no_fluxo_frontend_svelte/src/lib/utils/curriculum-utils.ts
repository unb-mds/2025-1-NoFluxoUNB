/**
 * Utilitários e análise centralizada de currículo (DRY com `curriculum-graph.ts`).
 * Consumível pelo fluxograma, pela aba Disciplinas e por qualquer tela que precise de
 * pré-requisitos transitivos, dependentes, co-reqs e camadas topológicas.
 */

import type { CursoModel } from '$lib/types/curso';
import type { MateriaModel } from '$lib/types/materia';
import type { EquivalenciaModel } from '$lib/types/equivalencia';
import { getCodigosFromExpressaoLogica } from '$lib/utils/expressao-logica';
import {
	getSubjectChain,
	getTopologicalPrerequisiteChain,
	type CurriculumChainLayer,
	type SubjectChainResult
} from '$lib/utils/curriculum-graph';

function normCode(c: string): string {
	return (c || '').trim().toUpperCase();
}

/** Remove acentos (compatível com busca resiliente). */
export function stripDiacritics(s: string): string {
	return s.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

/**
 * Normaliza termo de busca: trim, minúsculas, sem acentos.
 */
export function normalizeSearchQuery(raw: string): string {
	return stripDiacritics(raw.trim().toLowerCase());
}

/**
 * Verifica se a matéria casa com o termo já normalizado (`normalizeSearchQuery`).
 */
export function materiaMatchesNormalizedQuery(m: MateriaModel, normalizedQuery: string): boolean {
	if (normalizedQuery.length < 2) return false;
	const code = normCode(m.codigoMateria).toLowerCase();
	const name = stripDiacritics(m.nomeMateria.toLowerCase());
	return code.includes(normalizedQuery) || name.includes(normalizedQuery);
}

function materiaByCodeMap(curso: CursoModel): Map<string, MateriaModel> {
	return new Map(curso.materias.map((m) => [normCode(m.codigoMateria), m]));
}

function sortMaterias(a: MateriaModel, b: MateriaModel): number {
	return a.nivel - b.nivel || a.codigoMateria.localeCompare(b.codigoMateria, 'pt-BR');
}

function equivalenciasTouchingMateria(
	curso: CursoModel,
	focusCode: string
): EquivalenciaModel[] {
	const n = normCode(focusCode);
	return curso.equivalencias.filter((eq) => {
		if (normCode(eq.codigoMateriaOrigem) === n) return true;
		if (normCode(eq.codigoMateriaEquivalente) === n) return true;
		if (eq.expressaoLogica) {
			try {
				return getCodigosFromExpressaoLogica(eq.expressaoLogica).some((c) => normCode(c) === n);
			} catch {
				return false;
			}
		}
		return false;
	});
}

export interface CurriculumAnalysis {
	focusCode: string;
	focusMateria: MateriaModel | null;
	/** Transitivos (exceto foco), ordenados por semestre sugerido. */
	preRequisites: MateriaModel[];
	dependencies: MateriaModel[];
	corequisites: MateriaModel[];
	equivalencies: EquivalenciaModel[];
	/** Camadas topológicas até o SCC da matéria alvo (roadmap em profundidade). */
	topologicalLayers: CurriculumChainLayer[];
	totalSccCount: number;
	/** Resultado bruto da cadeia contextual (co-req, conjuntos). */
	chain: SubjectChainResult | null;
}

let analysisCache = new Map<string, CurriculumAnalysis>();

function cacheKey(curso: CursoModel, code: string): string {
	return `${curso.idCurso}\0${curso.curriculoCompleto ?? curso.matrizCurricular ?? ''}\0${normCode(code)}`;
}

/**
 * Análise completa para uma matéria no currículo ativo.
 * Reutiliza caches internos de `getSubjectChain` / grafo.
 */
export function getCurriculumAnalysis(curso: CursoModel, targetCode: string): CurriculumAnalysis | null {
	if (!targetCode?.trim()) return null;
	const key = cacheKey(curso, targetCode);
	const hit = analysisCache.get(key);
	if (hit) return hit;

	const map = materiaByCodeMap(curso);
	const f = normCode(targetCode);
	const focusMateria = map.get(f) ?? null;

	const chain = getSubjectChain(curso, targetCode);
	const topo = getTopologicalPrerequisiteChain(curso, targetCode);

	const preRequisites: MateriaModel[] = [];
	const dependencies: MateriaModel[] = [];
	const corequisites: MateriaModel[] = [];

	if (chain) {
		for (const c of chain.precursors) {
			const m = map.get(c);
			if (m) preRequisites.push(m);
		}
		for (const c of chain.descendants) {
			const m = map.get(c);
			if (m) dependencies.push(m);
		}
		for (const c of chain.corequisites) {
			const m = map.get(c);
			if (m) corequisites.push(m);
		}
		preRequisites.sort(sortMaterias);
		dependencies.sort(sortMaterias);
		corequisites.sort(sortMaterias);
	}

	const result: CurriculumAnalysis = {
		focusCode: f,
		focusMateria,
		preRequisites,
		dependencies,
		corequisites,
		equivalencies: equivalenciasTouchingMateria(curso, targetCode),
		topologicalLayers: topo.layers,
		totalSccCount: topo.totalSccCount,
		chain
	};

	analysisCache.set(key, result);
	return result;
}

/** Limpa cache de análise (ex.: ao trocar de matriz no seletor). */
export function clearCurriculumAnalysisCache(): void {
	analysisCache.clear();
}

/**
 * Fachada única para telas (fluxograma, disciplinas, futuras). Alterações nas regras de
 * pré-requisito/equivalência devem concentrar-se em `curriculum-graph` + este módulo.
 */
export const CurriculumEngine = {
	analyze: getCurriculumAnalysis,
	clearAnalysisCache: clearCurriculumAnalysisCache,
	normalizeSearchQuery,
	materiaMatchesNormalizedQuery
} as const;

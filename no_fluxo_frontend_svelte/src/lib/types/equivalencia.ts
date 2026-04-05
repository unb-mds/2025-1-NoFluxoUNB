/**
 * Equivalence type definitions and expression evaluation
 */

import type { MateriaModel } from './materia';
import type { ExpressaoLogicaRecursiva } from '$lib/utils/expressao-logica';
import {
	evaluateExpressaoLogica,
	evaluateExpression,
	evaluateExpressionWithTracking,
	extractSubjectCodesFromExpression,
	getCodigosFromExpressaoLogica,
	type ExpressionResult
} from '$lib/utils/expressao-logica';

export type { ExpressionResult };
export { extractSubjectCodesFromExpression };

export interface EquivalenciaModel {
	idEquivalencia: number;
	codigoMateriaOrigem: string;
	nomeMateriaOrigem: string;
	codigoMateriaEquivalente: string;
	nomeMateriaEquivalente: string;
	expressao: string;
	/** Formato recursivo { operador, condicoes } - usado quando disponível para avaliação */
	expressaoLogica?: ExpressaoLogicaRecursiva | null;
	idCurso?: number | null;
	nomeCurso?: string | null;
	matrizCurricular?: string | null;
	curriculo?: string | null;
	dataVigencia?: string | null;
	fimVigencia?: string | null;
}

export interface EquivalenciaResult {
	isEquivalente: boolean;
	equivalentes: MateriaModel[];
}

export function isMateriaEquivalente(
	equivalencia: EquivalenciaModel,
	materiasCursadas: MateriaModel[]
): EquivalenciaResult {
	const materias = new Set(materiasCursadas.map((m) => m.codigoMateria));
	const materiasNorm = new Set([...materias].map((c) => c.trim().toUpperCase()));

	let result: ExpressionResult;
	if (equivalencia.expressaoLogica != null) {
		const isTrue = evaluateExpressaoLogica(equivalencia.expressaoLogica, materiasNorm);
		const codigos = getCodigosFromExpressaoLogica(equivalencia.expressaoLogica);
		const matchingMaterias = new Set(codigos.filter((c) => materiasNorm.has(c)));
		result = { isTrue, matchingMaterias };
	} else {
		result = evaluateExpressionWithTracking(equivalencia.expressao.trim(), materias);
	}

	const normSet = new Set([...result.matchingMaterias].map((c) => c.trim().toUpperCase()));
	const equivalenteMaterias = materiasCursadas.filter((m) =>
		normSet.has(m.codigoMateria.trim().toUpperCase())
	);

	return {
		isEquivalente: result.isTrue,
		equivalentes: equivalenteMaterias
	};
}

export function findValidEquivalences(
	subjectCode: string,
	equivalencias: EquivalenciaModel[],
	materiasCursadas: MateriaModel[]
): EquivalenciaResult[] {
	const results: EquivalenciaResult[] = [];

	for (const equiv of equivalencias) {
		if (equiv.codigoMateriaOrigem === subjectCode) {
			const result = isMateriaEquivalente(equiv, materiasCursadas);
			if (result.isEquivalente) {
				results.push(result);
			}
		}
	}

	return results;
}

export function hasValidEquivalence(
	subjectCode: string,
	equivalencias: EquivalenciaModel[],
	completedCodes: Set<string>
): boolean {
	const relevantEquivalencias = equivalencias.filter(
		(e) => e.codigoMateriaOrigem === subjectCode
	);
	const completedNorm = new Set([...completedCodes].map((c) => c.trim().toUpperCase()));

	for (const equiv of relevantEquivalencias) {
		const satisfaz =
			equiv.expressaoLogica != null
				? evaluateExpressaoLogica(equiv.expressaoLogica, completedNorm)
				: evaluateExpression(equiv.expressao, completedCodes);
		if (satisfaz) return true;
	}

	return false;
}

/**
 * Returns the set of subject codes (codigoMateriaOrigem) that are considered
 * completed by equivalence: the user has not completed that exact subject,
 * but has completed one or more subjects that satisfy its equivalence expression.
 * Used so the fluxograma marks "MATEMÁTICA DISCRETA 2" as concluída when the user
 * completed e.g. MAT0035 (which satisfies the equivalence expression).
 */
export function getCompletedByEquivalenceCodes(
	equivalencias: EquivalenciaModel[],
	completedCodes: Set<string>
): Set<string> {
	const result = new Set<string>();
	/** Códigos já “válidos”; cresce com cada origem satisfeita (cadeia de equivalências). */
	const workNorm = new Set(
		[...completedCodes].map((c) => c.trim().toUpperCase()).filter((c) => c.length > 0)
	);
	let changed = true;
	let guard = 0;
	while (changed && guard++ < 64) {
		changed = false;
		for (const equiv of equivalencias) {
			const origemRaw = (equiv.codigoMateriaOrigem || '').trim();
			if (!origemRaw) continue;
			const origemU = origemRaw.toUpperCase();
			if (workNorm.has(origemU)) continue;
			const snap = new Set(workNorm);
			const satisfaz =
				equiv.expressaoLogica != null
					? evaluateExpressaoLogica(equiv.expressaoLogica, snap)
					: evaluateExpression((equiv.expressao || '').trim(), snap);
			if (satisfaz) {
				workNorm.add(origemU);
				result.add(origemRaw);
				changed = true;
			}
		}
	}
	return result;
}


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
 *
 * PASSE ÚNICO, de propósito: só o que o aluno cursou DE VERDADE satisfaz uma
 * equivalência — uma matéria marcada por equivalência não realimenta a expansão.
 * Ou seja, A≡B e B≡C NÃO implica A≡C. Equivalência na UnB é tabela explícita, não
 * relação transitiva: a secretaria não aceita a cadeia só porque os dois pares
 * existem.
 *
 * Alinha o frontend ao backend (`expandirCumpridasComEquivalencias` em
 * plano_formatura.service.ts, commit 7e7075f4). Antes divergiam, e o aluno via
 * matéria verde no fluxograma que o plano de formatura insistia que faltava.
 *
 * Medido nos 1.658 alunos com fluxograma: encadear inflava as marcações por
 * equivalência em 29% (8.497 contra 6.035 matérias de matriz), mexendo em 824.
 */
export function getCompletedByEquivalenceCodes(
	equivalencias: EquivalenciaModel[],
	completedCodes: Set<string>
): Set<string> {
	const result = new Set<string>();
	/** O que o aluno cursou de verdade — nunca cresce durante a avaliação. */
	const base = new Set(
		[...completedCodes].map((c) => c.trim().toUpperCase()).filter((c) => c.length > 0)
	);

	for (const equiv of equivalencias) {
		const origemRaw = (equiv.codigoMateriaOrigem || '').trim();
		if (!origemRaw) continue;
		if (base.has(origemRaw.toUpperCase())) continue;

		const satisfaz =
			equiv.expressaoLogica != null
				? evaluateExpressaoLogica(equiv.expressaoLogica, base)
				: evaluateExpression((equiv.expressao || '').trim(), base);
		if (satisfaz) result.add(origemRaw);
	}

	return result;
}

/**
 * Para um código já sabido como "concluído por equivalência" (ver
 * getCompletedByEquivalenceCodes), retorna os códigos das disciplinas
 * efetivamente cursadas que satisfizeram alguma expressão de equivalência
 * pra esse código -- usado pra exibir os dados reais (menção, professor)
 * da disciplina que cursou, em vez dos de uma tentativa direta reprovada
 * no próprio código de origem.
 */
export function findEquivalenceSourceCodes(
	codigoMateria: string,
	equivalencias: EquivalenciaModel[],
	completedCodes: Set<string>
): string[] {
	const codeU = codigoMateria.trim().toUpperCase();
	const completedNorm = new Set([...completedCodes].map((c) => c.trim().toUpperCase()));
	const sources = new Set<string>();
	for (const equiv of equivalencias) {
		if ((equiv.codigoMateriaOrigem || '').trim().toUpperCase() !== codeU) continue;
		if (equiv.expressaoLogica != null) {
			for (const c of getCodigosFromExpressaoLogica(equiv.expressaoLogica)) {
				if (completedNorm.has(c)) sources.add(c);
			}
		} else {
			const result = evaluateExpressionWithTracking(
				(equiv.expressao || '').trim(),
				completedCodes
			);
			for (const c of result.matchingMaterias) sources.add(c.trim().toUpperCase());
		}
	}
	return [...sources];
}


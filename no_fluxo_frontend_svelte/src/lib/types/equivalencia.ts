/**
 * Equivalence type definitions and expression evaluation
 */

import type { MateriaModel } from './materia';

export interface EquivalenciaModel {
	idEquivalencia: number;
	codigoMateriaOrigem: string;
	nomeMateriaOrigem: string;
	codigoMateriaEquivalente: string;
	nomeMateriaEquivalente: string;
	expressao: string;
	idCurso?: number | null;
	nomeCurso?: string | null;
	matrizCurricular?: string | null;
	curriculo?: string | null;
	dataVigencia?: string | null;
	fimVigencia?: string | null;
}

export interface ExpressionResult {
	isTrue: boolean;
	matchingMaterias: Set<string>;
}

export interface EquivalenciaResult {
	isEquivalente: boolean;
	equivalentes: MateriaModel[];
}

function removeOuterParentheses(expression: string): string {
	let trimmed = expression.trim();

	if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
		let count = 0;
		for (let i = 0; i < trimmed.length; i++) {
			if (trimmed[i] === '(') count++;
			if (trimmed[i] === ')') count--;
			if (count === 0 && i < trimmed.length - 1) {
				return trimmed;
			}
		}
		return trimmed.substring(1, trimmed.length - 1).trim();
	}

	return trimmed;
}

function findMainOperator(expression: string, operator: string): number | null {
	let parenthesesCount = 0;
	const operatorLength = operator.length;

	for (let i = expression.length - operatorLength; i >= 0; i--) {
		if (expression[i] === ')') parenthesesCount++;
		if (expression[i] === '(') parenthesesCount--;

		if (
			parenthesesCount === 0 &&
			i + operatorLength <= expression.length &&
			expression.substring(i, i + operatorLength) === operator
		) {
			const validBefore =
				i === 0 || expression[i - 1] === ' ' || expression[i - 1] === ')';
			const validAfter =
				i + operatorLength === expression.length ||
				expression[i + operatorLength] === ' ' ||
				expression[i + operatorLength] === '(';

			if (validBefore && validAfter) {
				return i;
			}
		}
	}

	return null;
}

export function evaluateExpressionWithTracking(
	expression: string,
	materias: Set<string>
): ExpressionResult {
	if (!expression || expression.trim() === '') {
		return { isTrue: false, matchingMaterias: new Set() };
	}

	expression = removeOuterParentheses(expression);

	const orIndex = findMainOperator(expression, 'OU');
	if (orIndex !== null) {
		const left = expression.substring(0, orIndex).trim();
		const right = expression.substring(orIndex + 2).trim();

		const leftResult = evaluateExpressionWithTracking(left, materias);
		const rightResult = evaluateExpressionWithTracking(right, materias);

		const matchingMaterias = new Set<string>();
		if (leftResult.isTrue) {
			leftResult.matchingMaterias.forEach((m) => matchingMaterias.add(m));
		}
		if (rightResult.isTrue) {
			rightResult.matchingMaterias.forEach((m) => matchingMaterias.add(m));
		}

		return {
			isTrue: leftResult.isTrue || rightResult.isTrue,
			matchingMaterias
		};
	}

	const andIndex = findMainOperator(expression, 'E');
	if (andIndex !== null) {
		const left = expression.substring(0, andIndex).trim();
		const right = expression.substring(andIndex + 1).trim();

		const leftResult = evaluateExpressionWithTracking(left, materias);
		const rightResult = evaluateExpressionWithTracking(right, materias);

		if (leftResult.isTrue && rightResult.isTrue) {
			const matchingMaterias = new Set<string>();
			leftResult.matchingMaterias.forEach((m) => matchingMaterias.add(m));
			rightResult.matchingMaterias.forEach((m) => matchingMaterias.add(m));
			return { isTrue: true, matchingMaterias };
		} else {
			return { isTrue: false, matchingMaterias: new Set() };
		}
	}

	const subjectCode = expression.trim();
	// Comparação case-insensitive: histórico pode vir "mat0035" e a expressão "MAT0035"
	const codeNorm = subjectCode.toUpperCase();
	const found = [...materias].find((m) => m.trim().toUpperCase() === codeNorm);
	const contains = !!found;

	return {
		isTrue: contains,
		matchingMaterias: contains && found ? new Set([found]) : new Set()
	};
}

export function evaluateExpression(expression: string, materias: Set<string>): boolean {
	return evaluateExpressionWithTracking(expression, materias).isTrue;
}

export function isMateriaEquivalente(
	equivalencia: EquivalenciaModel,
	materiasCursadas: MateriaModel[]
): EquivalenciaResult {
	const materias = new Set(materiasCursadas.map((m) => m.codigoMateria));

	const result = evaluateExpressionWithTracking(equivalencia.expressao.trim(), materias);

	const equivalenteMaterias = materiasCursadas.filter((materia) =>
		result.matchingMaterias.has(materia.codigoMateria)
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

	for (const equiv of relevantEquivalencias) {
		if (evaluateExpression(equiv.expressao, completedCodes)) {
			return true;
		}
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
	for (const equiv of equivalencias) {
		if (evaluateExpression(equiv.expressao.trim(), completedCodes)) {
			result.add(equiv.codigoMateriaOrigem);
		}
	}
	return result;
}

export function extractSubjectCodesFromExpression(expression: string): string[] {
	const cleaned = expression
		.replace(/\bOU\b/g, ' ')
		.replace(/\bE\b/g, ' ')
		.replace(/[()]/g, ' ')
		.trim();

	return cleaned.split(/\s+/).filter((code) => code.length > 0);
}

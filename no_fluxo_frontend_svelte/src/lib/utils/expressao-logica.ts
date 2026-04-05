/**
 * Avaliação de expressao_logica (JSONB) para pré/co-requisitos e equivalências.
 * Suporta dois formatos:
 * - Legado: { "materias": ["COD1", "COD2"], "operador": "OU" | "E" | null }
 * - Recursivo: string | { "operador": "OU"|"E", "condicoes": ExpressaoLogicaRecursiva[] }
 */

export type ExpressaoLogicaRecursiva =
	| string
	| { operador: 'OU' | 'E'; condicoes: ExpressaoLogicaRecursiva[] };

export interface ExpressaoLogicaJson {
	materias?: string[];
	operador?: 'OU' | 'E' | null;
}

function norm(code: string): string {
	return (code || '').trim().toUpperCase();
}

function setHasCode(codes: Set<string>, code: string): boolean {
	const c = norm(code);
	if (codes.has(c)) return true;
	return [...codes].some((x) => norm(x) === c);
}

/** Código de disciplina isolado (ex.: MAT0026) — alinhado a `parseExpressaoLogica` em factories. */
const CODIGO_MATERIA_REGEX = /^[A-Za-z]{2,}\d{3,}$/;

export interface ExpressionResult {
	isTrue: boolean;
	matchingMaterias: Set<string>;
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

/**
 * Avalia expressão textual SIGAA com operadores `OU` / `E` e parênteses (campo expressao / texto legado).
 */
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
		}
		return { isTrue: false, matchingMaterias: new Set() };
	}

	const subjectCode = expression.trim();
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

/**
 * Avalia expressão recursiva { operador, condicoes }.
 */
function evaluateRecursivo(
	expr: ExpressaoLogicaRecursiva | null | undefined,
	completedCodes: Set<string>
): boolean {
	if (!expr) return false;
	if (typeof expr === 'string') return setHasCode(completedCodes, expr);
	if (expr && typeof expr === 'object' && Array.isArray(expr.condicoes)) {
		if (expr.condicoes.length === 0) return false;
		const op = (expr.operador || 'OU').toUpperCase();
		const results = expr.condicoes.map((c) => evaluateRecursivo(c, completedCodes));
		return op === 'E' ? results.every(Boolean) : results.some(Boolean);
	}
	return false;
}

/**
 * Extrai todos os códigos de uma expressão recursiva.
 */
/** Extrai códigos aproximados de uma expressão textual `OU`/`E` (pré-requisito legado). */
export function extractSubjectCodesFromExpression(expression: string): string[] {
	const cleaned = expression
		.replace(/\bOU\b/gi, ' ')
		.replace(/\bE\b/g, ' ')
		.replace(/[()]/g, ' ')
		.trim();

	return cleaned
		.split(/\s+/)
		.map((code) => norm(code))
		.filter((code) => code.length > 0);
}

export function getCodigosFromExpressaoLogica(
	expr: ExpressaoLogicaRecursiva | ExpressaoLogicaJson | null | undefined
): string[] {
	if (!expr) return [];
	if (typeof expr === 'string') {
		const c = norm(expr);
		if (!c) return [];
		if (CODIGO_MATERIA_REGEX.test(c)) return [c];
		return extractSubjectCodesFromExpression(expr);
	}
	if (expr && typeof expr === 'object') {
		if ('condicoes' in expr && Array.isArray(expr.condicoes)) {
			return expr.condicoes.flatMap((c) => getCodigosFromExpressaoLogica(c));
		}
		if ('materias' in expr && Array.isArray(expr.materias)) {
			return expr.materias.map((m) => norm(String(m)));
		}
	}
	return [];
}

/**
 * Avalia a expressão lógica contra o conjunto de códigos concluídos.
 * Suporta formato legado { materias, operador } e recursivo { operador, condicoes }.
 */
export function evaluateExpressaoLogica(
	expressaoLogica: ExpressaoLogicaJson | ExpressaoLogicaRecursiva | null | undefined,
	completedCodes: Set<string>
): boolean {
	if (!expressaoLogica) return false;

	// String no JSONB / parse: código único ou texto "COD1 OU COD2" (antes não era avaliado — caía em .materias e retornava false)
	if (typeof expressaoLogica === 'string') {
		const s = expressaoLogica.trim();
		if (!s) return false;
		if (CODIGO_MATERIA_REGEX.test(s)) {
			return setHasCode(completedCodes, s);
		}
		return evaluateExpression(s, completedCodes);
	}

	// Formato recursivo { operador, condicoes }
	if (typeof expressaoLogica === 'object' && 'condicoes' in expressaoLogica) {
		return evaluateRecursivo(expressaoLogica as ExpressaoLogicaRecursiva, completedCodes);
	}

	// Formato legado { materias, operador }
	if (!expressaoLogica.materias || expressaoLogica.materias.length === 0) return false;
	const materias = expressaoLogica.materias.map(norm);
	const operador = expressaoLogica.operador ?? null;
	if (operador === 'OU') return materias.some((m) => setHasCode(completedCodes, m));
	if (operador === 'E') return materias.every((m) => setHasCode(completedCodes, m));
	return setHasCode(completedCodes, materias[0]);
}

/**
 * Retorna os códigos da expressão que estão em completedCodes (para highlight/feedback).
 */
export function getMatchingCodesFromExpressao(
	expressaoLogica: ExpressaoLogicaJson | ExpressaoLogicaRecursiva | null | undefined,
	completedCodes: Set<string>
): Set<string> {
	const out = new Set<string>();
	const codigos = getCodigosFromExpressaoLogica(expressaoLogica);
	for (const m of codigos) {
		if (setHasCode(completedCodes, m)) {
			const found = [...completedCodes].find((c) => norm(c) === norm(m));
			if (found) out.add(found);
			else out.add(m);
		}
	}
	return out;
}

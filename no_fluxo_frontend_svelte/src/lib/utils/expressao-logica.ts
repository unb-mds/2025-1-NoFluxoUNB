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

function evaluateRecursivoWithResolver(
	expr: ExpressaoLogicaRecursiva | null | undefined,
	isSatisfied: (code: string) => boolean
): boolean {
	if (!expr) return false;
	if (typeof expr === 'string') return isSatisfied(expr);
	if (expr && typeof expr === 'object' && Array.isArray(expr.condicoes)) {
		if (expr.condicoes.length === 0) return false;
		const op = (expr.operador || 'OU').toUpperCase();
		const results = expr.condicoes.map((c) => evaluateRecursivoWithResolver(c, isSatisfied));
		return op === 'E' ? results.every(Boolean) : results.some(Boolean);
	}
	return false;
}

/**
 * Extrai todos os códigos de uma expressão recursiva.
 */
export function getCodigosFromExpressaoLogica(
	expr: ExpressaoLogicaRecursiva | ExpressaoLogicaJson | null | undefined
): string[] {
	if (!expr) return [];
	if (typeof expr === 'string') {
		const c = norm(expr);
		return c ? [c] : [];
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
 * Como {@link evaluateExpressaoLogica}, mas cada folha (código) usa `isSatisfied(codigo)`.
 * Útil p.ex. para exigir histórico real em optativas que são pré-requisito.
 */
export function evaluateExpressaoLogicaWithResolver(
	expressaoLogica: ExpressaoLogicaJson | ExpressaoLogicaRecursiva | null | undefined,
	isSatisfied: (code: string) => boolean
): boolean {
	if (!expressaoLogica) return false;

	if (typeof expressaoLogica === 'object' && 'condicoes' in expressaoLogica) {
		return evaluateRecursivoWithResolver(expressaoLogica as ExpressaoLogicaRecursiva, isSatisfied);
	}

	if (!expressaoLogica.materias || expressaoLogica.materias.length === 0) return false;
	const materias = expressaoLogica.materias.map(norm);
	const operador = expressaoLogica.operador ?? null;
	if (operador === 'OU') return materias.some((m) => isSatisfied(m));
	if (operador === 'E') return materias.every((m) => isSatisfied(m));
	return isSatisfied(materias[0]);
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

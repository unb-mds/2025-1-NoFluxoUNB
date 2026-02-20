/**
 * Avaliação de expressao_logica (JSONB) para pré/co-requisitos e equivalências.
 * Formato: { "materias": ["COD1", "COD2"], "operador": "OU" | "E" | null }
 * operador null = matéria única.
 */

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
 * Avalia a expressão lógica contra o conjunto de códigos concluídos.
 * Retorna true se a expressão for satisfeita (ex.: (A OU B) com A concluída).
 */
export function evaluateExpressaoLogica(
	expressaoLogica: ExpressaoLogicaJson | null | undefined,
	completedCodes: Set<string>
): boolean {
	if (!expressaoLogica || !expressaoLogica.materias || expressaoLogica.materias.length === 0) {
		return false;
	}

	const materias = expressaoLogica.materias.map(norm);
	const operador = expressaoLogica.operador ?? null;

	if (operador === 'OU') {
		return materias.some((m) => setHasCode(completedCodes, m));
	}
	if (operador === 'E') {
		return materias.every((m) => setHasCode(completedCodes, m));
	}
	// Matéria única
	return setHasCode(completedCodes, materias[0]);
}

/**
 * Retorna os códigos da expressão que estão em completedCodes (para highlight/feedback).
 */
export function getMatchingCodesFromExpressao(
	expressaoLogica: ExpressaoLogicaJson | null | undefined,
	completedCodes: Set<string>
): Set<string> {
	const out = new Set<string>();
	if (!expressaoLogica?.materias) return out;
	for (const m of expressaoLogica.materias) {
		if (setHasCode(completedCodes, m)) {
			const found = [...completedCodes].find((c) => norm(c) === norm(m));
			if (found) out.add(found);
			else out.add(m);
		}
	}
	return out;
}

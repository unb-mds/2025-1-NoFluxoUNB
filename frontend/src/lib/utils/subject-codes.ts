/** Comparação de código de disciplina no histórico / sets (caixa e espaços). */
export function setHasCodeIgnoreCase(codes: Set<string>, code: string): boolean {
	if (codes.has(code)) return true;
	const codeUpper = (code || '').trim().toUpperCase();
	if (!codeUpper) return false;
	return [...codes].some((c) => c.trim().toUpperCase() === codeUpper);
}

/**
 * Tira da lista os códigos que o aluno já concluiu ou está cursando.
 *
 * `emCurso` (MATR) sai junto porque estará concluída antes do semestre que o aluno
 * está montando — mesma regra que `recomendarPorHorarioLivre` usa no backend, onde
 * as cumpridas são "aprovadas ∪ em curso". Reprovada NÃO entra em nenhum dos dois
 * conjuntos, então continua na lista: é exatamente o que precisa ser cursado de novo.
 *
 * Normaliza dos dois lados e remove duplicatas, preservando a ordem de entrada.
 */
export function filtrarNaoCursados(
	codigos: string[],
	concluidos: Set<string>,
	emCurso: Set<string>
): string[] {
	const vistos = new Set<string>();
	const out: string[] = [];

	for (const codigo of codigos) {
		const norm = (codigo || '').trim().toUpperCase();
		if (!norm || vistos.has(norm)) continue;
		if (setHasCodeIgnoreCase(concluidos, codigo)) continue;
		if (setHasCodeIgnoreCase(emCurso, codigo)) continue;
		vistos.add(norm);
		out.push(codigo);
	}

	return out;
}

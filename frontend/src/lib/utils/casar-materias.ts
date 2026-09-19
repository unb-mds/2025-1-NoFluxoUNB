/**
 * Filtros alinhados à regra da grade: obrigatória ≠ optativa
 * (tipo_natureza 1 ou nivel 0 = optativa — ver `isOptativa` em materia.ts).
 * Garante que listas de "pendentes" no pós-casamento não incluam optativas.
 */

/** true = conta como obrigatória no casamento (não é optativa da grade). */
export function isMateriaObrigatoriaNoCasamento(m: Record<string, unknown>): boolean {
	const tipo = String(m.tipo ?? '')
		.trim()
		.toLowerCase();
	if (tipo === 'optativa') return false;
	if (m.nivel != null && m.nivel !== '' && Number(m.nivel) === 0) return false;
	return true;
}

/** Mantém só obrigatórias (exclui optativas e disciplinas de nível 0). */
export function filterMateriasPendentesSomenteObrigatorias(
	rows: Record<string, unknown>[]
): Record<string, unknown>[] {
	return rows.filter(isMateriaObrigatoriaNoCasamento);
}

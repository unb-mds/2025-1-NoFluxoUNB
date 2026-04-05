/** Comparação de código de disciplina no histórico / sets (caixa e espaços). */
export function setHasCodeIgnoreCase(codes: Set<string>, code: string): boolean {
	if (codes.has(code)) return true;
	const codeUpper = (code || '').trim().toUpperCase();
	if (!codeUpper) return false;
	return [...codes].some((c) => c.trim().toUpperCase() === codeUpper);
}

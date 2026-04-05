/**
 * Telas estreitas (retrato) ou celular deitado: rolagem nativa + chrome tipo mobile (FAB),
 * mesmo quando a largura passa de 768px em landscape.
 */
export function matchesFluxogramCompactTouchMode(): boolean {
	if (typeof window === 'undefined') return false;
	return (
		window.matchMedia('(max-width: 768px)').matches ||
		window.matchMedia('(orientation: landscape) and (max-height: 560px)').matches
	);
}

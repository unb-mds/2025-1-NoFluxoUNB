/**
 * Queries canônicas do modo compacto do fluxograma — mantidas num único lugar
 * para JS (matchMedia) e store concordarem no mesmo pixel (Tailwind md = 768px,
 * então mobile é <= 767px).
 */
export const FLUXOGRAM_NARROW_QUERY = '(max-width: 767px)';
export const FLUXOGRAM_COMPACT_LANDSCAPE_QUERY =
	'(orientation: landscape) and (max-height: 560px)';

/**
 * Telas estreitas (retrato) ou celular deitado: rolagem nativa + chrome tipo mobile (FAB),
 * mesmo quando a largura passa de 767px em landscape.
 */
export function matchesFluxogramCompactTouchMode(): boolean {
	if (typeof window === 'undefined') return false;
	return (
		window.matchMedia(FLUXOGRAM_NARROW_QUERY).matches ||
		window.matchMedia(FLUXOGRAM_COMPACT_LANDSCAPE_QUERY).matches
	);
}

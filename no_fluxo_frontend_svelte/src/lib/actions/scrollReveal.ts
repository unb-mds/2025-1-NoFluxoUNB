import type { Action } from 'svelte/action';

interface ScrollRevealParams {
	delay?: number;
	threshold?: number;
	dy?: number;
	dx?: number;
	scale?: number;
}

export const scrollReveal: Action<HTMLElement, ScrollRevealParams | undefined> = (
	node,
	params
) => {
	if (typeof window === 'undefined' || typeof IntersectionObserver === 'undefined') return {};

	const { delay = 0, threshold = 0.12, dy = 22, dx = 0, scale = 1 } = params ?? {};

	if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return {};

	const translateParts: string[] = [];
	if (dx !== 0) translateParts.push(`translateX(${dx}px)`);
	if (dy !== 0) translateParts.push(`translateY(${dy}px)`);
	if (scale !== 1) translateParts.push(`scale(${scale})`);
	const initTransform = translateParts.length ? translateParts.join(' ') : 'none';

	node.style.opacity = '0';
	node.style.transform = initTransform;
	node.style.transition = [
		`opacity 0.42s cubic-bezier(0.16,1,0.3,1) ${delay}ms`,
		`transform 0.42s cubic-bezier(0.16,1,0.3,1) ${delay}ms`
	].join(', ');

	const observer = new IntersectionObserver(
		([entry]) => {
			if (entry?.isIntersecting) {
				node.style.opacity = '1';
				node.style.transform = 'none';
				observer.disconnect();
			}
		},
		{ threshold, rootMargin: '0px 0px -32px 0px' }
	);

	requestAnimationFrame(() => observer.observe(node));

	return { destroy: () => observer.disconnect() };
};

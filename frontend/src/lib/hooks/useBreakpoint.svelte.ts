import { browser } from '$app/environment';

export type Breakpoint = 'mobile' | 'tablet' | 'desktop' | 'wide';

const BREAKPOINTS = {
	mobile: 0,
	tablet: 640,
	desktop: 1024,
	wide: 1400
} as const;

function getBreakpoint(width: number): Breakpoint {
	if (width >= BREAKPOINTS.wide) return 'wide';
	if (width >= BREAKPOINTS.desktop) return 'desktop';
	if (width >= BREAKPOINTS.tablet) return 'tablet';
	return 'mobile';
}

export function useBreakpoint() {
	let width = $state(browser ? window.innerWidth : 1200);
	let height = $state(browser ? window.innerHeight : 800);

	$effect(() => {
		if (!browser) return;

		const handleResize = () => {
			width = window.innerWidth;
			height = window.innerHeight;
		};

		window.addEventListener('resize', handleResize);
		return () => window.removeEventListener('resize', handleResize);
	});

	const bp = $derived(getBreakpoint(width));

	return {
		get width() {
			return width;
		},
		get height() {
			return height;
		},
		get breakpoint() {
			return bp;
		},
		get isMobile() {
			return bp === 'mobile';
		},
		get isTablet() {
			return bp === 'tablet';
		},
		get isDesktop() {
			return bp === 'desktop' || bp === 'wide';
		},
		get isWide() {
			return bp === 'wide';
		}
	};
}

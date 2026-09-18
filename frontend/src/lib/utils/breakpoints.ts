import { browser } from '$app/environment';

export const breakpoints = {
	sm: 640,
	md: 768,
	lg: 1024,
	xl: 1280,
	'2xl': 1536
} as const;

export function getIsMobile(): boolean {
	if (!browser) return false;
	return window.innerWidth < breakpoints.md;
}

export function getIsTablet(): boolean {
	if (!browser) return false;
	return window.innerWidth >= breakpoints.md && window.innerWidth < breakpoints.lg;
}

export function getIsDesktop(): boolean {
	if (!browser) return false;
	return window.innerWidth >= breakpoints.lg;
}

import { browser } from '$app/environment';

export function useMediaQuery(query: string) {
	let matches = $state(false);

	$effect(() => {
		if (!browser) return;

		const mediaQuery = window.matchMedia(query);
		matches = mediaQuery.matches;

		const handler = (e: MediaQueryListEvent) => {
			matches = e.matches;
		};

		mediaQuery.addEventListener('change', handler);
		return () => mediaQuery.removeEventListener('change', handler);
	});

	return {
		get matches() {
			return matches;
		}
	};
}

export function useIsMobile() {
	return useMediaQuery('(max-width: 767px)');
}

export function useIsDesktop() {
	return useMediaQuery('(min-width: 1024px)');
}

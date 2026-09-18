import { browser } from '$app/environment';
import { writable } from 'svelte/store';

type Theme = 'light' | 'dark' | 'system';

function getInitialTheme(): Theme {
	if (!browser) return 'dark';
	const stored = localStorage.getItem('theme') as Theme | null;
	if (stored && ['light', 'dark', 'system'].includes(stored)) {
		return stored;
	}
	return 'dark';
}

function getSystemTheme(): 'light' | 'dark' {
	if (!browser) return 'dark';
	return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function createThemeStore() {
	const { subscribe, set, update } = writable<Theme>(getInitialTheme());
	let currentTheme: Theme = getInitialTheme();

	subscribe((value) => {
		currentTheme = value;
	});

	function applyTheme(theme: Theme) {
		if (!browser) return;
		const effectiveTheme = theme === 'system' ? getSystemTheme() : theme;
		document.documentElement.classList.remove('light', 'dark');
		document.documentElement.classList.add(effectiveTheme);
		localStorage.setItem('theme', theme);
	}

	if (browser) {
		const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
		mediaQuery.addEventListener('change', () => {
			if (currentTheme === 'system') {
				applyTheme('system');
			}
		});
		applyTheme(getInitialTheme());
	}

	return {
		subscribe,
		set: (theme: Theme) => {
			set(theme);
			applyTheme(theme);
		},
		toggle: () => {
			update((current) => {
				const newTheme = current === 'dark' ? 'light' : 'dark';
				applyTheme(newTheme);
				return newTheme;
			});
		},
		setSystem: () => {
			set('system');
			applyTheme('system');
		}
	};
}

export const theme = createThemeStore();

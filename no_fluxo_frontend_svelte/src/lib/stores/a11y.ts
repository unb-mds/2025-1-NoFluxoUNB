import { writable, get } from 'svelte/store';
import { browser } from '$app/environment';

// Decisao: usar writable (svelte/store) em vez de $state runes para compatibilidade
// ampla com codigo legacy e facilidade de subscribe externa.

export interface A11ySettings {
	highContrast: boolean;
	reducedMotion: boolean;
	largeText: boolean;
	dyslexicFont: boolean;
	focusBold: boolean;
}

const STORAGE_KEY = 'nofluxo_a11y';

const DEFAULTS: A11ySettings = {
	highContrast: false,
	reducedMotion: false,
	largeText: false,
	dyslexicFont: false,
	focusBold: false
};

const CLASS_MAP: Record<keyof A11ySettings, string> = {
	highContrast: 'a11y-high-contrast',
	reducedMotion: 'a11y-reduced-motion',
	largeText: 'a11y-large-text',
	dyslexicFont: 'a11y-dyslexic',
	focusBold: 'a11y-focus-bold'
};

function loadInitial(): A11ySettings {
	if (!browser) return { ...DEFAULTS };
	try {
		const raw = localStorage.getItem(STORAGE_KEY);
		if (raw) {
			const parsed = JSON.parse(raw);
			return { ...DEFAULTS, ...parsed };
		}
	} catch {
		// ignore corrupt storage
	}
	// Nada salvo: respeitar preferencia do SO para reduced motion.
	const prefersReduced =
		typeof window !== 'undefined' &&
		typeof window.matchMedia === 'function' &&
		window.matchMedia('(prefers-reduced-motion: reduce)').matches;
	return { ...DEFAULTS, reducedMotion: prefersReduced };
}

export const a11ySettings = writable<A11ySettings>(loadInitial());

// Persistencia automatica
if (browser) {
	a11ySettings.subscribe((value) => {
		try {
			localStorage.setItem(STORAGE_KEY, JSON.stringify(value));
		} catch {
			// quota / privacy mode: ignorar
		}
	});
}

export function applyA11yClasses(s: A11ySettings): void {
	if (!browser) return;
	const root = document.documentElement;
	(Object.keys(CLASS_MAP) as (keyof A11ySettings)[]).forEach((key) => {
		const cls = CLASS_MAP[key];
		if (s[key]) root.classList.add(cls);
		else root.classList.remove(cls);
	});
}

export function resetA11y(): void {
	a11ySettings.set({ ...DEFAULTS });
}

// Helper: aplica imediatamente o estado atual e assina mudancas futuras.
// Retorna funcao para cancelar a subscricao.
export function subscribeAndApply(): () => void {
	if (!browser) return () => {};
	applyA11yClasses(get(a11ySettings));
	return a11ySettings.subscribe(applyA11yClasses);
}

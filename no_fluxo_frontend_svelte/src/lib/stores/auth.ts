import { writable, derived, get } from 'svelte/store';
import { browser } from '$app/environment';
import type { AuthState, UserModel } from '$lib/types/auth';

const STORAGE_KEY = 'nofluxo_user';
const ANON_KEY = 'nofluxo_anonimo';

// Initialize state from localStorage if available
function getInitialState(): AuthState {
	if (browser) {
		const storedUser = localStorage.getItem(STORAGE_KEY);
		const isAnonymous = localStorage.getItem(ANON_KEY) === 'true';

		if (storedUser && storedUser !== 'null') {
			try {
				const rawUser = JSON.parse(storedUser);
				// Handle both old snake_case and new camelCase formats from localStorage
				const user: UserModel = rawUser.idUser !== undefined ? rawUser : {
					idUser: rawUser.id_user ?? 0,
					email: rawUser.email ?? '',
					nomeCompleto: rawUser.nome_completo ?? '',
					token: rawUser.token ?? null,
					dadosFluxograma: rawUser.dados_fluxograma ?? null
				};
				return {
					user,
					isAuthenticated: true,
					isAnonymous: false,
					isLoading: false,
					error: null
				};
			} catch {
				localStorage.removeItem(STORAGE_KEY);
			}
		}

		if (isAnonymous) {
			return {
				user: null,
				isAuthenticated: false,
				isAnonymous: true,
				isLoading: false,
				error: null
			};
		}
	}

	return {
		user: null,
		isAuthenticated: false,
		isAnonymous: false,
		isLoading: true,
		error: null
	};
}

function createAuthStore() {
	const { subscribe, set, update } = writable<AuthState>(getInitialState());

	return {
		subscribe,

		setUser(user: UserModel | null) {
			if (browser) {
				if (user) {
					localStorage.setItem(STORAGE_KEY, JSON.stringify(user));
					localStorage.removeItem(ANON_KEY);
				} else {
					localStorage.removeItem(STORAGE_KEY);
				}
			}

			update((state) => ({
				...state,
				user,
				isAuthenticated: !!user,
				isAnonymous: false,
				isLoading: false,
				error: null
			}));
		},

		setAnonymous(value: boolean) {
			if (browser) {
				if (value) {
					localStorage.setItem(ANON_KEY, 'true');
					localStorage.removeItem(STORAGE_KEY);
				} else {
					localStorage.removeItem(ANON_KEY);
				}
			}

			update((state) => ({
				...state,
				user: null,
				isAuthenticated: false,
				isAnonymous: value,
				isLoading: false,
				error: null
			}));
		},

		setLoading(isLoading: boolean) {
			update((state) => ({ ...state, isLoading }));
		},

		setError(error: string | null) {
			update((state) => ({ ...state, error, isLoading: false }));
		},

		updateToken(token: string) {
			update((state) => {
				if (state.user) {
					const updatedUser = { ...state.user, token };
					if (browser) {
						localStorage.setItem(STORAGE_KEY, JSON.stringify(updatedUser));
					}
					return { ...state, user: updatedUser };
				}
				return state;
			});
		},

		updateDadosFluxograma(dados: UserModel['dadosFluxograma']) {
			update((state) => {
				if (state.user) {
					const updatedUser = { ...state.user, dadosFluxograma: dados };
					if (browser) {
						localStorage.setItem(STORAGE_KEY, JSON.stringify(updatedUser));
					}
					return { ...state, user: updatedUser };
				}
				return state;
			});
		},

		clear() {
			if (browser) {
				localStorage.removeItem(STORAGE_KEY);
				localStorage.removeItem(ANON_KEY);
				// Remove anonymous cookie
				document.cookie = 'nofluxo_anonimo=; path=/; max-age=0';
			}
			set({
				user: null,
				isAuthenticated: false,
				isAnonymous: false,
				isLoading: false,
				error: null
			});
		},

		getUser(): UserModel | null {
			return get({ subscribe }).user;
		},

		isLoggedIn(): boolean {
			const state = get({ subscribe });
			return state.isAuthenticated || state.isAnonymous;
		}
	};
}

export const authStore = createAuthStore();

// Derived stores for convenience
export const currentUser = derived(authStore, ($auth) => $auth.user);
export const isAuthenticated = derived(authStore, ($auth) => $auth.isAuthenticated);
export const isAnonymous = derived(authStore, ($auth) => $auth.isAnonymous);
export const isLoading = derived(authStore, ($auth) => $auth.isLoading);
export const authError = derived(authStore, ($auth) => $auth.error);

import { browser } from '$app/environment';
import { goto } from '$app/navigation';
import { get } from 'svelte/store';
import { authStore } from '$lib/stores/auth';
import { authService } from '$lib/services/auth.service';
import { requiresAdmin, requiredAdminScope } from '$lib/config/routes';
import { hasAdminScope } from '$lib/types/user';

const PUBLIC_ROUTES_EXACT = [
	'/',
	'/home',
	'/login',
	'/signup',
	'/password-recovery',
	'/login-anonimo',
	'/auth/callback',
	'/auth/reset-password',
	'/termos',
	'/privacidade'
];

/** Rotas públicas por prefixo: qualquer path que comece com um deles é público (ex: /fluxogramas, /meu-fluxograma/Engenharia). */
const PUBLIC_ROUTES_PREFIX = ['/fluxogramas', '/disciplinas', '/meu-fluxograma'];

export function isPublicRoute(path: string): boolean {
	const normalized = path.replace(/\/+$/, '') || '/';
	if (PUBLIC_ROUTES_EXACT.includes(normalized)) return true;
	return PUBLIC_ROUTES_PREFIX.some((prefix) => path === prefix || path.startsWith(prefix + '/'));
}

/**
 * Check if user should be redirected.
 * This is the sole auth guard — no server-side hooks.server.ts.
 */
export async function checkAuth(path: string): Promise<boolean> {
	if (!browser) return true;

	if (isPublicRoute(path)) return true;

	const state = get(authStore);

	// Allow anonymous users
	if (state.isAnonymous) return true;

	// D9/D10 (Alto, transversal): antes, qualquer rota privada acessada antes do
	// bootstrap (state.isLoading=true) era liberada implicitamente, expondo a tela
	// por alguns segundos enquanto a sessão era buscada. Agora aguardamos o boot
	// terminar antes de decidir — bloquear é o default seguro.
	if (state.isLoading) {
		const start = Date.now();
		while (Date.now() - start < 3000) {
			const s = get(authStore);
			if (!s.isLoading) break;
			await new Promise((r) => setTimeout(r, 50));
		}
	}

	// Re-leitura do estado após o wait
	const settled = get(authStore);
	if (settled.isAnonymous) return true;

	// Check if authenticated
	if (settled.isAuthenticated && settled.user) {
		// Verify session is still valid (covers expiry check previously in hooks.server.ts)
		const isValid = await authService.isSessionValid();
		if (!isValid) {
			await authService.signOut();
			await goto('/login?error=session_expired');
			return false;
		}

		// Rotas admin: exige o escopo correspondente (superadmin passa sempre)
		if (requiresAdmin(path)) {
			const scope = requiredAdminScope(path);
			if (!scope || !hasAdminScope(settled.user, scope)) {
				await goto('/suporte?error=access_denied');
				return false;
			}
		}

		return true;
	}

	// Not authenticated, redirect to login
	await goto(`/login?redirect=${encodeURIComponent(path)}`);
	return false;
}

/**
 * Guard for pages that should redirect logged-in users
 * (e.g., login page should redirect to home if already logged in)
 */
export async function checkAlreadyAuthenticated(redirectTo = '/upload-historico'): Promise<boolean> {
	if (!browser) return false;

	const state = get(authStore);

	if (state.isAuthenticated || state.isAnonymous) {
		await goto(redirectTo);
		return true;
	}

	return false;
}

import { browser } from '$app/environment';
import { goto } from '$app/navigation';
import { get } from 'svelte/store';
import { authStore } from '$lib/stores/auth';
import { authService } from '$lib/services/auth.service';

const PUBLIC_ROUTES = [
	'/',
	'/home',
	'/login',
	'/signup',
	'/password-recovery',
	'/login-anonimo',
	'/auth/callback',
	'/auth/reset-password'
];

export function isPublicRoute(path: string): boolean {
	return PUBLIC_ROUTES.includes(path);
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

	// Still loading auth state — let the layout spinner handle it
	if (state.isLoading) return true;

	// Check if authenticated
	if (state.isAuthenticated && state.user) {
		// Verify session is still valid (covers expiry check previously in hooks.server.ts)
		const isValid = await authService.isSessionValid();
		if (isValid) return true;

		// Session expired — sign out and redirect
		await authService.signOut();
		await goto('/login?error=session_expired');
		return false;
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

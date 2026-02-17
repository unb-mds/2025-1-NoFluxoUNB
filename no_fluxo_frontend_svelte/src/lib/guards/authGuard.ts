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
 * Check if user should be redirected
 * Call this in +layout.svelte or individual pages
 */
export async function checkAuth(path: string): Promise<boolean> {
	if (!browser) return true;

	if (isPublicRoute(path)) return true;

	const state = get(authStore);

	// Allow anonymous users
	if (state.isAnonymous) return true;

	// Check if authenticated
	if (state.isAuthenticated && state.user) {
		// Verify session is still valid
		const isValid = await authService.isSessionValid();
		if (isValid) return true;
	}

	// Not authenticated, redirect to login
	await goto(`/login?redirect=${encodeURIComponent(path)}`);
	return false;
}

/**
 * Guard for pages that should redirect logged-in users
 * (e.g., login page should redirect to home if already logged in)
 */
export async function checkAlreadyAuthenticated(redirectTo = '/fluxogramas'): Promise<boolean> {
	if (!browser) return false;

	const state = get(authStore);

	if (state.isAuthenticated || state.isAnonymous) {
		await goto(redirectTo);
		return true;
	}

	return false;
}

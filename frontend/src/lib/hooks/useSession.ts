import { onMount, onDestroy } from 'svelte';
import { authService } from '$lib/services/auth.service';
import { authStore } from '$lib/stores/auth';

/**
 * Hook to manage session refresh.
 * Call this in a root layout or component that's always mounted.
 */
export function useSession() {
	let refreshInterval: ReturnType<typeof setInterval>;
	let subscription: { unsubscribe: () => void } | null = null;

	onMount(() => {
		// Refresh session every 10 minutes to keep token fresh
		refreshInterval = setInterval(
			async () => {
				const session = await authService.refreshSession();
				if (!session) {
					// Session expired or invalid
					authStore.clear();
				}
			},
			10 * 60 * 1000
		); // 10 minutes

		// Listen to auth state changes
		const { data } = authService.onAuthStateChange((event, session) => {
			if (event === 'SIGNED_OUT') {
				authStore.clear();
			} else if (event === 'TOKEN_REFRESHED' && session?.access_token) {
				authStore.updateToken(session.access_token);
			}
		});

		subscription = data.subscription;
	});

	onDestroy(() => {
		if (refreshInterval) {
			clearInterval(refreshInterval);
		}
		if (subscription) {
			subscription.unsubscribe();
		}
	});
}

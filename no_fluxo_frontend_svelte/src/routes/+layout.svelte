<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { browser } from '$app/environment';
	import { authStore, isLoading, currentUser, isAuthenticated } from '$lib/stores/auth';
	import { authService } from '$lib/services/auth.service';
	import { checkAuth, isPublicRoute } from '$lib/guards/authGuard';
	import { isAuthRoute } from '$lib/config/routes';
	import Navbar from '$lib/components/layout/Navbar.svelte';
	import Footer from '$lib/components/layout/Footer.svelte';
	import LoadingBar from '$lib/components/layout/LoadingBar.svelte';
	import { Toaster } from 'svelte-sonner';
	import '../app.css';

	let { children } = $props();

	// Determine layout visibility based on current route
	let showNavbar = $derived(
		!isAuthRoute($page.url.pathname) && $page.url.pathname !== '/'
	);
	let showFooter = $derived(false);

	// Watch for route changes and verify auth
	$effect(() => {
		if (browser && $page.url.pathname) {
			checkAuth($page.url.pathname);
		}
	});

	onMount(() => {
		// Set up auth state listener
		const {
			data: { subscription }
		} = authService.onAuthStateChange(async (event, session) => {
			console.log('Auth state changed:', event);

			if (event === 'SIGNED_OUT') {
				authStore.clear();
			} else if (event === 'SIGNED_IN' && session?.user?.email) {
				const currentUser = authStore.getUser();
				if (!currentUser) {
					const result = await authService.databaseSearchUser(session.user.email);
					if (result.success) {
						authStore.setUser(result.user);
					}
				}
			} else if (event === 'TOKEN_REFRESHED' && session?.access_token) {
				authStore.updateToken(session.access_token);
			}
		});

		// Initial session check
		authService.getSession().then(async (session) => {
			if (session?.user?.email) {
				const result = await authService.databaseSearchUser(session.user.email);
				if (result.success) {
					authStore.setUser(result.user);
				} else {
					authStore.setLoading(false);
				}
			} else {
				authStore.setLoading(false);
			}
		});

		return () => {
			subscription.unsubscribe();
		};
	});
</script>

<svelte:head>
	<title>NoFluxo UNB</title>
</svelte:head>

<LoadingBar />

<div class="flex min-h-screen flex-col">
	{#if showNavbar}
		<Navbar user={$currentUser} isAuthenticated={$isAuthenticated} />
	{/if}

	<main class="flex-1">
		{#if $isLoading && !isPublicRoute($page.url.pathname)}
			<div class="flex min-h-[60vh] items-center justify-center">
				<div class="text-center">
					<div class="mx-auto h-12 w-12 animate-spin rounded-full border-4 border-white/10 border-t-purple-500"></div>
					<p class="mt-4 text-gray-400">Carregando...</p>
				</div>
			</div>
		{:else}
			{@render children()}
		{/if}
	</main>

	{#if showFooter}
		<Footer />
	{/if}
</div>

<Toaster richColors position="top-right" />

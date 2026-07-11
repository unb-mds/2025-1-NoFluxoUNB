import type { PageLoad } from './$types';
import { redirect } from '@sveltejs/kit';
import { browser } from '$app/environment';
import { get } from 'svelte/store';
import { authStore } from '$lib/stores/auth';
import { authService } from '$lib/services/auth.service';

export const ssr = false;
export const prerender = false;

export const load: PageLoad = async () => {
	if (!browser) return {};

	await authService.ensureSessionBootstrapped();

	if (!get(authStore).user?.dadosFluxograma) {
		throw redirect(303, '/upload-historico');
	}

	return {};
};

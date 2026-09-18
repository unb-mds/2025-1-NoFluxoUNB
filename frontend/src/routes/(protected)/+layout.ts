import type { LayoutLoad } from './$types';
import { guardProtectedRoute } from '$lib/guards/authGuard';

export const ssr = false;
export const prerender = false;

export const load: LayoutLoad = async ({ url }) => {
	await guardProtectedRoute(url);
	return {};
};

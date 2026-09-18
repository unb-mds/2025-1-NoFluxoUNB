import { error } from '@sveltejs/kit';
import { config } from '$lib/config';

export const ssr = false;

export function load() {
	if (config.isProd || !import.meta.env.DEV) {
		throw error(404, 'Not Found');
	}
	return {};
}

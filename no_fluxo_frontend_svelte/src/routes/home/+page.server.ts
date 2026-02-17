import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

// Redirect /home to / (matching Flutter behavior)
export const load: PageServerLoad = async () => {
	redirect(301, '/');
};

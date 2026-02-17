import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ url, locals }) => {
	const code = url.searchParams.get('code');
	const next = url.searchParams.get('next') || '/fluxogramas';

	if (code) {
		const { error } = await locals.supabase.auth.exchangeCodeForSession(code);

		if (error) {
			console.error('OAuth callback error:', error);
			throw redirect(303, `/login?error=${encodeURIComponent(error.message)}`);
		}
	}

	throw redirect(303, next);
};

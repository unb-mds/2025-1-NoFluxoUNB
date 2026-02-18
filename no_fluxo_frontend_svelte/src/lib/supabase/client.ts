import { createBrowserClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

/**
 * Create a Supabase client for use in the browser (client-side only).
 * For server-side, use the client from event.locals.supabase.
 */
export function createSupabaseBrowserClient() {
	return createBrowserClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY);
}

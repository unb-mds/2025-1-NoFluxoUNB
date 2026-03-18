import { createBrowserClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';
import { browser } from '$app/environment';

/**
 * Create a Supabase client for use in the browser with cookie-based storage.
 * This ensures PKCE code verifier persists across OAuth redirects.
 * During SSR/prerendering, returns a stub to avoid errors when env vars are empty.
 */
export function createSupabaseBrowserClient() {
	if (!browser && (!PUBLIC_SUPABASE_URL || !PUBLIC_SUPABASE_ANON_KEY)) {
		// During SSR/prerendering with missing env vars, return a no-op stub
		const stub = new Proxy({} as any, {
			get: () => stub,
			apply: () => stub
		});
		return stub as ReturnType<typeof createBrowserClient>;
	}

	return createBrowserClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
		cookies: {
			getAll() {
				return document.cookie
					.split(';')
					.map(cookie => cookie.trim())
					.filter(cookie => cookie.length > 0)
					.map(cookie => {
						const [name, ...rest] = cookie.split('=');
						const value = rest.join('=');
						return { name: name.trim(), value: value || '' };
					});
			},
			setAll(cookiesToSet) {
				cookiesToSet.forEach(({ name, value, options }) => {
					const cookieOptions = {
						path: '/',
						maxAge: 60 * 60 * 24 * 7, // 7 days
						sameSite: 'lax',
						secure: window.location.protocol === 'https:',
						...options
					};

					let cookieString = `${name}=${value}`;
					
					if (cookieOptions.maxAge !== undefined) {
						cookieString += `; Max-Age=${cookieOptions.maxAge}`;
					}
					if (cookieOptions.path) {
						cookieString += `; Path=${cookieOptions.path}`;
					}
					if (cookieOptions.sameSite) {
						cookieString += `; SameSite=${cookieOptions.sameSite}`;
					}
					if (cookieOptions.secure) {
						cookieString += '; Secure';
					}

					document.cookie = cookieString;
				});
			}
		},
		cookieOptions: {
			name: 'sb-auth-token',
			maxAge: 60 * 60 * 24 * 7, // 7 days
			path: '/',
			sameSite: 'lax'
		}
	});
}

import { createServerClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';
import { redirect, type Handle } from '@sveltejs/kit';

// Routes that don't require authentication
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

function isPublicRoute(path: string): boolean {
	return PUBLIC_ROUTES.some((route) => {
		if (route === path) return true;
		if (route.endsWith('*') && path.startsWith(route.slice(0, -1))) return true;
		return false;
	});
}

export const handle: Handle = async ({ event, resolve }) => {
	// Create Supabase server client
	event.locals.supabase = createServerClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
		cookies: {
			getAll: () => event.cookies.getAll(),
			setAll: (cookiesToSet) => {
				cookiesToSet.forEach(({ name, value, options }) => {
					event.cookies.set(name, value, { ...options, path: '/' });
				});
			}
		}
	});

	// Session helpers
	event.locals.getSession = async () => {
		const {
			data: { session }
		} = await event.locals.supabase.auth.getSession();
		return session;
	};

	event.locals.getUser = async () => {
		const {
			data: { user }
		} = await event.locals.supabase.auth.getUser();
		return user;
	};

	const path = event.url.pathname;

	// Skip auth check for public routes, static assets, and API routes
	if (isPublicRoute(path) || path.startsWith('/_app') || path.startsWith('/api')) {
		return resolve(event, {
			filterSerializedResponseHeaders(name) {
				return name === 'content-range' || name === 'x-supabase-api-version';
			}
		});
	}

	// Check for anonymous session (stored in cookie)
	const isAnonymous = event.cookies.get('nofluxo_anonimo') === 'true';

	if (isAnonymous) {
		return resolve(event, {
			filterSerializedResponseHeaders(name) {
				return name === 'content-range' || name === 'x-supabase-api-version';
			}
		});
	}

	// Verify session for protected routes
	const session = await event.locals.getSession();

	if (!session) {
		const redirectUrl = `/login?redirect=${encodeURIComponent(path)}`;
		throw redirect(303, redirectUrl);
	}

	// Verify session hasn't expired
	if (session.expires_at && Date.now() > session.expires_at * 1000) {
		await event.locals.supabase.auth.signOut();
		throw redirect(303, '/login?error=session_expired');
	}

	return resolve(event, {
		filterSerializedResponseHeaders(name) {
			return name === 'content-range' || name === 'x-supabase-api-version';
		}
	});
};

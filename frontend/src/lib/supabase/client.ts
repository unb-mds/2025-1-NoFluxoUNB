import { createBrowserClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

/**
 * Instância única do browser, memoizada.
 *
 * Cada `createBrowserClient` monta um `GoTrueClient` próprio, e todos disputam o
 * MESMO lock exclusivo do Navigator LockManager (`lock:sb-auth-token`) para
 * renovar o token. Com uma instância por serviço — o app chegou a catorze —, os
 * perdedores da corrida estouram
 * `Acquiring an exclusive Navigator LockManager lock ... immediately failed`
 * no console, e o refresh de sessão passa a depender de qual cliente ganhou.
 * O próprio Supabase avisa contra múltiplos GoTrueClient no mesmo contexto.
 *
 * Só memoiza no browser: no SSR cada requisição precisa do seu próprio cliente,
 * senão a sessão de um usuário vazaria para a requisição de outro.
 */
let clienteDoBrowser: ReturnType<typeof criarCliente> | null = null;

/**
 * Create a Supabase client for use in the browser with cookie-based storage.
 * This ensures PKCE code verifier persists across OAuth redirects.
 *
 * Devolve sempre a MESMA instância no browser — ver `clienteDoBrowser`.
 */
export function createSupabaseBrowserClient() {
	if (clienteDoBrowser) return clienteDoBrowser;

	const cliente = criarCliente();
	if (typeof window !== 'undefined') clienteDoBrowser = cliente;
	return cliente;
}

/**
 * A construção em si, separada só para o tipo do cliente memoizado ser inferido
 * daqui. Anotar `ReturnType<typeof createBrowserClient>` na variável instancia os
 * genéricos com os defaults e apaga a tipagem do schema, o que espalha
 * `implicitly has an 'any' type` por todos os consumidores.
 */
function criarCliente() {
	return createBrowserClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
		cookies: {
			getAll() {
				if (typeof document === 'undefined') {
					return [];
				}
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
				if (typeof document === 'undefined') {
					return;
				}
				cookiesToSet.forEach(({ name, value, options }) => {
					const cookieOptions = {
						path: '/',
						maxAge: 60 * 60 * 24 * 7, // 7 days
						sameSite: 'lax',
						secure: typeof window !== 'undefined' && window.location.protocol === 'https:',
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

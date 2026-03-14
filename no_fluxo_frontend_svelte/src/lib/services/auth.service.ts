import { createSupabaseBrowserClient } from '$lib/supabase/client';
import { authStore } from '$lib/stores/auth';
import type { UserModel } from '$lib/types';
import { createUserModelFromJson } from '$lib/factories';
import { parseAuthError } from '$lib/types/errors';
import type { User, Session } from '@supabase/supabase-js';

export class AuthService {
	private supabase = createSupabaseBrowserClient();

	/**
	 * Search for user in database — DIRECT SUPABASE QUERY
	 * REPLACES: GET /users/get-user-by-email
	 */
	async databaseSearchUser(): Promise<
		{ success: true; user: UserModel } | { success: false; error: string }
	> {
		try {
			const { data: authUser } = await this.supabase.auth.getUser();
			if (!authUser.user) {
				return { success: false, error: 'Not authenticated' };
			}

			const { data, error } = await this.supabase
				.from('users')
				.select('*, dados_users(*)')
				.eq('auth_id', authUser.user.id)
				.maybeSingle();

			if (error || !data) {
				return { success: false, error: error?.message || 'User not found' };
			}

			const user = createUserModelFromJson(data as Record<string, unknown>);
			user.token = (await this.supabase.auth.getSession()).data.session?.access_token ?? null;
			return { success: true, user };
		} catch (error) {
			console.error('databaseSearchUser error:', error);
			return { success: false, error: String(error) };
		}
	}

	/**
	 * Register user in database — DIRECT SUPABASE INSERT
	 * REPLACES: POST /users/register-user-with-google
	 * REPLACES: POST /users/registrar-user-with-email
	 */
	async databaseRegisterUser(
		email: string,
		nomeCompleto: string
	): Promise<{ success: true; user: UserModel } | { success: false; error: string }> {
		try {
			const { data: authUser } = await this.supabase.auth.getUser();
			if (!authUser.user) {
				return { success: false, error: 'Not authenticated' };
			}

			const { data, error } = await this.supabase
				.from('users')
				.insert({
					email,
					nome_completo: nomeCompleto,
					auth_id: authUser.user.id
				})
				.select()
				.single();

			if (error) {
				// User already exists (unique constraint on auth_id or email)
				if (error.code === '23505') {
					return this.databaseSearchUser();
				}
				// RLS ou permissão — mensagem mais clara
				const friendlyMessage =
					error.message?.includes('row-level security') ||
					error.message?.includes('policy') ||
					error.code === '42501'
						? 'Não foi possível criar sua conta. Tente novamente ou contate o suporte.'
						: error.message;
				console.error('databaseRegisterUser error:', error.code, error.message);
				return { success: false, error: friendlyMessage };
			}

			const user = createUserModelFromJson(data as Record<string, unknown>);
			user.token = (await this.supabase.auth.getSession()).data.session?.access_token ?? null;
			return { success: true, user };
		} catch (error) {
			console.error('databaseRegisterUser error:', error);
			return { success: false, error: String(error) };
		}
	}

	/**
	 * Sign up with email and password
	 */
	async signUp(
		email: string,
		password: string,
		displayName?: string
	): Promise<{ success: true; user: User } | { success: false; error: string }> {
		try {
			authStore.setLoading(true);

			const { data, error } = await this.supabase.auth.signUp({
				email,
				password,
				options: {
					data: displayName ? { display_name: displayName } : undefined
				}
			});

			if (error) {
				const msg = parseAuthError(error).message;
				authStore.setError(msg);
				return { success: false, error: msg };
			}

			if (!data.user) {
				const msg = 'Erro ao criar conta. Tente novamente.';
				authStore.setError(msg);
				return { success: false, error: msg };
			}

			// Register in database (direct Supabase insert)
			const dbResult = await this.databaseRegisterUser(
				email,
				displayName || email.split('@')[0]
			);

			if (!dbResult.success) {
				// Rollback: sign out from Supabase
				await this.supabase.auth.signOut();
				const msg = parseAuthError(dbResult.error).message;
				authStore.setError(msg);
				return { success: false, error: msg };
			}

			authStore.setUser(dbResult.user);
			return { success: true, user: data.user };
		} catch (error) {
			const msg = parseAuthError(error).message;
			authStore.setError(msg);
			return { success: false, error: msg };
		}
	}

	/**
	 * Sign in with email and password
	 */
	async signIn(
		email: string,
		password: string
	): Promise<{ success: true; user: UserModel } | { success: false; error: string }> {
		try {
			authStore.setLoading(true);

			const { data, error } = await this.supabase.auth.signInWithPassword({
				email,
				password
			});

			if (error) {
				const msg = parseAuthError(error).message;
				authStore.setError(msg);
				return { success: false, error: msg };
			}

			if (!data.user) {
				const msg = 'Email ou senha inválidos';
				authStore.setError(msg);
				return { success: false, error: msg };
			}

			// Fetch user from database (direct Supabase query)
			const result = await this.databaseSearchUser();

			if (!result.success) {
				authStore.setError(
					'Usuário autenticado, mas não encontrado no banco de dados interno. Contate o suporte.'
				);
				return {
					success: false,
					error:
						'Usuário autenticado, mas não encontrado no banco de dados interno. Contate o suporte.'
				};
			}

			authStore.setUser(result.user);
			return { success: true, user: result.user };
		} catch (error) {
			const msg = parseAuthError(error).message;
			authStore.setError(msg);
			return { success: false, error: msg };
		}
	}

	/**
	 * Sign in with Google OAuth
	 */
	async signInWithGoogle(redirectTo?: string): Promise<void> {
		const { error } = await this.supabase.auth.signInWithOAuth({
			provider: 'google',
			options: {
				redirectTo: redirectTo || `${window.location.origin}/auth/callback`,
				queryParams: {
					prompt: 'consent'
				}
			}
		});

		if (error) {
			const msg = parseAuthError(error).message;
			authStore.setError(msg);
			throw error;
		}
	}

	/**
	 * Exchange OAuth code for session and then handle callback (register/lookup user).
	 * Use this on the /auth/callback page so the same client that did the exchange is used for getSession and DB — fixes new-user Google login.
	 */
	async exchangeCodeForSessionAndHandleCallback(
		code: string
	): Promise<{ success: true; user: UserModel } | { success: false; error: string }> {
		try {
			const { data, error: exchangeError } = await this.supabase.auth.exchangeCodeForSession(code);

			if (exchangeError) {
				// Se for erro de PKCE code verifier, tentar fallback com getSession
				if (exchangeError.message?.includes('code verifier') || exchangeError.message?.includes('PKCE')) {
					console.warn('PKCE code verifier not found, trying fallback with getSession');
					return this.handleOAuthCallback();
				}
				
				authStore.setError(parseAuthError(exchangeError).message);
				return { success: false, error: parseAuthError(exchangeError).message };
			}

			// Passa a sessão do exchange para não depender de getUser() logo em seguida (evita race em novos usuários)
			return this.handleOAuthCallback(data.session ?? undefined);
		} catch (error) {
			const errorMessage = error instanceof Error ? error.message : String(error);
			
			// Se for erro de PKCE, tentar fallback
			if (errorMessage.includes('code verifier') || errorMessage.includes('PKCE')) {
				console.warn('PKCE exchange failed, trying fallback with getSession');
				return this.handleOAuthCallback();
			}
			
			authStore.setError(parseAuthError(errorMessage).message);
			return { success: false, error: parseAuthError(errorMessage).message };
		}
	}

	/**
	 * Handle OAuth callback and sync with backend.
	 * @param sessionOptional Se vier do exchangeCodeForSession, usa essa sessão; senão chama getUser().
	 */
	async handleOAuthCallback(sessionOptional?: Session): Promise<
		{ success: true; user: UserModel } | { success: false; error: string }
	> {
		try {
			authStore.setLoading(true);

			let email: string;
			let displayName: string;

			if (sessionOptional?.user?.email) {
				email = sessionOptional.user.email;
				displayName =
					sessionOptional.user.user_metadata?.name ||
					sessionOptional.user.user_metadata?.full_name ||
					'';
			} else {
				const { data: authData, error: userError } = await this.supabase.auth.getUser();
				if (userError || !authData?.user?.email) {
					const msg = parseAuthError(userError ?? new Error('Sessão inválida ou usuário sem e-mail')).message;
					authStore.setError(msg);
					return { success: false, error: msg };
				}
				email = authData.user.email;
				displayName =
					authData.user.user_metadata?.name ||
					authData.user.user_metadata?.full_name ||
					'';
			}

			// Tentar encontrar usuário no banco; se não existir (novo usuário Google), registrar
			let result = await this.databaseSearchUser();

			if (!result.success) {
				result = await this.databaseRegisterUser(email, displayName);
			}

			if (result.success) {
				authStore.setUser(result.user);
				return { success: true, user: result.user };
			}

			const msg = parseAuthError(result.error).message;
			authStore.setError(msg);
			return { success: false, error: msg };
		} catch (error) {
			const msg = parseAuthError(error).message;
			authStore.setError(msg);
			return { success: false, error: msg };
		}
	}

	/**
	 * Set anonymous login state
	 */
	setAnonymous(): void {
		authStore.setAnonymous(true);
	}

	/**
	 * Sign out
	 */
	async signOut(): Promise<void> {
		try {
			await this.supabase.auth.signOut();
			authStore.clear();
		} catch (error) {
			console.error('Sign out error:', error);
			// Clear local state even if Supabase signout fails
			authStore.clear();
		}
	}

	/**
	 * Get current session
	 */
	async getSession(): Promise<Session | null> {
		const {
			data: { session }
		} = await this.supabase.auth.getSession();
		return session;
	}

	/**
	 * Get current user from Supabase
	 */
	async getCurrentUser(): Promise<User | null> {
		const {
			data: { user }
		} = await this.supabase.auth.getUser();
		return user;
	}

	/**
	 * Check if session is valid and not expired
	 */
	async isSessionValid(): Promise<boolean> {
		const session = await this.getSession();

		if (!session) return false;

		if (session.expires_at) {
			const expiresAt = new Date(session.expires_at * 1000);
			if (new Date() > expiresAt) {
				await this.signOut();
				return false;
			}
		}

		return true;
	}

	/**
	 * Refresh session and update token in store
	 */
	async refreshSession(): Promise<Session | null> {
		const {
			data: { session },
			error
		} = await this.supabase.auth.refreshSession();

		if (error) {
			console.error('Session refresh error:', error);
			return null;
		}

		if (session?.access_token) {
			authStore.updateToken(session.access_token);
		}

		return session;
	}

	/**
	 * Get headers for authorized API requests
	 */
	async getAuthHeaders(): Promise<Record<string, string>> {
		const session = await this.refreshSession();
		const user = authStore.getUser();

		return {
			Authorization: session?.access_token || '',
			'User-ID': user?.idUser?.toString() || '',
			'Content-Type': 'application/json'
		};
	}

	/**
	 * Listen to auth state changes
	 */
	onAuthStateChange(callback: (event: string, session: Session | null) => void) {
		return this.supabase.auth.onAuthStateChange((event, session) => {
			callback(event, session);
		});
	}

	/**
	 * Password recovery
	 */
	async sendPasswordResetEmail(email: string): Promise<{ success: boolean; error?: string }> {
		const { error } = await this.supabase.auth.resetPasswordForEmail(email, {
			redirectTo: `${window.location.origin}/auth/reset-password`
		});

		if (error) {
			return { success: false, error: parseAuthError(error).message };
		}

		return { success: true };
	}

	/**
	 * Verify recovery token from email link (token_hash + type=recovery in URL).
	 * Call this when the user lands on /auth/reset-password from the reset email.
	 */
	async verifyRecoveryToken(tokenHash: string): Promise<{ success: boolean; error?: string }> {
		const { error } = await this.supabase.auth.verifyOtp({
			type: 'recovery',
			token_hash: tokenHash
		});

		if (error) {
			return { success: false, error: parseAuthError(error).message };
		}

		return { success: true };
	}

	/**
	 * Update password
	 */
	async updatePassword(newPassword: string): Promise<{ success: boolean; error?: string }> {
		const { error } = await this.supabase.auth.updateUser({
			password: newPassword
		});

		if (error) {
			return { success: false, error: parseAuthError(error).message };
		}

		return { success: true };
	}

}

// Singleton instance
export const authService = new AuthService();

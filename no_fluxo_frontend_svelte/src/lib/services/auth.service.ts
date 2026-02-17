import { createSupabaseBrowserClient } from '$lib/supabase/client';
import { authStore } from '$lib/stores/auth';
import type { UserModel } from '$lib/types';
import { createUserModelFromJson } from '$lib/factories';
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
				.single();

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
				return { success: false, error: error.message };
			}

			const user = createUserModelFromJson(data as Record<string, unknown>);
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
				authStore.setError(error.message);
				return { success: false, error: error.message };
			}

			if (!data.user) {
				const msg = 'Erro ao criar conta no Supabase';
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
				authStore.setError(dbResult.error);
				return { success: false, error: dbResult.error };
			}

			authStore.setUser(dbResult.user);
			return { success: true, user: data.user };
		} catch (error) {
			const msg = `Erro inesperado: ${error}`;
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
				authStore.setError(error.message);
				return { success: false, error: error.message };
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
			const msg = `Erro: ${error}`;
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
			authStore.setError(error.message);
			throw error;
		}
	}

	/**
	 * Handle OAuth callback and sync with backend
	 */
	async handleOAuthCallback(): Promise<
		{ success: true; user: UserModel } | { success: false; error: string }
	> {
		try {
			authStore.setLoading(true);

			const {
				data: { session },
				error
			} = await this.supabase.auth.getSession();

			if (error || !session?.user?.email) {
				const msg = error?.message || 'Sessão inválida';
				authStore.setError(msg);
				return { success: false, error: msg };
			}

			const email = session.user.email;

			// Try to find user in database (direct Supabase query)
			let result = await this.databaseSearchUser();

			if (!result.success) {
				// User not found, register (direct Supabase insert)
				const displayName =
					session.user.user_metadata?.name || session.user.user_metadata?.full_name || '';
				result = await this.databaseRegisterUser(email, displayName);
			}

			if (result.success) {
				authStore.setUser(result.user);
				return { success: true, user: result.user };
			}

			authStore.setError(result.error);
			return { success: false, error: result.error };
		} catch (error) {
			const msg = `Erro no callback OAuth: ${error}`;
			authStore.setError(msg);
			return { success: false, error: msg };
		}
	}

	/**
	 * Set anonymous login state
	 */
	setAnonymous(): void {
		authStore.setAnonymous(true);

		// Set cookie for SSR
		if (typeof document !== 'undefined') {
			document.cookie = 'nofluxo_anonimo=true; path=/; max-age=31536000; samesite=lax';
		}
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
			return { success: false, error: error.message };
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
			return { success: false, error: error.message };
		}

		return { success: true };
	}

}

// Singleton instance
export const authService = new AuthService();

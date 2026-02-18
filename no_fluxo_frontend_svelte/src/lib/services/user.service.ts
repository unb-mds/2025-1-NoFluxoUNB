import { createSupabaseBrowserClient } from '$lib/supabase/client';
import { authStore } from '$lib/stores/auth';
import type { UserModel, DadosFluxogramaUser } from '$lib/types';
import { createUserModelFromJson, dadosFluxogramaUserToJson } from '$lib/factories';

export class UserService {
	private supabase = createSupabaseBrowserClient();

	/**
	 * Fetch current user data — DIRECT SUPABASE QUERY (no backend call)
	 * REPLACES: GET /users/get-user-by-email
	 */
	async fetchCurrentUser(): Promise<UserModel | null> {
		const { data: authUser } = await this.supabase.auth.getUser();

		if (!authUser.user) {
			return null;
		}

		const { data, error } = await this.supabase
			.from('users')
			.select('*, dados_users(*)')
			.eq('auth_id', authUser.user.id)
			.single();

		if (error || !data) {
			console.warn('User profile not found:', error?.message);
			return null;
		}

		const user = createUserModelFromJson(data as Record<string, unknown>);
		user.token = (await this.supabase.auth.getSession()).data.session?.access_token ?? null;

		authStore.setUser(user);
		return user;
	}

	/**
	 * Update user's fluxograma data — DIRECT SUPABASE QUERY (no backend call)
	 * REPLACES: POST /fluxograma/upload-dados-fluxograma
	 */
	async updateFluxograma(dados: DadosFluxogramaUser): Promise<boolean> {
		try {
			const user = authStore.getUser();

			if (!user) {
				throw new Error('Usuário não autenticado');
			}

			const { error } = await this.supabase
				.from('dados_users')
				.upsert(
					{
						id_user: user.idUser,
						fluxograma_atual: JSON.stringify(dadosFluxogramaUserToJson(dados))
					},
					{ onConflict: 'id_user' }
				);

			if (error) {
				console.error('Failed to update fluxograma:', error.message);
				return false;
			}

			authStore.updateDadosFluxograma(dados);
			return true;
		} catch (error) {
			console.error('updateFluxograma error:', error);
			return false;
		}
	}

	/**
	 * Sync user state after app loads — DIRECT SUPABASE QUERY
	 */
	async syncUserState(): Promise<void> {
		const { data: authUser } = await this.supabase.auth.getUser();

		if (!authUser.user) {
			authStore.setLoading(false);
			return;
		}

		const user = await this.fetchCurrentUser();

		if (!user) {
			console.warn('User not found in database');
			authStore.setError('Usuário não encontrado no sistema. Contate o suporte.');
		}
	}
}

export const userService = new UserService();

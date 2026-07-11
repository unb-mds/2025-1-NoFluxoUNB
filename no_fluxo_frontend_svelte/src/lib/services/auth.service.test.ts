import { describe, it, expect, vi, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import { AuthService } from './auth.service';
import { authStore } from '$lib/stores/auth';

describe('AuthService.ensureSessionBootstrapped', () => {
	beforeEach(() => {
		authStore.clear();
	});

	it('busca a sessão inicial só uma vez mesmo com chamadas concorrentes e repetidas', async () => {
		const service = new AuthService();
		const getSessionSpy = vi.spyOn(service, 'getSession').mockResolvedValue(null);

		await Promise.all([service.ensureSessionBootstrapped(), service.ensureSessionBootstrapped()]);
		await service.ensureSessionBootstrapped();

		expect(getSessionSpy).toHaveBeenCalledTimes(1);
	});

	it('popula authStore com o usuário quando existe sessão válida', async () => {
		const service = new AuthService();
		vi.spyOn(service, 'getSession').mockResolvedValue({
			user: { email: 'a@a.com' }
		} as never);
		vi.spyOn(service, 'databaseSearchUser').mockResolvedValue({
			success: true,
			user: { idUser: 1, email: 'a@a.com', nomeCompleto: 'A' }
		});

		await service.ensureSessionBootstrapped();

		const state = get(authStore);
		expect(state.isAuthenticated).toBe(true);
		expect(state.user?.email).toBe('a@a.com');
	});
});

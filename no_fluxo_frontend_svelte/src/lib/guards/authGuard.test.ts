import { describe, it, expect } from 'vitest';
import { decideProtectedRouteAccess } from './authGuard';
import type { AuthState } from '$lib/types/auth';

type GuardState = Pick<AuthState, 'isAuthenticated' | 'isAnonymous' | 'user'>;

const loggedOut: GuardState = { isAuthenticated: false, isAnonymous: false, user: null };
const anonymous: GuardState = { isAuthenticated: false, isAnonymous: true, user: null };

function realUser(
	overrides: { isAdmin?: boolean; adminRole?: 'admin' | 'superadmin' | null; adminScopes?: string[] } = {}
): GuardState {
	return {
		isAuthenticated: true,
		isAnonymous: false,
		user: {
			idUser: 1,
			email: 'a@a.com',
			nomeCompleto: 'A',
			isAdmin: overrides.isAdmin ?? false,
			adminRole: overrides.adminRole ?? null,
			adminScopes: overrides.adminScopes ?? []
		}
	};
}

describe('decideProtectedRouteAccess', () => {
	it('bloqueia usuário deslogado em qualquer rota protegida', () => {
		expect(decideProtectedRouteAccess('/assistente', loggedOut)).toEqual({
			action: 'redirect',
			to: '/login?redirect=%2Fassistente'
		});
	});

	it('permite anônimo em /assistente e /upload-historico', () => {
		expect(decideProtectedRouteAccess('/assistente', anonymous)).toEqual({ action: 'allow' });
		expect(decideProtectedRouteAccess('/upload-historico', anonymous)).toEqual({ action: 'allow' });
	});

	it('bloqueia anônimo em /plano-formatura e /suporte (exigem conta real)', () => {
		expect(decideProtectedRouteAccess('/plano-formatura', anonymous)).toEqual({
			action: 'redirect',
			to: '/login?redirect=%2Fplano-formatura'
		});
		expect(decideProtectedRouteAccess('/suporte', anonymous)).toEqual({
			action: 'redirect',
			to: '/login?redirect=%2Fsuporte'
		});
	});

	it('permite conta real (sem escopo admin) em /plano-formatura e /suporte', () => {
		expect(decideProtectedRouteAccess('/plano-formatura', realUser())).toEqual({ action: 'allow' });
		expect(decideProtectedRouteAccess('/suporte', realUser())).toEqual({ action: 'allow' });
	});

	it('bloqueia anônimo em rota admin — corrige o bypass que existia no checkAuth central', () => {
		expect(decideProtectedRouteAccess('/admin/dashboard', anonymous)).toEqual({
			action: 'redirect',
			to: '/login?redirect=%2Fadmin%2Fdashboard'
		});
	});

	it('bloqueia conta real sem o escopo admin necessário', () => {
		expect(
			decideProtectedRouteAccess('/admin/dashboard', realUser({ isAdmin: true, adminScopes: ['tickets'] }))
		).toEqual({ action: 'redirect', to: '/suporte?error=access_denied' });
	});

	it('permite conta real com o escopo admin necessário; superadmin passa em qualquer escopo', () => {
		expect(
			decideProtectedRouteAccess('/admin/dashboard', realUser({ isAdmin: true, adminScopes: ['dashboard'] }))
		).toEqual({ action: 'allow' });
		expect(
			decideProtectedRouteAccess('/admin/tickets', realUser({ isAdmin: true, adminScopes: ['dashboard'] }))
		).toEqual({ action: 'redirect', to: '/suporte?error=access_denied' });
		expect(
			decideProtectedRouteAccess('/admin/tickets', realUser({ isAdmin: true, adminRole: 'superadmin' }))
		).toEqual({ action: 'allow' });
	});
});

import { describe, it, expect } from 'vitest';
import { resolvePostLoginRedirect } from './post-login-redirect';

describe('resolvePostLoginRedirect', () => {
	it('honra um redirect explícito interno válido, com ou sem fluxograma salvo', () => {
		expect(resolvePostLoginRedirect('/plano-formatura', false)).toBe('/plano-formatura');
		expect(resolvePostLoginRedirect('/plano-formatura', true)).toBe('/plano-formatura');
	});

	it('ignora redirect externo/malicioso e cai no fallback baseado em ter fluxograma', () => {
		expect(resolvePostLoginRedirect('https://evil.com', false)).toBe('/upload-historico');
		expect(resolvePostLoginRedirect('//evil.com', true)).toBe('/meu-fluxograma');
	});

	it('sem redirect explícito, manda usuário com fluxograma salvo para /meu-fluxograma', () => {
		expect(resolvePostLoginRedirect('', true)).toBe('/meu-fluxograma');
	});

	it('sem redirect explícito, manda usuário sem fluxograma salvo para /upload-historico', () => {
		expect(resolvePostLoginRedirect('', false)).toBe('/upload-historico');
	});
});

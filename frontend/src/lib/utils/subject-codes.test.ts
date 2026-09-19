import { describe, expect, it } from 'vitest';
import { setHasCodeIgnoreCase, filtrarNaoCursados } from './subject-codes';

describe('setHasCodeIgnoreCase', () => {
	it('compara ignorando caixa e espaços', () => {
		const codes = new Set([' cic0004 ']);
		expect(setHasCodeIgnoreCase(codes, 'CIC0004')).toBe(true);
		expect(setHasCodeIgnoreCase(codes, 'CIC0007')).toBe(false);
	});
});

/**
 * O pool do Montador de Grade é semeado do plano + do que ficou salvo no localStorage,
 * e nunca conferia o histórico: matéria já aprovada continuava aparecendo como se
 * fosse pra cursar. Caso real: CIC0004 (ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES),
 * aprovada em 2023.1, voltando na lista lateral.
 */
describe('filtrarNaoCursados', () => {
	it('remove matéria já concluída', () => {
		expect(filtrarNaoCursados(['CIC0004', 'FGA0009'], new Set(['CIC0004']), new Set())).toEqual([
			'FGA0009'
		]);
	});

	/** MATR estará concluída antes do semestre que o aluno está montando. */
	it('remove matéria que o aluno está cursando agora', () => {
		expect(filtrarNaoCursados(['FGA0124', 'FGA0009'], new Set(), new Set(['FGA0124']))).toEqual([
			'FGA0009'
		]);
	});

	it('mantém matéria reprovada — ela precisa ser cursada de novo', () => {
		expect(filtrarNaoCursados(['IFD0171'], new Set(['MAT0025']), new Set())).toEqual(['IFD0171']);
	});

	it('compara ignorando caixa e espaços dos dois lados', () => {
		expect(filtrarNaoCursados([' cic0004 '], new Set(['CIC0004']), new Set())).toEqual([]);
		expect(filtrarNaoCursados(['CIC0004'], new Set([' cic0004 ']), new Set())).toEqual([]);
	});

	it('preserva a ordem e não duplica', () => {
		expect(
			filtrarNaoCursados(['FGA0009', 'FGA0011', 'FGA0009'], new Set(), new Set())
		).toEqual(['FGA0009', 'FGA0011']);
	});

	it('sem histórico, devolve tudo', () => {
		expect(filtrarNaoCursados(['CIC0004', 'FGA0009'], new Set(), new Set())).toEqual([
			'CIC0004',
			'FGA0009'
		]);
	});
});

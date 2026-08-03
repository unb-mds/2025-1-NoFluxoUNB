import { describe, expect, it } from 'vitest';
import {
	construirSubstitutosPorCodigo,
	resolverTurmasComEquivalencia
} from './oferta-equivalencia';

/**
 * Quando a matéria muda de código, a matriz continua com o antigo mas a turma é
 * publicada sob o novo. Caso real (matriz 693, Eng. de Software): CIC0151 sem turma,
 * CIC0197/FGA0158 com.
 *
 * Spec: docs/superpowers/specs/2026-08-03-equivalencias-oferta-turmas-design.md
 */
describe('construirSubstitutosPorCodigo', () => {
	it('mapeia a matéria da matriz para os códigos que a substituem', () => {
		const equivalencias = [
			{
				codigoMateriaOrigem: 'CIC0151',
				expressaoLogica: { operador: 'OU' as const, condicoes: ['CIC0197', 'FGA0158'] }
			}
		];
		const mapa = construirSubstitutosPorCodigo(equivalencias, ['CIC0151']);
		expect(mapa.get('CIC0151')?.sort()).toEqual(['CIC0197', 'FGA0158']);
	});

	it('ignora equivalência de matéria que não está na lista de interesse', () => {
		const equivalencias = [
			{
				codigoMateriaOrigem: 'MAT0025',
				expressaoLogica: { operador: 'OU' as const, condicoes: ['MAT0026'] }
			}
		];
		expect(construirSubstitutosPorCodigo(equivalencias, ['CIC0151']).size).toBe(0);
	});

	it('une várias linhas da mesma matéria (currículos diferentes)', () => {
		const equivalencias = [
			{ codigoMateriaOrigem: 'CIC0151', expressaoLogica: 'CIC0197' },
			{ codigoMateriaOrigem: 'CIC0151', expressaoLogica: 'FGA0158' }
		];
		expect(construirSubstitutosPorCodigo(equivalencias, ['CIC0151']).get('CIC0151')?.sort()).toEqual([
			'CIC0197',
			'FGA0158'
		]);
	});

	it('expressão E não gera substituto', () => {
		const equivalencias = [
			{
				codigoMateriaOrigem: 'FGA0100',
				expressaoLogica: { operador: 'E' as const, condicoes: ['FGA0001', 'FGA0002'] }
			}
		];
		expect(construirSubstitutosPorCodigo(equivalencias, ['FGA0100']).size).toBe(0);
	});

	it('não lista a própria matéria como substituta de si mesma', () => {
		const equivalencias = [
			{
				codigoMateriaOrigem: 'CIC0151',
				expressaoLogica: { operador: 'OU' as const, condicoes: ['CIC0151', 'FGA0158'] }
			}
		];
		expect(construirSubstitutosPorCodigo(equivalencias, ['CIC0151']).get('CIC0151')).toEqual([
			'FGA0158'
		]);
	});
});

describe('resolverTurmasComEquivalencia', () => {
	const turmaA = { id_turmas: 1, id_materia: 10, turma: 'A' };
	const turmaB = { id_turmas: 2, id_materia: 99, turma: 'B' };

	it('usa as turmas do próprio código, sem marcar codigoOfertado', () => {
		const resultado = resolverTurmasComEquivalencia(
			'CIC0151',
			10,
			['FGA0158'],
			new Map([['FGA0158', 99]]),
			new Map([
				[10, [turmaA]],
				[99, [turmaB]]
			])
		);
		expect(resultado).toEqual([{ turma: turmaA, codigoOfertado: undefined }]);
	});

	it('cai no substituto quando a matéria não tem turma própria, marcando o código ofertado', () => {
		const resultado = resolverTurmasComEquivalencia(
			'CIC0151',
			10,
			['FGA0158'],
			new Map([['FGA0158', 99]]),
			new Map([[99, [turmaB]]])
		);
		expect(resultado).toEqual([{ turma: turmaB, codigoOfertado: 'FGA0158' }]);
	});

	/**
	 * Substituto é FALLBACK, não alternativa: se a matéria ainda é ofertada no próprio
	 * código, é nele que o aluno se matricula. Medido em produção: 1.396 pares têm
	 * oferta nos DOIS códigos, ou seja, coexistem em vez de terem sido renomeados.
	 */
	it('não mistura turmas de substituto quando o próprio código tem oferta', () => {
		const resultado = resolverTurmasComEquivalencia(
			'CIC0151',
			10,
			['FGA0158'],
			new Map([['FGA0158', 99]]),
			new Map([
				[10, [turmaA]],
				[99, [turmaB]]
			])
		);
		expect(resultado.map((t) => t.turma)).toEqual([turmaA]);
	});

	it('junta turmas de vários substitutos quando nenhum é o próprio código', () => {
		const turmaC = { id_turmas: 3, id_materia: 98, turma: 'C' };
		const resultado = resolverTurmasComEquivalencia(
			'CIC0151',
			10,
			['FGA0158', 'CIC0197'],
			new Map([
				['FGA0158', 99],
				['CIC0197', 98]
			]),
			new Map([
				[99, [turmaB]],
				[98, [turmaC]]
			])
		);
		expect(resultado).toEqual([
			{ turma: turmaB, codigoOfertado: 'FGA0158' },
			{ turma: turmaC, codigoOfertado: 'CIC0197' }
		]);
	});

	it('devolve lista vazia quando nem o próprio código nem os substitutos têm turma', () => {
		expect(
			resolverTurmasComEquivalencia('CIC0151', 10, ['FGA0158'], new Map([['FGA0158', 99]]), new Map())
		).toEqual([]);
	});

	it('substituto sem id_materia no catálogo é ignorado sem quebrar', () => {
		expect(
			resolverTurmasComEquivalencia('CIC0151', 10, ['FGA9999'], new Map(), new Map())
		).toEqual([]);
	});
});

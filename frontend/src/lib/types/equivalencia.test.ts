import { describe, expect, it } from 'vitest';
import { getCompletedByEquivalenceCodes, getCurrentByEquivalenceCodes } from './equivalencia';
import type { EquivalenciaModel } from './equivalencia';
import type { ExpressaoLogicaRecursiva } from '$lib/utils/expressao-logica';

function equiv(origem: string, expressaoLogica: ExpressaoLogicaRecursiva): EquivalenciaModel {
	return {
		idEquivalencia: 0,
		codigoMateriaOrigem: origem,
		nomeMateriaOrigem: origem,
		codigoMateriaEquivalente: '',
		nomeMateriaEquivalente: '',
		expressao: '',
		expressaoLogica
	};
}

describe('getCompletedByEquivalenceCodes', () => {
	it('marca a matéria cuja equivalência é satisfeita pelo que o aluno cursou', () => {
		const result = getCompletedByEquivalenceCodes([equiv('CIC0088', 'CIC0004')], new Set(['CIC0004']));
		expect([...result]).toEqual(['CIC0088']);
	});

	it('respeita operador E — só marca com todas as condições cumpridas', () => {
		const equivalencias = [equiv('FGA0100', { operador: 'E', condicoes: ['FGA0001', 'FGA0002'] })];
		expect(getCompletedByEquivalenceCodes(equivalencias, new Set(['FGA0001'])).size).toBe(0);
		expect(
			getCompletedByEquivalenceCodes(equivalencias, new Set(['FGA0001', 'FGA0002'])).size
		).toBe(1);
	});

	/**
	 * Equivalência na UnB é tabela explícita, não relação transitiva: a secretaria não
	 * aceita a cadeia só porque os dois pares existem. Passe único, alinhado ao backend
	 * (expandirCumpridasComEquivalencias, commit 7e7075f4).
	 *
	 * Medido nos 1.658 alunos com fluxograma: encadear inflava as marcações por
	 * equivalência em 29% (8.497 contra 6.035 matérias de matriz), mexendo em 824 deles.
	 */
	it('NÃO propaga em cadeia — marcada por equivalência não satisfaz outra equivalência', () => {
		const equivalencias = [equiv('B', 'C'), equiv('A', 'B')];
		const result = getCompletedByEquivalenceCodes(equivalencias, new Set(['C']));

		// B sai direto de C, que o aluno cursou de verdade.
		expect(result.has('B')).toBe(true);
		// A dependeria de B, que só existe por equivalência — não conta.
		expect(result.has('A')).toBe(false);
	});

	it('ordem das linhas não muda o resultado', () => {
		const defs = [equiv('B', 'C'), equiv('A', 'B')];
		const direta = getCompletedByEquivalenceCodes(defs, new Set(['C']));
		const invertida = getCompletedByEquivalenceCodes([...defs].reverse(), new Set(['C']));
		expect([...direta].sort()).toEqual([...invertida].sort());
	});

	it('não remarca matéria que o aluno já cursou diretamente', () => {
		const result = getCompletedByEquivalenceCodes([equiv('CIC0004', 'CIC0088')], new Set(['CIC0004']));
		expect(result.has('CIC0004')).toBe(false);
	});

	it('equivalência não satisfeita não marca nada', () => {
		expect(getCompletedByEquivalenceCodes([equiv('CIC0088', 'CIC0004')], new Set(['MAT0025'])).size).toBe(0);
	});
});

/**
 * "Matriculado em Equivalente": aluno cursa AGORA uma matéria que satisfaz a
 * equivalência de uma obrigatória da matriz — a obrigatória deve aparecer como
 * em curso (roxa), e não como reprovada por causa de uma tentativa antiga.
 * Caso real: cursando FGA0146 (ED1 nova) ⇒ FGA0147 (matriz) matriculada;
 * cursando MAT0038 (Teoria dos Números 1) ⇒ FGA0108 (MD2) matriculada.
 */
describe('getCurrentByEquivalenceCodes', () => {
	it('marca a matéria da matriz quando o aluno cursa a equivalente agora', () => {
		const result = getCurrentByEquivalenceCodes(
			[equiv('FGA0147', 'FGA0146')],
			new Set<string>(),
			new Set(['FGA0146'])
		);
		expect([...result]).toEqual(['FGA0147']);
	});

	it('concluída tem precedência: expressão satisfeita só por concluídas não entra', () => {
		// Aluno já concluiu a equivalente — isso é caso de concluída-por-equivalência,
		// não de "matriculado em equivalente".
		const result = getCurrentByEquivalenceCodes(
			[equiv('FGA0147', 'FGA0146')],
			new Set(['FGA0146']),
			new Set(['MAT0025'])
		);
		expect(result.size).toBe(0);
	});

	it('expressão E mista: parte concluída + parte em curso conta como em curso', () => {
		const result = getCurrentByEquivalenceCodes(
			[equiv('FGA0100', { operador: 'E', condicoes: ['FGA0001', 'FGA0002'] })],
			new Set(['FGA0001']),
			new Set(['FGA0002'])
		);
		expect([...result]).toEqual(['FGA0100']);
	});

	it('não marca quem já está matriculado ou aprovado no próprio código da matriz', () => {
		const defs = [equiv('FGA0147', 'FGA0146')];
		expect(
			getCurrentByEquivalenceCodes(defs, new Set<string>(), new Set(['FGA0147', 'FGA0146'])).has(
				'FGA0147'
			)
		).toBe(false);
		expect(
			getCurrentByEquivalenceCodes(defs, new Set(['FGA0147']), new Set(['FGA0146'])).size
		).toBe(0);
	});

	it('sem nenhuma matrícula atual, não marca nada', () => {
		expect(
			getCurrentByEquivalenceCodes([equiv('FGA0147', 'FGA0146')], new Set(['CIC0004']), new Set())
				.size
		).toBe(0);
	});

	it('passe único — matéria em curso por equivalência não realimenta outra equivalência', () => {
		const defs = [equiv('B', 'C'), equiv('A', 'B')];
		const result = getCurrentByEquivalenceCodes(defs, new Set<string>(), new Set(['C']));
		expect(result.has('B')).toBe(true);
		expect(result.has('A')).toBe(false);
	});
});

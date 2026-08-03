import { describe, expect, it } from 'vitest';
import { getCompletedByEquivalenceCodes } from './equivalencia';
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

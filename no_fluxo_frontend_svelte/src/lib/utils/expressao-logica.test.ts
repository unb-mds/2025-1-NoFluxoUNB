import { describe, expect, it } from 'vitest';
import {
	evaluateExpression,
	evaluateExpressionWithTracking,
	extractSubjectCodesFromExpression,
	getCodigosFromExpressaoLogica,
	evaluateExpressaoLogica,
	getMatchingCodesFromExpressao,
	getLogicalCodeGroups,
	getSubstitutosFromExpressaoLogica
} from './expressao-logica';

describe('expressao logica helpers', () => {
	it('interpreta expressões com acento/caixa e códigos válidos', () => {
		const completed = new Set(['MAT101', 'FIS201']);
		expect(evaluateExpression('MAT101', completed)).toBe(true);
		expect(evaluateExpression('mat101', completed)).toBe(true);
		expect(evaluateExpression('MAT999', completed)).toBe(false);
	});

	it('rastrea as matérias correspondentes para combinações OU e E', () => {
		const completed = new Set(['MAT101', 'FIS201']);
		const orResult = evaluateExpressionWithTracking('MAT101 OU FIS201', completed);
		expect(orResult.isTrue).toBe(true);
		expect([...orResult.matchingMaterias].sort()).toEqual(['FIS201', 'MAT101']);

		const andResult = evaluateExpressionWithTracking('MAT101 E FIS201', completed);
		expect(andResult.isTrue).toBe(true);
		expect([...andResult.matchingMaterias].sort()).toEqual(['FIS201', 'MAT101']);

		const missing = evaluateExpressionWithTracking('MAT101 E MAT999', completed);
		expect(missing.isTrue).toBe(false);
		expect(missing.matchingMaterias.size).toBe(0);
	});

	it('extrai códigos de expressões textuais com caracteres especiais e operadores', () => {
		expect(extractSubjectCodesFromExpression('(MAT101 OU FIS201)')).toEqual(['MAT101', 'FIS201']);
		expect(extractSubjectCodesFromExpression('MAT101 E FIS201')).toEqual(['MAT101', 'FIS201']);
		expect(extractSubjectCodesFromExpression('((MAT101))')).toEqual(['MAT101']);
		expect(extractSubjectCodesFromExpression('(MAT101) E (FIS201)')).toEqual(['MAT101', 'FIS201']);
	});

	it('avalia expressões lógicas de forma resiliente a caixa, caracteres especiais e estruturas recursivas', () => {
		const completed = new Set(['FIS201']);
		expect(evaluateExpressaoLogica({ materias: ['MAT101', 'FIS201'], operador: 'OU' }, completed)).toBe(true);
		expect(evaluateExpressaoLogica({ materias: ['MAT101', 'FIS201'], operador: 'E' }, completed)).toBe(false);
		expect(evaluateExpressaoLogica({ operador: 'OU', condicoes: ['MAT101', 'FIS201'] }, completed)).toBe(true);
		expect(evaluateExpressaoLogica({ operador: 'E', condicoes: ['MAT101', 'FIS201'] }, completed)).toBe(false);
		expect(getMatchingCodesFromExpressao('(MAT101 OU FIS201)', completed)).toEqual(new Set(['FIS201']));
		expect(getMatchingCodesFromExpressao({ operador: 'OU', condicoes: ['MAT101', 'FIS201'] }, completed)).toEqual(new Set(['FIS201']));
	});

	it('gera grupos lógicos e retorna lista vazia para entradas inválidas ou muito grandes', () => {
		expect(getLogicalCodeGroups({ operador: 'OU', condicoes: [{ operador: 'E', condicoes: ['MAT101', 'FIS201'] }, 'EST301'] })).toEqual([
			['MAT101', 'FIS201'],
			['EST301']
		]);
		expect(getLogicalCodeGroups('MAT101 OU FIS201')).toEqual([['MAT101'], ['FIS201']]);
		const huge = 'MAT' + 'X'.repeat(1000);
		expect(getCodigosFromExpressaoLogica(huge)).toEqual([]);
		expect(getCodigosFromExpressaoLogica('')).toEqual([]);
	});
});

/**
 * Espelho de getSubstitutosFromExpressaoLogica no backend
 * (no_fluxo_backend/src/utils/expressao_logica.ts).
 * Spec: docs/superpowers/specs/2026-08-03-equivalencias-oferta-turmas-design.md (D2)
 */
describe('getSubstitutosFromExpressaoLogica', () => {
	it('OU: cada condição substitui sozinha', () => {
		expect(
			getSubstitutosFromExpressaoLogica({ operador: 'OU', condicoes: ['CIC0197', 'FGA0158'] }).sort()
		).toEqual(['CIC0197', 'FGA0158']);
	});

	it('E: nenhuma condição substitui sozinha', () => {
		expect(getSubstitutosFromExpressaoLogica({ operador: 'E', condicoes: ['FGA0001', 'FGA0002'] })).toEqual([]);
	});

	it('misto: só o ramo OU vira substituto', () => {
		expect(
			getSubstitutosFromExpressaoLogica({
				operador: 'OU',
				condicoes: ['MAT0025', { operador: 'E', condicoes: ['FGA0001', 'FGA0002'] }]
			})
		).toEqual(['MAT0025']);
	});

	it('string simples e expressão textual OU', () => {
		expect(getSubstitutosFromExpressaoLogica('CIC0198')).toEqual(['CIC0198']);
		expect(getSubstitutosFromExpressaoLogica('CIC0197 OU FGA0158').sort()).toEqual([
			'CIC0197',
			'FGA0158'
		]);
	});

	it('expressão textual com E não gera substituto', () => {
		expect(getSubstitutosFromExpressaoLogica('FGA0001 E FGA0002')).toEqual([]);
	});

	it('formato legado { materias, operador } respeita o operador', () => {
		expect(
			getSubstitutosFromExpressaoLogica({ materias: ['CIC0197', 'FGA0158'], operador: 'OU' }).sort()
		).toEqual(['CIC0197', 'FGA0158']);
		expect(
			getSubstitutosFromExpressaoLogica({ materias: ['FGA0001', 'FGA0002'], operador: 'E' })
		).toEqual([]);
	});

	it('entrada nula/vazia devolve lista vazia', () => {
		expect(getSubstitutosFromExpressaoLogica(null)).toEqual([]);
		expect(getSubstitutosFromExpressaoLogica(undefined)).toEqual([]);
		expect(getSubstitutosFromExpressaoLogica({ operador: 'OU', condicoes: [] })).toEqual([]);
	});
});

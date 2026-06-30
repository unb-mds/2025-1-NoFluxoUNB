import { describe, expect, it } from 'vitest';
import {
	evaluateExpression,
	evaluateExpressionWithTracking,
	extractSubjectCodesFromExpression,
	getCodigosFromExpressaoLogica,
	evaluateExpressaoLogica,
	getMatchingCodesFromExpressao,
	getLogicalCodeGroups
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

import { describe, it, expect } from 'vitest';
import { isOptativa, classificarNatureza, type MateriaModel } from './materia';

function materia(over: Partial<MateriaModel> = {}): MateriaModel {
	return {
		ementa: '',
		idMateria: 1,
		nomeMateria: 'Teste',
		codigoMateria: 'TST0001',
		nivel: 3,
		creditos: 4,
		...over
	};
}

describe('isOptativa', () => {
	it('tipoNatureza tem prioridade sobre nivel', () => {
		expect(isOptativa(materia({ tipoNatureza: 1, nivel: 5 }))).toBe(true);
		// Dados legados: obrigatória com nivel 0 continua obrigatória.
		expect(isOptativa(materia({ tipoNatureza: 0, nivel: 0 }))).toBe(false);
	});

	it('sem tipoNatureza, cai no fallback nivel === 0', () => {
		expect(isOptativa(materia({ tipoNatureza: null, nivel: 0 }))).toBe(true);
		expect(isOptativa(materia({ tipoNatureza: null, nivel: 4 }))).toBe(false);
	});
});

describe('classificarNatureza', () => {
	it('fora da matriz é módulo livre', () => {
		expect(classificarNatureza(null)).toBe('modulo_livre');
		expect(classificarNatureza(undefined)).toBe('modulo_livre');
	});

	it('na matriz, separa optativa de obrigatória', () => {
		expect(classificarNatureza(materia({ tipoNatureza: 1 }))).toBe('optativa');
		expect(classificarNatureza(materia({ tipoNatureza: 0 }))).toBe('obrigatoria');
	});
});

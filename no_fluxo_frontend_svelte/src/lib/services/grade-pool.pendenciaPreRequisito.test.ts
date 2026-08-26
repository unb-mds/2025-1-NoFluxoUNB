import { describe, it, expect, beforeEach, vi } from 'vitest';
import type { MateriaModel } from '$lib/types/materia';
import type { PreRequisitoModel } from '$lib/types/curso';

/**
 * Stub do fluxograma: o que está sob teste é a regra de "o que falta", não o
 * acesso ao banco nem a montagem do pool.
 */
const curso = {
	materias: [] as MateriaModel[],
	preRequisitos: [] as PreRequisitoModel[],
	coRequisitos: [] as unknown[],
	equivalencias: [] as unknown[]
};
const completed = new Set<string>();
const current = new Set<string>();

vi.mock('$lib/stores/fluxograma.store.svelte', () => ({
	fluxogramaStore: {
		get state() {
			return { courseData: curso };
		},
		get completedCodes() {
			return completed;
		},
		get currentCodes() {
			return current;
		}
	}
}));

vi.mock('$lib/services/oferta-turmas.service', () => ({
	getOfertaComEquivalencia: async () => new Map()
}));

const { pendenciaPreRequisito, pendenciasPreRequisito } = await import('./grade-pool.service');

function materia(codigo: string, idMateria: number, nome = codigo): MateriaModel {
	return {
		codigoMateria: codigo,
		nomeMateria: nome,
		idMateria,
		nivel: 1,
		tipoNatureza: 0,
		creditos: 4,
		ementa: ''
	} as unknown as MateriaModel;
}

function preRequisito(
	idPreRequisito: number,
	idMateria: number,
	extras: Partial<PreRequisitoModel> = {}
): PreRequisitoModel {
	return {
		idPreRequisito,
		idMateria,
		idMateriaRequisito: null,
		codigoMateriaRequisito: '',
		nomeMateriaRequisito: '',
		...extras
	} as PreRequisitoModel;
}

describe('pendenciaPreRequisito', () => {
	beforeEach(() => {
		curso.materias = [];
		curso.preRequisitos = [];
		completed.clear();
		current.clear();
	});

	it('devolve null quando a matéria não tem pré-requisito', () => {
		curso.materias = [materia('CIC0097', 1, 'Algoritmos e Programação de Computadores')];

		expect(pendenciaPreRequisito('CIC0097')).toBeNull();
	});

	it('devolve null quando todos os pré-requisitos já foram cumpridos', () => {
		curso.materias = [materia('CIC0004', 1), materia('CIC0007', 2, 'Estruturas de Dados')];
		curso.preRequisitos = [
			preRequisito(1, 2, {
				idMateriaRequisito: 1,
				codigoMateriaRequisito: 'CIC0004',
				nomeMateriaRequisito: 'Algoritmos'
			})
		];
		completed.add('CIC0004');

		expect(pendenciaPreRequisito('CIC0007')).toBeNull();
	});

	it('lista os faltantes, o nome da matéria e a expressão original', () => {
		curso.materias = [
			materia('CIC0004', 1),
			materia('MAT0025', 2),
			materia('CIC0007', 3, 'Estruturas de Dados')
		];
		curso.preRequisitos = [
			preRequisito(1, 3, {
				idMateriaRequisito: 1,
				codigoMateriaRequisito: 'CIC0004',
				nomeMateriaRequisito: 'Algoritmos',
				expressaoOriginal: 'CIC0004 E MAT0025'
			}),
			preRequisito(2, 3, {
				idMateriaRequisito: 2,
				codigoMateriaRequisito: 'MAT0025',
				nomeMateriaRequisito: 'Cálculo 1',
				expressaoOriginal: 'CIC0004 E MAT0025'
			})
		];
		completed.add('CIC0004');

		expect(pendenciaPreRequisito('CIC0007')).toEqual({
			codigo: 'CIC0007',
			nome: 'Estruturas de Dados',
			faltantes: ['MAT0025'],
			expressaoOriginal: 'CIC0004 E MAT0025'
		});
	});

	/** OU parcialmente satisfeito já basta — avisar aqui seria alarme falso. */
	it('devolve null quando uma expressão OU está parcialmente satisfeita', () => {
		curso.materias = [materia('MAT0025', 1), materia('MAT0026', 2), materia('CIC0007', 3)];
		curso.preRequisitos = [
			preRequisito(1, 3, {
				expressaoOriginal: 'MAT0025 OU MAT0026',
				expressaoLogica: { materias: ['MAT0025', 'MAT0026'], operador: 'OU' }
			})
		];
		completed.add('MAT0026');

		expect(pendenciaPreRequisito('CIC0007')).toBeNull();
	});

	it('avisa quando nenhum lado do OU foi cumprido', () => {
		curso.materias = [materia('CIC0007', 3, 'Estruturas de Dados')];
		curso.preRequisitos = [
			preRequisito(1, 3, {
				expressaoOriginal: 'MAT0025 OU MAT0026',
				expressaoLogica: { materias: ['MAT0025', 'MAT0026'], operador: 'OU' }
			})
		];

		expect(pendenciaPreRequisito('CIC0007')).toEqual({
			codigo: 'CIC0007',
			nome: 'Estruturas de Dados',
			faltantes: ['MAT0025 OU MAT0026'],
			expressaoOriginal: 'MAT0025 OU MAT0026'
		});
	});

	/** Módulo livre: o courseData não tem as regras dela, então não há o que afirmar. */
	it('devolve null para matéria fora da matriz', () => {
		curso.materias = [materia('CIC0004', 1)];
		curso.preRequisitos = [
			preRequisito(1, 99, { codigoMateriaRequisito: 'MAT0025', nomeMateriaRequisito: 'Cálculo 1' })
		];

		expect(pendenciaPreRequisito('FGA0210')).toBeNull();
	});

	it('ignora diferença de caixa e espaços no código consultado', () => {
		curso.materias = [materia('CIC0007', 3, 'Estruturas de Dados')];
		curso.preRequisitos = [
			preRequisito(1, 3, { codigoMateriaRequisito: 'CIC0004', nomeMateriaRequisito: 'Algoritmos' })
		];

		expect(pendenciaPreRequisito(' cic0007 ')?.faltantes).toEqual(['CIC0004']);
	});
});

describe('pendenciasPreRequisito (lote)', () => {
	beforeEach(() => {
		curso.materias = [];
		curso.preRequisitos = [];
		completed.clear();
		current.clear();
	});

	/** Matriz com CIC0007 e CIC0008 pendentes e CIC0004 sem pré-requisito. */
	function matrizComDuasPendencias() {
		curso.materias = [
			materia('CIC0004', 1, 'Algoritmos'),
			materia('CIC0007', 2, 'Estruturas de Dados'),
			materia('CIC0008', 3, 'Sistemas Operacionais')
		];
		curso.preRequisitos = [
			preRequisito(1, 2, {
				codigoMateriaRequisito: 'MAT0025',
				nomeMateriaRequisito: 'Cálculo 1'
			}),
			preRequisito(2, 3, {
				codigoMateriaRequisito: 'CIC0004',
				nomeMateriaRequisito: 'Algoritmos'
			})
		];
	}

	it('devolve lista vazia para entrada vazia', () => {
		matrizComDuasPendencias();

		expect(pendenciasPreRequisito([])).toEqual([]);
	});

	it('devolve lista vazia quando nenhuma das matérias tem pendência', () => {
		matrizComDuasPendencias();
		completed.add('MAT0025');
		completed.add('CIC0004');

		expect(pendenciasPreRequisito(['CIC0004', 'CIC0007', 'CIC0008'])).toEqual([]);
	});

	it('mantém a ordem de entrada e descarta quem não tem pendência', () => {
		matrizComDuasPendencias();

		const r = pendenciasPreRequisito(['CIC0008', 'CIC0004', 'FGA0210', 'CIC0007']);

		expect(r.map((p) => p.codigo)).toEqual(['CIC0008', 'CIC0007']);
		expect(r[0].faltantes).toEqual(['CIC0004']);
		expect(r[1].faltantes).toEqual(['MAT0025']);
	});

	it('não repete matéria quando o código vem duplicado', () => {
		matrizComDuasPendencias();

		const r = pendenciasPreRequisito(['CIC0007', 'cic0007', ' CIC0007 ', 'CIC0008']);

		expect(r.map((p) => p.codigo)).toEqual(['CIC0007', 'CIC0008']);
	});

	it('ignora códigos vazios', () => {
		matrizComDuasPendencias();

		expect(pendenciasPreRequisito(['', '   ', 'CIC0007']).map((p) => p.codigo)).toEqual(['CIC0007']);
	});
});

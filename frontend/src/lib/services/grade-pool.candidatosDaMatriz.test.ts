import { describe, it, expect, beforeEach, vi } from 'vitest';
import type { MateriaModel } from '$lib/types/materia';

/**
 * Stubs no lugar do fluxograma e da oferta: aqui o que está sob teste é a regra de
 * escolha (quem entra e em que ordem), não o acesso ao banco.
 */
const curso = {
	materias: [] as MateriaModel[],
	preRequisitos: [] as unknown[],
	coRequisitos: [] as unknown[],
	equivalencias: [] as unknown[]
};
const completed = new Set<string>();
const current = new Set<string>();
/** Códigos que têm turma no período; o resto volta sem oferta. */
let comOferta = new Set<string>();

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
	getOfertaComEquivalencia: async (materias: Array<{ codigo: string }>) =>
		new Map(
			materias.map((m) => [
				m.codigo,
				comOferta.has(m.codigo)
					? [{ turma: { id_turmas: 1, horario: '2M12' }, codigoOfertado: undefined }]
					: []
			])
		)
}));

const { candidatosDaMatriz } = await import('./grade-pool.service');

function materiaDaMatriz(
	codigo: string,
	nivel: number,
	tipoNatureza: 0 | 1,
	idMateria: number
): MateriaModel {
	return {
		codigoMateria: codigo,
		nomeMateria: codigo,
		idMateria,
		nivel,
		tipoNatureza,
		creditos: 4,
		ementa: ''
	} as unknown as MateriaModel;
}

describe('candidatosDaMatriz', () => {
	beforeEach(() => {
		curso.materias = [];
		curso.preRequisitos = [];
		completed.clear();
		current.clear();
		comOferta = new Set();
	});

	it('descarta matéria sem turma no período', async () => {
		curso.materias = [materiaDaMatriz('MAT0001', 1, 0, 1), materiaDaMatriz('MAT0002', 1, 0, 2)];
		comOferta = new Set(['MAT0001']);

		expect((await candidatosDaMatriz('2026.2')).map((m) => m.codigo)).toEqual(['MAT0001']);
	});

	it('descarta cursadas, em curso e as excluídas pelo chamador', async () => {
		curso.materias = [
			materiaDaMatriz('MAT0001', 1, 0, 1),
			materiaDaMatriz('MAT0002', 1, 0, 2),
			materiaDaMatriz('MAT0003', 1, 0, 3),
			materiaDaMatriz('MAT0004', 1, 0, 4)
		];
		comOferta = new Set(['MAT0001', 'MAT0002', 'MAT0003', 'MAT0004']);
		completed.add('MAT0002');
		current.add('MAT0003');

		const r = await candidatosDaMatriz('2026.2', ['MAT0004']);

		expect(r.map((m) => m.codigo)).toEqual(['MAT0001']);
	});

	it('obrigatória vem antes de optativa e, dentro disso, o nível mais baixo primeiro', async () => {
		curso.materias = [
			materiaDaMatriz('OPT0001', 0, 1, 10),
			materiaDaMatriz('OBR0005', 5, 0, 11),
			materiaDaMatriz('OBR0001', 1, 0, 12)
		];
		comOferta = new Set(['OPT0001', 'OBR0005', 'OBR0001']);

		const r = await candidatosDaMatriz('2026.2');

		expect(r.map((m) => m.codigo)).toEqual(['OBR0001', 'OBR0005', 'OPT0001']);
	});

	/** Pré-requisito pendente não bloqueia (o app só avisa), mas vai para o fim da fila. */
	it('deixa por último quem está com pré-requisito pendente', async () => {
		curso.materias = [materiaDaMatriz('OBR0002', 2, 0, 20), materiaDaMatriz('OBR0009', 9, 0, 21)];
		comOferta = new Set(['OBR0002', 'OBR0009']);
		curso.preRequisitos = [
			{
				idPreRequisito: 1,
				idMateria: 20,
				idMateriaRequisito: 99,
				codigoMateriaRequisito: 'MAT9999',
				nomeMateriaRequisito: 'MAT9999'
			}
		];

		const r = await candidatosDaMatriz('2026.2');

		expect(r.map((m) => m.codigo)).toEqual(['OBR0009', 'OBR0002']);
	});
});

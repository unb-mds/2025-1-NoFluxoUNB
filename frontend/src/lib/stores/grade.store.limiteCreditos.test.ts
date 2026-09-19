import { describe, it, expect, beforeEach } from 'vitest';
import { gradeStore, type MateriaGrade } from './grade.store.svelte';
import type { TurmaOferta } from '$lib/services/turmas.service';

function turmaOferta(id: number): TurmaOferta {
	return {
		id_turmas: id,
		id_materia: id,
		turma: 'A',
		docente: null,
		horario: null,
		local: null,
		ano_periodo: '2026.1',
		vagas_ofertadas: null,
		vagas_ocupadas: null,
		vagas_sobrando: null
	};
}

/** Matéria com uma turma única no bit informado — nunca colide com outro bit. */
function materia(codigo: string, creditos: number, bit: number): MateriaGrade {
	return {
		codigo,
		nome: codigo,
		creditos,
		idMateria: bit + 1,
		turmas: [{ mask: 1n << BigInt(bit), turma: turmaOferta(bit + 1) }]
	};
}

const idDaTurma = (m: MateriaGrade) => m.turmas[0].turma.id_turmas;

describe('gradeStore — matéria que o aluno já está cursando (MATR) é obrigatória', () => {
	beforeEach(() => {
		gradeStore.init([], { idUser: null, periodo: '2026.1' });
	});

	/**
	 * Defeito medido: logo depois de "Montar grade" nenhuma MATR está travada (a
	 * trava só nasce quando o aluno escolhe a turma real na mão), então o slider
	 * derrubava matéria de matrícula já efetivada.
	 */
	it('o slider não tira uma MATR mesmo sem ela estar travada', () => {
		const matr = materia('MATR', 6, 0);
		const opcional = materia('OPT', 6, 1);
		gradeStore.init([matr, opcional], { idUser: null, periodo: '2026.1' });
		gradeStore.definirCursandoAtual(['MATR']);
		gradeStore.montarAutomatico();
		// A montagem automática não trava nada: é esse o cenário do bug.
		expect(gradeStore.isTravada('MATR')).toBe(false);
		expect(gradeStore.creditosSelecionados).toBe(12);

		gradeStore.ajustarParaLimite(6);

		expect(gradeStore.turmaSelecionada('MATR')?.turma.id_turmas).toBe(idDaTurma(matr));
		expect(gradeStore.turmaSelecionada('OPT')).toBeUndefined();
	});

	it('a MATR sobra sozinha acima do limite quando nem ela cabe', () => {
		gradeStore.init([materia('MATR', 10, 0), materia('OPT', 4, 1)], {
			idUser: null,
			periodo: '2026.1'
		});
		gradeStore.definirCursandoAtual(['MATR']);
		gradeStore.montarAutomatico();

		gradeStore.ajustarParaLimite(4);

		expect(gradeStore.turmaSelecionada('MATR')).toBeDefined();
		expect(gradeStore.creditosSelecionados).toBe(10);
	});
});

describe('gradeStore.montarAutomatico — limite de créditos', () => {
	beforeEach(() => {
		gradeStore.init([], { idUser: null, periodo: '2026.1' });
	});

	it('sem limite continua enchendo a grade como antes', () => {
		const pool = [materia('A', 4, 0), materia('B', 4, 1), materia('C', 4, 2)];
		gradeStore.init(pool, { idUser: null, periodo: '2026.1' });

		const r = gradeStore.montarAutomatico();

		expect(r.naoAlocadas).toEqual([]);
		expect(gradeStore.creditosSelecionados).toBe(12);
	});

	it('não passa do limite quando todas as matérias são opcionais', () => {
		const pool = [materia('A', 4, 0), materia('B', 4, 1), materia('C', 4, 2)];
		gradeStore.init(pool, { idUser: null, periodo: '2026.1' });

		const r = gradeStore.montarAutomatico({ limiteCreditos: 10 });

		expect(gradeStore.creditosSelecionados).toBeLessThanOrEqual(10);
		expect(gradeStore.selecao.size).toBe(2);
		expect(r.naoAlocadas.length).toBe(1);
	});

	it('as MATR entram primeiro e comem o orçamento das opcionais', () => {
		const pool = [
			materia('OPT1', 4, 0),
			materia('OPT2', 4, 1),
			materia('MATR', 6, 2)
		];
		gradeStore.init(pool, { idUser: null, periodo: '2026.1' });
		gradeStore.definirCursandoAtual(['MATR']);

		gradeStore.montarAutomatico({ limiteCreditos: 10 });

		expect(gradeStore.selecao.has('MATR')).toBe(true);
		expect(gradeStore.creditosSelecionados).toBe(10); // MATR (6) + uma opcional (4)
		expect(gradeStore.selecao.size).toBe(2);
	});

	/** Caso real do aluno 2828: 10 MATR = 36 créditos contra um teto de 24. */
	it('obrigatórias que já estouram o limite não são sacrificadas nem quebram a montagem', () => {
		const pool = [
			materia('M1', 6, 0),
			materia('M2', 6, 1),
			materia('M3', 6, 2),
			materia('OPT', 4, 3)
		];
		gradeStore.init(pool, { idUser: null, periodo: '2026.1' });
		gradeStore.definirCursandoAtual(['M1', 'M2', 'M3']);

		const r = gradeStore.montarAutomatico({ limiteCreditos: 12 });

		expect(gradeStore.selecao.has('M1')).toBe(true);
		expect(gradeStore.selecao.has('M2')).toBe(true);
		expect(gradeStore.selecao.has('M3')).toBe(true);
		expect(gradeStore.selecao.has('OPT')).toBe(false);
		expect(gradeStore.creditosSelecionados).toBe(18);
		expect(r.naoAlocadas).toEqual(['OPT']);
	});

	it('o crédito da matéria travada também conta no orçamento', () => {
		gradeStore.init([materia('TRAVADA', 8, 0), materia('OPT', 4, 1)], {
			idUser: null,
			periodo: '2026.1'
		});
		gradeStore.definirCursandoAtual(['TRAVADA']);
		gradeStore.selecionarTurma('TRAVADA', 1); // trava com a turma real
		expect(gradeStore.isTravada('TRAVADA')).toBe(true);

		gradeStore.montarAutomatico({ limiteCreditos: 10 });

		expect(gradeStore.selecao.has('TRAVADA')).toBe(true);
		expect(gradeStore.selecao.has('OPT')).toBe(false); // 8 + 4 passaria de 10
		expect(gradeStore.creditosSelecionados).toBe(8);
	});
});

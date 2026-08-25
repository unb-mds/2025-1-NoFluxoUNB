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

/** Matéria com uma turma por bit informado — `bits` vira uma turma por posição. */
function materiaComTurmas(codigo: string, creditos: number, bits: number[], baseId: number): MateriaGrade {
	return {
		codigo,
		nome: codigo,
		creditos,
		idMateria: baseId,
		turmas: bits.map((bit, i) => ({ mask: 1n << BigInt(bit), turma: turmaOferta(baseId + i) }))
	};
}

describe('gradeStore — matéria travada (já cursando, turma real escolhida)', () => {
	beforeEach(() => {
		gradeStore.init([], { idUser: null, periodo: '2026.1' });
	});

	it('trava sozinha ao escolher a turma de uma matéria marcada como cursando', () => {
		const materias = [materiaComTurmas('L', 4, [0], 1)];
		gradeStore.init(materias, { idUser: null, periodo: '2026.1' });
		gradeStore.definirCursandoAtual(['L']);

		expect(gradeStore.isTravada('L')).toBe(false);
		gradeStore.selecionarTurma('L', 1);
		expect(gradeStore.isTravada('L')).toBe(true);
	});

	it('"Montar grade" nunca reatribui a turma travada e evita conflito com ela', () => {
		// L (travada) só tem turma no bit 0. B (livre) tem duas opções: uma no
		// mesmo bit 0 (colidiria com L) e outra no bit 1 (livre).
		const materias = [
			materiaComTurmas('L', 4, [0], 1),
			materiaComTurmas('B', 4, [0, 1], 10)
		];
		gradeStore.init(materias, { idUser: null, periodo: '2026.1' });
		gradeStore.definirCursandoAtual(['L']);
		gradeStore.selecionarTurma('L', 1); // trava com a turma id=1 (bit 0)

		gradeStore.montarAutomatico();

		expect(gradeStore.turmaSelecionada('L')?.turma.id_turmas).toBe(1);
		// B só podia entrar pela turma do bit 1 (id=11) — a do bit 0 (id=10) colide com L.
		expect(gradeStore.turmaSelecionada('B')?.turma.id_turmas).toBe(11);
	});

	it('destrava ao remover a turma manualmente ou remover a matéria do pool', () => {
		const materias = [materiaComTurmas('L', 4, [0], 1), materiaComTurmas('M', 4, [1], 10)];
		gradeStore.init(materias, { idUser: null, periodo: '2026.1' });
		gradeStore.definirCursandoAtual(['L', 'M']);
		gradeStore.selecionarTurma('L', 1);
		gradeStore.selecionarTurma('M', 10);
		expect(gradeStore.isTravada('L')).toBe(true);
		expect(gradeStore.isTravada('M')).toBe(true);

		gradeStore.removerTurma('L');
		expect(gradeStore.isTravada('L')).toBe(false);

		gradeStore.removerMateriaDoPool('M');
		expect(gradeStore.isTravada('M')).toBe(false);
		expect(gradeStore.isCursandoAtual('M')).toBe(false);
	});

	it('o slider de créditos nunca tira uma matéria travada, mesmo passando do limite', () => {
		const materias = [materiaComTurmas('L', 10, [0], 1)];
		gradeStore.init(materias, { idUser: null, periodo: '2026.1' });
		gradeStore.definirCursandoAtual(['L']);
		gradeStore.selecionarTurma('L', 1);

		gradeStore.ajustarParaLimite(2);

		expect(gradeStore.turmaSelecionada('L')?.turma.id_turmas).toBe(1);
		expect(gradeStore.creditosSelecionados).toBe(10);
	});
});

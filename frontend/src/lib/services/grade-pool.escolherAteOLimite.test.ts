import { describe, it, expect, beforeEach } from 'vitest';
import { escolherAteOLimite } from './grade-pool.service';
import { gradeStore, type MateriaGrade } from '$lib/stores/grade.store.svelte';
import { slotMaskFromHorario } from '$lib/utils/horario-slots';

/** Matéria com uma turma por horário informado. */
function materia(codigo: string, creditos: number, horarios: string[]): MateriaGrade {
	const base = Number(codigo.replace(/\D/g, '')) * 100;
	return {
		codigo,
		nome: codigo,
		creditos,
		idMateria: base,
		turmas: horarios.map((h, i) => ({
			mask: slotMaskFromHorario(h),
			turma: { id_turmas: base + i, horario: h, turma: String(i) } as never
		}))
	};
}

describe('escolherAteOLimite', () => {
	beforeEach(() => {
		gradeStore.init([], { idUser: null, periodo: '2026.2' });
	});

	it('enche até o limite de créditos, na ordem de prioridade recebida', () => {
		const candidatos = [
			materia('MAT0001', 6, ['2M12']),
			materia('MAT0002', 6, ['3M12']),
			materia('MAT0003', 6, ['4M12']),
			materia('MAT0004', 6, ['5M12']),
			materia('MAT0005', 6, ['6M12'])
		];

		const escolhidas = escolherAteOLimite(candidatos, 24);

		expect(escolhidas.map((m) => m.codigo)).toEqual(['MAT0001', 'MAT0002', 'MAT0003', 'MAT0004']);
	});

	it('nunca passa do limite — pula a que não cabe e segue para uma menor', () => {
		const candidatos = [
			materia('MAT0001', 6, ['2M12']),
			materia('MAT0002', 6, ['3M12']),
			materia('MAT0003', 4, ['4M12']), // 16 > 14: não cabe
			materia('MAT0004', 2, ['5M12']) // 14: cabe
		];

		const escolhidas = escolherAteOLimite(candidatos, 14);

		expect(escolhidas.map((m) => m.codigo)).toEqual(['MAT0001', 'MAT0002', 'MAT0004']);
	});

	/**
	 * O conjunto devolvido é o contrato com `montarAutomatico`: ele maximiza matérias
	 * e não conhece limite de créditos, então só não estoura porque o que semeamos já
	 * cabe junto. Se aqui saísse gente em conflito, a montagem largaria alguém de fora.
	 */
	it('só devolve matérias que cabem juntas sem conflito de horário', () => {
		const candidatos = [
			materia('MAT0001', 4, ['2M12']),
			materia('MAT0002', 4, ['2M12']), // mesmo slot: fora
			materia('MAT0003', 4, ['2M12', '3T12']) // cai na alternativa
		];

		const escolhidas = escolherAteOLimite(candidatos, 24);

		expect(escolhidas.map((m) => m.codigo)).toEqual(['MAT0001', 'MAT0003']);

		gradeStore.init(escolhidas, { idUser: null, periodo: '2026.2' });
		expect(gradeStore.montarAutomatico().naoAlocadas).toEqual([]);
	});

	it('respeita os turnos desligados pelo aluno', () => {
		gradeStore.toggleTurno('M');
		const candidatos = [materia('MAT0001', 4, ['2M12']), materia('MAT0002', 4, ['3T12'])];

		expect(escolherAteOLimite(candidatos, 24).map((m) => m.codigo)).toEqual(['MAT0002']);
	});

	/** Semear complementa a grade em vez de ignorá-la: o que já está escolhido conta. */
	it('parte do que já está na grade — créditos e horários ocupados', () => {
		gradeStore.init([materia('MAT0001', 6, ['2M12'])], { idUser: null, periodo: '2026.2' });
		gradeStore.selecionarTurma('MAT0001', 100);

		const candidatos = [
			materia('MAT0002', 6, ['2M12']), // conflita com a já escolhida
			materia('MAT0003', 6, ['3M12']),
			materia('MAT0004', 6, ['4M12']),
			materia('MAT0005', 6, ['5M12']),
			// Sem contar os 6 créditos já na grade, esta ainda caberia — é o que o teste
			// tranca: 6 (escolhida) + 3 x 6 = 24 fecha o limite.
			materia('MAT0006', 6, ['6M12'])
		];

		const escolhidas = escolherAteOLimite(candidatos, 24);

		expect(escolhidas.map((m) => m.codigo)).toEqual(['MAT0003', 'MAT0004', 'MAT0005']);
	});
});

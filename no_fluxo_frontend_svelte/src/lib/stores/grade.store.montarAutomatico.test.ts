import { describe, it, expect, beforeEach } from 'vitest';
import { gradeStore, type MateriaGrade } from './grade.store.svelte';
import { slotMaskFromHorario } from '$lib/utils/horario-slots';

/** Matéria com N turmas em horários distintos. `horarios` vazio = sem oferta. */
function materia(codigo: string, horarios: string[]): MateriaGrade {
	const base = Number(codigo.replace(/\D/g, '')) * 100;
	return {
		codigo,
		nome: codigo,
		creditos: 4,
		idMateria: base,
		turmas: horarios.map((h, i) => ({
			mask: slotMaskFromHorario(h),
			turma: { id_turmas: base + i, horario: h, turma: String(i) } as never
		}))
	};
}

describe('gradeStore.montarAutomatico', () => {
	beforeEach(() => {
		gradeStore.init([], { idUser: null, periodo: '2026.2' });
	});

	it('encaixa tudo que não conflita', () => {
		gradeStore.init([materia('MAT0001', ['2M12']), materia('MAT0002', ['3T12'])], {
			idUser: null,
			periodo: '2026.2'
		});

		const r = gradeStore.montarAutomatico();

		expect(r.naoAlocadas).toEqual([]);
		expect(gradeStore.selecao.size).toBe(2);
	});

	it('escolhe a turma alternativa quando a primeira conflita', () => {
		gradeStore.init([materia('MAT0001', ['2M12']), materia('MAT0002', ['2M12', '4T34'])], {
			idUser: null,
			periodo: '2026.2'
		});

		const r = gradeStore.montarAutomatico();

		expect(r.naoAlocadas).toEqual([]);
		expect(gradeStore.selecao.get('MAT0002')?.turma.horario).toBe('4T34');
	});

	it('reporta a matéria sem oferta em naoAlocadas, sem derrubar as outras', () => {
		gradeStore.init([materia('MAT0001', ['2M12']), materia('MAT0002', [])], {
			idUser: null,
			periodo: '2026.2'
		});

		const r = gradeStore.montarAutomatico();

		expect(r.naoAlocadas).toEqual(['MAT0002']);
		expect(gradeStore.selecao.has('MAT0001')).toBe(true);
	});

	/**
	 * Regressão do "aperto em Rearranjar e não acontece nada": com uma matéria sem
	 * oferta o ótimo teórico vira inalcançável. A busca antiga não tinha poda por
	 * limite superior e varria o espaço inteiro, congelando a thread por minutos —
	 * daí a impressão de botão morto.
	 */
	it('responde rápido com pool grande + matéria sem oferta', () => {
		// Todas disputam o mesmo conjunto de horários: nem tudo cabe, que é
		// justamente a situação em que a busca antiga explodia.
		const HORARIOS = ['2M12', '3M12', '4M12', '5M12', '6M12', '2T12', '3T12', '4T12', '5T12', '6T12'];
		const pool = Array.from({ length: 9 }, (_, i) =>
			materia(`MAT${String(i + 1).padStart(4, '0')}`, HORARIOS)
		);
		pool.push(materia('MAT9999', []));
		gradeStore.init(pool, { idUser: null, periodo: '2026.2' });

		const t0 = performance.now();
		const r = gradeStore.montarAutomatico();
		const ms = performance.now() - t0;

		expect(r.naoAlocadas).toContain('MAT9999');
		expect(ms).toBeLessThan(500);
	});

	it('prioritária (estrela) entra na frente quando as duas disputam o horário', () => {
		gradeStore.init([materia('MAT0001', ['2M12']), materia('MAT0002', ['2M12'])], {
			idUser: null,
			periodo: '2026.2'
		});
		gradeStore.togglePrioridade('MAT0002');

		const r = gradeStore.montarAutomatico();

		expect(gradeStore.selecao.has('MAT0002')).toBe(true);
		expect(r.naoAlocadas).toEqual(['MAT0001']);
	});
});

import { describe, it, expect, beforeEach } from 'vitest';
import { gradeStore } from './grade.store.svelte';
import { slotMaskFromHorario, maskDosTurnos } from '$lib/utils/horario-slots';
import type { MateriaGrade } from './grade.store.svelte';

function materiaComTurma(codigo: string, horario: string): MateriaGrade {
	return {
		codigo,
		nome: codigo,
		creditos: 4,
		idMateria: Number(codigo.replace(/\D/g, '')),
		turmas: [{ mask: slotMaskFromHorario(horario), turma: { id_turmas: Number(codigo.replace(/\D/g, '')), horario } as any }]
	};
}

describe('gradeStore.freeMask', () => {
	beforeEach(() => {
		gradeStore.init([], { idUser: null, periodo: '2026.2' });
	});

	it('sem nada selecionado, freeMask cobre todo o universo dos turnos permitidos', () => {
		expect(gradeStore.freeMask).toBe(maskDosTurnos(['M', 'T', 'N']));
	});

	it('depois de selecionar uma turma, o slot dela sai do freeMask', () => {
		const mat = materiaComTurma('FGA0001', '2M12');
		gradeStore.addMateriaAoPool(mat);
		gradeStore.selecionarTurma('FGA0001', mat.turmas[0].turma.id_turmas);

		const ocupado = slotMaskFromHorario('2M12');
		expect(gradeStore.freeMask & ocupado).toBe(0n);
	});

	it('filtrando turno (só manhã), freeMask não inclui slots de tarde/noite', () => {
		gradeStore.setTurnos(['M']);
		const tarde = slotMaskFromHorario('2T1');
		expect(gradeStore.freeMask & tarde).toBe(0n);
	});
});

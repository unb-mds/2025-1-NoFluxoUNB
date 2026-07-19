import { describe, it, expect } from 'vitest';
import {
	slotMaskFromHorario,
	hasConflict,
	autoMontarGrade,
	type MateriaTurmas
} from './horario-slots';

/**
 * Bit de referência, computado de forma independente da implementação,
 * para validar o layout: diaIndex(0..5) * 16 + offsetTurno + (modulo-1).
 * offsetTurno: M=0, T=5, N=12.
 */
function bit(diaCod: string, turno: 'M' | 'T' | 'N', modulo: number): bigint {
	const diaIndex = Number(diaCod) - 2; // '2' -> 0 ... '7' -> 5
	const offset = turno === 'M' ? 0 : turno === 'T' ? 5 : 12;
	return 1n << BigInt(diaIndex * 16 + offset + (modulo - 1));
}

describe('slotMaskFromHorario', () => {
	it('parseia código composto (24M12 35T34) nos bits exatos', () => {
		const esperado =
			bit('2', 'M', 1) |
			bit('2', 'M', 2) |
			bit('4', 'M', 1) |
			bit('4', 'M', 2) |
			bit('3', 'T', 3) |
			bit('3', 'T', 4) |
			bit('5', 'T', 3) |
			bit('5', 'T', 4);
		expect(slotMaskFromHorario('24M12 35T34')).toBe(esperado);
	});

	it('é tolerante a casing e espaços extras', () => {
		expect(slotMaskFromHorario('  6 n 1234 ')).toBe(
			bit('6', 'N', 1) | bit('6', 'N', 2) | bit('6', 'N', 3) | bit('6', 'N', 4)
		);
	});

	it('retorna 0n para horário vazio, nulo ou sem padrão reconhecível', () => {
		expect(slotMaskFromHorario('')).toBe(0n);
		expect(slotMaskFromHorario('   ')).toBe(0n);
		expect(slotMaskFromHorario('A DEFINIR')).toBe(0n);
		// @ts-expect-error validação de robustez em runtime
		expect(slotMaskFromHorario(null)).toBe(0n);
	});

	it('não colide entre turnos no mesmo dia (M5, T7 e N4 distintos)', () => {
		const m = slotMaskFromHorario('2M5');
		const t = slotMaskFromHorario('2T7');
		const n = slotMaskFromHorario('2N4');
		expect(m & t).toBe(0n);
		expect(m & n).toBe(0n);
		expect(t & n).toBe(0n);
	});
});

describe('hasConflict', () => {
	it('detecta sobreposição no mesmo dia/turno/módulo', () => {
		expect(hasConflict(slotMaskFromHorario('24M12'), slotMaskFromHorario('2M2'))).toBe(true);
	});

	it('não acusa conflito quando são disjuntos', () => {
		expect(hasConflict(slotMaskFromHorario('24M12'), slotMaskFromHorario('35T34'))).toBe(false);
		// Mesmo dia e turno, módulos diferentes
		expect(hasConflict(slotMaskFromHorario('2M12'), slotMaskFromHorario('2M34'))).toBe(false);
	});

	it('máscara vazia (EAD/a definir) nunca conflita', () => {
		expect(hasConflict(0n, slotMaskFromHorario('24M12'))).toBe(false);
		expect(hasConflict(0n, 0n)).toBe(false);
	});
});

describe('autoMontarGrade', () => {
	const mk = <T>(chave: string, turmas: Array<{ mask: bigint; turma: T }>): MateriaTurmas<T> => ({
		chave,
		turmas
	});

	it('encontra solução quando existe uma combinação sem conflito', () => {
		const materias = [
			mk('A', [{ mask: slotMaskFromHorario('2M12'), turma: 'A1' }]),
			mk('B', [{ mask: slotMaskFromHorario('3M12'), turma: 'B1' }])
		];
		const r = autoMontarGrade(materias);
		expect(r.naoAlocadas).toEqual([]);
		expect(r.selecao.get('A')?.turma).toBe('A1');
		expect(r.selecao.get('B')?.turma).toBe('B1');
	});

	it('escolhe a turma que evita conflito quando há alternativas', () => {
		const materias = [
			mk('A', [{ mask: slotMaskFromHorario('2M12'), turma: 'A1' }]),
			mk('B', [
				{ mask: slotMaskFromHorario('2M12'), turma: 'B-conflita' }, // colide com A1
				{ mask: slotMaskFromHorario('3M12'), turma: 'B-ok' }
			])
		];
		const r = autoMontarGrade(materias);
		expect(r.naoAlocadas).toEqual([]);
		expect(r.selecao.get('B')?.turma).toBe('B-ok');
	});

	it('aloca o máximo possível e reporta as que não couberam', () => {
		const mesmoHorario = slotMaskFromHorario('2M12');
		const materias = [
			mk('A', [{ mask: mesmoHorario, turma: 'A1' }]),
			mk('B', [{ mask: mesmoHorario, turma: 'B1' }]) // só existe no mesmo horário de A
		];
		const r = autoMontarGrade(materias);
		expect(r.selecao.size).toBe(1);
		expect(r.naoAlocadas.length).toBe(1);
		// A que sobrou tem de ser uma das duas
		expect(['A', 'B']).toContain(r.naoAlocadas[0]);
	});

	it('trata matéria sem turmas como não alocada', () => {
		const materias = [
			mk('A', [{ mask: slotMaskFromHorario('2M12'), turma: 'A1' }]),
			mk('SEM_TURMA', [])
		];
		const r = autoMontarGrade(materias);
		expect(r.selecao.get('A')?.turma).toBe('A1');
		expect(r.naoAlocadas).toContain('SEM_TURMA');
	});
});

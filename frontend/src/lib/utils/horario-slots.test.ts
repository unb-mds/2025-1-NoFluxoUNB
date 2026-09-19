import { describe, it, expect } from 'vitest';
import {
	slotMaskFromHorario,
	hasConflict,
	autoMontarGrade,
	type MateriaTurmas
} from './horario-slots';

/** Turmas fictícias com horários espalhados — poucas colidem entre si. */
function turmasPara(seed: number, n: number) {
	return Array.from({ length: n }, (_, i) => {
		const bitA = (seed * 7 + i * 3) % 96;
		const bitB = (seed * 11 + i * 5 + 40) % 96;
		return {
			mask: (1n << BigInt(bitA)) | (1n << BigInt(bitB)),
			turma: { id_turmas: seed * 100 + i },
			bonus: 0
		};
	});
}

/** Pool no formato que o grade.store monta: peso alto por matéria, bônus pequeno. */
function poolRealista(
	nMaterias: number,
	nTurmas: number,
	{ semOferta = false } = {}
): Array<MateriaTurmas<{ id_turmas: number }>> {
	const pesoBase = 5 * nMaterias + 1;
	const mats = Array.from({ length: nMaterias }, (_, s) => ({
		chave: `MAT${s}`,
		turmas: turmasPara(s + 1, nTurmas),
		peso: pesoBase
	}));
	if (semOferta) mats.push({ chave: 'SEM_OFERTA', turmas: [], peso: pesoBase });
	return mats;
}

describe('slotMaskFromHorario', () => {
	it('converte horário SIGAA em máscara e detecta conflito', () => {
		expect(hasConflict(slotMaskFromHorario('24M12'), slotMaskFromHorario('24M23'))).toBe(true);
		expect(hasConflict(slotMaskFromHorario('24M12'), slotMaskFromHorario('35T12'))).toBe(false);
	});

	it('horário vazio / a definir nunca conflita', () => {
		expect(slotMaskFromHorario('A DEFINIR')).toBe(0n);
		expect(hasConflict(slotMaskFromHorario(''), slotMaskFromHorario('24M12'))).toBe(false);
	});
});

describe('autoMontarGrade', () => {
	it('aloca tudo quando não há conflito', () => {
		const r = autoMontarGrade(poolRealista(6, 8));
		expect(r.naoAlocadas).toEqual([]);
		expect(r.selecao.size).toBe(6);
	});

	it('não escolhe turmas conflitantes entre si', () => {
		const r = autoMontarGrade(poolRealista(8, 10, { semOferta: true }));
		let acc = 0n;
		for (const t of r.selecao.values()) {
			expect(hasConflict(t.mask, acc)).toBe(false);
			acc |= t.mask;
		}
	});

	// Regressão do "Rearranjar não faz nada": quando o ótimo teórico é inalcançável
	// (matéria sem oferta no semestre, ou turmas descartadas pelo filtro de turno),
	// a busca não tinha poda por limite superior e varria o espaço inteiro —
	// travando a thread principal por minutos. Um pool de tamanho normal tem que
	// resolver em milissegundos.
	it('resolve rápido mesmo com matéria sem oferta (poda por limite superior)', () => {
		const t0 = performance.now();
		const r = autoMontarGrade(poolRealista(9, 12, { semOferta: true }));
		const ms = performance.now() - t0;

		expect(r.naoAlocadas).toEqual(['SEM_OFERTA']);
		expect(r.selecao.size).toBe(9);
		expect(ms).toBeLessThan(500);
	});

	it('respeita prioridade: matéria com peso alto entra mesmo disputando horário', () => {
		const conflito = 1n << 3n;
		const r = autoMontarGrade([
			{ chave: 'BAIXA', turmas: [{ mask: conflito, turma: { id_turmas: 1 } }], peso: 10 },
			{ chave: 'ALTA', turmas: [{ mask: conflito, turma: { id_turmas: 2 } }], peso: 10_000 }
		]);
		expect(r.selecao.has('ALTA')).toBe(true);
		expect(r.naoAlocadas).toEqual(['BAIXA']);
	});

	it('preferência desempata mas nunca custa uma matéria', () => {
		const slotA = 1n << 3n;
		const slotB = 1n << 9n;
		// ALVO só cabe em slotA. OUTRA prefere slotA (bônus), mas cabe em slotB.
		const r = autoMontarGrade([
			{ chave: 'ALVO', turmas: [{ mask: slotA, turma: { id_turmas: 1 }, bonus: 0 }], peso: 100 },
			{
				chave: 'OUTRA',
				turmas: [
					{ mask: slotA, turma: { id_turmas: 2 }, bonus: 5 },
					{ mask: slotB, turma: { id_turmas: 3 }, bonus: 0 }
				],
				peso: 100
			}
		]);
		expect(r.naoAlocadas).toEqual([]);
		expect(r.selecao.get('OUTRA')?.turma.id_turmas).toBe(3);
		expect(r.preferenciasNaoAtendidas).toEqual(['OUTRA']);
	});
});

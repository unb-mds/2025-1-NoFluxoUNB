import { describe, it, expect } from 'vitest';
import { autoMontarGrade, hasConflict, type MateriaTurmas } from './horario-slots';

/** Matéria com uma turma no bit informado — bits distintos nunca colidem. */
function mat(
	chave: string,
	bit: number,
	extra: Partial<MateriaTurmas<{ id_turmas: number }>> = {}
): MateriaTurmas<{ id_turmas: number }> {
	return {
		chave,
		turmas: [{ mask: 1n << BigInt(bit), turma: { id_turmas: bit } }],
		...extra
	};
}

describe('autoMontarGrade — orçamento de créditos', () => {
	it('sem orçamento ignora os créditos (comportamento de antes)', () => {
		const r = autoMontarGrade([
			mat('A', 0, { creditos: 10 }),
			mat('B', 1, { creditos: 10 })
		]);
		expect(r.selecao.size).toBe(2);
		expect(r.naoAlocadas).toEqual([]);
	});

	it('não aloca além do orçamento', () => {
		const r = autoMontarGrade(
			[mat('A', 0, { creditos: 4 }), mat('B', 1, { creditos: 4 }), mat('C', 2, { creditos: 4 })],
			0n,
			10
		);
		const gasto = [...r.selecao.keys()].length * 4;
		expect(gasto).toBeLessThanOrEqual(10);
		expect(r.selecao.size).toBe(2);
		expect(r.naoAlocadas.length).toBe(1);
	});

	it('obrigatória entra mesmo estourando o orçamento e satura o resto', () => {
		const r = autoMontarGrade(
			[
				mat('OBR', 0, { creditos: 12, obrigatoria: true, peso: 1_000_000 }),
				mat('OPT', 1, { creditos: 2 })
			],
			0n,
			8
		);
		expect(r.selecao.has('OBR')).toBe(true);
		expect(r.selecao.has('OPT')).toBe(false);
		expect(r.naoAlocadas).toEqual(['OPT']);
	});

	it('a máscara inicial não deixa a busca ignorar o horário já ocupado', () => {
		const ocupado = 1n << 0n;
		const r = autoMontarGrade([mat('A', 0, { creditos: 4 })], ocupado, 10);
		expect(r.naoAlocadas).toEqual(['A']);
	});

	/**
	 * A poda por limite superior também tem que enxergar o orçamento: sem isso um
	 * pool em que quase nada cabe no teto de créditos volta a varrer o espaço inteiro
	 * (é o mesmo modo de falha do "Rearranjar não faz nada").
	 */
	it('resolve rápido com pool grande e orçamento apertado', () => {
		const pool = Array.from({ length: 12 }, (_, i) => ({
			chave: `MAT${i}`,
			creditos: 4,
			// Três turmas por matéria, com colisões espalhadas pela semana.
			turmas: Array.from({ length: 3 }, (_, j) => ({
				mask: (1n << BigInt((i * 5 + j * 7) % 96)) | (1n << BigInt((i * 3 + j * 11 + 30) % 96)),
				turma: { id_turmas: i * 10 + j }
			}))
		}));

		const t0 = performance.now();
		const r = autoMontarGrade(pool, 0n, 12);
		const ms = performance.now() - t0;

		expect(r.selecao.size).toBe(3);
		let acc = 0n;
		for (const t of r.selecao.values()) {
			expect(hasConflict(t.mask, acc)).toBe(false);
			acc |= t.mask;
		}
		expect(ms).toBeLessThan(500);
	});
});

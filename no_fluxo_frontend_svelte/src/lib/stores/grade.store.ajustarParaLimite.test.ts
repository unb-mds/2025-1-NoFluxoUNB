import { describe, it, expect, beforeEach } from 'vitest';
import { gradeStore, type MateriaGrade } from './grade.store.svelte';
import type { TurmaOferta } from '$lib/services/turmas.service';

/** Matéria fictícia com uma única turma cuja máscara não colide com nenhuma outra. */
function materia(codigo: string, creditos: number, bit: number): MateriaGrade {
	const turma: TurmaOferta = {
		id_turmas: bit + 1,
		id_materia: bit + 1,
		turma: 'A',
		docente: null,
		horario: null,
		local: null,
		ano_periodo: '2026.1',
		vagas_ofertadas: null,
		vagas_ocupadas: null,
		vagas_sobrando: null
	};
	return {
		codigo,
		nome: codigo,
		creditos,
		idMateria: bit + 1,
		turmas: [{ mask: 1n << BigInt(bit), turma }]
	};
}

/** Monta o pool, seleciona a única turma de cada matéria e marca as prioritárias. */
function montarCenario(materias: MateriaGrade[], prioritarias: string[] = []): void {
	gradeStore.init(materias, { idUser: null, periodo: '2026.1' });
	for (const m of materias) gradeStore.selecionarTurma(m.codigo, m.turmas[0].turma.id_turmas);
	for (const codigo of prioritarias) gradeStore.togglePrioridade(codigo);
}

describe('gradeStore.ajustarParaLimite', () => {
	beforeEach(() => {
		gradeStore.init([], { idUser: null, periodo: '2026.1' });
	});

	it('não mexe na seleção quando já cabe no limite', () => {
		const materias = [materia('A', 4, 0), materia('B', 6, 1)];
		montarCenario(materias);

		gradeStore.ajustarParaLimite(10);

		expect(gradeStore.creditosSelecionados).toBe(10);
		expect(gradeStore.turmaSelecionada('A')).toBeDefined();
		expect(gradeStore.turmaSelecionada('B')).toBeDefined();
	});

	it('tira as não-prioritárias primeiro, começando pela de mais crédito', () => {
		// A=4, B=6, C=2 (estrela), D=8 — total 20.
		const materias = [materia('A', 4, 0), materia('B', 6, 1), materia('C', 2, 2), materia('D', 8, 3)];
		montarCenario(materias, ['C']);

		// 20 → 14: só precisa tirar D (8) pra caber (12 ≤ 14). B, mesmo maior que A,
		// não devia sair — não tira mais do que o necessário.
		gradeStore.ajustarParaLimite(14);
		expect(gradeStore.creditosSelecionados).toBe(12);
		expect(gradeStore.turmaSelecionada('D')).toBeUndefined();
		expect(gradeStore.turmaSelecionada('A')).toBeDefined();
		expect(gradeStore.turmaSelecionada('B')).toBeDefined();
		expect(gradeStore.turmaSelecionada('C')).toBeDefined();

		// 12 → 10: agora tira B (6, maior não-prioritária) antes de A (4) — e a
		// prioritária C nunca é candidata enquanto sobra não-prioritária.
		gradeStore.ajustarParaLimite(10);
		expect(gradeStore.creditosSelecionados).toBe(6);
		expect(gradeStore.turmaSelecionada('B')).toBeUndefined();
		expect(gradeStore.turmaSelecionada('A')).toBeDefined();
		expect(gradeStore.turmaSelecionada('C')).toBeDefined();
	});

	it('tira prioritárias também quando só sobra prioritária e ainda passa do limite', () => {
		const materias = [materia('E', 10, 0), materia('F', 10, 1)];
		montarCenario(materias, ['E', 'F']);

		gradeStore.ajustarParaLimite(5);

		expect(gradeStore.creditosSelecionados).toBe(0);
		expect(gradeStore.turmaSelecionada('E')).toBeUndefined();
		expect(gradeStore.turmaSelecionada('F')).toBeUndefined();
	});
});

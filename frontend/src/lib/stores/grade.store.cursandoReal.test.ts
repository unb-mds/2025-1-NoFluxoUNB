/**
 * Fluxo completo "matrícula real do SIGAA": a rota marca as matérias em curso,
 * pré-seleciona a turma real (via encontrarTurmaReal) e o resto do montador —
 * montagem automática, slider, limpar, voltar ao início — respeita essa
 * matrícula. Testa a integração store + util, do jeito que a página usa.
 */
import { describe, it, expect, beforeEach } from 'vitest';
import { gradeStore, type MateriaGrade } from './grade.store.svelte';
import { encontrarTurmaReal } from '$lib/utils/turmas-reais';
import type { TurmaOferta } from '$lib/services/turmas.service';

function turmaOferta(id: number, turma = 'A'): TurmaOferta {
	return {
		id_turmas: id,
		id_materia: id,
		turma,
		docente: null,
		horario: null,
		local: null,
		ano_periodo: '2026.2',
		vagas_ofertadas: null,
		vagas_ocupadas: null,
		vagas_sobrando: null
	};
}

/** Matéria com uma turma por entrada — cada uma com bit de horário e nome próprios. */
function materiaComTurmas(
	codigo: string,
	creditos: number,
	turmas: Array<{ bit: number; id: number; nome?: string; codigoOfertado?: string }>
): MateriaGrade {
	return {
		codigo,
		nome: codigo,
		creditos,
		idMateria: turmas[0]?.id ?? 0,
		turmas: turmas.map((t) => ({
			mask: 1n << BigInt(t.bit),
			turma: turmaOferta(t.id, t.nome ?? '01'),
			codigoOfertado: t.codigoOfertado
		}))
	};
}

/** O que a página faz em `preencherTurmasReais`, sem a parte de auth/rota. */
function preencherTurmasReais(reais: Map<string, string>): void {
	for (const m of gradeStore.pool) {
		if (!gradeStore.isCursandoAtual(m.codigo) || gradeStore.turmaSelecionada(m.codigo)) continue;
		const idTurma = encontrarTurmaReal(m, reais);
		if (idTurma != null) gradeStore.selecionarTurma(m.codigo, idTurma);
	}
}

describe('gradeStore + turmas reais — pré-seleção da matrícula do SIGAA', () => {
	beforeEach(() => {
		gradeStore.init([], { idUser: null, periodo: '2026.2' });
	});

	it('pré-seleciona e trava a turma real da matéria em curso', () => {
		const pool = [
			materiaComTurmas('FGA0240', 4, [
				{ bit: 0, id: 10, nome: '01' },
				{ bit: 1, id: 11, nome: '02' }
			])
		];
		gradeStore.init(pool, { idUser: null, periodo: '2026.2' });
		gradeStore.definirCursandoAtual(['FGA0240']);

		preencherTurmasReais(new Map([['FGA0240', '2']])); // SIGAA sem zero à esquerda

		expect(gradeStore.turmaSelecionada('FGA0240')?.turma.id_turmas).toBe(11);
		expect(gradeStore.isTravada('FGA0240')).toBe(true);
	});

	it('não sobrescreve turma que o aluno já tinha escolhido', () => {
		const pool = [
			materiaComTurmas('FGA0240', 4, [
				{ bit: 0, id: 10, nome: '01' },
				{ bit: 1, id: 11, nome: '02' }
			])
		];
		gradeStore.init(pool, { idUser: null, periodo: '2026.2' });
		gradeStore.definirCursandoAtual(['FGA0240']);
		gradeStore.selecionarTurma('FGA0240', 10); // escolha manual anterior

		preencherTurmasReais(new Map([['FGA0240', '02']]));

		expect(gradeStore.turmaSelecionada('FGA0240')?.turma.id_turmas).toBe(10);
	});

	it('matrícula em equivalente pré-seleciona pelo codigoOfertado', () => {
		const pool = [
			materiaComTurmas('FGA0240', 4, [{ bit: 0, id: 20, nome: '01', codigoOfertado: 'FGA0317' }])
		];
		gradeStore.init(pool, { idUser: null, periodo: '2026.2' });
		gradeStore.definirCursandoAtual(['FGA0240']);

		preencherTurmasReais(new Map([['FGA0317', '01']]));

		expect(gradeStore.turmaSelecionada('FGA0240')?.turma.id_turmas).toBe(20);
	});

	it('matéria sem correspondência fica sem turma — e "Montar grade" pode alocá-la', () => {
		const pool = [
			materiaComTurmas('FGA0240', 4, [{ bit: 0, id: 10, nome: '01' }]),
			materiaComTurmas('FGA0250', 4, [{ bit: 1, id: 30, nome: '01' }])
		];
		gradeStore.init(pool, { idUser: null, periodo: '2026.2' });
		gradeStore.definirCursandoAtual(['FGA0240']);

		// Histórico só conhece outra matéria: nada é pré-selecionado.
		preencherTurmasReais(new Map([['MAT0025', '01']]));
		expect(gradeStore.selecao.size).toBe(0);
		expect(gradeStore.isTravada('FGA0240')).toBe(false);

		const r = gradeStore.montarAutomatico();
		expect(r.naoAlocadas).toHaveLength(0);
		expect(gradeStore.selecao.size).toBe(2);
	});

	it('"Montar grade" monta AO REDOR da matrícula real, nunca por cima dela', () => {
		// Cursando FGA0240 na turma do bit 0. FGA0250 tem duas turmas: uma colide
		// (bit 0), outra não (bit 1) — o solver precisa escolher a livre.
		const pool = [
			materiaComTurmas('FGA0240', 4, [
				{ bit: 0, id: 10, nome: '01' },
				{ bit: 2, id: 11, nome: '02' }
			]),
			materiaComTurmas('FGA0250', 4, [
				{ bit: 0, id: 30, nome: '01' },
				{ bit: 1, id: 31, nome: '02' }
			])
		];
		gradeStore.init(pool, { idUser: null, periodo: '2026.2' });
		gradeStore.definirCursandoAtual(['FGA0240']);
		preencherTurmasReais(new Map([['FGA0240', '01']]));

		gradeStore.montarAutomatico();

		expect(gradeStore.turmaSelecionada('FGA0240')?.turma.id_turmas).toBe(10);
		expect(gradeStore.turmaSelecionada('FGA0250')?.turma.id_turmas).toBe(31);
	});

	it('reset ("voltar ao início") seguido do preenchimento reconstrói a matrícula real', () => {
		const pool = [
			materiaComTurmas('FGA0240', 4, [
				{ bit: 0, id: 10, nome: '01' },
				{ bit: 1, id: 11, nome: '02' }
			])
		];
		gradeStore.init(pool, { idUser: null, periodo: '2026.2' });
		gradeStore.definirCursandoAtual(['FGA0240']);
		preencherTurmasReais(new Map([['FGA0240', '01']]));
		// Aluno bagunça tudo: troca a turma na mão e depois limpa tudo.
		gradeStore.destravar('FGA0240');
		gradeStore.selecionarTurma('FGA0240', 11);
		gradeStore.limparTudo();
		expect(gradeStore.pool).toHaveLength(0);

		// A página refaz: resetarParaInicio + definirCursandoAtual + preencher.
		gradeStore.resetarParaInicio(pool);
		gradeStore.definirCursandoAtual(['FGA0240']);
		preencherTurmasReais(new Map([['FGA0240', '01']]));

		expect(gradeStore.turmaSelecionada('FGA0240')?.turma.id_turmas).toBe(10);
		expect(gradeStore.isTravada('FGA0240')).toBe(true);
	});

	it('duas cursando com matrícula real em horários conflitantes: a segunda não entra à força', () => {
		// Dados reais podem vir tortos (ex.: histórico de outro curso) — o store
		// nunca deixa duas turmas no mesmo slot, mesmo vindas do SIGAA.
		const pool = [
			materiaComTurmas('FGA0240', 4, [{ bit: 0, id: 10, nome: '01' }]),
			materiaComTurmas('FGA0250', 4, [{ bit: 0, id: 30, nome: '01' }])
		];
		gradeStore.init(pool, { idUser: null, periodo: '2026.2' });
		gradeStore.definirCursandoAtual(['FGA0240', 'FGA0250']);

		preencherTurmasReais(
			new Map([
				['FGA0240', '01'],
				['FGA0250', '01']
			])
		);

		expect(gradeStore.selecao.size).toBe(1);
		expect(gradeStore.turmaSelecionada('FGA0240')?.turma.id_turmas).toBe(10);
		expect(gradeStore.turmaSelecionada('FGA0250')).toBeUndefined();
	});
});

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { gradeStore, slotMaskFromHorario, type MateriaGrade } from './grade.store.svelte';

/**
 * Reprodução do relato: "entro na página, clico em Montar grade sem escolher
 * nada, e aparece 'Nenhuma turma disponível para as matérias da lista'".
 *
 * A tela mostra essa frase quando a montagem termina com seleção VAZIA e
 * `naoAlocadas` também VAZIA (`MontadorGradeView`). E `naoAlocadas` só vem vazia
 * quando a lista que chega ao solver é vazia — ela é construída percorrendo
 * exatamente essa lista. Ou seja: o pool tem matéria com turma, mas nenhuma
 * delas chegou a ser candidata.
 *
 * Este arquivo enumera os estados que produzem isso, para separar causa de
 * sintoma antes de mexer na mensagem.
 */
vi.mock('$lib/stores/fluxograma.store.svelte', () => ({
	fluxogramaStore: {
		get optatorias() {
			return new Map<string, string[]>();
		}
	}
}));

let seq = 0;
function materia(
	codigo: string,
	horarios: string[],
	extra: Partial<MateriaGrade> = {}
): MateriaGrade {
	const base = ++seq * 100;
	return {
		codigo,
		nome: codigo,
		creditos: 4,
		idMateria: base,
		turmas: horarios.map((h, i) => ({
			mask: slotMaskFromHorario(h),
			turma: { id_turmas: base + i, horario: h, turma: String(i + 1) } as never
		})),
		...extra
	};
}

/** O estado que a tela lê para decidir a frase do aviso. */
function sintoma(r: { naoAlocadas: string[]; candidatas: number }): {
	selecao: number;
	naoAlocadas: number;
	/** A tela cairia na frase que culpa a oferta de turmas? */
	culparíaOferta: boolean;
	/** A tela sabe que ninguém sequer concorreu? */
	sabeQueNaoHouveCandidata: boolean;
} {
	const selecao = gradeStore.selecao.size;
	const naoAlocadas = r.naoAlocadas.length;
	return {
		selecao,
		naoAlocadas,
		culparíaOferta: selecao === 0 && naoAlocadas === 0 && r.candidatas > 0,
		sabeQueNaoHouveCandidata: r.candidatas === 0
	};
}

beforeEach(() => {
	seq = 0;
	gradeStore.definirCursandoAtual([]);
	gradeStore.definirSituacao(null);
	gradeStore.init([], { idUser: null, periodo: '2026.2' });
	gradeStore.setIncluirCursando(true);
});

describe('quando a montagem não seleciona nada e também não reporta nada', () => {
	/**
	 * O caminho que reproduz o relato: o aluno desligou "matérias em curso" e
	 * TODAS as matérias da lista são matrícula dele. Não sobra candidata, e o
	 * aviso culpa a oferta de turmas — que está intacta.
	 */
	it('modo "sem as cursando" com a lista inteira em curso', () => {
		gradeStore.init([materia('CIC0004', ['2M12']), materia('MAT0025', ['3M12'])], {
			idUser: null,
			periodo: '2026.2'
		});
		gradeStore.definirCursandoAtual(['CIC0004', 'MAT0025']);
		gradeStore.setIncluirCursando(false);

		const r = gradeStore.montarAutomatico({ limiteCreditos: 24 });

		// O pool TEM turma ofertada, então culpar a oferta seria falso. O motor
		// precisa dizer que ninguém concorreu, para a tela explicar o que houve.
		expect(gradeStore.pool.some((m) => m.turmas.length > 0)).toBe(true);
		expect(sintoma(r).selecao).toBe(0);
		expect(sintoma(r).sabeQueNaoHouveCandidata).toBe(true);
		expect(sintoma(r).culparíaOferta).toBe(false);
	});

	/**
	 * Contraprova: com as em curso ligadas, as mesmas matérias entram e a grade
	 * é montada. Isolar isto é o que mostra que a oferta nunca foi o problema.
	 */
	it('as mesmas matérias montam normalmente com o modo ligado', () => {
		gradeStore.init([materia('CIC0004', ['2M12']), materia('MAT0025', ['3M12'])], {
			idUser: null,
			periodo: '2026.2'
		});
		gradeStore.definirCursandoAtual(['CIC0004', 'MAT0025']);
		gradeStore.setIncluirCursando(true);

		const r = gradeStore.montarAutomatico({ limiteCreditos: 24 });

		expect(sintoma(r).selecao).toBe(2);
	});

	/**
	 * Toda matéria travada também esvazia a lista do solver — mas trava só nasce
	 * de `selecionarTurma`, que seleciona junto. A seleção sobrevive à montagem,
	 * então este caminho NÃO produz o aviso. Fica registrado para a próxima
	 * pessoa não voltar a suspeitar dele.
	 */
	it('lista toda travada não produz o aviso: as travadas seguem na grade', () => {
		gradeStore.init([materia('CIC0004', ['2M12'])], { idUser: null, periodo: '2026.2' });
		gradeStore.selecionarTurma('CIC0004', 100);

		const r = gradeStore.montarAutomatico({ limiteCreditos: 24 });

		expect(gradeStore.isTravada('CIC0004')).toBe(true);
		expect(sintoma(r).selecao).toBe(1);
	});

	/**
	 * Quando existe candidata e ela não cabe, o motor a devolve em `naoAlocadas` —
	 * e aí a tela mostra a outra frase, a que fala de créditos e turno. Este é o
	 * caso legítimo do aviso; o do primeiro teste não é.
	 */
	it('candidata que não cabe é reportada, não silenciada', () => {
		gradeStore.init([materia('CIC0004', [])], { idUser: null, periodo: '2026.2' });

		const r = gradeStore.montarAutomatico({ limiteCreditos: 24 });

		expect(r.naoAlocadas).toEqual(['CIC0004']);
		expect(r.candidatas).toBe(1);
		expect(sintoma(r).sabeQueNaoHouveCandidata).toBe(false);
	});
});

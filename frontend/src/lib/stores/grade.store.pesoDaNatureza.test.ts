import { describe, it, expect } from 'vitest';
import {
	pesoDaNatureza,
	PESO_OBRIGATORIA,
	PESO_NECESSARIA,
	PESO_SATURADO,
	PESO_PRIORITARIA,
	FATOR_ENTRE_DEGRAUS
} from './grade.store.svelte';
import type { SituacaoAcademica } from '$lib/services/situacao-academica.service';

/**
 * A regra que decide o que a montagem automática prioriza, agora que ela conhece
 * o saldo de carga horária do aluno.
 *
 * Testada como função pura, separada do solver: aqui se prova a POLÍTICA (quem
 * vale mais), e nos testes de `montarAutomatico` se prova o EFEITO dela na grade.
 */

/** Situação com os faltantes que o teste quiser; o resto é irrelevante aqui. */
function situacao(faltam: Partial<SituacaoAcademica['faltam']>): SituacaoAcademica {
	return {
		faltam: { obrigatoria: 480, optativa: 180, modulo_livre: null, ...faltam },
		exigido: { obrigatoria: 2400, optativa: 360, modulo_livre: 120 },
		realizado: { obrigatoria: 1920, optativa: 180, modulo_livre: 0 },
		exigeModuloLivre: true,
		complementarConfiavel: true
	};
}

/**
 * A aritmética que sustenta a escada inteira.
 *
 * `autoMontarGrade` maximiza a SOMA dos pesos, então um degrau só é superior ao
 * seguinte se nem uma grade cheia do de baixo alcançar uma matéria do de cima.
 * O bound honesto para "quantas cabem juntas" é o tamanho do pool: a montagem
 * pode rodar sem teto de créditos, o slider vai a 40, e matéria EAD tem máscara
 * vazia e não conflita com ninguém. Sem esta prova, "obrigatória vence optativa"
 * seria uma intenção no comentário em vez de uma garantia.
 */
describe('escada de pesos — separação entre degraus', () => {
	it('cada degrau é FATOR vezes o de baixo', () => {
		expect(PESO_NECESSARIA).toBe(PESO_SATURADO * FATOR_ENTRE_DEGRAUS);
		expect(PESO_OBRIGATORIA).toBe(PESO_NECESSARIA * FATOR_ENTRE_DEGRAUS);
		expect(PESO_PRIORITARIA).toBe(PESO_OBRIGATORIA * FATOR_ENTRE_DEGRAUS);
	});

	it('o fator cobre com folga qualquer pool que caiba na tela', () => {
		expect(FATOR_ENTRE_DEGRAUS).toBeGreaterThan(200);
	});

	/** Somar o degrau mais alto no pool inteiro não pode perder a precisão inteira. */
	it('a soma no pior caso continua exata em ponto flutuante', () => {
		const piorCaso = 200 * PESO_PRIORITARIA * FATOR_ENTRE_DEGRAUS;

		expect(piorCaso).toBeLessThan(Number.MAX_SAFE_INTEGER);
	});
});

describe('pesoDaNatureza — sem situação carregada', () => {
	/**
	 * Toda falha da camada de integralização cai aqui. O montador tem de voltar ao
	 * comportamento anterior — obrigatória acima de optativa —, nunca a um pior.
	 */
	it('obrigatória continua acima de optativa', () => {
		expect(pesoDaNatureza('obrigatoria', null, false)).toBe(PESO_OBRIGATORIA);
		expect(pesoDaNatureza('optativa', null, false)).toBe(PESO_NECESSARIA);
		expect(pesoDaNatureza('modulo_livre', null, false)).toBe(PESO_NECESSARIA);
	});

	it('ninguém satura sem dado', () => {
		expect(pesoDaNatureza('optativa', null, false)).not.toBe(PESO_SATURADO);
		expect(pesoDaNatureza('modulo_livre', null, false)).not.toBe(PESO_SATURADO);
	});
});

describe('pesoDaNatureza — natureza cumprida', () => {
	it('optativa com a carga cumprida cai para o degrau saturado', () => {
		expect(pesoDaNatureza('optativa', situacao({ optativa: 0 }), false)).toBe(PESO_SATURADO);
	});

	it('módulo livre cumprido também satura', () => {
		expect(pesoDaNatureza('modulo_livre', situacao({ modulo_livre: 0 }), false)).toBe(
			PESO_SATURADO
		);
	});

	/**
	 * Saturada não é zero: a matéria ainda entra num buraco que sobrou da grade.
	 * Cursar optativa a mais é escolha legítima — ela só não desloca ninguém.
	 */
	it('saturada ainda soma alguma coisa, para caber em buraco', () => {
		expect(pesoDaNatureza('optativa', situacao({ optativa: 0 }), false)).toBeGreaterThan(0);
	});

	it('faltante desconhecido não satura', () => {
		expect(pesoDaNatureza('modulo_livre', situacao({ modulo_livre: null }), false)).toBe(
			PESO_NECESSARIA
		);
	});
});

/**
 * Quem decide se ainda falta obrigatória é a LISTA de pendentes da matriz, nunca
 * a conta de horas.
 *
 * As duas divergem de verdade: `carga_horaria_integralizada` vem do PDF do SIGAA
 * e fala do curso atual, então quem mudou de matriz ou cumpriu matéria por
 * equivalência tem números de currículos diferentes somados. Entre esconder uma
 * obrigatória que o aluno ainda deve e sugerir uma a mais, o erro barato é o
 * segundo — o primeiro custa um semestre.
 */
describe('pesoDaNatureza — obrigatória nunca satura por carga horária', () => {
	it('obrigatória fica no topo mesmo com a CH obrigatória zerada', () => {
		expect(pesoDaNatureza('obrigatoria', situacao({ obrigatoria: 0 }), false)).toBe(
			PESO_OBRIGATORIA
		);
	});

	it('obrigatória fica acima de optativa que ainda falta', () => {
		const s = situacao({ obrigatoria: 60, optativa: 300 });

		expect(pesoDaNatureza('obrigatoria', s, false)).toBeGreaterThan(
			pesoDaNatureza('optativa', s, false)
		);
	});
});

/**
 * "Optatória" é a optativa que é pré-requisito de uma obrigatória pendente: o
 * SIGAA a lista como optativa, mas sem ela o aluno não destrava o que precisa.
 * Descartá-la junto com as demais quando a carga optativa fecha o deixaria
 * travado numa obrigatória por causa de uma conta de horas já satisfeita.
 */
describe('pesoDaNatureza — optatória nunca satura', () => {
	it('sobe ao degrau da obrigatória mesmo com a carga optativa cumprida', () => {
		expect(pesoDaNatureza('optativa', situacao({ optativa: 0 }), true)).toBe(PESO_OBRIGATORIA);
	});

	it('sobe ao degrau da obrigatória mesmo sem situação nenhuma', () => {
		expect(pesoDaNatureza('optativa', null, true)).toBe(PESO_OBRIGATORIA);
	});
});

/**
 * Matéria cuja matriz não foi resolvida chega sem natureza. Antes valia como
 * optativa; o que não pode é sumir da grade por falta de dado.
 */
describe('pesoDaNatureza — matéria sem natureza declarada', () => {
	it('vale como necessária, nunca como saturada', () => {
		expect(pesoDaNatureza(undefined, situacao({ optativa: 0 }), false)).toBe(PESO_NECESSARIA);
		expect(pesoDaNatureza(undefined, null, false)).toBe(PESO_NECESSARIA);
	});
});

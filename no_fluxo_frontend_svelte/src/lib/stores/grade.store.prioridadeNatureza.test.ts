/**
 * Montador de Grade — a natureza da matéria manda na montagem automática.
 *
 * Regressão do relato "não considera as obrigatórias como prioridade, adiciona
 * optativa demais": `montarAutomatico` só pesava `cursandoAtual` (matrícula real)
 * e `prioritarias` (estrela do aluno). Obrigatória da matriz e optativa saíam com
 * o mesmo peso 1, então o branch-and-bound — que maximiza Σ peso — virava um
 * maximizador de CONTAGEM e trocava uma obrigatória por duas optativas sempre que
 * elas colidiam no horário.
 *
 * As duas últimas suítes montam pools a partir de grades reais de aluno da UnB
 * (CIC e FGA), com os horários exatamente como o SIGAA publica.
 */
import { describe, it, expect, beforeEach } from 'vitest';
import { gradeStore, type MateriaGrade } from './grade.store.svelte';
import { slotMaskFromHorario } from '$lib/utils/horario-slots';

let seq = 0;

/** Matéria com uma turma por horário informado. `horarios` vazio = sem oferta. */
function mat(
	codigo: string,
	horarios: string[],
	natureza: MateriaGrade['natureza'],
	creditos = 4
): MateriaGrade {
	const base = ++seq * 100;
	return {
		codigo,
		nome: codigo,
		creditos,
		idMateria: base,
		natureza,
		turmas: horarios.map((h, i) => ({
			mask: slotMaskFromHorario(h),
			turma: { id_turmas: base + i, horario: h, turma: String(i + 1).padStart(2, '0') } as never
		}))
	};
}

const obrig = (c: string, h: string[], cr = 4) => mat(c, h, 'obrigatoria', cr);
const optat = (c: string, h: string[], cr = 4) => mat(c, h, 'optativa', cr);
const livre = (c: string, h: string[], cr = 4) => mat(c, h, 'modulo_livre', cr);

/** Códigos selecionados, ordenados — comparação estável nos expects. */
function selecionados(): string[] {
	return [...gradeStore.selecao.keys()].sort();
}

function init(pool: MateriaGrade[]): void {
	gradeStore.init(pool, { idUser: null, periodo: '2026.2' });
}

beforeEach(() => {
	seq = 0;
	// `init` não zera `cursandoAtual` (ele vem da rota, depois do init) — sem isso
	// a marcação de um teste vazaria para o seguinte.
	gradeStore.definirCursandoAtual([]);
	init([]);
});

describe('montarAutomatico — obrigatória vence optativa', () => {
	it('mantém a obrigatória mesmo custando uma matéria a menos na grade', () => {
		// A obrigatória ocupa os dois horários que as optativas disputam: ou entra
		// ela sozinha, ou entram as duas optativas. Maximizar contagem escolhe as
		// optativas; maximizar formatura escolhe a obrigatória.
		init([obrig('CIC0007', ['2M12 4M12']), optat('OPT0001', ['2M12']), optat('OPT0002', ['4M12'])]);

		gradeStore.montarAutomatico();

		expect(selecionados()).toEqual(['CIC0007']);
	});

	it('encaixa a optativa no buraco que sobra, sem deslocar obrigatória', () => {
		init([obrig('CIC0007', ['2M12']), optat('OPT0001', ['3T12'])]);

		gradeStore.montarAutomatico();

		expect(selecionados()).toEqual(['CIC0007', 'OPT0001']);
	});

	it('gasta o orçamento de créditos nas obrigatórias antes das optativas', () => {
		// Teto de 8 créditos: cabem exatamente duas matérias de 4.
		init([
			optat('OPT0001', ['2M12']),
			optat('OPT0002', ['3M12']),
			obrig('CIC0007', ['4M12']),
			obrig('CIC0008', ['5M12'])
		]);

		gradeStore.montarAutomatico({ limiteCreditos: 8 });

		expect(selecionados()).toEqual(['CIC0007', 'CIC0008']);
		expect(gradeStore.creditosSelecionados).toBeLessThanOrEqual(8);
	});

	it('trata módulo livre com o mesmo peso de optativa (perde da obrigatória)', () => {
		init([obrig('CIC0007', ['2M12 4M12']), livre('CEM0054', ['2M12']), livre('LIP0096', ['4M12'])]);

		gradeStore.montarAutomatico();

		expect(selecionados()).toEqual(['CIC0007']);
	});

	it('não muda nada quando o pool não tem obrigatória: volta a maximizar contagem', () => {
		init([optat('OPT0001', ['2M12 4M12']), optat('OPT0002', ['2M12']), optat('OPT0003', ['4M12'])]);

		gradeStore.montarAutomatico();

		expect(selecionados()).toEqual(['OPT0002', 'OPT0003']);
	});

	it('pool sem natureza declarada continua funcionando (compatibilidade)', () => {
		init([mat('X0001', ['2M12'], undefined), mat('X0002', ['3M12'], undefined)]);

		const r = gradeStore.montarAutomatico();

		expect(r.naoAlocadas).toEqual([]);
		expect(selecionados()).toEqual(['X0001', 'X0002']);
	});
});

describe('montarAutomatico — hierarquia acima da natureza', () => {
	it('estrela do aluno numa optativa vence a obrigatória (escolha explícita)', () => {
		init([obrig('CIC0007', ['2M12 4M12']), optat('OPT0001', ['2M12']), optat('OPT0002', ['4M12'])]);
		gradeStore.togglePrioridade('OPT0001');
		gradeStore.togglePrioridade('OPT0002');

		gradeStore.montarAutomatico();

		expect(selecionados()).toEqual(['OPT0001', 'OPT0002']);
	});

	it('matéria já cursando (MATR) vence obrigatória da matriz', () => {
		init([obrig('CIC0007', ['2M12 4M12']), optat('OPT0001', ['2M12']), optat('OPT0002', ['4M12'])]);
		gradeStore.definirCursandoAtual(['OPT0001', 'OPT0002']);

		gradeStore.montarAutomatico();

		expect(selecionados()).toEqual(['OPT0001', 'OPT0002']);
	});
});

/**
 * Grade real de aluno de Ciência da Computação (6 matérias, 2026.2).
 * CIC0161 245T45 · CEM0054 35M12 · LIP0096 6M1234 · CIC0093 24M12 ·
 * CIC0202 35M34 · CIC0104 24M34
 */
describe('montarAutomatico — grade real CIC', () => {
	/** As 4 do núcleo de CIC são obrigatórias; CEM/LIP entram como módulo livre. */
	function poolCIC(): MateriaGrade[] {
		return [
			obrig('CIC0161', ['245T45']),
			obrig('CIC0093', ['24M12']),
			obrig('CIC0202', ['35M34']),
			obrig('CIC0104', ['24M34']),
			livre('CEM0054', ['35M12'], 2),
			livre('LIP0096', ['6M1234'])
		];
	}

	it('reproduz a grade do aluno inteira — nada conflita', () => {
		init(poolCIC());

		const r = gradeStore.montarAutomatico({ limiteCreditos: 24 });

		expect(r.naoAlocadas).toEqual([]);
		expect(selecionados()).toEqual([
			'CEM0054',
			'CIC0093',
			'CIC0104',
			'CIC0161',
			'CIC0202',
			'LIP0096'
		]);
	});

	it('com optativas disputando a manhã, as 4 obrigatórias do CIC continuam de pé', () => {
		// Seis optativas ocupando exatamente os horários das obrigatórias da manhã:
		// pela contagem pura, trocá-las seria empate ou vantagem.
		init([
			...poolCIC(),
			optat('OPT0101', ['2M12']),
			optat('OPT0102', ['4M12']),
			optat('OPT0103', ['2M34']),
			optat('OPT0104', ['4M34']),
			optat('OPT0105', ['3M34']),
			optat('OPT0106', ['5M34'])
		]);

		gradeStore.montarAutomatico({ limiteCreditos: 24 });

		for (const codigo of ['CIC0161', 'CIC0093', 'CIC0202', 'CIC0104']) {
			expect(gradeStore.selecao.has(codigo), codigo + ' deveria estar na grade').toBe(true);
		}
	});

	it('sob teto de 16 créditos, mantém obrigatória e corta o módulo livre', () => {
		init(poolCIC());

		gradeStore.montarAutomatico({ limiteCreditos: 16 });

		expect(selecionados()).toEqual(['CIC0093', 'CIC0104', 'CIC0161', 'CIC0202']);
	});
});

/**
 * Grade real de aluno de Engenharia de Software / FGA (4 matérias, 2026.2).
 * FGA0109 46M34 · FGA0173 35M12 · FGA0210 46T23 · FGA0314 35M34
 */
describe('montarAutomatico — grade real FGA', () => {
	function poolFGA(): MateriaGrade[] {
		return [
			obrig('FGA0109', ['46M34']),
			obrig('FGA0173', ['35M12'], 2),
			obrig('FGA0210', ['46T23']),
			obrig('FGA0314', ['35M34'])
		];
	}

	it('reproduz a grade do aluno — as 4 obrigatórias cabem juntas', () => {
		init(poolFGA());

		const r = gradeStore.montarAutomatico({ limiteCreditos: 24 });

		expect(r.naoAlocadas).toEqual([]);
		expect(selecionados()).toEqual(['FGA0109', 'FGA0173', 'FGA0210', 'FGA0314']);
	});

	it('optativa da tarde não desloca FGA0210, que só tem turma 46T23', () => {
		init([...poolFGA(), optat('OPT0201', ['46T23']), optat('OPT0202', ['2T23'])]);

		gradeStore.montarAutomatico({ limiteCreditos: 24 });

		expect(gradeStore.selecao.has('FGA0210')).toBe(true);
		expect(gradeStore.selecao.has('OPT0201')).toBe(false);
		// OPT0202 está livre na segunda à tarde: entra sem tirar ninguém.
		expect(gradeStore.selecao.has('OPT0202')).toBe(true);
	});

	it('teto de 14 créditos prioriza as obrigatórias mais baratas em crédito', () => {
		init([...poolFGA(), optat('OPT0201', ['2M12'], 2)]);

		gradeStore.montarAutomatico({ limiteCreditos: 14 });

		// 4+2+4+4 = 14 exatos nas obrigatórias; a optativa de 2 não cabe mais.
		expect(selecionados()).toEqual(['FGA0109', 'FGA0173', 'FGA0210', 'FGA0314']);
		expect(gradeStore.creditosSelecionados).toBe(14);
	});
});

/**
 * O slider de créditos usa uma segunda lista de prioridade, independente da do
 * solver — e ela também nasceu sem natureza. Encolher a grade pelo slider corta
 * primeiro quem tem mais crédito, o que na prática significa cortar obrigatória
 * (4cr) e preservar optativa (2cr): o mesmo defeito, por outro caminho.
 */
describe('ajustarParaLimite — o slider também respeita natureza', () => {
	it('corta a optativa antes da obrigatória, mesmo custando mais cortes', () => {
		// Obrigatória 4cr + duas optativas de 2cr = 8. Descer para 4 exige tirar 4
		// créditos: ou a obrigatória sozinha, ou as duas optativas.
		init([
			obrig('CIC0007', ['2M12'], 4),
			optat('OPT0001', ['3M12'], 2),
			optat('OPT0002', ['4M12'], 2)
		]);
		gradeStore.montarAutomatico();
		expect(gradeStore.creditosSelecionados).toBe(8);

		gradeStore.ajustarParaLimite(4);

		expect(selecionados()).toEqual(['CIC0007']);
	});

	it('entre optativas, tira a de mais crédito — sai menos matéria', () => {
		init([
			optat('OPT0001', ['2M12'], 6),
			optat('OPT0002', ['3M12'], 2),
			optat('OPT0003', ['4M12'], 2)
		]);
		gradeStore.montarAutomatico();

		gradeStore.ajustarParaLimite(4);

		expect(selecionados()).toEqual(['OPT0002', 'OPT0003']);
	});

	it('só corta obrigatória quando não sobrou optativa para cortar', () => {
		init([obrig('CIC0007', ['2M12'], 4), obrig('CIC0008', ['3M12'], 4)]);
		gradeStore.montarAutomatico();

		gradeStore.ajustarParaLimite(4);

		expect(gradeStore.creditosSelecionados).toBeLessThanOrEqual(4);
		expect(gradeStore.selecao.size).toBe(1);
	});

	it('a estrela do aluno sobrevive ao corte de uma obrigatória', () => {
		init([obrig('CIC0007', ['2M12'], 4), optat('OPT0001', ['3M12'], 4)]);
		gradeStore.montarAutomatico();
		gradeStore.togglePrioridade('OPT0001');

		gradeStore.ajustarParaLimite(4);

		expect(selecionados()).toEqual(['OPT0001']);
	});

	it('nunca corta matéria que o aluno já está cursando', () => {
		init([obrig('CIC0007', ['2M12'], 4), optat('OPT0001', ['3M12'], 4)]);
		gradeStore.definirCursandoAtual(['OPT0001']);
		gradeStore.montarAutomatico();

		gradeStore.ajustarParaLimite(2);

		expect(gradeStore.selecao.has('OPT0001')).toBe(true);
	});
});

/**
 * A ordem em que as matérias entram no pool é acidente: vem do plano de formatura,
 * das buscas do aluno e do chat, em ordem de inserção. O resultado da montagem não
 * pode depender dela.
 *
 * Era exatamente o que segurava o defeito de pé: com todos os pesos em 1 o sort do
 * solver é estável, então quem chegasse primeiro vencia — e como
 * `candidatosDaMatriz` já entrega obrigatória-primeiro, a montagem acertava por
 * acidente por um caminho e errava por todos os outros.
 */
describe('montarAutomatico — o resultado não depende da ordem do pool', () => {
	/** Mesmo conjunto, 4 ordens diferentes de entrada. */
	function permutacoes(): MateriaGrade[][] {
		const base = () => [
			obrig('CIC0007', ['2M12 4M12']),
			obrig('CIC0008', ['3M34']),
			optat('OPT0001', ['2M12']),
			optat('OPT0002', ['4M12']),
			optat('OPT0003', ['3M34'])
		];
		const p = base();
		return [
			p,
			[...base()].reverse(),
			(() => {
				const b = base();
				return [b[2], b[3], b[4], b[0], b[1]];
			})(),
			(() => {
				const b = base();
				return [b[4], b[0], b[2], b[1], b[3]];
			})()
		];
	}

	it('todas as ordens produzem a mesma grade', () => {
		const resultados = permutacoes().map((pool) => {
			init(pool);
			gradeStore.montarAutomatico({ limiteCreditos: 24 });
			return selecionados().join(',');
		});

		expect(
			new Set(resultados).size,
			`ordens divergiram: ${[...new Set(resultados)].join(' ≠ ')}`
		).toBe(1);
		// E o resultado certo é o das duas obrigatórias, não o das três optativas.
		expect(resultados[0]).toBe('CIC0007,CIC0008');
	});
});

/** Casos de borda em que a prioridade por natureza não pode atropelar outra regra. */
describe('montarAutomatico — bordas da prioridade por natureza', () => {
	it('obrigatória sem oferta vai para naoAlocadas sem derrubar as outras', () => {
		init([obrig('CIC0007', []), optat('OPT0001', ['2M12'])]);

		const r = gradeStore.montarAutomatico();

		expect(r.naoAlocadas).toEqual(['CIC0007']);
		expect(selecionados()).toEqual(['OPT0001']);
	});

	it('obrigatória troca de turma em vez de sair quando a primeira conflita', () => {
		init([optat('OPT0001', ['2M12']), obrig('CIC0007', ['2M12', '5T34'])]);

		gradeStore.montarAutomatico();

		expect(selecionados()).toEqual(['CIC0007', 'OPT0001']);
		expect(gradeStore.selecao.get('CIC0007')?.turma.horario).toBe('5T34');
	});

	it('o filtro de turno é rígido: obrigatória fora do turno fica de fora', () => {
		// Regra deliberada — o aluno que só pode de manhã não quer uma grade à noite.
		init([obrig('CIC0007', ['2N12']), optat('OPT0001', ['2M12'])]);
		gradeStore.setTurnos(['M']);

		const r = gradeStore.montarAutomatico();

		expect(r.naoAlocadas).toEqual(['CIC0007']);
		expect(selecionados()).toEqual(['OPT0001']);
		gradeStore.setTurnos(['M', 'T', 'N']);
	});

	it('docente obrigatório continua sendo filtro rígido, inclusive para obrigatória', () => {
		const cic = obrig('CIC0007', ['2M12', '4M12']);
		cic.turmas[0].turma = { ...cic.turmas[0].turma, docente: 'ANA SOUZA' } as never;
		cic.turmas[1].turma = { ...cic.turmas[1].turma, docente: 'BRUNO LIMA' } as never;
		init([cic, optat('OPT0001', ['4M12'])]);

		gradeStore.montarAutomatico({ docentesObrigatorios: { CIC0007: 'ANA SOUZA' } });

		expect(gradeStore.selecao.get('CIC0007')?.turma.horario).toBe('2M12');
		expect(gradeStore.selecao.has('OPT0001')).toBe(true);
	});

	it('obrigatória se encaixa em volta da turma travada, sem tentar movê-la', () => {
		init([optat('OPT0001', ['2M12']), obrig('CIC0007', ['2M12', '3T12'])]);
		// Cursando + turma escolhida na mão = travada: o solver não pode mexer nela.
		gradeStore.definirCursandoAtual(['OPT0001']);
		gradeStore.selecionarTurma('OPT0001', gradeStore.pool[0].turmas[0].turma.id_turmas);
		gradeStore.definirCursandoAtual(['OPT0001']);

		gradeStore.montarAutomatico();

		expect(gradeStore.selecao.get('OPT0001')?.turma.horario).toBe('2M12');
		expect(gradeStore.selecao.get('CIC0007')?.turma.horario).toBe('3T12');
	});

	it('empate entre obrigatórias é resolvido, não trava a montagem', () => {
		init([obrig('CIC0007', ['2M12']), obrig('CIC0008', ['2M12'])]);

		const r = gradeStore.montarAutomatico();

		expect(gradeStore.selecao.size).toBe(1);
		expect(r.naoAlocadas.length).toBe(1);
	});
});

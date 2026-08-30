import { describe, it, expect, beforeEach, vi } from 'vitest';
import type { IntegralizacaoResult } from '$lib/types/matriz';

/**
 * A tradução de `IntegralizacaoResult` para o vocabulário do Montador, e a
 * regra que sustenta tudo o mais: dado ruim vira `null`, nunca `0`.
 *
 * A diferença importa porque `0` significa "essa carga já está cumprida, pare de
 * recomendar" — afirmar isso a partir de um PDF que não trouxe o número faria o
 * montador esconder do aluno justamente a matéria que ele ainda precisa.
 */

/** O que `getIntegralizacao` devolve neste teste. `null` = falhou. */
let resultado: IntegralizacaoResult | null = null;
/** Quantas vezes o serviço foi chamado — para provar a memoização. */
let chamadas = 0;

vi.mock('$lib/services/integralizacao.service', () => ({
	getIntegralizacao: async () => {
		chamadas++;
		if (resultado === null) throw new Error('falhou');
		return resultado;
	}
}));

let matrizCurricular: string | null = '6360/1 - 2017.1';

vi.mock('$lib/stores/auth', () => ({
	authStore: {
		getUser: () => ({ idUser: 1, dadosFluxograma: { matrizCurricular } })
	}
}));

vi.mock('$lib/stores/fluxograma.store.svelte', () => ({
	fluxogramaStore: {
		get state() {
			return { courseData: { equivalencias: [] } };
		},
		get cargaHorariaIntegralizada() {
			return cargaPdf;
		}
	}
}));

let cargaPdf: { obrigatoria: number; optativa: number; complementar: number; total: number } | null =
	null;

const { carregarSituacao, saturada, invalidarSituacao } = await import(
	'./situacao-academica.service'
);

/** Um `IntegralizacaoResult` com os números que o teste quer, e nada de surpresa. */
function integralizacao(opts: {
	exigido: [number, number, number];
	realizado: [number, number, number];
}): IntegralizacaoResult {
	const [eo, ep, ec] = opts.exigido;
	const [ro, rp, rc] = opts.realizado;
	const faltar = (e: number, r: number) => Math.max(0, e - r);
	return {
		curriculoCompleto: '6360/1 - 2017.1',
		idMatriz: 1,
		idCurso: 1,
		exigido: { chObrigatoria: eo, chOptativa: ep, chComplementar: ec, chTotal: eo + ep + ec },
		realizado: { chObrigatoria: ro, chOptativa: rp, chComplementar: rc, chTotal: ro + rp + rc },
		faltam: {
			chObrigatoria: faltar(eo, ro),
			chOptativa: faltar(ep, rp),
			chComplementar: faltar(ec, rc),
			chTotal: faltar(eo + ep + ec, ro + rp + rc)
		},
		codigosObrigatorios: [],
		codigosConcluidos: [],
		pctObrigatoria: 0,
		pctOptativa: 0,
		pctComplementar: 0,
		pctTotal: 0
	};
}

beforeEach(() => {
	chamadas = 0;
	matrizCurricular = '6360/1 - 2017.1';
	cargaPdf = { obrigatoria: 1920, optativa: 360, complementar: 0, total: 2280 };
	resultado = integralizacao({ exigido: [2400, 360, 120], realizado: [1920, 360, 0] });
	invalidarSituacao();
});

describe('carregarSituacao', () => {
	it('traduz as três naturezas, com complementar virando módulo livre', async () => {
		const s = await carregarSituacao();

		expect(s?.faltam.obrigatoria).toBe(480);
		expect(s?.faltam.optativa).toBe(0);
		expect(s?.faltam.modulo_livre).toBe(120);
		expect(s?.exigido.modulo_livre).toBe(120);
	});

	it('memoiza: a segunda chamada não vai ao banco de novo', async () => {
		await carregarSituacao();
		await carregarSituacao();

		expect(chamadas).toBe(1);
	});

	it('devolve null quando o aluno não tem matriz', async () => {
		matrizCurricular = null;

		expect(await carregarSituacao()).toBeNull();
		expect(chamadas).toBe(0);
	});

	it('devolve null quando a integralização falha, sem propagar o erro', async () => {
		resultado = null;

		await expect(carregarSituacao()).resolves.toBeNull();
	});

	/**
	 * A matriz que não exige carga complementar nenhuma não deve render pergunta
	 * de módulo livre — perguntar seria inventar uma exigência que o curso não faz.
	 */
	it('marca exigeModuloLivre=false quando a matriz não exige complementar', async () => {
		resultado = integralizacao({ exigido: [2400, 360, 0], realizado: [1920, 360, 0] });

		const s = await carregarSituacao();

		expect(s?.exigeModuloLivre).toBe(false);
	});

	it('marca exigeModuloLivre=true quando a matriz exige e ainda falta', async () => {
		const s = await carregarSituacao();

		expect(s?.exigeModuloLivre).toBe(true);
	});
});

/**
 * `getGradeByMatriz` nunca classifica uma disciplina como "complementar", então
 * a CH complementar realizada só é confiável quando veio do PDF do SIGAA. Sem
 * essa distinção o montador diria "faltam 120h de módulo livre" para quem já
 * cumpriu tudo — o número existiria, só estaria errado.
 */
describe('confiabilidade da carga complementar', () => {
	it('é confiável quando o PDF do SIGAA trouxe carga integralizada', async () => {
		const s = await carregarSituacao();

		expect(s?.complementarConfiavel).toBe(true);
		expect(s?.faltam.modulo_livre).toBe(120);
	});

	it('sem PDF, o faltante de módulo livre é null em vez de um número inventado', async () => {
		cargaPdf = null;

		const s = await carregarSituacao();

		expect(s?.complementarConfiavel).toBe(false);
		expect(s?.faltam.modulo_livre).toBeNull();
		// As outras duas continuam válidas: elas têm fonte pela grade da matriz.
		expect(s?.faltam.obrigatoria).toBe(480);
	});

	it('PDF zerado por completo conta como ausente', async () => {
		cargaPdf = { obrigatoria: 0, optativa: 0, complementar: 0, total: 0 };

		const s = await carregarSituacao();

		expect(s?.complementarConfiavel).toBe(false);
		expect(s?.faltam.modulo_livre).toBeNull();
	});
});

describe('saturada', () => {
	it('natureza com faltante zero está saturada', async () => {
		const s = await carregarSituacao();

		expect(saturada(s, 'optativa')).toBe(true);
	});

	it('natureza que ainda falta não está saturada', async () => {
		const s = await carregarSituacao();

		expect(saturada(s, 'obrigatoria')).toBe(false);
	});

	/** O ponto central: desconhecido nunca satura, ou o montador esconderia matéria. */
	it('faltante desconhecido (null) NUNCA satura', async () => {
		cargaPdf = null;

		const s = await carregarSituacao();

		expect(s?.faltam.modulo_livre).toBeNull();
		expect(saturada(s, 'modulo_livre')).toBe(false);
	});

	it('sem situação nenhuma, nada satura — o montador volta ao comportamento antigo', () => {
		expect(saturada(null, 'obrigatoria')).toBe(false);
		expect(saturada(null, 'optativa')).toBe(false);
		expect(saturada(null, 'modulo_livre')).toBe(false);
	});
});

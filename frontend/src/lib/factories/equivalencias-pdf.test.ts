import { describe, it, expect } from 'vitest';
import { injetarEquivalenciasDoPdf } from '$lib/factories';
import type { DadosFluxogramaUser } from '$lib/types/user';

/**
 * Cenário real: histórico 231026330 (Eng. Software 2017.1) declara na seção
 * "Equivalências:" seis pares "Cumpriu X através de Y". O casamento via banco
 * pode não conhecer todos — os pares do PDF são a fonte oficial de fallback.
 */
function fluxoBase(): DadosFluxogramaUser {
	return {
		nomeCurso: 'ENGENHARIA DE SOFTWARE',
		ira: 3.71,
		matricula: '231026330',
		horasIntegralizadas: 2100,
		suspensoes: [],
		anoAtual: '2026.2',
		matrizCurricular: '6360/1 - 2017.1',
		semestreAtual: 8,
		dadosFluxograma: [
			[
				{
					codigoMateria: 'FGA0307',
					mencao: 'SS',
					professor: 'MARIO',
					status: 'APR',
					anoPeriodo: '2026.1'
				},
				// Par já resolvido pelo banco: entrada de equivalência pré-existente.
				{
					codigoMateria: 'FGA0147',
					mencao: 'MM',
					professor: '',
					status: 'CUMP',
					tipoDado: 'equivalencia',
					codigoEquivalente: 'FGA0146'
				}
			]
		]
	};
}

const PARES_PDF = [
	{ cumpriu: 'FGA0184', atraves_de: 'FGA0307', nome_cumpriu: 'GESTÃO DA PRODUÇÃO E QUALIDADE' },
	{ cumpriu: 'FGA0150', atraves_de: 'FGA0303', nome_cumpriu: 'PROJETO INTEGRADOR DE ENGENHARIA 1' },
	{ cumpriu: 'FGA0138', atraves_de: 'FGA0312' },
	{ cumpriu: 'FGA0147', atraves_de: 'FGA0146' }, // já coberto pelo banco — não duplica
	{ cumpriu: 'FGA0172', atraves_de: 'FGA0313' },
	{ cumpriu: 'FGA0278', atraves_de: 'FGA0315', nome_equivalente: 'QUALIDADE DE SOFTWARE 1' }
];

describe('injetarEquivalenciasDoPdf', () => {
	it('injeta pares do histórico como entradas CUMP/equivalencia', () => {
		const dados = fluxoBase();
		injetarEquivalenciasDoPdf(dados, PARES_PDF);

		const todas = dados.dadosFluxograma.flat();
		const fga0184 = todas.find((m) => m.codigoMateria === 'FGA0184');
		expect(fga0184).toBeDefined();
		expect(fga0184!.status).toBe('CUMP');
		expect(fga0184!.tipoDado).toBe('equivalencia');
		expect(fga0184!.codigoEquivalente).toBe('FGA0307');
		expect(fga0184!.nomeMateria).toBe('GESTÃO DA PRODUÇÃO E QUALIDADE');
	});

	it('não duplica par que o banco já resolveu', () => {
		const dados = fluxoBase();
		injetarEquivalenciasDoPdf(dados, PARES_PDF);

		const fga0147 = dados.dadosFluxograma.flat().filter((m) => m.codigoMateria === 'FGA0147');
		expect(fga0147).toHaveLength(1);
	});

	it('guarda a lista bruta para auditoria', () => {
		const dados = fluxoBase();
		injetarEquivalenciasDoPdf(dados, PARES_PDF);

		expect(dados.equivalenciasPdf).toHaveLength(6);
		expect(dados.equivalenciasPdf![0]).toEqual({
			cumpriu: 'FGA0184',
			atravesDe: 'FGA0307',
			nomeCumpriu: 'GESTÃO DA PRODUÇÃO E QUALIDADE',
			nomeEquivalente: null
		});
	});

	it('injeta os 5 pares pendentes (todos menos o já coberto)', () => {
		const dados = fluxoBase();
		injetarEquivalenciasDoPdf(dados, PARES_PDF);

		const codigos = dados.dadosFluxograma.flat().map((m) => m.codigoMateria);
		for (const cod of ['FGA0184', 'FGA0150', 'FGA0138', 'FGA0172', 'FGA0278']) {
			expect(codigos).toContain(cod);
		}
	});

	it('ignora entrada vazia ou malformada sem quebrar', () => {
		const dados = fluxoBase();
		injetarEquivalenciasDoPdf(dados, undefined);
		injetarEquivalenciasDoPdf(dados, []);
		injetarEquivalenciasDoPdf(dados, [{ cumpriu: '', atraves_de: 'X' }, null, 'lixo']);

		expect(dados.dadosFluxograma.flat()).toHaveLength(2);
		expect(dados.equivalenciasPdf).toBeUndefined();
	});
});

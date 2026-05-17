/**
 * Indicativo de elegibilidade à mudança de curso (UnB — referência institucional):
 * não substitui edital PPC / SIGAA; usa grade + histórico carregados no NoFluxo.
 */

import { fluxogramaService } from '$lib/services/fluxograma.service';
import type { IntegralizacaoResult } from '$lib/types/matriz';
import type { DadosFluxogramaUser } from '$lib/types/user';
import { getCompletedSubjectCodes } from '$lib/types/user';
import { getCompletedByEquivalenceCodes } from '$lib/types/equivalencia';
import type { EquivalenciaModel } from '$lib/types/equivalencia';
import { isOptativa } from '$lib/types/materia';

/** Carga mínima (h) em disciplinas obrigatórias e/ou optativas do destino conforme norma citada pela coordenação. */
export const CH_MINIMA_CURSO_DESTINO_MUDANCA = 360;

export type AvaliacaoIntegralizacaoOrigem = {
	podeAvaliar: boolean;
	/** Obrigatórias nos semestres 1 e 2 da matriz oficial (níveis 1 e 2 na grade). */
	obrigatoriosPeriodos12Total: number;
	obrigatoriosConcluidos: number;
	codigosPendentes: string[];
	/** null se não há base para concluir (ex.: sem grade). */
	atendeIntegralizacaoOrigem: boolean | null;
};

export type AvaliacaoIntegralizacaoDestino = {
	/** Soma CH obrigatória + optativa integralizada no destino (simulação). */
	horasObrigatoriasEOptativas: number;
	minimoHorasInstitucional: number;
	atendeCargaDestino: boolean;
};

export type AvaliacaoMudancaCurso = {
	origem: AvaliacaoIntegralizacaoOrigem;
	destino: AvaliacaoIntegralizacaoDestino;
};

/** Expande códigos concluídos + equivalentes declarados na matriz de origem. */
function montarCodigosContamParaGrade(codes: Set<string>, equivalencias: EquivalenciaModel[]): Set<string> {
	const expanded = new Set<string>();
	const upper = [...codes].map((c) => String(c).trim().toUpperCase()).filter(Boolean);
	for (const c of upper) expanded.add(c);
	for (const c of getCompletedByEquivalenceCodes(equivalencias, codes)) expanded.add(String(c).trim().toUpperCase());
	return expanded;
}

/**
 * Avalia dois eixos: (origem) obrigatórias 1º e 2º períodos conforme níveis 1–2 na grade;
 * (destino) ≥360h em obrig + optativa contabilizadas na integralização da simulação.
 */
export async function avaliarRequisitosMudancaCurso(
	dadosFluxograma: DadosFluxogramaUser,
	integralizacaoDestino: IntegralizacaoResult | null
): Promise<AvaliacaoMudancaCurso | null> {
	if (!integralizacaoDestino) return null;

	const horasDestino =
		Math.round((integralizacaoDestino.realizado.chObrigatoria + integralizacaoDestino.realizado.chOptativa) * 10) /
		10;

	const destino: AvaliacaoIntegralizacaoDestino = {
		horasObrigatoriasEOptativas: horasDestino,
		minimoHorasInstitucional: CH_MINIMA_CURSO_DESTINO_MUDANCA,
		atendeCargaDestino: horasDestino >= CH_MINIMA_CURSO_DESTINO_MUDANCA
	};

	const ccOrigem = (dadosFluxograma.matrizCurricular ?? '').trim();
	if (!ccOrigem) {
		return {
			origem: {
				podeAvaliar: false,
				obrigatoriosPeriodos12Total: 0,
				obrigatoriosConcluidos: 0,
				codigosPendentes: [],
				atendeIntegralizacaoOrigem: null
			},
			destino
		};
	}

	let origemPartial: AvaliacaoIntegralizacaoOrigem = {
		podeAvaliar: false,
		obrigatoriosPeriodos12Total: 0,
		obrigatoriosConcluidos: 0,
		codigosPendentes: [],
		atendeIntegralizacaoOrigem: null
	};

	try {
		const cursoOrigem = await fluxogramaService.getCourseDataByCurriculoCompleto(ccOrigem);

		const obrigatoriasPrimeirosPeriodos = cursoOrigem.materias.filter((m) => {
			const n = Number(m.nivel);
			if (!Number.isFinite(n) || n < 1 || n > 2) return false;
			return !isOptativa(m);
		});

		const codigosReq = obrigatoriasPrimeirosPeriodos
			.map((m) => String(m.codigoMateria ?? '').trim().toUpperCase())
			.filter(Boolean);

		const uniqueReq = [...new Set(codigosReq)];

		if (uniqueReq.length === 0) {
			origemPartial = {
				podeAvaliar: false,
				obrigatoriosPeriodos12Total: 0,
				obrigatoriosConcluidos: 0,
				codigosPendentes: [],
				atendeIntegralizacaoOrigem: null
			};
			return { origem: origemPartial, destino };
		}

		const concluded = getCompletedSubjectCodes(dadosFluxograma);
		const conta = montarCodigosContamParaGrade(concluded, cursoOrigem.equivalencias ?? []);

		const pendentes = uniqueReq.filter((c) => !conta.has(c));
		const concluidos = uniqueReq.length - pendentes.length;

		origemPartial = {
			podeAvaliar: true,
			obrigatoriosPeriodos12Total: uniqueReq.length,
			obrigatoriosConcluidos: concluidos,
			codigosPendentes: pendentes,
			atendeIntegralizacaoOrigem: pendentes.length === 0
		};
	} catch {
		origemPartial = {
			podeAvaliar: false,
			obrigatoriosPeriodos12Total: 0,
			obrigatoriosConcluidos: 0,
			codigosPendentes: [],
			atendeIntegralizacaoOrigem: null
		};
	}

	return { origem: origemPartial, destino };
}

/**
 * Serviço global de integralização.
 * Compara exigido (matrizes) vs realizado (PDF) e retorna pronto para o front.
 * A porcentagem é calculada aqui no backend (Node.js), não no banco.
 */

import { SupabaseWrapper } from '../supabase_wrapper';

export interface CargaHorariaIntegralizada {
	obrigatoria: number;
	optativa: number;
	complementar: number;
	total: number;
}

function pct(exigido: number, realizado: number): number {
	if (exigido <= 0) return 0;
	return Math.min(100, Math.round((realizado / exigido) * 100));
}

export interface IntegralizacaoResult {
	curriculoCompleto: string;
	idMatriz: number;
	idCurso: number;
	exigido: { chObrigatoria: number; chOptativa: number; chComplementar: number; chTotal: number };
	realizado: { chObrigatoria: number; chOptativa: number; chComplementar: number; chTotal: number };
	faltam: { chObrigatoria: number; chOptativa: number; chComplementar: number; chTotal: number };
	pctObrigatoria: number;
	pctOptativa: number;
	pctComplementar: number;
	pctTotal: number;
}

export async function calcularIntegralizacao(
	curriculoCompleto: string,
	cargaHorariaIntegralizada: CargaHorariaIntegralizada | null
): Promise<IntegralizacaoResult | null> {
	if (!curriculoCompleto?.trim() || !cargaHorariaIntegralizada) return null;

	const cc = curriculoCompleto.trim();

	// Busca matriz por curriculo_completo exato
	let { data: matriz, error } = await SupabaseWrapper.get()
		.from('matrizes')
		.select('id_matriz, id_curso, curriculo_completo, ch_obrigatoria_exigida, ch_optativa_exigida, ch_complementar_exigida, ch_total_exigida')
		.eq('curriculo_completo', cc)
		.maybeSingle();

	if (error) throw new Error(`Erro ao buscar matriz: ${error.message}`);

	// Fallback: match por prefixo (ex: "6360/1" -> "6360/1 - 2017.1")
	if (!matriz && cc.includes('/')) {
		const prefix = cc.split(' - ')[0]?.trim() ?? cc;
		const { data: rows } = await SupabaseWrapper.get()
			.from('matrizes')
			.select('id_matriz, id_curso, curriculo_completo, ch_obrigatoria_exigida, ch_optativa_exigida, ch_complementar_exigida, ch_total_exigida')
			.like('curriculo_completo', prefix + '%')
			.order('curriculo_completo')
			.limit(1);
		matriz = rows?.[0] ?? null;
	}

	if (!matriz) return null;

	const exObr = matriz.ch_obrigatoria_exigida ?? 0;
	const exOpt = matriz.ch_optativa_exigida ?? 0;
	const exCompl = matriz.ch_complementar_exigida ?? 0;
	const exTotal = matriz.ch_total_exigida ?? 0;

	const reObr = cargaHorariaIntegralizada.obrigatoria ?? 0;
	const reOpt = cargaHorariaIntegralizada.optativa ?? 0;
	const reCompl = cargaHorariaIntegralizada.complementar ?? 0;
	const reTotal = cargaHorariaIntegralizada.total > 0
		? cargaHorariaIntegralizada.total
		: reObr + reOpt + reCompl;

	return {
		curriculoCompleto: matriz.curriculo_completo,
		idMatriz: matriz.id_matriz,
		idCurso: matriz.id_curso,
		exigido: { chObrigatoria: exObr, chOptativa: exOpt, chComplementar: exCompl, chTotal: exTotal },
		realizado: { chObrigatoria: reObr, chOptativa: reOpt, chComplementar: reCompl, chTotal: reTotal },
		faltam: {
			chObrigatoria: Math.max(0, exObr - reObr),
			chOptativa: Math.max(0, exOpt - reOpt),
			chComplementar: Math.max(0, exCompl - reCompl),
			chTotal: Math.max(0, exTotal - reTotal)
		},
		pctObrigatoria: pct(exObr, reObr),
		pctOptativa: pct(exOpt, reOpt),
		pctComplementar: pct(exCompl, reCompl),
		pctTotal: pct(exTotal, reTotal)
	};
}

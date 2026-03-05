/**
 * Endpoint de integralização: compara CH do PDF vs exigido da matriz (Supabase).
 * Não depende do backend Node — calcula direto aqui.
 */
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

const supabaseUrl = PUBLIC_SUPABASE_URL;
const supabaseKey = PUBLIC_SUPABASE_ANON_KEY;

function pct(exigido: number, realizado: number): number {
	if (exigido <= 0) return 0;
	return Math.min(100, Math.round((realizado / exigido) * 100));
}

export const POST: RequestHandler = async ({ request }) => {
	try {
		const body = await request.json();
		const { curriculoCompleto, cargaHorariaIntegralizada } = body;
		if (!curriculoCompleto?.trim() || !cargaHorariaIntegralizada) {
			return json({ error: 'curriculoCompleto e cargaHorariaIntegralizada são obrigatórios' }, { status: 400 });
		}

		const cc = String(curriculoCompleto).trim();
		const supabase = createClient(supabaseUrl, supabaseKey);

		// Busca matriz por curriculo_completo exato
		let { data: matriz, error } = await supabase
			.from('matrizes')
			.select('id_matriz, id_curso, curriculo_completo, ch_obrigatoria_exigida, ch_optativa_exigida, ch_complementar_exigida, ch_total_exigida')
			.eq('curriculo_completo', cc)
			.maybeSingle();

		if (error) throw new Error(`Erro ao buscar matriz: ${error.message}`);

		// Fallback: match por prefixo (ex: "6360/1" -> "6360/1 - 2017.1")
		if (!matriz && cc.includes('/')) {
			const prefix = cc.split(' - ')[0]?.trim() ?? cc;
			const { data: rows } = await supabase
				.from('matrizes')
				.select('id_matriz, id_curso, curriculo_completo, ch_obrigatoria_exigida, ch_optativa_exigida, ch_complementar_exigida, ch_total_exigida')
				.like('curriculo_completo', prefix + '%')
				.order('curriculo_completo')
				.limit(1);
			matriz = rows?.[0] ?? null;
		}

		if (!matriz) {
			return json({ error: 'Matriz não encontrada para o currículo informado' }, { status: 404 });
		}

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

		const result = {
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

		return json(result);
	} catch (err) {
		console.error('[api/integralizacao]', err);
		return json(
			{ error: err instanceof Error ? err.message : 'Erro ao calcular integralização' },
			{ status: 500 }
		);
	}
};

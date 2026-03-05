/**
 * Serviço central de Integralização: compara Exigido (da matriz) vs Realizado (aluno).
 * Quando cargaHorariaIntegralizada está disponível (PDF), chama o backend para cálculo centralizado.
 * Caso contrário, usa Supabase + grade para somar disciplinas concluídas.
 */

import { supabaseDataService } from '$lib/services/supabase-data.service';
import type { IntegralizacaoResult, MatrizModel } from '$lib/types/matriz';
import type { DadosFluxogramaUser } from '$lib/types/user';
import type { CargaHorariaIntegralizada } from '$lib/types/user';
import { getCompletedSubjectCodes } from '$lib/types/user';
import { getCompletedByEquivalenceCodes } from '$lib/types/equivalencia';
import type { EquivalenciaModel } from '$lib/types/equivalencia';

export interface IntegralizacaoInput {
	/** curriculo_completo (ex: "8117/-2 - 2018.2") para buscar a matriz. */
	curriculoCompleto: string;
	/** Dados do histórico do aluno (disciplinas concluídas). */
	dadosFluxograma: DadosFluxogramaUser | null;
	/** Carga horária integralizada do PDF (SIGAA). Só usar quando for o curso do usuário — em mudança de curso, recalcular. */
	cargaHorariaIntegralizada?: CargaHorariaIntegralizada | null;
	/** Equivalências aplicáveis (gerais + específicas da matriz) para expandir concluídas. */
	equivalencias?: EquivalenciaModel[];
	/** Se true, ignora cargaHorariaIntegralizada e sempre calcula a partir das disciplinas casadas (para simulação de outro curso). */
	recalcularPorDisciplinas?: boolean;
}

/** Classificação da disciplina na grade: obrigatória (nivel >= 1) ou optativa (nivel 0). */
type CategoriaCH = 'obrigatoria' | 'optativa' | 'complementar';

interface GradeItem {
	codigoMateria: string;
	cargaHoraria: number;
	categoria: CategoriaCH;
}

/**
 * Retorna o JSON de integralização: Exigido (matriz) vs Realizado (soma das concluídas).
 */
function pct(exigido: number, realizado: number): number {
	if (exigido <= 0) return 0;
	return Math.min(100, Math.round((realizado / exigido) * 100));
}

export async function getIntegralizacao(input: IntegralizacaoInput): Promise<IntegralizacaoResult | null> {
	const { curriculoCompleto, dadosFluxograma, cargaHorariaIntegralizada, equivalencias = [], recalcularPorDisciplinas = false } = input;

	// Quando temos cargaHorariaIntegralizada do PDF e NÃO é simulação de outro curso, usa o backend
	const temChPdf = !recalcularPorDisciplinas && cargaHorariaIntegralizada && (cargaHorariaIntegralizada.total > 0 || cargaHorariaIntegralizada.obrigatoria > 0 || cargaHorariaIntegralizada.optativa > 0 || (cargaHorariaIntegralizada.complementar ?? 0) > 0);
	if (temChPdf && curriculoCompleto?.trim()) {
		try {
			const res = await fetch('/api/integralizacao', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ curriculoCompleto: curriculoCompleto.trim(), cargaHorariaIntegralizada })
			});
			if (res.ok) {
				const data = (await res.json()) as IntegralizacaoResult & { codigosObrigatorios?: string[]; codigosConcluidos?: string[] };
				return {
					...data,
					codigosObrigatorios: data.codigosObrigatorios ?? [],
					codigosConcluidos: data.codigosConcluidos ?? []
				};
			}
		} catch {
			// Fallback para lógica local em caso de erro
		}
	}

	const matriz = await supabaseDataService.getMatrizByCurriculoCompleto(curriculoCompleto);
	if (!matriz) return null;

	const grade = await supabaseDataService.getGradeByMatriz(matriz.idMatriz);
	if (!grade || grade.length === 0) {
		return buildResultZeroRealizado(matriz, [], []);
	}

	const codigosObrigatorios = grade.filter((g) => g.categoria === 'obrigatoria').map((g) => g.codigoMateria);
	const completedCodes = dadosFluxograma ? getCompletedSubjectCodes(dadosFluxograma) : new Set<string>();
	const completedByEquiv = getCompletedByEquivalenceCodes(equivalencias, completedCodes);
	const codesThatCount = new Set<string>([...completedCodes, ...completedByEquiv]);

	let chObrigatoriaRealizado: number;
	let chOptativaRealizado: number;
	let chComplementarRealizado: number;

	if (!recalcularPorDisciplinas && cargaHorariaIntegralizada && (cargaHorariaIntegralizada.total > 0 || cargaHorariaIntegralizada.obrigatoria > 0 || cargaHorariaIntegralizada.optativa > 0)) {
		chObrigatoriaRealizado = cargaHorariaIntegralizada.obrigatoria ?? 0;
		chOptativaRealizado = cargaHorariaIntegralizada.optativa ?? 0;
		chComplementarRealizado = cargaHorariaIntegralizada.complementar ?? 0;
	} else {
		chObrigatoriaRealizado = 0;
		chOptativaRealizado = 0;
		chComplementarRealizado = 0;
		for (const item of grade) {
			const concluida = codesThatCount.has(item.codigoMateria) || [...codesThatCount].some((c) => c.toUpperCase() === item.codigoMateria.toUpperCase());
			if (!concluida) continue;

			if (item.categoria === 'obrigatoria') chObrigatoriaRealizado += item.cargaHoraria;
			else if (item.categoria === 'optativa') chOptativaRealizado += item.cargaHoraria;
			else chComplementarRealizado += item.cargaHoraria;
		}
	}

	const exigido = {
		chObrigatoria: matriz.chObrigatoriaExigida ?? 0,
		chOptativa: matriz.chOptativaExigida ?? 0,
		chComplementar: matriz.chComplementarExigida ?? 0,
		chTotal: matriz.chTotalExigida ?? 0
	};

	const chTotalRealizado =
		!recalcularPorDisciplinas && cargaHorariaIntegralizada && cargaHorariaIntegralizada.total > 0
			? cargaHorariaIntegralizada.total
			: chObrigatoriaRealizado + chOptativaRealizado + chComplementarRealizado;

	const realizado = {
		chObrigatoria: chObrigatoriaRealizado,
		chOptativa: chOptativaRealizado,
		chComplementar: chComplementarRealizado,
		chTotal: chTotalRealizado
	};

	const faltam = {
		chObrigatoria: Math.max(0, exigido.chObrigatoria - realizado.chObrigatoria),
		chOptativa: Math.max(0, exigido.chOptativa - realizado.chOptativa),
		chComplementar: Math.max(0, exigido.chComplementar - realizado.chComplementar),
		chTotal: Math.max(0, exigido.chTotal - realizado.chTotal)
	};

	return {
		curriculoCompleto: matriz.curriculoCompleto,
		idMatriz: matriz.idMatriz,
		idCurso: matriz.idCurso,
		exigido,
		realizado,
		faltam,
		codigosObrigatorios,
		codigosConcluidos: [...codesThatCount],
		pctObrigatoria: pct(exigido.chObrigatoria, realizado.chObrigatoria),
		pctOptativa: pct(exigido.chOptativa, realizado.chOptativa),
		pctComplementar: pct(exigido.chComplementar, realizado.chComplementar),
		pctTotal: pct(exigido.chTotal, realizado.chTotal)
	};
}

function buildResultZeroRealizado(
	matriz: MatrizModel,
	codigosObrigatorios: string[],
	codigosConcluidos: string[]
): IntegralizacaoResult {
	const exigido = {
		chObrigatoria: matriz.chObrigatoriaExigida ?? 0,
		chOptativa: matriz.chOptativaExigida ?? 0,
		chComplementar: matriz.chComplementarExigida ?? 0,
		chTotal: matriz.chTotalExigida ?? 0
	};
	return {
		curriculoCompleto: matriz.curriculoCompleto,
		idMatriz: matriz.idMatriz,
		idCurso: matriz.idCurso,
		exigido,
		realizado: { chObrigatoria: 0, chOptativa: 0, chComplementar: 0, chTotal: 0 },
		faltam: { ...exigido },
		codigosObrigatorios,
		codigosConcluidos,
		pctObrigatoria: 0,
		pctOptativa: 0,
		pctComplementar: 0,
		pctTotal: 0
	};
}

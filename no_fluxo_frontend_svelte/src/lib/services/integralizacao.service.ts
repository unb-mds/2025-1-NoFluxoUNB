/**
 * Serviço central de Integralização: compara Exigido (da matriz) vs Realizado (aluno).
 * Usa apenas ch_* da tabela matrizes como verdade oficial (SIGAA).
 * Realizado = soma das cargas horárias das disciplinas integralizadas (considerando equivalências).
 */

import { supabaseDataService } from '$lib/services/supabase-data.service';
import type { IntegralizacaoResult, MatrizModel } from '$lib/types/matriz';
import type { DadosFluxogramaUser } from '$lib/types/user';
import { getCompletedSubjectCodes } from '$lib/types/user';
import { getCompletedByEquivalenceCodes } from '$lib/types/equivalencia';
import type { EquivalenciaModel } from '$lib/types/equivalencia';

export interface IntegralizacaoInput {
	/** curriculo_completo (ex: "8117/-2 - 2018.2") para buscar a matriz. */
	curriculoCompleto: string;
	/** Dados do histórico do aluno (disciplinas concluídas). */
	dadosFluxograma: DadosFluxogramaUser | null;
	/** Equivalências aplicáveis (gerais + específicas da matriz) para expandir concluídas. */
	equivalencias?: EquivalenciaModel[];
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
export async function getIntegralizacao(input: IntegralizacaoInput): Promise<IntegralizacaoResult | null> {
	const { curriculoCompleto, dadosFluxograma, equivalencias = [] } = input;

	const matriz = await supabaseDataService.getMatrizByCurriculoCompleto(curriculoCompleto);
	if (!matriz) return null;

	const grade = await supabaseDataService.getGradeByMatriz(matriz.idMatriz);
	if (!grade || grade.length === 0) {
		return buildResultZeroRealizado(matriz, [], []);
	}

	const completedCodes = dadosFluxograma ? getCompletedSubjectCodes(dadosFluxograma) : new Set<string>();
	const completedByEquiv = getCompletedByEquivalenceCodes(equivalencias, completedCodes);
	const codesThatCount = new Set<string>([...completedCodes, ...completedByEquiv]);

	const codigosObrigatorios = grade.filter((g) => g.categoria === 'obrigatoria').map((g) => g.codigoMateria);
	const codigosOptativas = grade.filter((g) => g.categoria === 'optativa').map((g) => g.codigoMateria);

	let chObrigatoriaRealizado = 0;
	let chOptativaRealizado = 0;
	let chComplementarRealizado = 0;

	for (const item of grade) {
		const concluida = codesThatCount.has(item.codigoMateria) || [...codesThatCount].some((c) => c.toUpperCase() === item.codigoMateria.toUpperCase());
		if (!concluida) continue;

		if (item.categoria === 'obrigatoria') chObrigatoriaRealizado += item.cargaHoraria;
		else if (item.categoria === 'optativa') chOptativaRealizado += item.cargaHoraria;
		else chComplementarRealizado += item.cargaHoraria;
	}

	const exigido = {
		chObrigatoria: matriz.chObrigatoriaExigida ?? 0,
		chOptativa: matriz.chOptativaExigida ?? 0,
		chComplementar: matriz.chComplementarExigida ?? 0,
		chTotal: matriz.chTotalExigida ?? 0
	};

	const realizado = {
		chObrigatoria: chObrigatoriaRealizado,
		chOptativa: chOptativaRealizado,
		chComplementar: chComplementarRealizado,
		chTotal: chObrigatoriaRealizado + chOptativaRealizado + chComplementarRealizado
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
		codigosConcluidos: [...codesThatCount]
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
		codigosConcluidos
	};
}

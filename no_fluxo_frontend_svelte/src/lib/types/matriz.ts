/**
 * Matriz curricular e integralização (exigido vs realizado).
 * Regras: Curso = entidade base; Matriz = variação (curriculo_completo é o identificador único).
 * CH oficial vem de matrizes (SIGAA): ch_obrigatoria_exigida, ch_optativa_exigida, etc.
 */

export interface MatrizModel {
	idMatriz: number;
	idCurso: number;
	curriculoCompleto: string;
	versao: string;
	anoVigor: string | null;
	chObrigatoriaExigida: number | null;
	chOptativaExigida: number | null;
	chComplementarExigida: number | null;
	chTotalExigida: number | null;
}

/** Carga horária por categoria (fonte: carga_horaria_integralizada jsonb). */
export interface CargaHoraria {
	obrigatoria: number;
	optativa: number;
	complementar: number;
	total: number;
}

/** Converte horas em créditos (1 crédito = 15h). */
export function horasParaCreditos(horas: number): number {
	return Math.round((horas / 15) * 10) / 10;
}

/** Exigido pela matriz (fonte: SIGAA) vs realizado pelo aluno (soma das disciplinas concluídas). */
export interface IntegralizacaoCategoria {
	exigido: number;
	realizado: number;
	faltam: number;
}

export interface IntegralizacaoResult {
	curriculoCompleto: string;
	idMatriz: number;
	idCurso: number;
	/** Valores oficiais da matriz (não calculados manualmente). */
	exigido: {
		chObrigatoria: number;
		chOptativa: number;
		chComplementar: number;
		chTotal: number;
	};
	/** Soma das cargas horárias das disciplinas integralizadas pelo aluno. */
	realizado: {
		chObrigatoria: number;
		chOptativa: number;
		chComplementar: number;
		chTotal: number;
	};
	/** Exigido - realizado (quanto falta). */
	faltam: {
		chObrigatoria: number;
		chOptativa: number;
		chComplementar: number;
		chTotal: number;
	};
	/** Códigos das disciplinas da grade consideradas obrigatórias (nivel > 0). */
	codigosObrigatorios: string[];
	/** Códigos concluídos (aprovados) pelo aluno. */
	codigosConcluidos: string[];
	/** Percentuais de integralização (realizado/exigido * 100). */
	pctObrigatoria: number;
	pctOptativa: number;
	pctComplementar: number;
	pctTotal: number;
	/** CH de optativas planejadas no fluxo (ainda não concluídas no histórico), contadas na grade como optativa. */
	chOptativaPlanejada?: number;
	/** % optativa considerando realizado + planejado vs exigido. */
	pctOptativaComPlanejamento?: number;
	/** Faltam horas de optativa após realizado + planejado. */
	faltamChOptativaAposPlanejamento?: number;
}

/** Decomposição do curriculo_completo para exibição/filtro: "8117/-2 - 2018.2" ou "8117/-2 - 2018.2 - DIURNO" -> codigo "8117", versao "-2", ano "2018.2". */
export function parseCurriculoCompleto(curriculoCompleto: string): {
	codigoCurso: string;
	versao: string;
	ano: string;
} {
	const s = (curriculoCompleto || '').trim();
	// Remove sufixo de turno ( - DIURNO / - NOTURNO) para parsing
	const sNorm = s.replace(/\s*-\s*(DIURNO|NOTURNO)\s*$/i, '').trim();
	const beforeBar = sNorm.split('/')[0]?.trim() ?? '';
	const afterBar = sNorm.split('/')[1]?.trim() ?? '';
	const match = afterBar.match(/\s*-\s*(\d{4}\.\d)\s*$/);
	const ano = match ? match[1] : '';
	const versao = match ? afterBar.replace(/\s*-\s*\d{4}\.\d\s*$/, '').trim() : afterBar;
	return {
		codigoCurso: beforeBar,
		versao,
		ano
	};
}

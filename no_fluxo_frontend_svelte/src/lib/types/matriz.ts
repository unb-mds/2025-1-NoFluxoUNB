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
}

/** Decomposição do curriculo_completo para exibição/filtro: "8117/-2 - 2018.2" -> codigo "8117", versao "-2", ano "2018.2". */
export function parseCurriculoCompleto(curriculoCompleto: string): {
	codigoCurso: string;
	versao: string;
	ano: string;
} {
	const s = (curriculoCompleto || '').trim();
	const beforeBar = s.split('/')[0]?.trim() ?? '';
	const afterBar = s.split('/')[1]?.trim() ?? '';
	const match = afterBar.match(/\s*-\s*(\d{4}\.\d)\s*$/);
	const ano = match ? match[1] : '';
	const versao = match ? afterBar.replace(/\s*-\s*\d{4}\.\d\s*$/, '').trim() : afterBar;
	return {
		codigoCurso: beforeBar,
		versao,
		ano
	};
}

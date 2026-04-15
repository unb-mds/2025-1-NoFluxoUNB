/**
 * User-related type definitions
 * Uses camelCase convention for TypeScript
 */

export type SubjectStatus = 'APR' | 'CUMP' | 'DISP' | 'MATR' | 'REP' | 'TRC' | 'PLANEJADO' | '-';

export type GradeMention = 'SS' | 'MS' | 'MM' | 'MI' | 'II' | 'SR' | '-';

/** Optativas colocadas no fluxograma pelo usuário (persistido em dados_users / localStorage). */
export interface OptativaPlanejadaRef {
	codigoMateria: string;
	semestre: number;
}

export interface DadosMateria {
	codigoMateria: string;
	mencao: GradeMention | string;
	professor: string;
	status: SubjectStatus | string;
	anoPeriodo?: string | null;
	frequencia?: string | null;
	tipoDado?: string | null;
	turma?: string | null;
	/** Quando concluída por equivalência: código da disciplina cursada (equivalente). */
	codigoEquivalente?: string | null;
	/** Quando concluída por equivalência: nome da disciplina cursada (equivalente). */
	nomeEquivalente?: string | null;
	/** Inclusão manual do usuário (não vem do histórico oficial). */
	isManual?: boolean;
	/** Nível (semestre) em que a matéria deve ser alocada. */
	nivelDestino?: number | string | null;
	/** Nível oficial de origem da matriz (quando conhecido). */
	nivel?: number | string | null;
	/** Alias serializado para compatibilidade com payloads legados/externos. */
	nivelAlocado?: number | string | null;
}

export interface DadosFluxogramaUser {
	nomeCurso: string;
	ira: number;
	/** Texto do IRA como no histórico (ex. "4,1234") — exibição fiel. */
	iraTexto?: string | null;
	matricula: string;
	horasIntegralizadas: number;
	suspensoes: string[];
	anoAtual: string;
	matrizCurricular: string;
	semestreAtual: number;
	dadosFluxograma: DadosMateria[][];
	/** Planejamento de optativas no fluxograma (semestre + código). */
	optativasPlanejadas?: OptativaPlanejadaRef[];
}

export interface OptativaManual {
	codigo: string;
	nivelAlocado: number;
	status: 'PLANEJADO' | 'CUMP' | 'APR' | string;
	nome?: string | null;
}

/** Carga horária integralizada extraída do PDF (SIGAA). */
export interface CargaHorariaIntegralizada {
	obrigatoria: number;
	optativa: number;
	complementar: number;
	total: number;
}

export interface UserModel {
	idUser: number;
	email: string;
	nomeCompleto: string;
	dadosFluxograma?: DadosFluxogramaUser | null;
	optativasManuais?: OptativaManual[];
	/** Carga horária integralizada do histórico (obrigatória, optativa, complementar). */
	cargaHorariaIntegralizada?: CargaHorariaIntegralizada | null;
	token?: string | null;
}

export function isMateriaCursada(dadosMateria: DadosMateria): boolean {
	const status = String(dadosMateria.status ?? '').trim().toUpperCase();
	return status === 'APR' || status === 'CUMP' || status === 'DISP';
}

export function isMateriaAprovada(dadosMateria: DadosMateria): boolean {
	const mencao = String(dadosMateria.mencao ?? '-').trim().toUpperCase();
	const status = String(dadosMateria.status ?? '-').trim().toUpperCase();
	return (
		mencao === 'SS' ||
		mencao === 'MM' ||
		mencao === 'MS' ||
		status === 'APR' ||
		status === 'CUMP' ||
		status === 'DISP'
	);
}

export function isMateriaCurrent(dadosMateria: DadosMateria): boolean {
	return String(dadosMateria.status ?? '').trim().toUpperCase() === 'MATR';
}

export function isMateriaCompletedOrCurrent(dadosMateria: DadosMateria): boolean {
	return isMateriaAprovada(dadosMateria) || isMateriaCurrent(dadosMateria);
}

export function getCompletedSubjectCodes(dados: DadosFluxogramaUser): Set<string> {
	const completed = new Set<string>();
	for (const semester of dados.dadosFluxograma) {
		for (const materia of semester) {
			if (isMateriaAprovada(materia)) {
				const code = materia.codigoMateria ?? (materia as unknown as { codigo?: string }).codigo ?? '';
				if (code) completed.add(code);
				// Inclui codigoEquivalente para casamento em outros cursos (ex.: cursou MAT0035, conta como MAT1234)
				const eq = materia.codigoEquivalente ?? (materia as unknown as { codigo_equivalente?: string }).codigo_equivalente ?? '';
				if (eq && eq !== code) completed.add(eq);
			}
		}
	}
	return completed;
}

export function getCurrentSubjectCodes(dados: DadosFluxogramaUser): Set<string> {
	const current = new Set<string>();
	for (const semester of dados.dadosFluxograma) {
		for (const materia of semester) {
			if (isMateriaCurrent(materia)) {
				current.add(materia.codigoMateria);
			}
		}
	}
	return current;
}

export function getCompletedOrCurrentSubjectCodes(dados: DadosFluxogramaUser): Set<string> {
	const codes = new Set<string>();
	for (const semester of dados.dadosFluxograma) {
		for (const materia of semester) {
			if (isMateriaCompletedOrCurrent(materia)) {
				codes.add(materia.codigoMateria);
			}
		}
	}
	return codes;
}

export function findSubjectInFluxograma(
	dados: DadosFluxogramaUser,
	codigoMateria: string
): DadosMateria | null {
	let fallback: DadosMateria | null = null;
	const codeUpper = codigoMateria.trim().toUpperCase();
	for (const semester of dados.dadosFluxograma) {
		for (const materia of semester) {
			const code = materia.codigoMateria ?? (materia as unknown as { codigo?: string }).codigo ?? '';
			if (code.trim().toUpperCase() !== codeUpper) continue;
			if (isMateriaAprovada(materia) && materia.tipoDado === 'equivalencia') return materia;
			if (isMateriaAprovada(materia) && !fallback) fallback = materia;
			if (!fallback) fallback = materia;
		}
	}
	return fallback;
}

export function getTotalCreditsCompleted(
	dados: DadosFluxogramaUser,
	creditsMap: Map<string, number>
): number {
	let total = 0;
	for (const semester of dados.dadosFluxograma) {
		for (const materia of semester) {
			if (isMateriaAprovada(materia) && creditsMap.has(materia.codigoMateria)) {
				total += creditsMap.get(materia.codigoMateria)!;
			}
		}
	}
	return total;
}

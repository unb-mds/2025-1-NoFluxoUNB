/**
 * User-related type definitions
 * Uses camelCase convention for TypeScript
 */

export type SubjectStatus = 'APR' | 'CUMP' | 'MATR' | 'REP' | 'TRC' | '-';

export type GradeMention = 'SS' | 'MS' | 'MM' | 'MI' | 'II' | 'SR' | '-';

export interface DadosMateria {
	codigoMateria: string;
	mencao: GradeMention | string;
	professor: string;
	status: SubjectStatus | string;
	anoPeriodo?: string | null;
	frequencia?: string | null;
	tipoDado?: string | null;
	turma?: string | null;
}

export interface DadosFluxogramaUser {
	nomeCurso: string;
	ira: number;
	matricula: string;
	horasIntegralizadas: number;
	suspensoes: string[];
	anoAtual: string;
	matrizCurricular: string;
	semestreAtual: number;
	dadosFluxograma: DadosMateria[][];
}

export interface UserModel {
	idUser: number;
	email: string;
	nomeCompleto: string;
	dadosFluxograma?: DadosFluxogramaUser | null;
	token?: string | null;
}

export function isMateriaCursada(dadosMateria: DadosMateria): boolean {
	const status = String(dadosMateria.status ?? '').trim().toUpperCase();
	return status === 'APR' || status === 'CUMP';
}

export function isMateriaAprovada(dadosMateria: DadosMateria): boolean {
	const mencao = String(dadosMateria.mencao ?? '-').trim().toUpperCase();
	const status = String(dadosMateria.status ?? '-').trim().toUpperCase();
	return (
		mencao === 'SS' ||
		mencao === 'MM' ||
		mencao === 'MS' ||
		(status === 'APR' && mencao !== '-') ||
		status === 'CUMP'
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
	for (const semester of dados.dadosFluxograma) {
		for (const materia of semester) {
			if (materia.codigoMateria === codigoMateria) {
				return materia;
			}
		}
	}
	return null;
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

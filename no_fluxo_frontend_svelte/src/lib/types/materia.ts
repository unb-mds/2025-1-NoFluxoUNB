/**
 * Subject/Course unit type definitions
 */

import type { CursoModel, PreRequisitoModel } from './curso';
import { satisfazPreRequisitos } from './curso';
import { evaluateExpressaoLogicaWithResolver } from '$lib/utils/expressao-logica';

export interface MateriaModel {
	ementa: string;
	idMateria: number;
	nomeMateria: string;
	codigoMateria: string;
	nivel: number;
	/** materias_por_curso.tipo_natureza: 0=obrigatória, 1=optativa. Prioridade sobre nivel para classificação. */
	tipoNatureza?: number | null;
	creditos: number;
	status?: string | null;
	mencao?: string | null;
	professor?: string | null;
	preRequisitos?: MateriaModel[];
}

export const SubjectStatusEnum = {
	NOT_STARTED: 'not_started',
	IN_PROGRESS: 'in_progress',
	COMPLETED: 'completed',
	FAILED: 'failed',
	AVAILABLE: 'available',
	LOCKED: 'locked'
} as const;

export type SubjectStatusValue = (typeof SubjectStatusEnum)[keyof typeof SubjectStatusEnum];

/** Optativa: tipo_natureza=1 (materias_por_curso). Fallback: nivel=0 quando tipo_natureza ausente. */
export function isOptativa(materia: MateriaModel): boolean {
	if (materia.tipoNatureza !== undefined && materia.tipoNatureza !== null) return materia.tipoNatureza === 1;
	return materia.nivel === 0;
}

export function getPrerequisiteCodes(materia: MateriaModel): string[] {
	return materia.preRequisitos?.map((m) => m.codigoMateria) ?? [];
}

export function getPrerequisiteNames(materia: MateriaModel): string[] {
	return materia.preRequisitos?.map((m) => m.nomeMateria) ?? [];
}

export function hasPrerequisites(materia: MateriaModel): boolean {
	return (materia.preRequisitos?.length ?? 0) > 0;
}

export function hasAnyPrerequisitesNotCompletedOrCurrent(
	materia: MateriaModel,
	completedCodes: Set<string>,
	currentCodes: Set<string>
): boolean {
	if (!hasPrerequisites(materia)) {
		return false;
	}

	const allCompletedOrCurrent = new Set([...completedCodes, ...currentCodes]);

	for (const prereq of materia.preRequisitos!) {
		if (!allCompletedOrCurrent.has(prereq.codigoMateria)) {
			return true;
		}
	}

	return false;
}

export function hasPrerequisite(materia: MateriaModel, codigoMateria: string): boolean {
	return materia.preRequisitos?.some((m) => m.codigoMateria === codigoMateria) ?? false;
}

export function getTotalPrerequisiteCredits(materia: MateriaModel): number {
	return materia.preRequisitos?.reduce((sum, m) => sum + m.creditos, 0) ?? 0;
}

export function canBeTaken(materia: MateriaModel, completedMateriasCodes: Set<string>): boolean {
	if (!hasPrerequisites(materia)) return true;

	return materia.preRequisitos!.every((prereq) =>
		setHasCodeIgnoreCase(completedMateriasCodes, prereq.codigoMateria)
	);
}

function setHasCodeIgnoreCase(codes: Set<string>, code: string): boolean {
	if (codes.has(code)) return true;
	const codeUpper = code.trim().toUpperCase();
	return [...codes].some((c) => c.trim().toUpperCase() === codeUpper);
}

export function determineSubjectStatus(
	materia: MateriaModel,
	completedCodes: Set<string>,
	currentCodes: Set<string>,
	failedCodes: Set<string>,
	curso?: CursoModel | null
): SubjectStatusValue {
	const code = materia.codigoMateria;

	// Concluída tem prioridade: no histórico ou por equivalência (com ou sem diferença de casing)
	if (setHasCodeIgnoreCase(completedCodes, code)) {
		return SubjectStatusEnum.COMPLETED;
	}

	if (currentCodes.has(code)) {
		return SubjectStatusEnum.IN_PROGRESS;
	}

	if (failedCodes.has(code)) {
		return SubjectStatusEnum.FAILED;
	}

	// Pré-requisitos: usa expressao_logica (curso) quando existir, senão materia.preRequisitos
	const prereqsParaMateria = curso?.preRequisitos?.filter((pr) => pr.idMateria === materia.idMateria) ?? [];
	const podeCursar =
		prereqsParaMateria.length > 0
			? satisfazPreRequisitos(prereqsParaMateria, completedCodes)
			: canBeTaken(materia, completedCodes);

	if (podeCursar) {
		return SubjectStatusEnum.AVAILABLE;
	}

	return SubjectStatusEnum.LOCKED;
}

/**
 * Para cada código: se na matriz for **optativa**, só conta o que está no **histórico** (`historicoAprovados`);
 * obrigatórias usam `aprovadosComEquivalencia` (como no fluxograma — inclui equivalências da matriz).
 */
function codigoAprovadoParaPreRequisitoRegistroOptativa(
	codigo: string,
	curso: CursoModel,
	historicoAprovados: Set<string>,
	aprovadosComEquivalencia: Set<string>
): boolean {
	const u = codigo.trim().toUpperCase();
	const m = curso.materias.find((x) => x.codigoMateria.trim().toUpperCase() === u);
	if (m && isOptativa(m)) {
		return setHasCodeIgnoreCase(historicoAprovados, codigo);
	}
	return setHasCodeIgnoreCase(aprovadosComEquivalencia, codigo);
}

function satisfazPreRequisitosRegistroOptativaConcluida(
	preRequisitosParaMateria: PreRequisitoModel[],
	curso: CursoModel,
	historicoAprovados: Set<string>,
	aprovadosComEquivalencia: Set<string>
): boolean {
	const resolver = (code: string) =>
		codigoAprovadoParaPreRequisitoRegistroOptativa(code, curso, historicoAprovados, aprovadosComEquivalencia);
	const vistos = new Set<number>();
	for (const pr of preRequisitosParaMateria) {
		if (pr.expressaoLogica != null) {
			if (vistos.has(pr.idPreRequisito)) continue;
			vistos.add(pr.idPreRequisito);
			if (!evaluateExpressaoLogicaWithResolver(pr.expressaoLogica, resolver)) return false;
		} else {
			const code = (pr.codigoMateriaRequisito || '').trim();
			if (!code) return false;
			if (!resolver(code)) return false;
		}
	}
	return true;
}

function canBeTakenRegistroOptativaConcluida(
	materia: MateriaModel,
	aprovadosComEquivalencia: Set<string>,
	historicoAprovados: Set<string>,
	curso: CursoModel | null | undefined
): boolean {
	if (!hasPrerequisites(materia)) return true;
	if (!curso) {
		return canBeTaken(materia, aprovadosComEquivalencia);
	}
	return materia.preRequisitos!.every((prereq) =>
		codigoAprovadoParaPreRequisitoRegistroOptativa(
			prereq.codigoMateria,
			curso,
			historicoAprovados,
			aprovadosComEquivalencia
		)
	);
}

/**
 * Validação para registrar optativa como **concluída** no histórico local.
 * - `aprovadosComEquivalencia`: como no fluxograma (histórico + equivalências da matriz).
 * - `historicoAprovados`: só o que veio do PDF/histórico (`getCompletedSubjectCodes`), sem “preencher” códigos de matriz.
 *
 * Assim, pré-requisito que é **optativa** exige disciplina aprovada de verdade (ou equivalente registrado no histórico),
 * não basta equivalência da matriz que marcaria a célula como verde.
 */
export function prerequisitosAprovadosParaRegistrarConcluida(
	materia: MateriaModel,
	aprovadosComEquivalencia: Set<string>,
	historicoAprovados: Set<string>,
	curso?: CursoModel | null
): boolean {
	const prereqsParaMateria = curso?.preRequisitos?.filter((pr) => pr.idMateria === materia.idMateria) ?? [];
	if (prereqsParaMateria.length > 0 && curso) {
		return satisfazPreRequisitosRegistroOptativaConcluida(
			prereqsParaMateria,
			curso,
			historicoAprovados,
			aprovadosComEquivalencia
		);
	}
	return canBeTakenRegistroOptativaConcluida(materia, aprovadosComEquivalencia, historicoAprovados, curso);
}

export function getStatusColorClass(status: SubjectStatusValue): string {
	const colorMap: Record<SubjectStatusValue, string> = {
		[SubjectStatusEnum.COMPLETED]: 'bg-green-500',
		[SubjectStatusEnum.IN_PROGRESS]: 'bg-blue-500',
		[SubjectStatusEnum.FAILED]: 'bg-red-500',
		[SubjectStatusEnum.AVAILABLE]: 'bg-yellow-500',
		[SubjectStatusEnum.LOCKED]: 'bg-gray-400',
		[SubjectStatusEnum.NOT_STARTED]: 'bg-gray-300'
	};
	return colorMap[status];
}

export function getStatusLabel(status: SubjectStatusValue): string {
	const labelMap: Record<SubjectStatusValue, string> = {
		[SubjectStatusEnum.COMPLETED]: 'Aprovado',
		[SubjectStatusEnum.IN_PROGRESS]: 'Matriculado',
		[SubjectStatusEnum.FAILED]: 'Reprovado',
		[SubjectStatusEnum.AVAILABLE]: 'Disponível',
		[SubjectStatusEnum.LOCKED]: 'Bloqueado',
		[SubjectStatusEnum.NOT_STARTED]: 'Não iniciado'
	};
	return labelMap[status];
}

export interface OptativaAdicionada {
	materia: MateriaModel;
	semestre: number;
}

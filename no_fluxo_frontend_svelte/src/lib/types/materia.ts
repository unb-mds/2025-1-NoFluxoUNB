/**
 * Subject/Course unit type definitions
 */

import type { CursoModel } from './curso';
import { satisfazPreRequisitos } from './curso';

export interface MateriaModel {
	ementa: string;
	idMateria: number;
	nomeMateria: string;
	codigoMateria: string;
	nivel: number;
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

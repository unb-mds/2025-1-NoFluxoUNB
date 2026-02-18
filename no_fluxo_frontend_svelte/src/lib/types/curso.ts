/**
 * Course type definitions
 */

import type { MateriaModel } from './materia';
import type { EquivalenciaModel } from './equivalencia';

export interface PreRequisitoModel {
	idPreRequisito: number;
	idMateria: number;
	idMateriaRequisito: number;
	codigoMateriaRequisito: string;
	nomeMateriaRequisito: string;
}

export interface CoRequisitoModel {
	idCoRequisito: number;
	idMateria: number;
	idMateriaCoRequisito: number;
	codigoMateriaCoRequisito: string;
	nomeMateriaCoRequisito: string;
}

export type CourseType = 'graduacao' | 'pos-graduacao' | 'tecnico' | 'outro';
export type CourseClassification = 'obrigatoria' | 'optativa' | 'modulo_livre' | 'outro';

export interface CursoModel {
	nomeCurso: string;
	matrizCurricular: string;
	idCurso: number;
	totalCreditos: number | null;
	classificacao: CourseClassification | string;
	tipoCurso: CourseType | string;
	materias: MateriaModel[];
	semestres: number;
	equivalencias: EquivalenciaModel[];
	preRequisitos: PreRequisitoModel[];
	coRequisitos: CoRequisitoModel[];
}

export interface MinimalCursoModel {
	nomeCurso: string;
	matrizCurricular: string;
	idCurso: number;
	creditos: number | null;
	tipoCurso: CourseType | string;
	classificacao: CourseClassification | string;
}

export function getCourseSubjectCodes(curso: CursoModel): Set<string> {
	return new Set(curso.materias.map((m) => m.codigoMateria));
}

export function getSubjectsBySemester(curso: CursoModel): Map<number, MateriaModel[]> {
	const semesterMap = new Map<number, MateriaModel[]>();

	for (const materia of curso.materias) {
		if (!semesterMap.has(materia.nivel)) {
			semesterMap.set(materia.nivel, []);
		}
		semesterMap.get(materia.nivel)!.push(materia);
	}

	return semesterMap;
}

export function getDirectPrerequisites(
	curso: CursoModel,
	codigoMateria: string
): MateriaModel[] {
	const materiaMap = new Map(curso.materias.map((m) => [m.codigoMateria, m]));
	const directPrereqs: MateriaModel[] = [];

	const materia = curso.materias.find((m) => m.codigoMateria === codigoMateria);
	if (!materia) return [];

	for (const preReq of curso.preRequisitos) {
		if (preReq.idMateria === materia.idMateria) {
			const prerequisiteMateria = materiaMap.get(preReq.codigoMateriaRequisito);
			if (prerequisiteMateria) {
				directPrereqs.push(prerequisiteMateria);
			}
		}
	}

	return directPrereqs;
}

export function getCorequisites(curso: CursoModel, codigoMateria: string): MateriaModel[] {
	const materiaMap = new Map(curso.materias.map((m) => [m.codigoMateria, m]));
	const coreqs: MateriaModel[] = [];

	const materia = curso.materias.find((m) => m.codigoMateria === codigoMateria);
	if (!materia) return [];

	for (const coReq of curso.coRequisitos) {
		if (coReq.idMateria === materia.idMateria) {
			const coreqMateria = materiaMap.get(coReq.codigoMateriaCoRequisito);
			if (coreqMateria) {
				coreqs.push(coreqMateria);
			}
		}
	}

	return coreqs;
}

export function filterPrerequisitesInCourse(
	preRequisitos: PreRequisitoModel[],
	courseSubjectCodes: Set<string>
): PreRequisitoModel[] {
	return preRequisitos.filter((pr) => courseSubjectCodes.has(pr.codigoMateriaRequisito));
}

export function calculateMaxSemester(materias: MateriaModel[]): number {
	return materias.reduce((max, m) => Math.max(max, m.nivel), 0);
}

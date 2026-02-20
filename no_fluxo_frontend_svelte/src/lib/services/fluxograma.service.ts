import { supabaseDataService } from './supabase-data.service';
import type {
	CursoModel,
	MinimalCursoModel,
	PreRequisitoModel,
	CoRequisitoModel
} from '$lib/types/curso';
import type { MateriaModel } from '$lib/types/materia';
import type { EquivalenciaModel } from '$lib/types/equivalencia';
import {
	createMateriaModelFromJson,
	createPreRequisitoModelFromJson,
	createCoRequisitoModelFromJson,
	createEquivalenciaModelFromJson
} from '$lib/factories';

/**
 * Fluxograma service — wraps SupabaseDataService for course/subject data.
 * All queries go directly to Supabase with RLS (no backend calls).
 *
 * See plan 14 (SUPABASE-DIRECT-RLS.md) for architecture details.
 */

class FluxogramaService {
	/**
	 * Get all courses (minimal info for index page)
	 * REPLACES: GET /cursos/all-cursos
	 */
	async getAllCursos(): Promise<MinimalCursoModel[]> {
		const data = await supabaseDataService.getCursosComCreditos();
		return (data || []).map((c: Record<string, unknown>, index: number) => {
			const creditos =
				c.creditos_totais != null
					? Number(c.creditos_totais)
					: c.ch_total_exigida != null
						? Math.floor(Number(c.ch_total_exigida) / 15)
						: c.creditos != null
							? Number(c.creditos)
							: null;
			const rawId = c.id_curso;
			const idCurso =
				rawId != null && rawId !== '' && !Number.isNaN(Number(rawId))
					? Number(rawId)
					: index;
			return {
				nomeCurso: String(c.nome_curso ?? ''),
				matrizCurricular: String(c.curriculo_completo ?? ''),
				idCurso,
				creditos,
				classificacao: '',
				tipoCurso: String(c.tipo_curso ?? '')
			};
		});
	}

	/**
	 * Get full course flowchart data by curriculo_completo (identificador único da matriz).
	 */
	async getCourseDataByCurriculoCompleto(curriculoCompleto: string): Promise<CursoModel> {
		if (!curriculoCompleto?.trim()) throw new Error('curriculo_completo não informado');
		const raw = await supabaseDataService.getCourseFlowchartDataByCurriculoCompleto(curriculoCompleto.trim());
		return this.buildCursoModelFromRaw(raw);
	}

	/**
	 * Get full course flowchart data (subjects, prereqs, equivalencies)
	 * REPLACES: GET /fluxograma/fluxograma?nome_curso=...
	 */
	async getCourseData(courseName: string): Promise<CursoModel> {
		if (!courseName) throw new Error('Nome do curso não informado');
		const raw = await supabaseDataService.getCourseFlowchartData(courseName);
		console.log('[FluxogramaService] Raw data loaded for', courseName, {
			curso: raw.curso?.nome_curso,
			materias: raw.materias?.length ?? 0,
			preRequisitos: raw.preRequisitos?.length ?? 0,
			coRequisitos: raw.coRequisitos?.length ?? 0,
			equivalencias: raw.equivalencias?.length ?? 0
		});
		return this.buildCursoModelFromRaw(raw);
	}

	private buildCursoModelFromRaw(raw: {
		curso: Record<string, unknown>;
		materias: unknown[];
		preRequisitos: unknown[];
		coRequisitos: unknown[];
		equivalencias: unknown[];
		matriz?: { curriculo_completo?: string } | null;
	}): CursoModel {
		const materias: MateriaModel[] = (raw.materias || []).map((mc) =>
			createMateriaModelFromJson(mc as Record<string, unknown>)
		);
		const preRequisitos: PreRequisitoModel[] = (raw.preRequisitos || []).map((pr) =>
			createPreRequisitoModelFromJson(pr as Record<string, unknown>)
		);
		const coRequisitos: CoRequisitoModel[] = (raw.coRequisitos || []).map((cr) =>
			createCoRequisitoModelFromJson(cr as Record<string, unknown>)
		);
		const equivalencias: EquivalenciaModel[] = (raw.equivalencias || []).map((eq) =>
			createEquivalenciaModelFromJson(eq as Record<string, unknown>)
		);

		const materiaCodes = new Set(materias.filter((m) => m.nivel !== 0).map((m) => m.codigoMateria));
		const preRequisitosInCurso = preRequisitos.filter((pr) => materiaCodes.has(pr.codigoMateriaRequisito));
		const allMateriaCodes = new Set(materias.map((m) => m.codigoMateria));
		const coRequisitosInCurso = coRequisitos.filter((cr) => allMateriaCodes.has(cr.codigoMateriaCoRequisito));

		const maxSemestre = Math.max(...materias.map((m) => m.nivel || 0), 0);
		const curriculoCompleto =
			(raw.curso as { curriculo_completo?: string })?.curriculo_completo ??
			raw.matriz?.curriculo_completo ??
			(raw.curso.matriz_curricular as string) ??
			null;

		const curso: CursoModel = {
			nomeCurso: String(raw.curso.nome_curso),
			matrizCurricular: String(raw.curso.matriz_curricular ?? curriculoCompleto ?? ''),
			idCurso: Number(raw.curso.id_curso),
			totalCreditos: (raw.curso as { creditos?: number }).creditos != null ? Number((raw.curso as { creditos?: number }).creditos) : null,
			tipoCurso: String(raw.curso.tipo_curso ?? ''),
			classificacao: String(raw.curso.classificacao ?? ''),
			materias,
			semestres: maxSemestre,
			equivalencias,
			preRequisitos: preRequisitosInCurso,
			coRequisitos: coRequisitosInCurso,
			curriculoCompleto: curriculoCompleto ?? undefined
		};

		const materiaMap = new Map(materias.map((m) => [m.codigoMateria, m]));
		for (const materia of materias) materia.preRequisitos = [];
		for (const preReq of preRequisitosInCurso) {
			const targetMateria = materias.find((m) => m.idMateria === preReq.idMateria);
			if (targetMateria) {
				const prereqMateria = materiaMap.get(preReq.codigoMateriaRequisito);
				if (prereqMateria) targetMateria.preRequisitos!.push(prereqMateria);
			}
		}

		const materiasWithPrereqs = materias.filter((m) => (m.preRequisitos?.length ?? 0) > 0);
		console.log('[FluxogramaService] Prerequisite refs populated:', {
			materiasWithPrereqs: materiasWithPrereqs.length,
			sample: materiasWithPrereqs.slice(0, 3).map((m) => ({
				code: m.codigoMateria,
				name: m.nomeMateria,
				preReqs: m.preRequisitos?.map((p) => p.codigoMateria)
			}))
		});

		return curso;
	}

	/**
	 * Get a single subject's details — REPLACES: GET /materias/:id
	 */
	async getMateriaData(idMateria: number): Promise<MateriaModel> {
		const m = await supabaseDataService.getMateriaById(idMateria);
		return {
			ementa: m.ementa,
			idMateria: m.id_materia,
			nomeMateria: m.nome_materia,
			codigoMateria: m.codigo_materia,
			creditos: (m.carga_horaria ?? 0) / 15,
			nivel: 0,
			preRequisitos: []
		};
	}

	/**
	 * Get subject names by code list
	 * REPLACES: POST /materias/materias-name-by-code
	 */
	async getMateriasByCode(codes: string[]) {
		return supabaseDataService.getMateriasByCode(codes);
	}

	/**
	 * Get full materia data for codes in a specific course
	 * REPLACES: POST /materias/materias-from-codigos
	 */
	async getMateriasFromCodigos(codes: string[], idCurso: number) {
		return supabaseDataService.getMateriasFromCodigos(codes, idCurso);
	}

	/**
	 * Delete user's flowchart data — REPLACES: DELETE /fluxograma/delete-fluxograma
	 */
	async deleteFluxograma(userId: number) {
		return supabaseDataService.deleteFluxogramaData(userId);
	}

	/**
	 * Save user's flowchart data — REPLACES: POST /fluxograma/upload-dados-fluxograma
	 */
	async saveFluxograma(userId: number, data: unknown, semestre?: number) {
		return supabaseDataService.saveFluxogramaData(userId, data, semestre);
	}
}

export const fluxogramaService = new FluxogramaService();

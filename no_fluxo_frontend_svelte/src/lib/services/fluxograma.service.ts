import { supabaseDataService } from './supabase-data.service';
import type { CursoModel, MinimalCursoModel, PreRequisitoModel, CoRequisitoModel } from '$lib/types/curso';
import { isOptativa, type MateriaModel } from '$lib/types/materia';
import type { EquivalenciaModel } from '$lib/types/equivalencia';
import {
	createMateriaModelFromJson,
	createPreRequisitoModelFromJson,
	createCoRequisitoModelFromJson,
	createEquivalenciaModelFromJson
} from '$lib/factories';
import { getCodigosFromExpressaoLogica } from '$lib/utils/expressao-logica';

/**
 * Fluxograma service — wraps SupabaseDataService for course/subject data.
 * All queries go directly to Supabase with RLS (no backend calls).
 *
 * See plan 14 (SUPABASE-DIRECT-RLS.md) for architecture details.
 */

class FluxogramaService {
	/**
	 * Inferir turno a partir de curriculo_completo quando a view não retorna turno
	 * (ex.: "Engenharia - 2017.1 - DIURNO" ou "Administração - 2020.1 - noturno").
	 */
	private inferTurnoFromCurriculo(curriculoCompleto: string | null | undefined): string | null {
		const s = (curriculoCompleto ?? '').trim();
		const match = s.match(/\s*-\s*(DIURNO|NOTURNO)\s*$/i);
		return match ? match[1].toUpperCase() : null;
	}

	/**
	 * Get all courses (minimal info for index page)
	 * REPLACES: GET /cursos/all-cursos
	 *
	 * IMPORTANTE:
	 * - tipo_curso e turno SEMPRE vêm diretamente da tabela cursos (fonte de verdade).
	 * - A view vw_creditos_por_matriz é usada só como fonte opcional de créditos/currículo.
	 */
	async getAllCursos(): Promise<MinimalCursoModel[]> {
		// 1) Cursos "puros" da tabela cursos — garante tipo_curso/turno corretos.
		const cursosRows = ((await supabaseDataService.getAllCursos()) || []) as Record<string, unknown>[];

		// 2) Créditos opcionais (view) indexados por id_curso.
		const creditRows = ((await supabaseDataService.getCursosComCreditos()) || []) as Record<
			string,
			unknown
		>[];
		const creditByCurso = new Map<
			number,
			{ creditos: number | null; curriculo_completo: string | null }
		>();
		for (const row of creditRows) {
			const rawId = row.id_curso ?? row.idCurso;
			const id = rawId != null && rawId !== '' ? Number(rawId) : NaN;
			if (Number.isNaN(id)) continue;
			const creditos =
				row.creditos_totais != null
					? Number(row.creditos_totais)
					: row.cred_total_exigido != null
						? Number(row.cred_total_exigido)
						: row.ch_total_exigida != null
							? Math.floor(Number(row.ch_total_exigida) / 15)
							: row.creditos != null
								? Number(row.creditos)
								: null;
			const curriculoCompleto =
				row.curriculo_completo != null ? String(row.curriculo_completo) : null;
			if (!creditByCurso.has(id)) {
				creditByCurso.set(id, { creditos, curriculo_completo: curriculoCompleto });
			}
		}

		// 3) Matriz representativa (curriculo_completo) por curso, direto da tabela matrizes.
		const matrizesResumo = await supabaseDataService.getMatrizesResumoPorCurso();

		// 4) Monta MinimalCursoModel com base em cursos + créditos + matriz.
		return cursosRows.map((c: Record<string, unknown>, index: number) => {
			const rawId = c.id_curso ?? c.idCurso;
			const idNum = rawId != null && rawId !== '' ? Number(rawId) : NaN;
			const idCurso = !Number.isNaN(idNum) ? idNum : index;

			const creditInfo = creditByCurso.get(idCurso);
			const creditos = creditInfo?.creditos ?? null;
			const matrizInfo = matrizesResumo.get(idCurso);
			// Prioriza curriculo_completo vindo da tabela matrizes; se não houver, cai para o da view (quando existir).
			const curriculoCompleto = matrizInfo?.curriculo_completo ?? creditInfo?.curriculo_completo ?? null;

			const tipoCursoRaw =
				c.tipo_curso != null
					? String(c.tipo_curso).trim()
					: c.tipoCurso != null
						? String(c.tipoCurso).trim()
						: '';
			let turnoRaw =
				c.turno != null
					? String(c.turno).trim()
					: '';
			if (turnoRaw === '' && curriculoCompleto) {
				turnoRaw = this.inferTurnoFromCurriculo(curriculoCompleto) ?? '';
			}
			const turno = turnoRaw !== '' ? turnoRaw.toUpperCase() : null;

			return {
				nomeCurso: String(c.nome_curso ?? c.nomeCurso ?? ''),
				matrizCurricular: curriculoCompleto ?? '',
				idCurso,
				creditos,
				classificacao: '',
				tipoCurso: tipoCursoRaw !== '' ? tipoCursoRaw : '',
				turno
			};
		});
	}

	/**
	 * Lista TODAS as matrizes com informações de curso, para o index /fluxogramas.
	 * Diferente de getAllCursos (que colapsa por curso), aqui cada matriz gera um card.
	 */
	async getAllMatrizesIndex(): Promise<MinimalCursoModel[]> {
		type CursoAninhado = Record<string, unknown>;
		type MatrizComCursoRow = Record<string, unknown> & {
			cursos?: CursoAninhado | CursoAninhado[] | null;
		};
		const rows = ((await supabaseDataService.getAllMatrizesWithCurso()) ||
			[]) as unknown as MatrizComCursoRow[];

		// Créditos continuam vindo da view por curso; serão iguais em todas as matrizes do mesmo curso.
		const creditRows = ((await supabaseDataService.getCursosComCreditos()) || []) as Record<
			string,
			unknown
		>[];
		const creditByCurso = new Map<number, number | null>();
		for (const row of creditRows) {
			const rawId = row.id_curso ?? (row as Record<string, unknown>).idCurso;
			const id = rawId != null && rawId !== '' ? Number(rawId) : NaN;
			if (Number.isNaN(id)) continue;
			const creditos =
				row.creditos_totais != null
					? Number(row.creditos_totais)
					: row.cred_total_exigido != null
						? Number(row.cred_total_exigido)
						: row.ch_total_exigida != null
							? Math.floor(Number(row.ch_total_exigida) / 15)
							: row.creditos != null
								? Number(row.creditos)
								: null;
			if (!creditByCurso.has(id)) {
				creditByCurso.set(id, creditos);
			}
		}

		const mapped = rows
			.map((row) => {
				const rawCursos = row.cursos;
				const cursoRec = ((Array.isArray(rawCursos) ? rawCursos[0] : rawCursos) ??
					{}) as Record<string, unknown>;
				const rawIdCurso = cursoRec.id_curso ?? cursoRec.idCurso;
				const idNum = rawIdCurso != null && rawIdCurso !== '' ? Number(rawIdCurso) : NaN;
				const idCurso = !Number.isNaN(idNum) ? idNum : null;

				const curriculoCompleto =
					(row.curriculo_completo != null ? String(row.curriculo_completo) : '') ?? '';

				const tipoCursoRaw =
					cursoRec.tipo_curso != null
						? String(cursoRec.tipo_curso).trim()
						: cursoRec.tipoCurso != null
							? String(cursoRec.tipoCurso).trim()
							: '';

				let turnoRaw = cursoRec.turno != null ? String(cursoRec.turno).trim() : '';
				if (turnoRaw === '' && curriculoCompleto) {
					turnoRaw = this.inferTurnoFromCurriculo(curriculoCompleto) ?? '';
				}
				const turno = turnoRaw !== '' ? turnoRaw.toUpperCase() : null;

				return {
					nomeCurso: String(cursoRec.nome_curso ?? cursoRec.nomeCurso ?? ''),
					matrizCurricular: curriculoCompleto,
					idCurso: idCurso ?? -1,
					creditos: idCurso != null ? creditByCurso.get(idCurso) ?? null : null,
					classificacao: '',
					tipoCurso: tipoCursoRaw !== '' ? tipoCursoRaw : '',
					turno
				} satisfies MinimalCursoModel;
			})
			.filter((c) => c.matrizCurricular && c.nomeCurso);

		// Ordena alfabeticamente por nome do curso e, dentro dele, por currículo
		mapped.sort((a, b) => {
			const nomeA = a.nomeCurso.localeCompare(b.nomeCurso, 'pt-BR', { sensitivity: 'base' });
			if (nomeA !== 0) return nomeA;
			const curA = (a.matrizCurricular ?? '').localeCompare(b.matrizCurricular ?? '', 'pt-BR', {
				numeric: true,
				sensitivity: 'base'
			});
			return curA;
		});

		return mapped;
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

		const codigoNorm = (c: string) => (c || '').trim().toUpperCase();
		const materiaCodesNorm = new Set(materias.map((m) => codigoNorm(m.codigoMateria)));
		const idsMateriasNoCurso = new Set(materias.map((m) => m.idMateria));
		const preRequisitosInCurso = preRequisitos.filter((pr) => idsMateriasNoCurso.has(pr.idMateria));
		const coRequisitosInCurso = coRequisitos.filter((cr) =>
			materiaCodesNorm.has(codigoNorm(cr.codigoMateriaCoRequisito || ''))
		);

		const maxSemestre = Math.max(...materias.map((m) => m.nivel || 0), 0);
		const curriculoCompleto =
			(raw.curso as { curriculo_completo?: string })?.curriculo_completo ??
			raw.matriz?.curriculo_completo ??
			(raw.curso.matriz_curricular as string) ??
			null;

		let turnoRaw =
			(raw.curso as { turno?: string | null }).turno != null
				? String((raw.curso as { turno?: string | null }).turno).trim()
				: '';
		let turnoResolved =
			turnoRaw !== '' ? turnoRaw.toUpperCase() : this.inferTurnoFromCurriculo(curriculoCompleto);
		if (!turnoResolved) {
			turnoResolved = this.inferTurnoFromCurriculo(String(raw.curso.matriz_curricular ?? ''));
		}

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
			curriculoCompleto: curriculoCompleto ?? undefined,
			turno: turnoResolved ?? null
		};

		const materiaByNorm = new Map(materias.map((m) => [codigoNorm(m.codigoMateria), m]));
		for (const materia of materias) materia.preRequisitos = [];
		for (const preReq of preRequisitosInCurso) {
			const targetMateria = materias.find((m) => m.idMateria === preReq.idMateria);
			if (!targetMateria) continue;
			const codigosPrereq = preReq.expressaoLogica
				? getCodigosFromExpressaoLogica(preReq.expressaoLogica)
				: preReq.codigoMateriaRequisito
					? [preReq.codigoMateriaRequisito.trim().toUpperCase()]
					: [];
			const existingNorm = new Set(targetMateria.preRequisitos!.map((m) => codigoNorm(m.codigoMateria)));
			for (const code of codigosPrereq) {
				const c = codigoNorm(code);
				const prereqMateria = materiaByNorm.get(c);
				if (prereqMateria && !existingNorm.has(c)) {
					targetMateria.preRequisitos!.push(prereqMateria);
					existingNorm.add(c);
				}
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

	async saveOptativasManuais(
		userId: number,
		optativasManuais: Array<{ codigo: string; nivel_alocado: number; status: string; nome?: string | null }>
	) {
		return supabaseDataService.saveOptativasManuaisData(userId, optativasManuais);
	}
}

export const fluxogramaService = new FluxogramaService();

import { createSupabaseBrowserClient } from '$lib/supabase/client';
import type { MatrizModel } from '$lib/types/matriz';
import { parseCurriculoCompleto } from '$lib/types/matriz';

/**
 * Central data service for all direct Supabase queries.
 * Replaces 9 backend API endpoints with direct database access via RLS.
 *
 * Identificador único de matriz = curriculo_completo (ex: "8117/-2 - 2018.2") ou "codigo/versao" (ex: "60810/1").
 * Grade = materias_por_curso por id_matriz. CH oficial = campos ch_* da tabela matrizes.
 */
export class SupabaseDataService {
	private supabase = createSupabaseBrowserClient();

	// ─── Matrizes (identificador curriculo_completo ou codigo/versao) ──────────

	/**
	 * Busca matriz por curriculo_completo ou por "codigo/versao" (mesma regra do casamento de disciplinas).
	 * 1) Tenta match exato em curriculo_completo.
	 * 2) Se não achar, interpreta como "codigo/versao" (id_curso + matriz.versao) e busca por isso.
	 */
	async getMatrizByCurriculoCompleto(curriculoCompleto: string): Promise<MatrizModel | null> {
		const s = curriculoCompleto.trim();
		if (!s) return null;

		const { data: byExact, error: errExact } = await this.supabase
			.from('matrizes')
			.select('*')
			.eq('curriculo_completo', s)
			.maybeSingle();

		if (errExact) throw new Error(`Erro ao buscar matriz: ${errExact.message}`);
		if (byExact) {
			return {
				idMatriz: byExact.id_matriz,
				idCurso: byExact.id_curso,
				curriculoCompleto: byExact.curriculo_completo,
				versao: byExact.versao ?? '',
				anoVigor: byExact.ano_vigor ?? null,
				chObrigatoriaExigida: byExact.ch_obrigatoria_exigida ?? null,
				chOptativaExigida: byExact.ch_optativa_exigida ?? null,
				chComplementarExigida: byExact.ch_complementar_exigida ?? null,
				chTotalExigida: byExact.ch_total_exigida ?? null
			};
		}

		const { codigoCurso, versao } = parseCurriculoCompleto(s);
		if (!codigoCurso || !/^\d+$/.test(codigoCurso) || versao === undefined) return null;
		const idCurso = parseInt(codigoCurso, 10);

		const { data: byCodeVersao, error: errCode } = await this.supabase
			.from('matrizes')
			.select('*')
			.eq('id_curso', idCurso)
			.eq('versao', versao)
			.maybeSingle();

		if (errCode) throw new Error(`Erro ao buscar matriz: ${errCode.message}`);
		if (!byCodeVersao) return null;

		return {
			idMatriz: byCodeVersao.id_matriz,
			idCurso: byCodeVersao.id_curso,
			curriculoCompleto: byCodeVersao.curriculo_completo,
			versao: byCodeVersao.versao ?? '',
			anoVigor: byCodeVersao.ano_vigor ?? null,
			chObrigatoriaExigida: byCodeVersao.ch_obrigatoria_exigida ?? null,
			chOptativaExigida: byCodeVersao.ch_optativa_exigida ?? null,
			chComplementarExigida: byCodeVersao.ch_complementar_exigida ?? null,
			chTotalExigida: byCodeVersao.ch_total_exigida ?? null
		};
	}

	/**
	 * Lista matrizes de um curso (para filtro/troca de matriz).
	 */
	async getMatrizesByCurso(idCurso: number) {
		const { data, error } = await this.supabase
			.from('matrizes')
			.select('*')
			.eq('id_curso', idCurso)
			.order('ano_vigor', { ascending: false });

		if (error) throw new Error(`Erro ao buscar matrizes: ${error.message}`);
		return (data || []).map((row) => ({
			idMatriz: row.id_matriz,
			idCurso: row.id_curso,
			curriculoCompleto: row.curriculo_completo,
			versao: row.versao ?? '',
			anoVigor: row.ano_vigor ?? null,
			chObrigatoriaExigida: row.ch_obrigatoria_exigida ?? null,
			chOptativaExigida: row.ch_optativa_exigida ?? null,
			chComplementarExigida: row.ch_complementar_exigida ?? null,
			chTotalExigida: row.ch_total_exigida ?? null
		}));
	}

	/**
	 * Grade da matriz: disciplinas com carga horária e categoria (obrigatória/optativa).
	 * nivel >= 1 = obrigatória, nivel === 0 = optativa.
	 */
	async getGradeByMatriz(idMatriz: number): Promise<Array<{ codigoMateria: string; cargaHoraria: number; categoria: 'obrigatoria' | 'optativa' | 'complementar' }>> {
		const { data, error } = await this.supabase
			.from('materias_por_curso')
			.select('id_materia, nivel, materias(codigo_materia, carga_horaria)')
			.eq('id_matriz', idMatriz);

		if (error) throw new Error(`Erro ao buscar grade: ${error.message}`);
		const rows = data || [];
		const out: Array<{ codigoMateria: string; cargaHoraria: number; categoria: 'obrigatoria' | 'optativa' | 'complementar' }> = [];
		for (const row of rows) {
			const mat = row.materias as { codigo_materia?: string; carga_horaria?: number } | null;
			const codigo = mat?.codigo_materia ?? '';
			const ch = Number(mat?.carga_horaria ?? 0);
			const nivel = Number(row.nivel ?? 0);
			const categoria = nivel >= 1 ? 'obrigatoria' : 'optativa';
			out.push({ codigoMateria: codigo, cargaHoraria: ch, categoria });
		}
		return out;
	}

	// ─── Courses ──────────────────────────────────────────────

	/**
	 * Get all courses — REPLACES: GET /cursos/all-cursos
	 */
	async getAllCursos() {
		const { data, error } = await this.supabase
			.from('cursos')
			.select('*')
			.order('nome_curso');

		if (error) throw new Error(`Erro ao buscar cursos: ${error.message}`);
		return data;
	}

	/**
	 * Get courses with credit/ch counts from view vw_creditos_por_matriz.
	 * Se a view retornar uma linha por matriz, deduplicamos por id_curso (primeira matriz) para a lista de cursos.
	 */
	async getCursosComCreditos() {
		const { data, error } = await this.supabase.from('vw_creditos_por_matriz').select('*');

		if (error) throw new Error(`Erro ao buscar créditos: ${error.message}`);
		const rows = data ?? [];
		// Uma linha por curso (primeira matriz de cada): evita duplicata quando a view é por matriz
		const byCurso = new Map<number, (typeof rows)[0]>();
		for (const row of rows) {
			const rawId = row.id_curso;
			const id = rawId != null && rawId !== '' ? Number(rawId) : NaN;
			if (!Number.isNaN(id) && !byCurso.has(id)) byCurso.set(id, row);
		}
		return byCurso.size > 0 ? [...byCurso.values()] : rows;
	}

	// ─── Subjects ─────────────────────────────────────────────

	/**
	 * Get subject names by their codes — REPLACES: GET /materias/materias-name-by-code
	 */
	async getMateriasByCode(codes: string[]) {
		if (codes.length === 0) return [];

		const { data, error } = await this.supabase
			.from('materias')
			.select('codigo_materia, nome_materia')
			.in('codigo_materia', codes);

		if (error) throw new Error(`Erro ao buscar matérias: ${error.message}`);
		return data;
	}

	/**
	 * Get full subject data for given codes in a matrix
	 */
	async getMateriasFromCodigosByMatriz(codes: string[], idMatriz: number) {
		if (codes.length === 0) return [];

		const { data, error } = await this.supabase
			.from('materias')
			.select('*, materias_por_curso!inner(nivel, id_matriz)')
			.in('codigo_materia', codes)
			.eq('materias_por_curso.id_matriz', idMatriz);

		if (error) throw new Error(`Erro ao buscar matérias da matriz: ${error.message}`);
		return data;
	}

	/**
	 * Get full subject data for given codes in a course (legacy: usa primeira matriz do curso)
	 */
	async getMateriasFromCodigos(codes: string[], idCurso: number) {
		if (codes.length === 0) return [];
		const matrizes = await this.getMatrizesByCurso(idCurso);
		const idMatriz = matrizes[0]?.idMatriz;
		if (idMatriz == null) return [];
		return this.getMateriasFromCodigosByMatriz(codes, idMatriz);
	}

	/**
	 * Get a single subject by ID — REPLACES: GET /materias/:id
	 */
	async getMateriaById(idMateria: number) {
		const { data, error } = await this.supabase
			.from('materias')
			.select('*')
			.eq('id_materia', idMateria)
			.single();

		if (error) throw new Error(`Erro ao buscar matéria: ${error.message}`);
		return data;
	}

	// ─── Full Course Flowchart Data (por matriz / curriculo_completo) ───

	/**
	 * Carrega fluxograma por curriculo_completo (identificador único de matriz).
	 * Curso + grade + pré/co-requisitos + equivalências (gerais e específicas).
	 */
	async getCourseFlowchartDataByCurriculoCompleto(curriculoCompleto: string) {
		const matriz = await this.getMatrizByCurriculoCompleto(curriculoCompleto);
		if (!matriz) throw new Error(`Matriz não encontrada: ${curriculoCompleto}`);
		return this.getCourseFlowchartDataByMatriz(matriz.idMatriz, matriz.idCurso);
	}

	/**
	 * Carrega fluxograma por id_matriz. Busca curso e grade por id_matriz.
	 */
	async getCourseFlowchartDataByMatriz(idMatriz: number, idCurso: number) {
		const { data: curso, error: cursoError } = await this.supabase
			.from('cursos')
			.select('*')
			.eq('id_curso', idCurso)
			.single();

		if (cursoError || !curso) throw new Error(`Curso não encontrado: id_curso ${idCurso}`);

		const { data: materiasCurso, error: mcError } = await this.supabase
			.from('materias_por_curso')
			.select('id_materia_curso, id_materia, nivel, id_matriz, materias(id_materia, codigo_materia, nome_materia, carga_horaria, ementa)')
			.eq('id_matriz', idMatriz);

		if (mcError) throw new Error(`Erro ao buscar matérias: ${mcError.message}`);

		const materiaIds = (materiasCurso || []).map((mc) => mc.id_materia).filter(Boolean) as number[];

		const [equivalenciasResult, prereqsResult, coreqsResult] = await Promise.all([
			this.supabase.from('equivalencias').select('*, materias!equivalencias_id_materia_fkey(codigo_materia, nome_materia)').in('id_materia', materiaIds),
			materiaIds.length > 0
				? this.supabase
						.from('pre_requisitos')
						.select('id_pre_requisito, id_materia, id_materia_requisito, expressao_original, expressao_logica, materias:id_materia_requisito(codigo_materia, nome_materia)')
						.in('id_materia', materiaIds)
				: Promise.resolve({ data: [], error: null }),
			materiaIds.length > 0
				? this.supabase
						.from('co_requisitos')
						.select('id_co_requisito, id_materia, id_materia_corequisito, expressao_original, expressao_logica, materias:id_materia_corequisito(codigo_materia, nome_materia)')
						.in('id_materia', materiaIds)
				: Promise.resolve({ data: [], error: null })
		]);

		const { data: matrizRow } = await this.supabase
			.from('matrizes')
			.select('curriculo_completo')
			.eq('id_matriz', idMatriz)
			.single();

		const equivalencias = (equivalenciasResult.data || []).map((eq: Record<string, unknown>) => {
			const mat = eq.materias as { codigo_materia?: string; nome_materia?: string } | null;
			return {
				...eq,
				codigo_materia_origem: mat?.codigo_materia ?? '',
				nome_materia_origem: mat?.nome_materia ?? '',
				codigo_materia_equivalente: '',
				nome_materia_equivalente: '',
				expressao: eq.expressao_original ?? ''
			};
		});

		return {
			curso: { ...curso, matriz_curricular: matrizRow?.curriculo_completo ?? '', curriculo_completo: matrizRow?.curriculo_completo ?? null },
			matriz: { id_matriz: idMatriz, id_curso: idCurso, curriculo_completo: matrizRow?.curriculo_completo ?? null },
			materias: materiasCurso || [],
			equivalencias,
			preRequisitos: prereqsResult.data || [],
			coRequisitos: coreqsResult.data || []
		};
	}

	/**
	 * Get all data needed to render a course flowchart by course name.
	 * Usa a primeira matriz do curso (para compatibilidade). Prefira getCourseFlowchartDataByCurriculoCompleto.
	 */
	async getCourseFlowchartData(courseName: string) {
		const { data: cursos, error: cursoError } = await this.supabase
			.from('cursos')
			.select('*')
			.eq('nome_curso', courseName)
			.limit(1);

		if (cursoError || !cursos?.length) throw new Error(`Curso não encontrado: ${courseName}`);
		const curso = cursos[0];
		const matrizes = await this.getMatrizesByCurso(curso.id_curso);
		const idMatriz = matrizes[0]?.idMatriz ?? null;
		if (idMatriz == null) throw new Error(`Nenhuma matriz encontrada para o curso: ${courseName}`);
		const out = await this.getCourseFlowchartDataByMatriz(idMatriz, curso.id_curso);
		return { ...out, curso: { ...curso, matriz_curricular: matrizes[0]?.curriculoCompleto ?? '' } };
	}

	// ─── User Data ────────────────────────────────────────────

	/**
	 * Get current user's profile with flowchart data
	 * REPLACES: GET /users/get-user-by-email
	 */
	async getCurrentUserProfile() {
		const { data: authUser } = await this.supabase.auth.getUser();
		if (!authUser.user) return null;

		const { data, error } = await this.supabase
			.from('users')
			.select('*, dados_users(*)')
			.eq('auth_id', authUser.user.id)
			.single();

		if (error) {
			console.warn('User profile not found:', error.message);
			return null;
		}

		return data;
	}

	/**
	 * Register a new user (direct insert)
	 * REPLACES: POST /users/register-user-with-google
	 * REPLACES: POST /users/registrar-user-with-email
	 */
	async registerUser(email: string, nomeCompleto: string) {
		const { data: authUser } = await this.supabase.auth.getUser();
		if (!authUser.user) throw new Error('Não autenticado');

		const { data, error } = await this.supabase
			.from('users')
			.insert({
				email,
				nome_completo: nomeCompleto,
				auth_id: authUser.user.id
			})
			.select()
			.single();

		if (error) {
			// If user already exists, fetch instead
			if (error.code === '23505') {
				return this.getCurrentUserProfile();
			}
			throw new Error(`Erro ao registrar usuário: ${error.message}`);
		}

		return data;
	}

	// ─── Flowchart User Data ──────────────────────────────────

	/**
	 * Save/update user's flowchart data (upsert)
	 * REPLACES: POST /fluxograma/upload-dados-fluxograma
	 */
	async saveFluxogramaData(idUser: number, fluxogramaData: unknown, semestreAtual?: number) {
		const { data, error } = await this.supabase
			.from('dados_users')
			.upsert(
				{
					id_user: idUser,
					fluxograma_atual: JSON.stringify(fluxogramaData),
					semestre_atual: semestreAtual ?? null
				},
				{ onConflict: 'id_user' }
			)
			.select()
			.single();

		if (error) throw new Error(`Erro ao salvar fluxograma: ${error.message}`);
		return data;
	}

	/**
	 * Delete user's flowchart data
	 * REPLACES: DELETE /fluxograma/delete-fluxograma
	 */
	async deleteFluxogramaData(idUser: number) {
		const { error } = await this.supabase.from('dados_users').delete().eq('id_user', idUser);

		if (error) throw new Error(`Erro ao deletar fluxograma: ${error.message}`);
		return true;
	}
}

// Singleton instance
export const supabaseDataService = new SupabaseDataService();

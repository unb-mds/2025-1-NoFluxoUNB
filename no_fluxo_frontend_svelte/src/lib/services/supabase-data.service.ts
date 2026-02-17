import { createSupabaseBrowserClient } from '$lib/supabase/client';

/**
 * Central data service for all direct Supabase queries.
 * Replaces 9 backend API endpoints with direct database access via RLS.
 *
 * Public tables (cursos, materias, etc.) → anyone can SELECT
 * User tables (users, dados_users) → RLS restricts to auth.uid()
 */
export class SupabaseDataService {
	private supabase = createSupabaseBrowserClient();

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
	 * Get courses with credit counts (from view)
	 */
	async getCursosComCreditos() {
		const { data, error } = await this.supabase.from('creditos_por_curso').select('*');

		if (error) throw new Error(`Erro ao buscar créditos: ${error.message}`);
		return data;
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
	 * Get full subject data for given codes in a course
	 * REPLACES: POST /materias/materias-from-codigos
	 */
	async getMateriasFromCodigos(codes: string[], idCurso: number) {
		if (codes.length === 0) return [];

		const { data, error } = await this.supabase
			.from('materias')
			.select('*, materias_por_curso!inner(nivel, id_curso)')
			.in('codigo_materia', codes)
			.eq('materias_por_curso.id_curso', idCurso);

		if (error) throw new Error(`Erro ao buscar matérias do curso: ${error.message}`);
		return data;
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

	// ─── Full Course Flowchart Data ───────────────────────────

	/**
	 * Get all data needed to render a course flowchart.
	 * REPLACES: GET /fluxograma/fluxograma?nome_curso=...
	 *
	 * Combines 4 queries that the backend did sequentially:
	 * course → subjects → equivalencies → prerequisites + corequisites
	 */
	async getCourseFlowchartData(courseName: string) {
		// 1. Get course (use limit(1) instead of single() because
		//    some course names appear multiple times in the table)
		const { data: cursos, error: cursoError } = await this.supabase
			.from('cursos')
			.select('*')
			.eq('nome_curso', courseName)
			.limit(1);

		if (cursoError || !cursos || cursos.length === 0) {
			throw new Error(`Curso não encontrado: ${courseName}`);
		}

		const curso = cursos[0];

		// 2. Get subjects for this course (with full materia data via join)
		const { data: materiasCurso, error: mcError } = await this.supabase
			.from('materias_por_curso')
			.select('*, materias(*)')
			.eq('id_curso', curso.id_curso);

		if (mcError) throw new Error(`Erro ao buscar matérias: ${mcError.message}`);

		const materiaIds = (materiasCurso || [])
			.map((mc) => mc.id_materia)
			.filter(Boolean) as number[];

		// 3. Get equivalencies, prerequisites, and co-requisites in parallel
		const [equivalenciasResult, prereqsResult, coreqsResult] = await Promise.all([
			this.supabase
				.from('vw_equivalencias_com_materias')
				.select('*')
				.eq('id_curso', curso.id_curso),

			materiaIds.length > 0
				? this.supabase
						.from('pre_requisitos')
						.select(
							'id_pre_requisito, id_materia, id_materia_requisito, materias:id_materia_requisito(codigo_materia, nome_materia)'
						)
						.in('id_materia', materiaIds)
				: Promise.resolve({ data: [], error: null }),

			materiaIds.length > 0
				? this.supabase
						.from('co_requisitos')
						.select(
							'id_co_requisito, id_materia, id_materia_corequisito, materias:id_materia_corequisito(codigo_materia, nome_materia)'
						)
						.in('id_materia', materiaIds)
				: Promise.resolve({ data: [], error: null })
		]);

		return {
			curso,
			materias: materiasCurso || [],
			equivalencias: equivalenciasResult.data || [],
			preRequisitos: prereqsResult.data || [],
			coRequisitos: coreqsResult.data || []
		};
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

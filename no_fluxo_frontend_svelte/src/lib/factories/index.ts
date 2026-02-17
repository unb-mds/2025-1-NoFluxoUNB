/**
 * Factory functions for creating typed objects from raw JSON/API data
 * Bridges between snake_case (database) and camelCase (TypeScript) conventions
 */

import type { UserModel, DadosMateria, DadosFluxogramaUser } from '$lib/types/user';
import type {
	CursoModel,
	MinimalCursoModel,
	PreRequisitoModel,
	CoRequisitoModel
} from '$lib/types/curso';
import type { MateriaModel } from '$lib/types/materia';
import type { EquivalenciaModel } from '$lib/types/equivalencia';

// ============================================================================
// DadosMateria Factory
// ============================================================================

export function createDadosMateriaFromJson(json: Record<string, unknown>): DadosMateria {
	return {
		codigoMateria: String(json.codigo ?? ''),
		mencao: String(json.mencao ?? '-'),
		professor: String(json.professor ?? ''),
		status: String(json.status ?? '-'),
		anoPeriodo: json.ano_periodo != null ? String(json.ano_periodo) : null,
		frequencia: json.frequencia != null ? String(json.frequencia) : null,
		tipoDado: json.tipo_dado != null ? String(json.tipo_dado) : null,
		turma: json.turma != null ? String(json.turma) : null
	};
}

export function dadosMateriaToJson(dados: DadosMateria): Record<string, unknown> {
	return {
		codigo: dados.codigoMateria,
		mencao: dados.mencao,
		professor: dados.professor,
		status: dados.status,
		ano_periodo: dados.anoPeriodo,
		frequencia: dados.frequencia,
		tipo_dado: dados.tipoDado,
		turma: dados.turma
	};
}

// ============================================================================
// DadosFluxogramaUser Factory
// ============================================================================

export function createDadosFluxogramaUserFromJson(
	json: Record<string, unknown>
): DadosFluxogramaUser {
	const dadosFluxograma = json.dados_fluxograma as unknown[][];

	return {
		nomeCurso: String(json.nome_curso ?? ''),
		ira: Number(json.ira ?? 0),
		matricula: String(json.matricula ?? ''),
		semestreAtual: Number(json.semestre_atual ?? 0),
		anoAtual: String(json.ano_atual ?? ''),
		matrizCurricular: String(json.matriz_curricular ?? ''),
		horasIntegralizadas: Number(json.horas_integralizadas ?? 0),
		suspensoes: Array.isArray(json.suspensoes)
			? (json.suspensoes as unknown[]).map(String)
			: [],
		dadosFluxograma: Array.isArray(dadosFluxograma)
			? dadosFluxograma.map((semester) =>
					Array.isArray(semester)
						? semester.map((materia) =>
								createDadosMateriaFromJson(materia as Record<string, unknown>)
							)
						: []
				)
			: []
	};
}

export function dadosFluxogramaUserToJson(
	dados: DadosFluxogramaUser
): Record<string, unknown> {
	return {
		nome_curso: dados.nomeCurso,
		ira: dados.ira,
		matricula: dados.matricula,
		matriz_curricular: dados.matrizCurricular,
		semestre_atual: dados.semestreAtual,
		ano_atual: dados.anoAtual,
		horas_integralizadas: dados.horasIntegralizadas,
		suspensoes: dados.suspensoes,
		dados_fluxograma: dados.dadosFluxograma.map((semester) =>
			semester.map(dadosMateriaToJson)
		)
	};
}

// ============================================================================
// UserModel Factory
// ============================================================================

export function createUserModelFromJson(json: Record<string, unknown>): UserModel {
	let dadosFluxograma: DadosFluxogramaUser | null = null;

	const dadosUsers = json.dados_users as Array<Record<string, unknown>> | undefined;
	if (
		dadosUsers &&
		dadosUsers.length > 0 &&
		dadosUsers[0] != null &&
		dadosUsers[0].fluxograma_atual != null
	) {
		const fluxogramaData =
			typeof dadosUsers[0].fluxograma_atual === 'string'
				? JSON.parse(dadosUsers[0].fluxograma_atual)
				: dadosUsers[0].fluxograma_atual;

		dadosFluxograma = createDadosFluxogramaUserFromJson(fluxogramaData);
	}

	return {
		idUser: Number(json.id_user),
		email: String(json.email ?? ''),
		nomeCompleto: String(json.nome_completo ?? ''),
		dadosFluxograma,
		token: json.token != null ? String(json.token) : null
	};
}

export function userModelToJson(
	user: UserModel,
	options: { includeToken?: boolean; includeDadosFluxograma?: boolean } = {}
): Record<string, unknown> {
	const result: Record<string, unknown> = {
		id_user: user.idUser,
		email: user.email,
		nome_completo: user.nomeCompleto
	};

	if (options.includeToken && user.token) {
		result.token = user.token;
	}

	if (options.includeDadosFluxograma && user.dadosFluxograma) {
		result.dados_users = [
			{
				fluxograma_atual: JSON.stringify(
					dadosFluxogramaUserToJson(user.dadosFluxograma)
				)
			}
		];
	}

	return result;
}

// ============================================================================
// MateriaModel Factory
// ============================================================================

export function createMateriaModelFromJson(json: Record<string, unknown>): MateriaModel {
	const materiaData = (json.materias as Record<string, unknown>) ?? json;

	return {
		ementa: String(materiaData.ementa ?? ''),
		idMateria: Number(materiaData.id_materia ?? 0),
		nomeMateria: String(materiaData.nome_materia ?? ''),
		codigoMateria: String(materiaData.codigo_materia ?? ''),
		creditos: Number(materiaData.carga_horaria ?? 0) / 15,
		nivel: Number(json.nivel ?? 0),
		status: materiaData.status != null ? String(materiaData.status) : null,
		mencao: materiaData.mencao != null ? String(materiaData.mencao) : null,
		professor: materiaData.professor != null ? String(materiaData.professor) : null,
		preRequisitos: []
	};
}

// ============================================================================
// PreRequisitoModel Factory
// ============================================================================

export function createPreRequisitoModelFromJson(
	json: Record<string, unknown>
): PreRequisitoModel {
	// The Supabase query JOINs materias via id_materia_requisito, returning
	// a nested "materias" object with { codigo_materia, nome_materia }
	const materias = json.materias as Record<string, unknown> | null | undefined;
	return {
		idPreRequisito: Number(json.id_pre_requisito ?? 0),
		idMateria: Number(json.id_materia ?? 0),
		idMateriaRequisito: Number(json.id_materia_requisito ?? 0),
		codigoMateriaRequisito: String(
			materias?.codigo_materia ?? json.codigo_materia_requisito ?? ''
		),
		nomeMateriaRequisito: String(
			materias?.nome_materia ?? json.nome_materia_requisito ?? ''
		)
	};
}

// ============================================================================
// CoRequisitoModel Factory
// ============================================================================

export function createCoRequisitoModelFromJson(
	json: Record<string, unknown>
): CoRequisitoModel {
	// The Supabase query JOINs materias via id_materia_corequisito, returning
	// a nested "materias" object with { codigo_materia, nome_materia }
	const materias = json.materias as Record<string, unknown> | null | undefined;
	return {
		idCoRequisito: Number(json.id_co_requisito ?? 0),
		idMateria: Number(json.id_materia ?? 0),
		idMateriaCoRequisito: Number(json.id_materia_corequisito ?? 0),
		codigoMateriaCoRequisito: String(
			materias?.codigo_materia ?? json.codigo_materia_corequisito ?? ''
		),
		nomeMateriaCoRequisito: String(
			materias?.nome_materia ?? json.nome_materia_corequisito ?? ''
		)
	};
}

// ============================================================================
// EquivalenciaModel Factory
// ============================================================================

export function createEquivalenciaModelFromJson(
	json: Record<string, unknown>
): EquivalenciaModel {
	return {
		idEquivalencia: Number(json.id_equivalencia ?? 0),
		codigoMateriaOrigem: String(json.codigo_materia_origem ?? ''),
		nomeMateriaOrigem: String(json.nome_materia_origem ?? ''),
		codigoMateriaEquivalente: String(json.codigo_materia_equivalente ?? ''),
		nomeMateriaEquivalente: String(json.nome_materia_equivalente ?? ''),
		expressao: String(json.expressao ?? ''),
		idCurso: json.id_curso != null ? Number(json.id_curso) : null,
		nomeCurso: json.nome_curso != null ? String(json.nome_curso) : null,
		matrizCurricular:
			json.matriz_curricular != null ? String(json.matriz_curricular) : null,
		curriculo: json.curriculo != null ? String(json.curriculo) : null,
		dataVigencia: json.data_vigencia != null ? String(json.data_vigencia) : null,
		fimVigencia: json.fim_vigencia != null ? String(json.fim_vigencia) : null
	};
}

// ============================================================================
// CursoModel Factory
// ============================================================================

export function createMinimalCursoModelFromJson(
	json: Record<string, unknown>
): MinimalCursoModel {
	return {
		nomeCurso: String(json.nome_curso ?? ''),
		matrizCurricular: String(json.matriz_curricular ?? ''),
		idCurso: Number(json.id_curso ?? 0),
		creditos: json.creditos != null ? Number(json.creditos) : null,
		tipoCurso: String(json.tipo_curso ?? 'outro'),
		classificacao: String(json.classificacao ?? 'outro')
	};
}

export function createCursoModelFromJson(json: Record<string, unknown>): CursoModel {
	const materiasPorCurso =
		(json.materias_por_curso as Array<Record<string, unknown>>) ?? [];
	const equivalenciasJson =
		(json.equivalencias as Array<Record<string, unknown>>) ?? [];
	const preRequisitosJson =
		(json.pre_requisitos as Array<Record<string, unknown>>) ?? [];
	const coRequisitosJson =
		(json.co_requisitos as Array<Record<string, unknown>>) ?? [];

	const materias = materiasPorCurso.map(createMateriaModelFromJson);

	let maxSemestre = 0;
	for (const materia of materias) {
		if (materia.nivel > maxSemestre) {
			maxSemestre = materia.nivel;
		}
	}

	const allPreRequisitos = preRequisitosJson.map(createPreRequisitoModelFromJson);
	const allCoRequisitos = coRequisitosJson.map(createCoRequisitoModelFromJson);

	const materiasInCursoFromCodigo = new Set(
		materias.filter((m) => m.nivel !== 0).map((m) => m.codigoMateria)
	);

	const preRequisitosInCurso = allPreRequisitos.filter((pr) =>
		materiasInCursoFromCodigo.has(pr.codigoMateriaRequisito)
	);

	const materiasInCursoFromCodigoCoReq = new Set(
		materias.map((m) => m.codigoMateria)
	);

	const coRequisitosInCurso = allCoRequisitos.filter((cr) =>
		materiasInCursoFromCodigoCoReq.has(cr.codigoMateriaCoRequisito)
	);

	const curso: CursoModel = {
		nomeCurso: String(json.nome_curso ?? ''),
		matrizCurricular: String(json.matriz_curricular ?? ''),
		idCurso: Number(json.id_curso ?? 0),
		totalCreditos: json.creditos != null ? Number(json.creditos) : null,
		tipoCurso: String(json.tipo_curso ?? ''),
		classificacao: String(json.classificacao ?? ''),
		materias,
		semestres: maxSemestre,
		equivalencias: equivalenciasJson.map(createEquivalenciaModelFromJson),
		preRequisitos: preRequisitosInCurso,
		coRequisitos: coRequisitosInCurso
	};

	populatePrerequisites(curso);

	return curso;
}

/**
 * Populate prerequisites for all materias in a course
 */
function populatePrerequisites(curso: CursoModel): void {
	for (const materia of curso.materias) {
		materia.preRequisitos = [];
	}

	const materiaMap = new Map<string, MateriaModel>();
	for (const materia of curso.materias) {
		materiaMap.set(materia.codigoMateria, materia);
	}

	const prerequisiteMap = new Map<string, string[]>();

	for (const preReq of curso.preRequisitos) {
		const targetMateria = curso.materias.find((m) => m.idMateria === preReq.idMateria);
		if (!targetMateria) continue;

		const materiaCode = targetMateria.codigoMateria;
		const prereqCode = preReq.codigoMateriaRequisito;

		if (!prerequisiteMap.has(materiaCode)) {
			prerequisiteMap.set(materiaCode, []);
		}
		prerequisiteMap.get(materiaCode)!.push(prereqCode);
	}

	for (const materia of curso.materias) {
		const directPrerequisites = prerequisiteMap.get(materia.codigoMateria) ?? [];

		for (const prereqCode of directPrerequisites) {
			const prereqMateria = materiaMap.get(prereqCode);
			if (prereqMateria) {
				materia.preRequisitos!.push(prereqMateria);
			}
		}

		const allPrerequisites = new Set<string>();
		collectAllPrerequisites(materia.codigoMateria, prerequisiteMap, allPrerequisites);

		const existingCodes = new Set(materia.preRequisitos!.map((m) => m.codigoMateria));
		for (const prereqCode of allPrerequisites) {
			const prereqMateria = materiaMap.get(prereqCode);
			if (prereqMateria && !existingCodes.has(prereqCode)) {
				materia.preRequisitos!.push(prereqMateria);
			}
		}
	}
}

function collectAllPrerequisites(
	materiaCode: string,
	prerequisiteMap: Map<string, string[]>,
	collected: Set<string>
): void {
	const directPrereqs = prerequisiteMap.get(materiaCode) ?? [];

	for (const prereqCode of directPrereqs) {
		if (!collected.has(prereqCode)) {
			collected.add(prereqCode);
			collectAllPrerequisites(prereqCode, prerequisiteMap, collected);
		}
	}
}

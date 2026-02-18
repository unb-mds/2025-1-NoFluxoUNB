import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

const LOG_PREFIX = '[CasarDisciplinas]';

interface DisciplinaHistorico {
	tipo_dado: string;
	nome: string;
	codigo: string;
	status: string;
	mencao?: string;
	creditos?: number;
	carga_horaria?: number;
	ano_periodo?: string;
	prefixo?: string;
	professor?: string;
	IRA?: string;
	valor?: number;
	valores?: Record<string, number>;
}

interface MateriasBanco {
	id_materia: number;
	nivel: number;
	materias: {
		id_materia: number;
		nome_materia: string;
		codigo_materia: string;
	};
}

interface EquivalenciaData {
	id_equivalencia: number;
	codigo_materia_origem: string;
	nome_materia_origem: string;
	codigo_materia_equivalente: string;
	nome_materia_equivalente: string;
	expressao: string;
	id_curso?: number;
	nome_curso?: string;
	matriz_curricular?: string;
	curriculo?: string;
	data_vigencia?: string;
	fim_vigencia?: string;
}

function extractSubjectCodes(expression: string): string[] {
	return Array.from(expression.matchAll(/[A-Z]{2,}\d{3,}/gi)).map((m) =>
		m[0].replace(/\s+/g, '').toUpperCase()
	);
}

function getStatusPriority(status: string): number {
	if (status === 'APR' || status === 'CUMP') return 3;
	if (status === 'MATR') return 2;
	return 1;
}

function findSubjectMatch(
	disciplina: DisciplinaHistorico,
	materiasObrigatorias: MateriasBanco[],
	materiasOptativas: MateriasBanco[]
): MateriasBanco | null {
	// 1. Match by code in mandatory subjects
	let match = materiasObrigatorias.find(
		(m) =>
			m.materias.codigo_materia &&
			disciplina.codigo &&
			m.materias.codigo_materia.toLowerCase().trim() === disciplina.codigo.toLowerCase().trim()
	);

	// 2. Match by code in elective subjects
	if (!match) {
		match = materiasOptativas.find(
			(m) =>
				m.materias.codigo_materia &&
				disciplina.codigo &&
				m.materias.codigo_materia.toLowerCase().trim() ===
					disciplina.codigo.toLowerCase().trim()
		);
	}

	// 3. Match by name in mandatory subjects
	if (!match) {
		match = materiasObrigatorias.find(
			(m) =>
				m.materias.nome_materia.toLowerCase().trim() === disciplina.nome.toLowerCase().trim()
		);
	}

	// 4. Match by name in elective subjects
	if (!match) {
		match = materiasOptativas.find(
			(m) =>
				m.materias.nome_materia.toLowerCase().trim() === disciplina.nome.toLowerCase().trim()
		);
	}

	return match ?? null;
}

function processMatchedDiscipline(
	disciplina: DisciplinaHistorico,
	materiaBanco: MateriasBanco,
	disciplinasCasadas: Record<string, unknown>[]
): Record<string, unknown> {
	const existingIndex = disciplinasCasadas.findIndex(
		(d) => d.id_materia === materiaBanco.id_materia
	);

	const disciplinaCasada = {
		...disciplina,
		nome: materiaBanco.materias.nome_materia || disciplina.nome,
		nome_materia: materiaBanco.materias.nome_materia,
		codigo_materia: materiaBanco.materias.codigo_materia,
		id_materia: materiaBanco.id_materia,
		encontrada_no_banco: true,
		nivel: materiaBanco.nivel,
		tipo: materiaBanco.nivel === 0 ? 'optativa' : 'obrigatoria'
	};

	if (existingIndex >= 0) {
		const existing = disciplinasCasadas[existingIndex];
		const currentPriority = getStatusPriority(existing.status as string);
		const newPriority = getStatusPriority(disciplina.status);

		if (newPriority > currentPriority) {
			disciplinasCasadas[existingIndex] = disciplinaCasada;
		}
		return disciplinasCasadas[existingIndex];
	}

	disciplinasCasadas.push(disciplinaCasada);
	return disciplinaCasada;
}

function checkEquivalencies(
	disciplinasCasadas: Record<string, unknown>[],
	equivalencias: EquivalenciaData[],
	_targetMateria: Record<string, unknown>
): boolean {
	for (const eq of equivalencias) {
		const codigosEquivalentes = extractSubjectCodes(eq.expressao);
		for (const codigoEq of codigosEquivalentes) {
			const encontrada = disciplinasCasadas.find(
				(d) =>
					d.codigo === codigoEq && (d.status === 'APR' || d.status === 'CUMP')
			);
			if (encontrada) {
				return true;
			}
		}
	}
	return false;
}

export const POST: RequestHandler = async ({ request, locals }) => {
	const supabase = locals.supabase;
	const startTime = Date.now();
	console.log(`${LOG_PREFIX} === DISCIPLINE MATCHING STARTED ===`);

	try {
		const { dados_extraidos } = await request.json();

		if (!dados_extraidos) {
			console.error(`${LOG_PREFIX} Missing dados_extraidos in request body`);
			return json({ error: 'Dados extraídos são obrigatórios' }, { status: 400 });
		}

		const curso_extraido = dados_extraidos.curso_extraido;
		const matriz_curricular = dados_extraidos.matriz_curricular;
		const media_ponderada = dados_extraidos.media_ponderada;
		const frequencia_geral = dados_extraidos.frequencia_geral;

		console.log(`${LOG_PREFIX} Input: ${dados_extraidos.extracted_data?.length ?? 0} extracted items`);
		console.log(`${LOG_PREFIX} Course: "${curso_extraido}" | Matrix: "${matriz_curricular}"`);
		console.log(`${LOG_PREFIX} MP: ${media_ponderada ?? 'N/A'} | Freq: ${frequencia_geral ?? 'N/A'}`);

		// If no course extracted, return available courses
		if (!curso_extraido) {
			console.warn(`${LOG_PREFIX} No course extracted from PDF — returning available courses`);
			const { data: todosCursos } = await supabase
				.from('cursos')
				.select('nome_curso, matriz_curricular')
				.order('nome_curso');

			return json(
				{
					error: 'Curso não foi extraído do PDF automaticamente',
					message: 'Por favor, selecione o curso manualmente',
					cursos_disponiveis: todosCursos || []
				},
				{ status: 400 }
			);
		}

		let materiasBanco: Record<string, unknown>[] | null = null;
		let error: { message: string } | null = null;

		// Handle keyword-based search
		if (curso_extraido.startsWith('PALAVRAS_CHAVE:')) {
			const palavrasChave = curso_extraido.replace('PALAVRAS_CHAVE:', '').split(',');

			const { data: todosCursos } = await supabase
				.from('cursos')
				.select('nome_curso, matriz_curricular')
				.order('nome_curso');

			if (todosCursos) {
				const cursosFiltrados = todosCursos.filter(
					(curso: { nome_curso?: string }) =>
						palavrasChave.some((palavra: string) =>
							curso.nome_curso?.toUpperCase().includes(palavra.toUpperCase())
						)
				);

				if (cursosFiltrados.length === 1) {
					const cursoSelecionado = cursosFiltrados[0];

					const { data, error: queryError } = await supabase
						.from('cursos')
						.select('*,materias_por_curso(id_materia,nivel,materias(*))')
						.eq('nome_curso', cursoSelecionado.nome_curso);

					materiasBanco = data;
					error = queryError;
				} else if (cursosFiltrados.length > 1) {
					return json(
						{
							error: 'Múltiplos cursos encontrados',
							message: 'Por favor, selecione o curso correto',
							cursos_disponiveis: cursosFiltrados,
							palavras_chave_encontradas: palavrasChave
						},
						{ status: 400 }
					);
				}
			}
		} else {
			// Normal course search — use curso_selecionado if provided
			const cursoNome = dados_extraidos.curso_selecionado || curso_extraido;

			let query = supabase
				.from('cursos')
				.select('*,materias_por_curso(id_materia,nivel,materias(*))')
				.like('nome_curso', '%' + cursoNome + '%');

			if (matriz_curricular) {
				query = query.eq('matriz_curricular', matriz_curricular);
			}

			const result = await query;
			materiasBanco = result.data;
			error = result.error;
		}

		if (error) {
			return json({ error: error.message }, { status: 500 });
		}

		if (!materiasBanco || materiasBanco.length === 0) {
			const { data: todosCursos } = await supabase
				.from('cursos')
				.select('nome_curso, matriz_curricular');

			return json(
				{
					error: 'Curso não encontrado',
					curso_buscado: curso_extraido,
					matriz_curricular_buscada: matriz_curricular,
					cursos_disponiveis: todosCursos
				},
				{ status: 404 }
			);
		}

		const curso = materiasBanco[0] as Record<string, unknown>;
		const materiasBancoList = curso.materias_por_curso as MateriasBanco[];
		const materiasObrigatorias = materiasBancoList.filter((m) => m.nivel > 0);
		const materiasOptativas = materiasBancoList.filter((m) => m.nivel === 0);

		console.log(`${LOG_PREFIX} Course found: ${curso.nome_curso}`);
		console.log(`${LOG_PREFIX} Subjects: ${materiasBancoList.length} total (${materiasObrigatorias.length} mandatory, ${materiasOptativas.length} elective)`);

		// Pre-load all equivalencies
		console.log(`${LOG_PREFIX} Loading equivalencies and other matrices...`);
		const { data: allEquivalencies } = await supabase
			.from('vw_equivalencias_com_materias')
			.select(
				'id_equivalencia,codigo_materia_origem,nome_materia_origem,codigo_materia_equivalente,nome_materia_equivalente,expressao'
			)
			.or(`id_curso.is.null,id_curso.eq.${curso.id_curso}`);

		// Pre-load other course matrices for cross-matrix matching
		const { data: outrasMatrizes } = await supabase
			.from('cursos')
			.select('*,materias_por_curso(id_materia,nivel,materias(*))')
			.eq('nome_curso', curso.nome_curso as string);

		console.log(`${LOG_PREFIX} Loaded ${allEquivalencies?.length ?? 0} equivalencies, ${outrasMatrizes?.length ?? 0} course matrices`);

		// Initialize result arrays
		const disciplinasCasadas: Record<string, unknown>[] = [];
		const materiasConcluidas: Record<string, unknown>[] = [];
		const materiasPendentes: Record<string, unknown>[] = [];
		const materiasOptativasConcluidas: Record<string, unknown>[] = [];
		const materiasOptativasPendentes: Record<string, unknown>[] = [];

		// Initialize validation data
		const dadosValidacao: Record<string, unknown> = {
			ira: null,
			media_ponderada: media_ponderada ? parseFloat(media_ponderada) : null,
			frequencia_geral: frequencia_geral ? parseFloat(frequencia_geral) : null,
			horas_integralizadas: 0,
			pendencias: [],
			curso_extraido,
			matriz_curricular
		};

		// Extract validation data (IRA, pendencias)
		for (const item of dados_extraidos.extracted_data) {
			if (item.IRA) {
				dadosValidacao.ira = parseFloat(item.valor);
			}
			if (item.tipo_dado === 'Pendencias') {
				dadosValidacao.pendencias = item.valores || [];
			}
		}

		// Main discipline matching loop
		console.log(`${LOG_PREFIX} Starting discipline matching for ${dados_extraidos.extracted_data.length} items...`);
		let foundCount = 0;
		let notFoundCount = 0;

		for (const disciplina of dados_extraidos.extracted_data) {
			if (
				disciplina.tipo_dado !== 'Disciplina Regular' &&
				disciplina.tipo_dado !== 'Disciplina CUMP'
			) {
				continue;
			}

			// 1. Try primary matrix match
			let materiaBanco: MateriasBanco | null = findSubjectMatch(
				disciplina,
				materiasObrigatorias,
				materiasOptativas
			);

			// 2. Try other matrices
			if (!materiaBanco && outrasMatrizes) {
				for (const matriz of outrasMatrizes as Record<string, unknown>[]) {
					if (matriz.matriz_curricular === curso.matriz_curricular) continue;

					const matrizList = matriz.materias_por_curso as MateriasBanco[];
					const obrig = matrizList.filter((m) => m.nivel > 0);
					const opt = matrizList.filter((m) => m.nivel === 0);

					materiaBanco = findSubjectMatch(disciplina, obrig, opt);
					if (materiaBanco) break;
				}
			}

			// 3. Try equivalency matching
			if (!materiaBanco && allEquivalencies) {
				const equivalenciasMatch = (allEquivalencies as EquivalenciaData[]).filter(
					(eq) =>
						eq.expressao &&
						(eq.expressao.includes(disciplina.codigo) ||
							eq.expressao.includes(disciplina.nome))
				);

				if (equivalenciasMatch.length > 0) {
					const targetMateria = materiasBancoList.find(
						(m) => m.materias.codigo_materia === equivalenciasMatch[0].codigo_materia_origem
					);
					if (targetMateria) {
						materiaBanco = targetMateria;
					}
				}
			}

			// Process the match
			if (materiaBanco) {
				processMatchedDiscipline(disciplina, materiaBanco, disciplinasCasadas);
				foundCount++;
				console.log(`${LOG_PREFIX}   ✓ "${disciplina.nome}" (${disciplina.codigo}) → ID ${materiaBanco.id_materia} (${materiaBanco.nivel === 0 ? 'elective' : 'mandatory'})`);
			} else {
				notFoundCount++;
				console.warn(`${LOG_PREFIX}   ✗ "${disciplina.nome}" (${disciplina.codigo}) — not found in database`);
				disciplinasCasadas.push({
					...disciplina,
					id_materia: null,
					encontrada_no_banco: false,
					nivel: null,
					tipo: 'nao_encontrada'
				});
			}
		}

		console.log(`${LOG_PREFIX} Matching done — Found: ${foundCount}, Not found: ${notFoundCount}`);

		// Classify matched disciplines
		for (const disciplinaCasada of disciplinasCasadas) {
			const isCompleted =
				disciplinaCasada.status === 'APR' || disciplinaCasada.status === 'CUMP';
			const isElective = disciplinaCasada.tipo === 'optativa';

			if (isCompleted) {
				const completedSubject = { ...disciplinaCasada, status_fluxograma: 'concluida' };
				if (isElective) {
					materiasOptativasConcluidas.push(completedSubject);
				} else {
					materiasConcluidas.push(completedSubject);
				}
			} else {
				const isInProgress = disciplinaCasada.status === 'MATR';
				const statusFluxograma = isInProgress ? 'em_andamento' : 'pendente';
				const pendingSubject = { ...disciplinaCasada, status_fluxograma: statusFluxograma };
				if (isElective) {
					materiasOptativasPendentes.push(pendingSubject);
				} else {
					materiasPendentes.push(pendingSubject);
				}
			}
		}

		console.log(`${LOG_PREFIX} Classification: ${materiasConcluidas.length} completed, ${materiasPendentes.length} pending, ${materiasOptativasConcluidas.length} electives completed`);

		// Find mandatory subjects NOT in transcript
		const materiasObrigatoriasNaoEncontradas = materiasObrigatorias
			.filter(
				(materiaBancoItem) =>
					!disciplinasCasadas.some((disc) => disc.id_materia === materiaBancoItem.id_materia)
			)
			.map((materiaBancoItem) => ({
				id_materia: materiaBancoItem.id_materia,
				nome: materiaBancoItem.materias.nome_materia,
				codigo: materiaBancoItem.materias.codigo_materia,
				nivel: materiaBancoItem.nivel,
				encontrada_no_banco: true,
				encontrada_no_historico: false,
				tipo: 'obrigatoria' as const,
				status_fluxograma: 'nao_cursada' as const
			}));

		console.log(`${LOG_PREFIX} Found ${materiasObrigatoriasNaoEncontradas.length} mandatory subjects not in transcript`);

		// Process equivalencies for missing mandatory subjects
		const materiasConcluidasPorEquivalencia: Record<string, unknown>[] = [];
		const materiasPendentesFinais: Record<string, unknown>[] = [];

		for (const materiaObrigatoria of materiasObrigatoriasNaoEncontradas) {
			const equivalenciasParaMateria =
				(allEquivalencies as EquivalenciaData[] | null)?.filter(
					(eq) => eq.codigo_materia_origem === materiaObrigatoria.codigo
				) || [];

			const cumpridaPorEquivalencia = checkEquivalencies(
				disciplinasCasadas,
				equivalenciasParaMateria,
				materiaObrigatoria
			);

			if (cumpridaPorEquivalencia) {
				let encontrada: Record<string, unknown> | undefined;
				for (const eq of equivalenciasParaMateria) {
					const codigosEquivalentes = extractSubjectCodes(eq.expressao);
					encontrada = disciplinasCasadas.find(
						(d) =>
							codigosEquivalentes.includes(d.codigo as string) &&
							(d.status === 'APR' || d.status === 'CUMP')
					);
					if (encontrada) break;
				}
				materiasConcluidasPorEquivalencia.push({
					...materiaObrigatoria,
					status_fluxograma: 'concluida_equivalencia',
					codigo_equivalente: encontrada?.codigo,
					nome_equivalente: encontrada?.nome
				});
			} else {
				materiasPendentesFinais.push(materiaObrigatoria);
			}
		}

		// Process electives as possible equivalencies for mandatory subjects
		const optativasParaProcessar = [
			...materiasOptativasConcluidas,
			...materiasOptativasPendentes
		];
		const optativasRestantes: Record<string, unknown>[] = [];

		for (const disciplinaOptativa of optativasParaProcessar) {
			let marcadaComoEquivalencia = false;

			if (allEquivalencies) {
				for (const eq of allEquivalencies as EquivalenciaData[]) {
					if (
						!eq.expressao ||
						!eq.expressao.toUpperCase().includes(disciplinaOptativa.codigo as string)
					)
						continue;

					const obrigatoria = materiasPendentesFinais.find(
						(m) => m.codigo === eq.codigo_materia_origem
					);
					if (!obrigatoria) continue;

					const codigosEquivalentes = extractSubjectCodes(eq.expressao);
					const encontrada = disciplinasCasadas.find(
						(d) =>
							codigosEquivalentes.includes(d.codigo as string) &&
							(d.status === 'APR' || d.status === 'CUMP')
					);

					if (encontrada) {
						materiasConcluidasPorEquivalencia.push({
							...obrigatoria,
							status_fluxograma: 'concluida_equivalencia',
							equivalencia: disciplinaOptativa.nome,
							codigo_equivalente: disciplinaOptativa.codigo,
							nome_equivalente: disciplinaOptativa.nome
						});
						marcadaComoEquivalencia = true;
						break;
					}
				}
			}

			if (!marcadaComoEquivalencia) {
				optativasRestantes.push(disciplinaOptativa);
			}
		}

		// Final calculations
		const todasMateriasPendentes = [...materiasPendentes, ...materiasPendentesFinais];
		const todasMateriasConcluidas = [...materiasConcluidas, ...materiasConcluidasPorEquivalencia];
		const todasMateriasOptativas = optativasRestantes;

		// Calculate integrated hours
		let horasIntegralizadas = 0;
		for (const disciplina of disciplinasCasadas) {
			if (
				(disciplina.status === 'APR' || disciplina.status === 'CUMP') &&
				disciplina.carga_horaria
			) {
				horasIntegralizadas += disciplina.carga_horaria as number;
			}
		}
		dadosValidacao.horas_integralizadas = horasIntegralizadas;

		const totalObrigatorias = todasMateriasConcluidas.length + todasMateriasPendentes.length;
		const percentualConclusao =
			totalObrigatorias > 0
				? (todasMateriasConcluidas.length / totalObrigatorias) * 100
				: 0;

		const elapsed = Date.now() - startTime;
		console.log(`${LOG_PREFIX} === PROCESSING SUMMARY ===`);
		console.log(`${LOG_PREFIX} Total matched: ${disciplinasCasadas.length}`);
		console.log(`${LOG_PREFIX} Completed mandatory: ${todasMateriasConcluidas.length} (${materiasConcluidasPorEquivalencia.length} by equivalency)`);
		console.log(`${LOG_PREFIX} Pending mandatory: ${todasMateriasPendentes.length}`);
		console.log(`${LOG_PREFIX} Electives: ${todasMateriasOptativas.length}`);
		console.log(`${LOG_PREFIX} Completion: ${percentualConclusao.toFixed(1)}% | Hours: ${horasIntegralizadas}`);
		console.log(`${LOG_PREFIX} Processing time: ${elapsed}ms`);
		console.log(`${LOG_PREFIX} === DISCIPLINE MATCHING COMPLETED ===`);

		return json({
			disciplinas_casadas: disciplinasCasadas,
			materias_concluidas: todasMateriasConcluidas,
			materias_pendentes: todasMateriasPendentes,
			materias_optativas: todasMateriasOptativas,
			dados_validacao: dadosValidacao,
			curso_extraido,
			matriz_curricular,
			resumo: {
				total_disciplinas: disciplinasCasadas.length,
				total_obrigatorias_concluidas: todasMateriasConcluidas.length,
				total_obrigatorias_pendentes: todasMateriasPendentes.length,
				total_optativas: todasMateriasOptativas.length,
				percentual_conclusao_obrigatorias: percentualConclusao
			}
		});
	} catch (err: unknown) {
		const message = err instanceof Error ? err.message : 'Erro ao casar disciplinas';
		const elapsed = Date.now() - startTime;
		console.error(`${LOG_PREFIX} ERROR after ${elapsed}ms: ${message}`);
		if (err instanceof Error && err.stack) {
			console.error(`${LOG_PREFIX} Stack: ${err.stack}`);
		}
		return json({ error: message }, { status: 500 });
	}
};

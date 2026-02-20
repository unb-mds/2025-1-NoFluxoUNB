import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import type { SupabaseClient } from '@supabase/supabase-js';

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
	const s = String(status ?? '').trim().toUpperCase();
	if (s === 'APR' || s === 'CUMP') return 3;
	if (s === 'MATR') return 2;
	return 1;
}

function isStatusCompleted(status: string): boolean {
	return ['APR', 'CUMP'].includes(String(status ?? '').trim().toUpperCase());
}

function isStatusMatriculado(status: string): boolean {
	return String(status ?? '').trim().toUpperCase() === 'MATR';
}

/** Compara ano_periodo (ex: "2024.1", "2023.2"). Retorna &gt; 0 se a &gt; b, &lt; 0 se a &lt; b. */
function compareAnoPeriodo(a: string, b: string): number {
	const parse = (s: string) => {
		const t = String(s ?? '').trim();
		const [y, sem] = t.split(/[./]/).map(Number);
		return { ano: y || 0, semestre: sem || 0 };
	};
	const pa = parse(a);
	const pb = parse(b);
	if (pa.ano !== pb.ano) return pa.ano - pb.ano;
	return pa.semestre - pb.semestre;
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

	// Usar código da matriz (codigo_materia) como "codigo" na resposta para o fluxograma
	// bater com as células do grid; codigo_historico/nome_historico = disciplina cursada no PDF (ex.: equivalente).
	const disciplinaCasada = {
		...disciplina,
		codigo: materiaBanco.materias.codigo_materia,
		codigo_historico: disciplina.codigo,
		nome_historico: disciplina.nome,
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
			const codigoUpper = codigoEq.toUpperCase();
			const encontrada = disciplinasCasadas.find((d) => {
				const dCodigo = String(d.codigo ?? '').trim().toUpperCase();
				return dCodigo === codigoUpper && isStatusCompleted(d.status as string);
			});
			if (encontrada) return true;
		}
	}
	return false;
}

/** Curso + uma matriz + lista de matérias (materias_por_curso). Schema: cursos → matrizes → materias_por_curso. */
type CursoComMaterias = Record<string, unknown> & { materias_por_curso: MateriasBanco[]; matriz_curricular: string };

/**
 * Parse do campo Currículo do histórico (ex.: "60810/1" ou "8150/-2 - 2017.2").
 * Regra: antes da "/" = código do curso (id_curso no banco); depois da "/" = versão da matriz.
 * O ano (ex. " - 2017.2") é só visual; a comparação usa apenas código + versão.
 */
function parseMatrizCurricular(matrizCurricular: string): { codigo_curso: number; versao: string } | null {
	const s = (matrizCurricular ?? '').trim();
	if (!s || !s.includes('/')) return null;
	const [antes, resto] = s.split('/', 2).map((x) => x.trim());
	const versao = resto.includes(' - ') ? resto.split(' - ')[0].trim() : resto;
	if (!antes || !/^\d+$/.test(antes) || !versao) return null;
	const codigo_curso = parseInt(antes, 10);
	return { codigo_curso, versao };
}

/**
 * Busca por código do curso + versão da matriz (forma correta: id_curso = código, matriz.versao = versão).
 */
async function getCursoComMateriasPorCodigoEVersao(
	supabase: SupabaseClient,
	codigo_curso: number,
	versao: string
): Promise<{ data: CursoComMaterias | null; error: { message: string } | null }> {
	const { data: curso, error: errCurso } = await supabase
		.from('cursos')
		.select('*')
		.eq('id_curso', codigo_curso)
		.maybeSingle();
	if (errCurso) return { data: null, error: errCurso };
	if (!curso) return { data: null, error: null };

	const { data: matriz, error: errMatriz } = await supabase
		.from('matrizes')
		.select('id_matriz, curriculo_completo')
		.eq('id_curso', codigo_curso)
		.eq('versao', versao)
		.maybeSingle();
	if (errMatriz) return { data: null, error: errMatriz };
	if (!matriz) return { data: null, error: null };

	const { data: mpc, error: errMpc } = await supabase
		.from('materias_por_curso')
		.select('id_materia, nivel, materias(id_materia, nome_materia, codigo_materia)')
		.eq('id_matriz', matriz.id_matriz);
	if (errMpc) return { data: null, error: errMpc };

	return {
		data: {
			...curso,
			matriz_curricular: matriz.curriculo_completo ?? `${codigo_curso}/${versao}`,
			materias_por_curso: (mpc ?? []) as unknown as MateriasBanco[]
		},
		error: null
	};
}

/**
 * Busca cursos com matérias por matriz (cursos → matrizes → materias_por_curso).
 * Se matriz_curricular vier no formato "8150/-2 - 2017.2", usa codigo_curso + versao (busca correta).
 */
async function getCursosComMateriasPorMatriz(
	supabase: SupabaseClient,
	opts: { nome_curso?: string; id_curso?: number; nome_curso_like?: string; matriz_curricular?: string }
): Promise<{ data: CursoComMaterias[] | null; error: { message: string } | null }> {
	// Preferência: quando temos matriz no formato "codigo/versao", buscar por id_curso (código) + versao
	if (opts.matriz_curricular) {
		const parsed = parseMatrizCurricular(opts.matriz_curricular);
		if (parsed) {
			const { data: one, error: err } = await getCursoComMateriasPorCodigoEVersao(
				supabase,
				parsed.codigo_curso,
				parsed.versao
			);
			if (err) return { data: null, error: err };
			if (one) return { data: [one], error: null };
			// Matriz não encontrada com esse código/versão; segue para fallback por nome se tiver
		}
	}

	let q = supabase.from('cursos').select('*');
	if (opts.id_curso != null) q = q.eq('id_curso', opts.id_curso);
	else if (opts.nome_curso) q = q.eq('nome_curso', opts.nome_curso);
	else if (opts.nome_curso_like) q = q.like('nome_curso', '%' + opts.nome_curso_like + '%');
	const { data: cursosList, error: errCursos } = await q;
	if (errCursos) return { data: null, error: errCursos };
	const cursos = (cursosList ?? []) as Record<string, unknown>[];
	if (cursos.length === 0) return { data: [], error: null };

	const norm = (s: string) => (typeof s === 'string' ? s.trim() : String(s ?? '')).toLowerCase();
	const result: CursoComMaterias[] = [];
	for (const curso of cursos) {
		const { data: matrizes, error: errMatrizes } = await supabase
			.from('matrizes')
			.select('id_matriz, curriculo_completo, versao')
			.eq('id_curso', curso.id_curso);
		if (errMatrizes) return { data: null, error: errMatrizes };
		let listaMatrizes = (matrizes ?? []) as { id_matriz: number; curriculo_completo: string; versao?: string }[];
		if (opts.matriz_curricular) {
			const parsed = parseMatrizCurricular(opts.matriz_curricular);
			if (parsed) {
				listaMatrizes = listaMatrizes.filter((m) => m.versao === parsed!.versao);
			}
			if (listaMatrizes.length === 0) {
				listaMatrizes = (matrizes ?? []) as { id_matriz: number; curriculo_completo: string }[];
				const filtro = listaMatrizes.filter((m) => norm(m.curriculo_completo) === norm(opts.matriz_curricular!));
				if (filtro.length) listaMatrizes = filtro;
			}
		}
		for (const matriz of listaMatrizes) {
			const { data: mpc, error: errMpc } = await supabase
				.from('materias_por_curso')
				.select('id_materia, nivel, materias(id_materia, nome_materia, codigo_materia)')
				.eq('id_matriz', matriz.id_matriz);
			if (errMpc) return { data: null, error: errMpc };
			result.push({
				...curso,
				matriz_curricular: matriz.curriculo_completo,
				materias_por_curso: (mpc ?? []) as unknown as MateriasBanco[]
			});
		}
	}
	return { data: result, error: null };
}

/** Lista para seleção: um item por (curso, matriz) com nome_curso e matriz_curricular. */
async function getCursosDisponiveis(
	supabase: SupabaseClient
): Promise<{ id_curso: number; nome_curso: string; matriz_curricular: string }[]> {
	const { data: rows } = await supabase
		.from('matrizes')
		.select('id_curso, curriculo_completo, cursos(nome_curso)')
		.order('curriculo_completo');
	const list = (rows ?? []) as unknown as { id_curso: number; curriculo_completo: string; cursos: { nome_curso: string } | null }[];
	return list.map((r) => ({
		id_curso: r.id_curso,
		nome_curso: String((r.cursos && typeof r.cursos === 'object' && !Array.isArray(r.cursos) ? (r.cursos as { nome_curso?: string }).nome_curso : null) ?? ''),
		matriz_curricular: r.curriculo_completo ?? ''
	}));
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
		const matriz_curricular = typeof dados_extraidos.matriz_curricular === 'string'
			? dados_extraidos.matriz_curricular.trim()
			: dados_extraidos.matriz_curricular;
		const media_ponderada = dados_extraidos.media_ponderada;
		const frequencia_geral = dados_extraidos.frequencia_geral;

		console.log(`${LOG_PREFIX} Input: ${dados_extraidos.extracted_data?.length ?? 0} extracted items`);
		console.log(`${LOG_PREFIX} Course: "${curso_extraido}" | Matrix: "${matriz_curricular}"`);
		console.log(`${LOG_PREFIX} MP: ${media_ponderada ?? 'N/A'} | Freq: ${frequencia_geral ?? 'N/A'}`);

		// If no course extracted, return available courses (por matriz: nome_curso + curriculo_completo)
		if (!curso_extraido) {
			console.warn(`${LOG_PREFIX} No course extracted from PDF — returning available courses`);
			const cursosDisponiveis = await getCursosDisponiveis(supabase);

			return json(
				{
					error: 'Curso não foi extraído do PDF automaticamente',
					message: 'Por favor, selecione o curso manualmente',
					cursos_disponiveis: cursosDisponiveis
				},
				{ status: 400 }
			);
		}

		let materiasBanco: Record<string, unknown>[] | null = null;
		let error: { message: string } | null = null;

		// Handle keyword-based search
		if (curso_extraido.startsWith('PALAVRAS_CHAVE:')) {
			const palavrasChave = curso_extraido.replace('PALAVRAS_CHAVE:', '').split(',');

			const todosCursos = await getCursosDisponiveis(supabase);
			const cursosFiltrados = todosCursos.filter((curso) =>
				palavrasChave.some((palavra: string) =>
					curso.nome_curso?.toUpperCase().includes(palavra.toUpperCase())
				)
			);

			if (cursosFiltrados.length === 1) {
				const cursoSelecionado = cursosFiltrados[0];
				const { data, error: queryError } = await getCursosComMateriasPorMatriz(supabase, {
					nome_curso: cursoSelecionado.nome_curso
				});
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
		} else {
			// Seleção explícita pelo usuário (modal de múltiplas matrizes)
			const idCursoSelecionado = dados_extraidos.id_curso_selecionado;
			if (idCursoSelecionado != null && idCursoSelecionado !== '') {
				const { data: cursosPorId, error: errId } = await getCursosComMateriasPorMatriz(supabase, {
					id_curso: Number(idCursoSelecionado),
					matriz_curricular: matriz_curricular || undefined
				});
				if (!errId && cursosPorId?.length) {
					materiasBanco = cursosPorId;
					console.log(`${LOG_PREFIX} Course selected by id_curso: ${(materiasBanco[0] as Record<string, unknown>).nome_curso} (${(materiasBanco[0] as Record<string, unknown>).matriz_curricular})`);
				}
			}

			if (!materiasBanco || materiasBanco.length === 0) {
				const cursoNome = dados_extraidos.curso_selecionado || curso_extraido;

				const result = await getCursosComMateriasPorMatriz(supabase, {
					nome_curso_like: cursoNome,
					matriz_curricular: matriz_curricular || undefined
				});
				materiasBanco = result.data;
				error = result.error;

				// Se veio matriz do PDF mas não achou nada, buscar só por nome e escolher pela matriz (match flexível)
				if (matriz_curricular && (!materiasBanco || materiasBanco.length === 0)) {
					const fallback = await getCursosComMateriasPorMatriz(supabase, { nome_curso_like: cursoNome });
					const fallbackData = fallback.data;
					if (fallbackData && fallbackData.length > 0) {
						const matrizNorm = (v: unknown) =>
							(typeof v === 'string' ? v.trim() : String(v ?? '')).toLowerCase();
						const matrizBuscada = matrizNorm(matriz_curricular);
						const match = fallbackData.find(
							(c) => matrizNorm(c.matriz_curricular) === matrizBuscada
						);
						if (match) {
							materiasBanco = [match];
							console.log(`${LOG_PREFIX} Matched matrix by normalized comparison: "${match.matriz_curricular}"`);
						}
					}
				}
			}
		}

		if (error) {
			return json({ error: error.message }, { status: 500 });
		}

		if (!materiasBanco || materiasBanco.length === 0) {
			const cursosDisponiveis = await getCursosDisponiveis(supabase);

			return json(
				{
					error: 'Curso não encontrado',
					curso_buscado: curso_extraido,
					matriz_curricular_buscada: matriz_curricular,
					cursos_disponiveis: cursosDisponiveis
				},
				{ status: 404 }
			);
		}

		// Se há vários cursos (ex.: mesmo nome com matrizes 2017.2 e 2019.2), usar a matriz do PDF
		// ou pedir seleção ao usuário — nunca pegar o primeiro arbitrariamente
		let curso: Record<string, unknown>;
		if (materiasBanco.length > 1) {
			const matrizNorm = (v: unknown) =>
				(typeof v === 'string' ? v.trim() : String(v ?? '')).toLowerCase();
			const matrizBuscada = matrizNorm(matriz_curricular);
			const byMatrix = (materiasBanco as Record<string, unknown>[]).find(
				(c) => matrizNorm(c.matriz_curricular) === matrizBuscada
			);
			if (byMatrix && matrizBuscada) {
				curso = byMatrix;
				console.log(`${LOG_PREFIX} Multiple courses: selected by matrix "${curso.matriz_curricular}"`);
			} else {
				// Matriz do PDF não bateu ou não veio no PDF: pedir seleção
				const cursosParaEscolha = (materiasBanco as Record<string, unknown>[]).map((c) => ({
					nome_curso: c.nome_curso,
					matriz_curricular: c.matriz_curricular,
					id_curso: c.id_curso
				}));
				return json(
					{
						type: 'COURSE_SELECTION',
						error: 'Mais de uma matriz curricular encontrada para este curso',
						message: 'Selecione a matriz curricular do seu histórico',
						cursos_disponiveis: cursosParaEscolha,
						matriz_extraida_pdf: matriz_curricular || null
					},
					{ status: 400 }
				);
			}
		} else {
			curso = materiasBanco[0] as Record<string, unknown>;
		}
		const materiasBancoList = curso.materias_por_curso as MateriasBanco[];
		const materiasObrigatorias = materiasBancoList.filter((m) => m.nivel > 0);
		const materiasOptativas = materiasBancoList.filter((m) => m.nivel === 0);

		console.log(`${LOG_PREFIX} Course found: ${curso.nome_curso}`);
		console.log(`${LOG_PREFIX} Subjects: ${materiasBancoList.length} total (${materiasObrigatorias.length} mandatory, ${materiasOptativas.length} elective)`);

		// Buscar equivalências no banco: tabela equivalencias, filtrada pelas matérias da matriz atual
		const materiaIds = materiasBancoList.map((m) => m.id_materia).filter(Boolean);
		console.log(`${LOG_PREFIX} Loading equivalencies from DB (matérias da matriz: ${materiaIds.length})...`);
		let allEquivalencies: EquivalenciaData[] = [];
		if (materiaIds.length > 0) {
			const { data: equivRows, error: equivErr } = await supabase
				.from('equivalencias')
				.select('id_equivalencia, id_materia, expressao_original, materias!equivalencias_id_materia_fkey(codigo_materia, nome_materia)')
				.in('id_materia', materiaIds);
			if (equivErr) {
				console.warn(`${LOG_PREFIX} Erro ao carregar equivalências: ${equivErr.message}`);
			} else if (equivRows?.length) {
				allEquivalencies = (equivRows as Record<string, unknown>[]).map((eq) => {
					const mat = eq.materias as { codigo_materia?: string; nome_materia?: string } | null;
					return {
						id_equivalencia: eq.id_equivalencia,
						codigo_materia_origem: mat?.codigo_materia ?? '',
						nome_materia_origem: mat?.nome_materia ?? '',
						codigo_materia_equivalente: '',
						nome_materia_equivalente: '',
						expressao: String(eq.expressao_original ?? '')
					} as EquivalenciaData;
				});
			}
		}

		// Pre-load other course matrices for cross-matrix matching (mesmo curso, outras matrizes)
		const { data: outrasMatrizes } = await getCursosComMateriasPorMatriz(supabase, {
			nome_curso: curso.nome_curso as string
		});

		console.log(`${LOG_PREFIX} Loaded ${allEquivalencies?.length ?? 0} equivalencies, ${outrasMatrizes?.length ?? 0} course matrices`);

		// Initialize result arrays
		const disciplinasCasadas: Record<string, unknown>[] = [];
		// Obrigatórias (materias_por_curso.nivel > 0): concluídas e pendentes
		const materiasConcluidas: Record<string, unknown>[] = [];
		const materiasPendentes: Record<string, unknown>[] = [];
		// Optativas (nivel === 0)
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

			// 3. Try equivalency matching: disciplina do PDF pode ser equivalente a uma matéria da matriz
			if (!materiaBanco && allEquivalencies) {
				const codigoUpper = String(disciplina.codigo ?? '').trim().toUpperCase();
				const nomeUpper = String(disciplina.nome ?? '').trim().toUpperCase();
				for (const eq of allEquivalencies as EquivalenciaData[]) {
					if (!eq.expressao) continue;
					const codigosNaExpressao = extractSubjectCodes(eq.expressao);
					const codigoEstaNaExpressao = codigosNaExpressao.some((c) => c === codigoUpper);
					const nomeBateComEquivalente =
						eq.nome_materia_equivalente &&
						String(eq.nome_materia_equivalente).trim().toUpperCase().includes(nomeUpper);
					if (!codigoEstaNaExpressao && !nomeBateComEquivalente) continue;
					const targetMateria = materiasBancoList.find(
						(m) => m.materias.codigo_materia === eq.codigo_materia_origem
					);
					if (targetMateria) {
						materiaBanco = targetMateria;
						break;
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

		// Classify matched disciplines (só obrigatórias e optativas; nao_encontrada não entra nas listas de resumo)
		for (const disciplinaCasada of disciplinasCasadas) {
			const tipo = disciplinaCasada.tipo as string;
			if (tipo === 'nao_encontrada') continue;

			const isCompleted = isStatusCompleted(disciplinaCasada.status as string);
			const isElective = tipo === 'optativa';

			if (isCompleted) {
				const codigoHist = String(disciplinaCasada.codigo_historico ?? '').trim();
				const codigoMat = String(disciplinaCasada.codigo_materia ?? disciplinaCasada.codigo ?? '').trim();
				const foiCursadaComoEquivalente = codigoHist && codigoHist.toUpperCase() !== codigoMat.toUpperCase();
				const completedSubject = {
					...disciplinaCasada,
					status_fluxograma: foiCursadaComoEquivalente ? 'concluida_equivalencia' : 'concluida',
					...(foiCursadaComoEquivalente && {
						codigo_equivalente: disciplinaCasada.codigo_historico,
						nome_equivalente: disciplinaCasada.nome_historico ?? disciplinaCasada.nome
					})
				};
				if (isElective) {
					materiasOptativasConcluidas.push(completedSubject);
				} else {
					materiasConcluidas.push(completedSubject);
				}
			} else {
				const isInProgress = isStatusMatriculado(disciplinaCasada.status as string);
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
				const candidatas: Record<string, unknown>[] = [];
				for (const eq of equivalenciasParaMateria) {
					const codigosEquivalentes = extractSubjectCodes(eq.expressao);
					for (const d of disciplinasCasadas) {
						const dc = String(d.codigo ?? '').trim().toUpperCase();
						if (codigosEquivalentes.includes(dc) && isStatusCompleted(d.status as string)) {
							candidatas.push(d);
						}
					}
				}
				// Escolher a tentativa mais recente (maior ano_periodo) para professor/menção
				const maisRecente = candidatas.length
					? candidatas.slice().sort((a, b) => {
							const ap = String(a.ano_periodo ?? '').trim();
							const bp = String(b.ano_periodo ?? '').trim();
							return compareAnoPeriodo(bp, ap);
						})[0]
					: undefined;
				materiasConcluidasPorEquivalencia.push({
					...materiaObrigatoria,
					status_fluxograma: 'concluida_equivalencia',
					codigo_equivalente: maisRecente?.codigo ?? materiaObrigatoria.codigo,
					nome_equivalente: maisRecente?.nome ?? materiaObrigatoria.nome,
					professor: maisRecente?.professor ?? '',
					mencao: maisRecente?.mencao ?? '-',
					status: maisRecente?.status ?? 'CUMP',
					ano_periodo: maisRecente?.ano_periodo ?? null
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
			const codigoOptUpper = String(disciplinaOptativa.codigo ?? '').trim().toUpperCase();

			if (allEquivalencies) {
				for (const eq of allEquivalencies as EquivalenciaData[]) {
					if (!eq.expressao) continue;
					const codigosEquivalentes = extractSubjectCodes(eq.expressao);
					if (!codigosEquivalentes.includes(codigoOptUpper)) continue;

					const obrigatoria = materiasPendentesFinais.find(
						(m) => m.codigo === eq.codigo_materia_origem
					);
					if (!obrigatoria) continue;

					const candidatas = disciplinasCasadas.filter((d) => {
						const dc = String(d.codigo ?? '').trim().toUpperCase();
						return codigosEquivalentes.includes(dc) && isStatusCompleted(d.status as string);
					});
					const maisRecenteOpt =
						candidatas.length > 0
							? candidatas.slice().sort((a, b) => {
									const ap = String(a.ano_periodo ?? '').trim();
									const bp = String(b.ano_periodo ?? '').trim();
									return compareAnoPeriodo(bp, ap);
								})[0]
							: null;

					if (maisRecenteOpt) {
						materiasConcluidasPorEquivalencia.push({
							...obrigatoria,
							status_fluxograma: 'concluida_equivalencia',
							equivalencia: disciplinaOptativa.nome,
							codigo_equivalente: maisRecenteOpt.codigo ?? disciplinaOptativa.codigo,
							nome_equivalente: maisRecenteOpt.nome ?? disciplinaOptativa.nome,
							professor: maisRecenteOpt.professor ?? '',
							mencao: maisRecenteOpt.mencao ?? '-',
							status: maisRecenteOpt.status ?? 'CUMP',
							ano_periodo: maisRecenteOpt.ano_periodo ?? null
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
			if (isStatusCompleted(disciplina.status as string) && disciplina.carga_horaria) {
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
				total_obrigatorias: totalObrigatorias,
				total_obrigatorias_concluidas: todasMateriasConcluidas.length,
				total_obrigatorias_pendentes: todasMateriasPendentes.length,
				total_optativas: todasMateriasOptativas.length,
				percentual_conclusao_obrigatorias: percentualConclusao
			}
			// total_disciplinas = todas casadas (obrig + optativas). Para resumo/progresso use total_obrigatorias (só nivel > 0).
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

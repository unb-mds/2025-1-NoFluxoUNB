import { EndpointController, RequestType } from "../interfaces";
import { Pair, Utils } from "../utils";
import { Request, Response } from "express";
import { SupabaseWrapper } from "../supabase_wrapper";
import axios from 'axios';
import FormData from 'form-data';
import { createControllerLogger } from '../utils/controller_logger';

// Helper interfaces for better type safety
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
    id_materia: number;
    expressao: string;
}

// Helper function to extract subject codes from equivalency expressions
function extractSubjectCodes(expression: string): string[] {
    return Array.from(expression.matchAll(/[A-Z]{2,}\d{3,}/gi))
        .map((m: any) => m[0].replace(/\s+/g, '').toUpperCase());
}

// Helper function to get status priority for conflict resolution
function getStatusPriority(status: string): number {
    if (status === 'APR' || status === 'CUMP') return 3;
    if (status === 'MATR') return 2;
    return 1; // REP, etc.
}

// Helper function to match a discipline with bank subjects
function findSubjectMatch(
    disciplina: DisciplinaHistorico,
    materiasObrigatorias: MateriasBanco[],
    materiasOptativas: MateriasBanco[]
): MateriasBanco | null {
    // 1. Match by code in mandatory subjects
    let match = materiasObrigatorias.find((m: any) =>
        m.materias.codigo_materia && disciplina.codigo &&
        m.materias.codigo_materia.toLowerCase().trim() === disciplina.codigo.toLowerCase().trim()
    );

    // 2. Match by code in elective subjects
    if (!match) {
        match = materiasOptativas.find((m: any) =>
            m.materias.codigo_materia && disciplina.codigo &&
            m.materias.codigo_materia.toLowerCase().trim() === disciplina.codigo.toLowerCase().trim()
        );
    }

    // 3. Match by name in mandatory subjects
    if (!match) {
        match = materiasObrigatorias.find((m: any) =>
            m.materias.nome_materia.toLowerCase().trim() === disciplina.nome.toLowerCase().trim()
        );
    }

    // 4. Match by name in elective subjects  
    if (!match) {
        match = materiasOptativas.find((m: any) =>
            m.materias.nome_materia.toLowerCase().trim() === disciplina.nome.toLowerCase().trim()
        );
    }

    return match || null;
}

// Helper function to process matched disciplines and handle duplicates
function processMatchedDiscipline(
    disciplina: DisciplinaHistorico,
    materiaBanco: MateriasBanco,
    disciplinasCasadas: any[],
    logger: any
): any {
    // Check for existing discipline with same ID
    const existingIndex = disciplinasCasadas.findIndex((d: any) => d.id_materia === materiaBanco.id_materia);

    const disciplinaCasada = {
        ...disciplina,
        id_materia: materiaBanco.id_materia,
        encontrada_no_banco: true,
        nivel: materiaBanco.nivel,
        tipo: materiaBanco.nivel === 0 ? 'optativa' : 'obrigatoria'
    };

    if (existingIndex >= 0) {
        const existing = disciplinasCasadas[existingIndex];
        const currentPriority = getStatusPriority(existing.status);
        const newPriority = getStatusPriority(disciplina.status);

        if (newPriority > currentPriority) {
            disciplinasCasadas[existingIndex] = disciplinaCasada;
            logger.info(`Updating status for "${disciplina.nome}": ${existing.status} → ${disciplina.status}`);
        }
        return disciplinasCasadas[existingIndex];
    } else {
        disciplinasCasadas.push(disciplinaCasada);
        return disciplinaCasada;
    }
}

// Helper function to check equivalencies
function checkEquivalencies(
    disciplinasCasadas: any[],
    equivalencias: EquivalenciaData[],
    targetMateria: any,
    logger: any
): boolean {
    for (const eq of equivalencias) {
        const codigosEquivalentes = extractSubjectCodes(eq.expressao);
        for (const codigoEq of codigosEquivalentes) {
            const encontrada = disciplinasCasadas.find(
                d => d.codigo === codigoEq && (d.status === 'APR' || d.status === 'CUMP')
            );
            if (encontrada) {
                logger.info(`Subject '${targetMateria.nome}' completed by equivalency with '${encontrada.nome}' (${encontrada.codigo})`);
                return true;
            }
        }
    }
    return false;
}

export const FluxogramaController: EndpointController = {
    name: "fluxograma",
    routes: {
        "fluxograma": new Pair(RequestType.GET, async (req: Request, res: Response) => {
            const logger = createControllerLogger("FluxogramaController", "fluxograma");
            logger.info(`Buscando fluxograma para curso`);
            const nome_curso = req.query.nome_curso as string;

            logger.info(`Nome do curso: ${nome_curso}`);
            if (!nome_curso) {
                logger.error("Nome do curso não informado");
                return res.status(400).json({ error: "Nome do curso não informado" });
            }

            const { data, error } = await SupabaseWrapper.get().from("cursos").select("*,materias_por_curso(nivel,materias(*))").like("nome_curso", "%" + req.query.nome_curso + "%");



            if (error) {
                logger.error(`Erro ao buscar fluxograma: ${error.message}`);
                return res.status(500).json({ error: error.message });
            }

            for (const curso of data) {
                // get equivalencias
                const { data: equivalencias, error: errorEquivalencias } = await SupabaseWrapper.get()
                    .from("equivalencias")
                    .select("id_equivalencia,id_materia,expressao,materias(*)")
                    .or(`id_curso.is.null,id_curso.eq.${curso.id_curso}`)
                    .or(`matriz_curricular.is.null,matriz_curricular.eq.${curso.matriz_curricular}`);

                if (errorEquivalencias) {
                    logger.error(`Erro ao buscar equivalencias: ${errorEquivalencias.message}`);
                    return res.status(500).json({ error: errorEquivalencias.message });
                }

                curso.equivalencias = equivalencias;
            }

            logger.info(`Fluxograma encontrado: ${JSON.stringify(data)}`);
            return res.status(200).json(data);
        }),

        "read_pdf": new Pair(RequestType.POST, async (req: Request, res: Response) => {
            const logger = createControllerLogger("FluxogramaController", "read_pdf");
            logger.info("Iniciando leitura de PDF");
            try {
                if (!req.files || !req.files.pdf) {
                    logger.error("Arquivo PDF não enviado");
                    return res.status(400).json({ error: "Arquivo PDF não enviado." });
                }

                const pdfFile = Array.isArray(req.files.pdf) ? req.files.pdf[0] : req.files.pdf;
                const form = new FormData();
                form.append('pdf', pdfFile.data, pdfFile.name);

                logger.info(`Enviando PDF para processamento: ${pdfFile.name}`);
                // Envia para o Python com timeout de 30 segundos
                const response = await axios.post(
                    'http://127.0.0.1:3001/upload-pdf',
                    form,
                    {
                        headers: form.getHeaders(),
                        timeout: 30000, // 30 segundos
                        maxContentLength: Infinity,
                        maxBodyLength: Infinity
                    }
                );

                logger.info("PDF processado com sucesso");
                // Retorna a resposta do Python para o frontend
                return res.status(200).json(response.data);
            } catch (error: any) {
                logger.error(`Erro ao processar PDF: ${error.message}`);
                if (error.code === 'ECONNREFUSED') {
                    return res.status(500).json({ error: 'Serviço de processamento de PDF não está disponível. Por favor, tente novamente em alguns instantes.' });
                }
                if (error.code === 'ETIMEDOUT' || error.code === 'ECONNABORTED') {
                    return res.status(500).json({ error: 'O processamento do PDF demorou muito tempo. Por favor, tente novamente.' });
                }
                return res.status(500).json({ error: error.message || "Erro ao processar PDF" });
            }
        }),

        "casar_disciplinas": new Pair(RequestType.POST, async (req: Request, res: Response) => {
            const logger = createControllerLogger("FluxogramaController", "casar_disciplinas");
            logger.info("Iniciando casamento de disciplinas");

            try {
                const { dados_extraidos } = req.body;

                if (!dados_extraidos) {
                    logger.error("Dados extraídos são obrigatórios");
                    return res.status(400).json({ error: "Dados extraídos são obrigatórios" });
                }

                // Extract basic information
                const curso_extraido = dados_extraidos.curso_extraido;
                const matriz_curricular = dados_extraidos.matriz_curricular;
                const media_ponderada = dados_extraidos.media_ponderada;
                const frequencia_geral = dados_extraidos.frequencia_geral;

                logger.info(`Curso extraído do PDF: "${curso_extraido}"`);
                logger.info(`Matriz curricular extraída: "${matriz_curricular}"`);

                if (!curso_extraido) {
                    logger.warn("Curso não foi extraído do PDF automaticamente");
                    const { data: todosCursos } = await SupabaseWrapper.get()
                        .from("cursos")
                        .select("nome_curso, matriz_curricular")
                        .order("nome_curso");

                    return res.status(400).json({
                        error: "Curso não foi extraído do PDF automaticamente",
                        message: "Por favor, selecione o curso manualmente",
                        cursos_disponiveis: todosCursos || []
                    });
                }

                // Find course in database
                let materiasBanco = null;
                let error = null;

                // Handle keyword-based search
                if (curso_extraido.startsWith('PALAVRAS_CHAVE:')) {
                    const palavrasChave = curso_extraido.replace('PALAVRAS_CHAVE:', '').split(',');
                    logger.info(`Buscando cursos com palavras-chave: ${palavrasChave.join(', ')}`);

                    const { data: todosCursos } = await SupabaseWrapper.get()
                        .from("cursos")
                        .select("nome_curso, matriz_curricular")
                        .order("nome_curso");

                    if (todosCursos) {
                        const cursosFiltrados = todosCursos.filter(curso =>
                            palavrasChave.some((palavra: string) =>
                                curso.nome_curso?.toUpperCase().includes(palavra.toUpperCase())
                            )
                        );

                        if (cursosFiltrados.length === 1) {
                            const cursoSelecionado = cursosFiltrados[0];
                            logger.info(`Using filtered course: ${cursoSelecionado.nome_curso}`);

                            const { data, error: queryError } = await SupabaseWrapper.get()
                                .from("cursos")
                                .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                                .eq("nome_curso", cursoSelecionado.nome_curso);

                            materiasBanco = data;
                            error = queryError;
                        } else if (cursosFiltrados.length > 1) {
                            return res.status(400).json({
                                error: "Múltiplos cursos encontrados",
                                message: "Por favor, selecione o curso correto",
                                cursos_disponiveis: cursosFiltrados,
                                palavras_chave_encontradas: palavrasChave
                            });
                        }
                    }
                } else {
                    // Normal course search
                    let query = SupabaseWrapper.get()
                        .from("cursos")
                        .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                        .like("nome_curso", "%" + curso_extraido + "%");

                    if (matriz_curricular) {
                        query = query.eq("matriz_curricular", matriz_curricular);
                    }

                    const result = await query;
                    materiasBanco = result.data;
                    error = result.error;
                }

                if (error) {
                    logger.error(`Erro ao buscar matérias do curso: ${error.message}`);
                    return res.status(500).json({ error: error.message });
                }

                if (!materiasBanco || materiasBanco.length === 0) {
                    logger.error(`Curso não encontrado: ${curso_extraido}`);
                    const { data: todosCursos } = await SupabaseWrapper.get()
                        .from("cursos")
                        .select("nome_curso, matriz_curricular");

                    return res.status(404).json({
                        error: "Curso não encontrado",
                        curso_buscado: curso_extraido,
                        matriz_curricular_buscada: matriz_curricular,
                        cursos_disponiveis: todosCursos
                    });
                }

                const curso = materiasBanco[0];
                const materiasBancoList = curso.materias_por_curso;
                const materiasObrigatorias = materiasBancoList.filter((m: any) => m.nivel > 0);
                const materiasOptativas = materiasBancoList.filter((m: any) => m.nivel === 0);

                logger.info(`Course found: ${curso.nome_curso}`);
                logger.info(`Total subjects: ${materiasBancoList.length}`);
                logger.info(`Mandatory subjects: ${materiasObrigatorias.length}`);
                logger.info(`Elective subjects: ${materiasOptativas.length}`);

                // PRE-LOAD all equivalencies to avoid database queries in loops
                const { data: allEquivalencies } = await SupabaseWrapper.get()
                    .from("equivalencias")
                    .select("id_equivalencia,id_materia,expressao")
                    .or(`id_curso.is.null,id_curso.eq.${curso.id_curso}`);

                logger.info(`Loaded ${allEquivalencies?.length || 0} equivalencies`);

                // PRE-LOAD other course matrices to avoid database queries in loops
                const { data: outrasMatrizes } = await SupabaseWrapper.get()
                    .from("cursos")
                    .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                    .eq("nome_curso", curso.nome_curso);

                logger.info(`Loaded ${outrasMatrizes?.length || 0} course matrices`);

                // Initialize result arrays
                const disciplinasCasadas: any[] = [];
                const materiasConcluidas: any[] = [];
                const materiasPendentes: any[] = [];
                const materiasOptativasConcluidas: any[] = [];
                const materiasOptativasPendentes: any[] = [];

                // Initialize validation data
                const dadosValidacao = {
                    ira: null as number | null,
                    media_ponderada: media_ponderada ? parseFloat(media_ponderada) : null,
                    frequencia_geral: frequencia_geral ? parseFloat(frequencia_geral) : null,
                    horas_integralizadas: 0,
                    pendencias: [],
                    curso_extraido: curso_extraido,
                    matriz_curricular: matriz_curricular
                };

                // Extract validation data
                for (const item of dados_extraidos.extracted_data) {
                    if (item.IRA) {
                        dadosValidacao.ira = parseFloat(item.valor);
                        logger.info(`IRA extracted: ${dadosValidacao.ira}`);
                    }
                    if (item.tipo_dado === 'Pendencias') {
                        dadosValidacao.pendencias = item.valores || [];
                        logger.info(`Pendencies extracted: ${dadosValidacao.pendencias}`);
                    }
                }

                // MAIN DISCIPLINE MATCHING LOOP - OPTIMIZED
                for (const disciplina of dados_extraidos.extracted_data) {
                    if (disciplina.tipo_dado === 'Disciplina Regular' || disciplina.tipo_dado === 'Disciplina CUMP') {

                        // 1. Try to match with primary matrix
                        let materiaBanco = findSubjectMatch(disciplina, materiasObrigatorias, materiasOptativas);

                        // 2. Try to match with other matrices (pre-loaded, no DB query)
                        if (!materiaBanco && outrasMatrizes) {
                            for (const matriz of outrasMatrizes) {
                                if (matriz.matriz_curricular === curso.matriz_curricular) continue;

                                const obrig = matriz.materias_por_curso.filter((m: any) => m.nivel > 0);
                                const opt = matriz.materias_por_curso.filter((m: any) => m.nivel === 0);

                                materiaBanco = findSubjectMatch(disciplina, obrig, opt);
                                if (materiaBanco) {
                                    logger.info(`Subject '${disciplina.nome}' found in other matrix: ${matriz.matriz_curricular}`);
                                    break;
                                }
                            }
                        }

                        // 3. Try to match with equivalencies (pre-loaded, no DB query)
                        if (!materiaBanco && allEquivalencies) {
                            const equivalenciasMatch = allEquivalencies.filter(eq =>
                                eq.expressao && (
                                    eq.expressao.includes(disciplina.codigo) ||
                                    eq.expressao.includes(disciplina.nome)
                                )
                            );

                            if (equivalenciasMatch.length > 0) {
                                // Find the target subject from the equivalency
                                const targetMateria = materiasBancoList.find((m: any) =>
                                    m.id_materia === equivalenciasMatch[0].id_materia
                                );

                                if (targetMateria) {
                                    materiaBanco = targetMateria;
                                    logger.info(`Subject '${disciplina.nome}' matched by equivalency`);
                                }
                            }
                        }

                        // Process the match
                        if (materiaBanco) {
                            processMatchedDiscipline(disciplina, materiaBanco, disciplinasCasadas, logger);
                        } else {
                            // Subject not found
                            disciplinasCasadas.push({
                                ...disciplina,
                                id_materia: null,
                                encontrada_no_banco: false,
                                nivel: null,
                                tipo: 'nao_encontrada'
                            });
                            logger.warn(`Subject not found: ${disciplina.nome}`);
                        }
                    }
                }

                // CLASSIFY MATCHED DISCIPLINES
                for (const disciplinaCasada of disciplinasCasadas) {
                    const isCompleted = disciplinaCasada.status === 'APR' || disciplinaCasada.status === 'CUMP';
                    const isInProgress = disciplinaCasada.status === 'MATR';
                    const isElective = disciplinaCasada.tipo === 'optativa';

                    if (isCompleted) {
                        const completedSubject = { ...disciplinaCasada, status_fluxograma: 'concluida' };
                        if (isElective) {
                            materiasOptativasConcluidas.push(completedSubject);
                        } else {
                            materiasConcluidas.push(completedSubject);
                        }
                    } else if (isInProgress) {
                        const inProgressSubject = { ...disciplinaCasada, status_fluxograma: 'em_andamento' };
                        if (isElective) {
                            materiasOptativasPendentes.push(inProgressSubject);
                        } else {
                            materiasPendentes.push(inProgressSubject);
                        }
                    } else {
                        const pendingSubject = { ...disciplinaCasada, status_fluxograma: 'pendente' };
                        if (isElective) {
                            materiasOptativasPendentes.push(pendingSubject);
                        } else {
                            materiasPendentes.push(pendingSubject);
                        }
                    }
                }

                // FIND MANDATORY SUBJECTS NOT IN TRANSCRIPT
                const materiasObrigatoriasNaoEncontradas = materiasObrigatorias.filter((materiaBanco: any) => {
                    return !disciplinasCasadas.some((disc: any) => disc.id_materia === materiaBanco.id_materia);
                }).map((materiaBanco: any) => ({
                    id_materia: materiaBanco.id_materia,
                    nome: materiaBanco.materias.nome_materia,
                    codigo: materiaBanco.materias.codigo_materia,
                    nivel: materiaBanco.nivel,
                    encontrada_no_banco: true,
                    encontrada_no_historico: false,
                    tipo: 'obrigatoria',
                    status_fluxograma: 'nao_cursada'
                }));

                // PROCESS EQUIVALENCIES FOR MISSING MANDATORY SUBJECTS
                const materiasConcluidasPorEquivalencia: any[] = [];
                const materiasPendentesFinais: any[] = [];

                for (const materiaObrigatoria of materiasObrigatoriasNaoEncontradas) {
                    const equivalenciasParaMateria = allEquivalencies?.filter(eq =>
                        eq.id_materia === materiaObrigatoria.id_materia
                    ) || [];

                    const cumpridaPorEquivalencia = checkEquivalencies(
                        disciplinasCasadas,
                        equivalenciasParaMateria,
                        materiaObrigatoria,
                        logger
                    );

                    if (cumpridaPorEquivalencia) {
                        // Encontrar a disciplina do histórico usada como equivalência
                        let encontrada = null;
                        for (const eq of equivalenciasParaMateria) {
                            const codigosEquivalentes = extractSubjectCodes(eq.expressao);
                            encontrada = disciplinasCasadas.find(
                                d => codigosEquivalentes.includes(d.codigo) && (d.status === 'APR' || d.status === 'CUMP')
                            );
                            if (encontrada) break;
                        }
                        materiasConcluidasPorEquivalencia.push({
                            ...materiaObrigatoria,
                            status_fluxograma: 'concluida_equivalencia',
                            codigo_equivalente: encontrada ? encontrada.codigo : undefined,
                            nome_equivalente: encontrada ? encontrada.nome : undefined
                        });
                    } else {
                        materiasPendentesFinais.push(materiaObrigatoria);
                    }
                }

                // PROCESS ELECTIVES THAT MIGHT BE EQUIVALENCIES FOR MANDATORY SUBJECTS
                const optativasParaProcessar = [...materiasOptativasConcluidas, ...materiasOptativasPendentes];
                const optativasRestantes: any[] = [];

                for (const disciplinaOptativa of optativasParaProcessar) {
                    let marcadaComoEquivalencia = false;

                    if (allEquivalencies) {
                        for (const eq of allEquivalencies) {
                            if (!eq.expressao || !eq.expressao.toUpperCase().includes(disciplinaOptativa.codigo)) continue;

                            const obrigatoria = materiasPendentesFinais.find((m: any) => m.id_materia === eq.id_materia);
                            if (!obrigatoria) continue;

                            const codigosEquivalentes = extractSubjectCodes(eq.expressao);
                            const encontrada = disciplinasCasadas.find(
                                d => codigosEquivalentes.includes(d.codigo) && (d.status === 'APR' || d.status === 'CUMP')
                            );

                            if (encontrada) {
                                materiasConcluidasPorEquivalencia.push({
                                    ...obrigatoria,
                                    status_fluxograma: 'concluida_equivalencia',
                                    equivalencia: disciplinaOptativa.nome,
                                    codigo_equivalente: disciplinaOptativa.codigo,
                                    nome_equivalente: disciplinaOptativa.nome
                                });
                                logger.info(`Elective '${disciplinaOptativa.nome}' marked as equivalency for mandatory '${obrigatoria.nome}'`);
                                marcadaComoEquivalencia = true;
                                break;
                            }
                        }
                    }

                    if (!marcadaComoEquivalencia) {
                        optativasRestantes.push(disciplinaOptativa);
                    }
                }

                // FINAL CALCULATIONS
                const todasMateriasPendentes = [...materiasPendentes, ...materiasPendentesFinais];
                const todasMateriasConcluidas = [...materiasConcluidas, ...materiasConcluidasPorEquivalencia];
                const todasMateriasOptativas = optativasRestantes;

                // Calculate integrated hours
                let horasIntegralizadas = 0;
                for (const disciplina of disciplinasCasadas) {
                    if ((disciplina.status === 'APR' || disciplina.status === 'CUMP') && disciplina.carga_horaria) {
                        horasIntegralizadas += disciplina.carga_horaria;
                    }
                }
                dadosValidacao.horas_integralizadas = horasIntegralizadas;

                // Final summary
                logger.info("Processing summary:");
                logger.info(`Total disciplines: ${disciplinasCasadas.length}`);
                logger.info(`Completed mandatory: ${todasMateriasConcluidas.length}`);
                logger.info(`Pending mandatory: ${todasMateriasPendentes.length}`);
                logger.info(`Electives: ${todasMateriasOptativas.length}`);
                logger.info(`Completion percentage: ${(todasMateriasConcluidas.length / (todasMateriasConcluidas.length + todasMateriasPendentes.length) * 100).toFixed(2)}%`);

                return res.status(200).json({
                    disciplinas_casadas: disciplinasCasadas,
                    materias_concluidas: todasMateriasConcluidas,
                    materias_pendentes: todasMateriasPendentes,
                    materias_optativas: todasMateriasOptativas,
                    dados_validacao: dadosValidacao,
                    curso_extraido: curso_extraido,
                    matriz_curricular: matriz_curricular,
                    resumo: {
                        total_disciplinas: disciplinasCasadas.length,
                        total_obrigatorias_concluidas: todasMateriasConcluidas.length,
                        total_obrigatorias_pendentes: todasMateriasPendentes.length,
                        total_optativas: todasMateriasOptativas.length,
                        percentual_conclusao_obrigatorias: todasMateriasConcluidas.length / (todasMateriasConcluidas.length + todasMateriasPendentes.length) * 100
                    }
                });

            } catch (error: any) {
                logger.error(`Erro ao casar disciplinas: ${error.message}`);
                return res.status(500).json({ error: error.message || "Erro ao casar disciplinas" });
            }
        }),

        "upload-dados-fluxograma": new Pair(RequestType.POST, async (req: Request, res: Response) => {
            var log = createControllerLogger("FluxogramaController", "upload-dados-fluxograma");
            log.info("Upload fluxograma chamado");
            try {
                if (!await Utils.checkAuthorization(req as Request)) {
                    return res.status(401).json({ error: "Usuário não autorizado" });
                }

                var userId = req.headers["user-id"] || req.headers["User-ID"];

                const { fluxograma, periodo_letivo } = req.body;

                log.info(`Periodo letivo: ${periodo_letivo}`);
                log.info(`User ID: ${userId}`);

                const { data, error } = await SupabaseWrapper.get()
                    .from("dados_users")
                    .insert({
                        fluxograma_atual: fluxograma,
                        id_user: userId,
                        semestre_atual: periodo_letivo
                    }).select("*");
                if (error) throw error;
                return res.status(200).json(data);
            } catch (error: any) {
                log.error(`Erro ao salvar fluxograma: ${error.message}`);
                return res.status(500).json({ error: error.message || "Erro ao salvar fluxograma" });
            }
        })
    }
}
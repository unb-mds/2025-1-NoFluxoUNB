import { EndpointController, RequestType } from "../interfaces";
import { Pair } from "../utils";
import { Request, Response } from "express";
import { SupabaseWrapper } from "../supabase_wrapper";
import axios from 'axios';
import FormData from 'form-data';
import { createControllerLogger } from '../utils/controller_logger';

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

            const { data, error } = await SupabaseWrapper.get().from("cursos").select("*,materias_por_curso(materias(*))").like("nome_curso", "%" + req.query.nome_curso + "%");

            if (error) {
                logger.error(`Erro ao buscar fluxograma: ${error.message}`);
                return res.status(500).json({ error: error.message });
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

                // Extrair informações do PDF
                const curso_extraido = dados_extraidos.curso_extraido;
                const matriz_curricular = dados_extraidos.matriz_curricular;
                const media_ponderada = dados_extraidos.media_ponderada;
                const frequencia_geral = dados_extraidos.frequencia_geral;

                logger.info(`Curso extraído do PDF: "${curso_extraido}"`);
                logger.info(`Matriz curricular extraída: "${matriz_curricular}"`);

                if (!curso_extraido) {
                    logger.error("Curso não foi extraído do PDF");
                    return res.status(400).json({ error: "Curso não foi extraído do PDF" });
                }

                // Buscar curso no banco usando nome do curso e matriz curricular
                let query = SupabaseWrapper.get()
                    .from("cursos")
                    .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                    .like("nome_curso", "%" + curso_extraido + "%");

                // Se temos matriz curricular, usar ela para filtrar
                if (matriz_curricular) {
                    query = query.eq("matriz_curricular", matriz_curricular);
                }

                let { data: materiasBanco, error } = await query;

                if (error) {
                    logger.error(`Erro ao buscar matérias do curso: ${error.message}`);
                    return res.status(500).json({ error: error.message });
                }

                logger.info(`Cursos encontrados: ${materiasBanco?.length || 0}`);
                if (materiasBanco && materiasBanco.length > 0) {
                    logger.info(`Curso encontrado: ${materiasBanco[0].nome_curso}`);
                } else {
                    // Listar todos os cursos disponíveis para debug
                    const { data: todosCursos } = await SupabaseWrapper.get()
                        .from("cursos")
                        .select("nome_curso");
                    logger.info(`Cursos disponíveis no banco: ${todosCursos?.map(c => c.nome_curso).join(', ')}`);
                }

                if (!materiasBanco || materiasBanco.length === 0) {
                    logger.warn(`Curso não encontrado com matriz curricular específica. Tentando busca alternativa...`);
                    
                    // Busca alternativa: apenas pelo nome do curso
                    const { data: materiasBancoAlt, error: errorAlt } = await SupabaseWrapper.get()
                        .from("cursos")
                        .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                        .like("nome_curso", "%" + curso_extraido + "%");

                    if (errorAlt || !materiasBancoAlt || materiasBancoAlt.length === 0) {
                        logger.error(`Curso não encontrado: ${curso_extraido}`);
                        return res.status(404).json({
                            error: "Curso não encontrado",
                            curso_buscado: curso_extraido,
                            matriz_curricular_buscada: matriz_curricular,
                            cursos_disponiveis: await SupabaseWrapper.get().from("cursos").select("nome_curso, matriz_curricular")
                        });
                    }

                    logger.info(`Curso encontrado na busca alternativa: ${materiasBancoAlt[0].nome_curso}`);
                    materiasBanco = materiasBancoAlt;
                }

                const materiasBancoList = materiasBanco[0].materias_por_curso;
                // Filtrar matérias obrigatórias (nivel > 0) e optativas (nivel = 0)
                const materiasObrigatorias = materiasBancoList.filter((m: any) => m.nivel > 0);
                const materiasOptativas = materiasBancoList.filter((m: any) => m.nivel === 0);
                const disciplinasCasadas: any[] = [];
                const materiasConcluidas: any[] = [];
                const materiasPendentes: any[] = [];
                const materiasOptativasConcluidas: any[] = [];
                const materiasOptativasPendentes: any[] = [];

                logger.info(`Total de matérias no curso: ${materiasBancoList.length}`);
                logger.info(`Matérias obrigatórias: ${materiasObrigatorias.length}`);
                logger.info(`Matérias optativas: ${materiasOptativas.length}`);

                // Extrair dados de validação do PDF
                const dadosValidacao = {
                    ira: null as number | null,
                    media_ponderada: media_ponderada ? parseFloat(media_ponderada) : null,
                    frequencia_geral: frequencia_geral ? parseFloat(frequencia_geral) : null,
                    horas_integralizadas: 0,
                    pendencias: [],
                    curso_extraido: curso_extraido,
                    matriz_curricular: matriz_curricular
                };

                // Buscar dados de validação nos dados extraídos
                for (const item of dados_extraidos.extracted_data) {
                    if (item.IRA) {
                        dadosValidacao.ira = parseFloat(item.valor);
                        logger.info(`IRA extraído do PDF: ${dadosValidacao.ira}`);
                    }
                    if (item.tipo_dado === 'Pendencias') {
                        dadosValidacao.pendencias = item.valores || [];
                        logger.info(`Pendências extraídas do PDF: ${dadosValidacao.pendencias.join(', ')}`);
                    }
                }

                logger.info(`Média ponderada extraída: ${dadosValidacao.media_ponderada}`);
                logger.info(`Frequência geral extraída: ${dadosValidacao.frequencia_geral}`);

                // Debug: verificar se há matérias com nível 0 ou nulo
                const materiasNivelZero = materiasBancoList.filter((m: any) => m.nivel === 0 || m.nivel === null);
                logger.info(`Matérias com nível 0 ou nulo: ${materiasNivelZero.length}`);
                if (materiasNivelZero.length > 0) {
                    logger.info(`Matérias nível 0: ${materiasNivelZero.map((m: any) => `${m.materias.nome_materia} (nível: ${m.nivel})`).join(', ')}`);
                }

                // Debug: verificar se há matérias duplicadas
                const nomesMaterias = materiasBancoList.map((m: any) => m.materias.nome_materia);
                const nomesUnicos = [...new Set(nomesMaterias)];
                logger.info(`Verificação de duplicatas - Total: ${nomesMaterias.length}, Únicos: ${nomesUnicos.length}`);
                if (nomesMaterias.length !== nomesUnicos.length) {
                    logger.warn("Encontradas matérias duplicadas");
                    const duplicatas = nomesMaterias.filter((nome: string, index: number) => nomesMaterias.indexOf(nome) !== index);
                    logger.warn(`Matérias duplicadas: ${[...new Set(duplicatas)].join(', ')}`);
                }

                // Casamento das disciplinas
                for (const disciplina of dados_extraidos.extracted_data) {
                    if (disciplina.tipo_dado === 'Disciplina Regular' || disciplina.tipo_dado === 'Disciplina CUMP') {

                        // Tentar casar primeiro com matérias obrigatórias
                        let materiaBanco = materiasObrigatorias.find((m: any) => {
                            const nomeMatch = m.materias.nome_materia.toLowerCase().trim() === disciplina.nome.toLowerCase().trim();
                            const codigoMatch = m.materias.codigo_materia.toLowerCase().trim() === (disciplina.codigo || '').toLowerCase().trim();
                            return nomeMatch || codigoMatch;
                        });

                        // Se não encontrou nas obrigatórias, tentar nas optativas
                        if (!materiaBanco) {
                            materiaBanco = materiasOptativas.find((m: any) => {
                                const nomeMatch = m.materias.nome_materia.toLowerCase().trim() === disciplina.nome.toLowerCase().trim();
                                const codigoMatch = m.materias.codigo_materia.toLowerCase().trim() === (disciplina.codigo || '').toLowerCase().trim();
                                return nomeMatch || codigoMatch;
                            });
                        }

                        if (materiaBanco) {
                            // Verificar se já existe uma disciplina casada com o mesmo ID
                            const disciplinaExistente = disciplinasCasadas.find((d: any) => d.id_materia === materiaBanco.materias.id_materia);

                            if (disciplinaExistente) {
                                // Se já existe, verificar qual status tem prioridade
                                const statusAtual = disciplinaExistente.status;
                                const statusNovo = disciplina.status;

                                // Prioridade: APR/CUMP > MATR > REP
                                const prioridade = (status: string) => {
                                    if (status === 'APR' || status === 'CUMP') return 3;
                                    if (status === 'MATR') return 2;
                                    return 1; // REP, etc.
                                };

                                if (prioridade(statusNovo) > prioridade(statusAtual)) {
                                    // Substituir pela versão com status melhor
                                    const index = disciplinasCasadas.findIndex((d: any) => d.id_materia === materiaBanco.materias.id_materia);
                                    disciplinasCasadas[index] = {
                                        ...disciplina,
                                        id_materia: materiaBanco.materias.id_materia,
                                        encontrada_no_banco: true,
                                        nivel: materiaBanco.nivel,
                                        tipo: materiaBanco.nivel === 0 ? 'optativa' : 'obrigatoria'
                                    };
                                    logger.info(`Atualizando status de "${disciplina.nome}": ${statusAtual} → ${statusNovo}`);
                                }
                            } else {
                                // Primeira ocorrência da matéria
                                const disciplinaCasada = {
                                    ...disciplina,
                                    id_materia: materiaBanco.materias.id_materia,
                                    encontrada_no_banco: true,
                                    nivel: materiaBanco.nivel,
                                    tipo: materiaBanco.nivel === 0 ? 'optativa' : 'obrigatoria'
                                };
                                disciplinasCasadas.push(disciplinaCasada);
                            }
                        } else {
                            // Disciplina não encontrada no banco (nem obrigatória nem optativa)
                            const disciplinaNaoEncontrada = {
                                ...disciplina,
                                id_materia: null,
                                encontrada_no_banco: false,
                                nivel: null,
                                tipo: 'nao_encontrada'
                            };
                            disciplinasCasadas.push(disciplinaNaoEncontrada);
                            logger.warn(`Disciplina não encontrada no banco: ${disciplina.nome}`);
                        }
                    }
                }

                // Classificar as disciplinas casadas por status e tipo
                for (const disciplinaCasada of disciplinasCasadas) {
                    if (disciplinaCasada.status === 'APR' || disciplinaCasada.status === 'CUMP') {
                        // Matéria concluída
                        if (disciplinaCasada.tipo === 'optativa') {
                            materiasOptativasConcluidas.push({
                                ...disciplinaCasada,
                                status_fluxograma: 'concluida'
                            });
                        } else {
                            materiasConcluidas.push({
                                ...disciplinaCasada,
                                status_fluxograma: 'concluida'
                            });
                        }
                    } else if (disciplinaCasada.status === 'MATR') {
                        // Matéria em andamento
                        if (disciplinaCasada.tipo === 'optativa') {
                            materiasOptativasPendentes.push({
                                ...disciplinaCasada,
                                status_fluxograma: 'em_andamento'
                            });
                        } else {
                            materiasPendentes.push({
                                ...disciplinaCasada,
                                status_fluxograma: 'em_andamento'
                            });
                        }
                    } else {
                        // Matéria não concluída (REP, etc.)
                        if (disciplinaCasada.tipo === 'optativa') {
                            materiasOptativasPendentes.push({
                                ...disciplinaCasada,
                                status_fluxograma: 'pendente'
                            });
                        } else {
                            materiasPendentes.push({
                                ...disciplinaCasada,
                                status_fluxograma: 'pendente'
                            });
                        }
                    }
                }

                // Adicionar matérias obrigatórias do banco que não foram encontradas no histórico
                const materiasObrigatoriasNaoEncontradas = materiasObrigatorias.filter((materiaBanco: any) => {
                    return !disciplinasCasadas.some((disc: any) =>
                        disc.id_materia === materiaBanco.materias.id_materia
                    );
                }).map((materiaBanco: any) => ({
                    id_materia: materiaBanco.materias.id_materia,
                    nome: materiaBanco.materias.nome_materia,
                    codigo: materiaBanco.materias.codigo_materia,
                    nivel: materiaBanco.nivel,
                    encontrada_no_banco: true,
                    encontrada_no_historico: false,
                    tipo: 'obrigatoria',
                    status_fluxograma: 'nao_cursada'
                }));

                // Combinar todas as matérias pendentes
                const todasMateriasPendentes = [...materiasPendentes, ...materiasObrigatoriasNaoEncontradas];
                const todasMateriasOptativas = [...materiasOptativasConcluidas, ...materiasOptativasPendentes];
                
                // Calcular horas integralizadas
                let horasIntegralizadas = 0;
                logger.info("Calculando horas integralizadas:");
                for (const disciplina of disciplinasCasadas) {
                    if ((disciplina.status === 'APR' || disciplina.status === 'CUMP') && disciplina.carga_horaria) {
                        logger.info(`${disciplina.nome} - ${disciplina.carga_horaria}h (${disciplina.status})`);
                        horasIntegralizadas += disciplina.carga_horaria;
                    }
                }
                dadosValidacao.horas_integralizadas = horasIntegralizadas;
                logger.info(`Total de horas integralizadas: ${horasIntegralizadas}h`);

                // Log do resumo final
                logger.info("Resumo do processamento:");
                logger.info(`Total de disciplinas: ${disciplinasCasadas.length}`);
                logger.info(`Obrigatórias concluídas: ${materiasConcluidas.length}`);
                logger.info(`Obrigatórias pendentes: ${todasMateriasPendentes.length}`);
                logger.info(`Optativas: ${todasMateriasOptativas.length}`);
                logger.info(`Percentual de conclusão: ${(materiasConcluidas.length / (materiasConcluidas.length + todasMateriasPendentes.length) * 100).toFixed(2)}%`);

                return res.status(200).json({
                    disciplinas_casadas: disciplinasCasadas,
                    materias_concluidas: materiasConcluidas,
                    materias_pendentes: todasMateriasPendentes,
                    materias_optativas: todasMateriasOptativas,
                    dados_validacao: dadosValidacao,
                    curso_extraido: curso_extraido,
                    matriz_curricular: matriz_curricular,
                    resumo: {
                        total_disciplinas: disciplinasCasadas.length,
                        total_obrigatorias_concluidas: materiasConcluidas.length,
                        total_obrigatorias_pendentes: todasMateriasPendentes.length,
                        total_optativas: todasMateriasOptativas.length,
                        percentual_conclusao_obrigatorias: materiasConcluidas.length / (materiasConcluidas.length + todasMateriasPendentes.length) * 100
                    }
                });

            } catch (error: any) {
                logger.error(`Erro ao casar disciplinas: ${error.message}`);
                return res.status(500).json({ error: error.message || "Erro ao casar disciplinas" });
            }
        })
    }
}
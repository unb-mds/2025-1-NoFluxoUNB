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
                    logger.warn("Curso não foi extraído do PDF automaticamente");
                    // Buscar todos os cursos disponíveis para o usuário escolher
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

                // Se extraiu palavras-chave, fazer busca fuzzy
                let cursosFiltrados = null;
                if (curso_extraido.startsWith('PALAVRAS_CHAVE:')) {
                    const palavrasChave = curso_extraido.replace('PALAVRAS_CHAVE:', '').split(',');
                    logger.info(`Buscando cursos com palavras-chave: ${palavrasChave.join(', ')}`);
                    
                    // Buscar cursos que contenham alguma das palavras-chave
                    const { data: todosCursos } = await SupabaseWrapper.get()
                        .from("cursos")
                        .select("nome_curso, matriz_curricular")
                        .order("nome_curso");
                    
                    if (todosCursos) {
                        cursosFiltrados = todosCursos.filter(curso => 
                            palavrasChave.some((palavra: string) => 
                                curso.nome_curso?.toUpperCase().includes(palavra.toUpperCase())
                            )
                        );
                        logger.info(`Encontrados ${cursosFiltrados.length} cursos com palavras-chave`);
                    }
                }

                // Buscar curso no banco
                let materiasBanco = null;
                let error = null;

                if (cursosFiltrados && cursosFiltrados.length > 0) {
                    if (cursosFiltrados.length === 1) {
                        // Se só há um curso filtrado, usar ele
                        const cursoSelecionado = cursosFiltrados[0];
                        logger.info(`Usando curso filtrado: ${cursoSelecionado.nome_curso}`);
                        
                        const { data, error: queryError } = await SupabaseWrapper.get()
                            .from("cursos")
                            .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                            .eq("nome_curso", cursoSelecionado.nome_curso);
                        
                        materiasBanco = data;
                        error = queryError;
                    } else {
                        // Se há múltiplos cursos, retornar para o usuário escolher
                        logger.info(`Múltiplos cursos encontrados: ${cursosFiltrados.length}`);
                        return res.status(400).json({ 
                            error: "Múltiplos cursos encontrados",
                            message: "Por favor, selecione o curso correto",
                            cursos_disponiveis: cursosFiltrados,
                            palavras_chave_encontradas: curso_extraido.replace('PALAVRAS_CHAVE:', '').split(',')
                        });
                    }
                } else {
                    // Busca normal por nome do curso e matriz curricular
                    let query = SupabaseWrapper.get()
                        .from("cursos")
                        .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                        .like("nome_curso", "%" + curso_extraido + "%");

                    // Se temos matriz curricular, usar ela para filtrar
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
                    
                    // Busca alternativa: pelo nome do curso e matriz curricular, se existir
                    let queryAlt = SupabaseWrapper.get()
                        .from("cursos")
                        .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                        .like("nome_curso", "%" + curso_extraido + "%");
                    if (matriz_curricular) {
                        queryAlt = queryAlt.eq("matriz_curricular", matriz_curricular);
                    }
                    const { data: materiasBancoAlt, error: errorAlt } = await queryAlt;

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

                // Novo fluxo de casamento de disciplinas
                const disciplinasCasadas: any[] = [];
                const materiasConcluidas: any[] = [];
                const materiasPendentes: any[] = [];
                const materiasOptativasConcluidas: any[] = [];
                const materiasOptativasPendentes: any[] = [];

                for (const disciplina of dados_extraidos.extracted_data) {
                    if (!(disciplina.tipo_dado === 'Disciplina Regular' || disciplina.tipo_dado === 'Disciplina CUMP')) continue;
                    let encontrada = false;
                    let materiaBanco = null;
                    // 1º: Casar como obrigatória (código)
                    materiaBanco = materiasObrigatorias.find((m: any) => m.materias.codigo_materia && disciplina.codigo && m.materias.codigo_materia.toLowerCase().trim() === disciplina.codigo.toLowerCase().trim());
                    // 2º: Se não encontrou, tentar pelo nome
                    if (!materiaBanco) {
                        materiaBanco = materiasObrigatorias.find((m: any) => m.materias.nome_materia.toLowerCase().trim() === disciplina.nome.toLowerCase().trim());
                    }
                    // 3º: Se não encontrou, buscar equivalência genérica
                    if (!materiaBanco) {
                        const { data: equivalenciasGenericas } = await SupabaseWrapper.get()
                            .from("equivalencias")
                            .select("*,materias(*)")
                            .is("id_curso", null)
                            .or(`expressao.eq.${disciplina.codigo},expressao.eq.${disciplina.nome}`);
                        if (equivalenciasGenericas && equivalenciasGenericas.length > 0) {
                            materiaBanco = equivalenciasGenericas[0].materias;
                        }
                    }
                    // 4º: Se não encontrou, buscar equivalência específica para o curso do usuário
                    if (!materiaBanco && materiasBanco && materiasBanco[0] && materiasBanco[0].id_curso) {
                        const idCursoUsuario = materiasBanco[0].id_curso;
                        const { data: equivalenciasEspecificas } = await SupabaseWrapper.get()
                            .from("equivalencias")
                            .select("*,materias(*)")
                            .eq("id_curso", idCursoUsuario)
                            .or(`expressao.eq.${disciplina.codigo},expressao.eq.${disciplina.nome}`);
                        if (equivalenciasEspecificas && equivalenciasEspecificas.length > 0) {
                            materiaBanco = equivalenciasEspecificas[0].materias;
                        }
                    }
                    // 5º: Se não encontrou, tentar casar como optativa (código)
                    if (!materiaBanco) {
                        materiaBanco = materiasOptativas.find((m: any) => m.materias.codigo_materia && disciplina.codigo && m.materias.codigo_materia.toLowerCase().trim() === disciplina.codigo.toLowerCase().trim());
                    }
                    // 6º: Se não encontrou, tentar casar como optativa (nome)
                    if (!materiaBanco) {
                        materiaBanco = materiasOptativas.find((m: any) => m.materias.nome_materia.toLowerCase().trim() === disciplina.nome.toLowerCase().trim());
                    }
                    // 7º: Se encontrou em algum passo acima, classifica
                    if (materiaBanco) {
                        encontrada = true;
                        const tipo = materiaBanco.nivel === 0 ? 'optativa' : 'obrigatoria';
                        const disciplinaCasada = {
                            ...disciplina,
                            id_materia: materiaBanco.id_materia,
                            encontrada_no_banco: true,
                            nivel: materiaBanco.nivel,
                            tipo: tipo
                        };
                        disciplinasCasadas.push(disciplinaCasada);
                        if (disciplina.status === 'APR' || disciplina.status === 'CUMP') {
                            if (tipo === 'optativa') {
                                materiasOptativasConcluidas.push({ ...disciplinaCasada, status_fluxograma: 'concluida' });
                            } else {
                                materiasConcluidas.push({ ...disciplinaCasada, status_fluxograma: 'concluida' });
                            }
                        } else if (disciplina.status === 'MATR') {
                            if (tipo === 'optativa') {
                                materiasOptativasPendentes.push({ ...disciplinaCasada, status_fluxograma: 'em_andamento' });
                            } else {
                                materiasPendentes.push({ ...disciplinaCasada, status_fluxograma: 'em_andamento' });
                            }
                        } else {
                            if (tipo === 'optativa') {
                                materiasOptativasPendentes.push({ ...disciplinaCasada, status_fluxograma: 'pendente' });
                            } else {
                                materiasPendentes.push({ ...disciplinaCasada, status_fluxograma: 'pendente' });
                            }
                        }
                    }
                    // 8º: Se não encontrou em nenhum, adiciona como módulo livre
                    if (!encontrada) {
                        disciplinasCasadas.push(disciplina);
                    }
                }

                // Corrigir a montagem de materiasObrigatoriasNaoEncontradas
                const materiasObrigatoriasNaoEncontradas = materiasObrigatorias.filter((materiaBanco: any) => {
                    return !disciplinasCasadas.some((disc: any) =>
                        disc.id_materia === materiaBanco.id_materia
                    );
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

                // Adicionar log antes do loop de equivalências para listar obrigatórias não encontradas
                logger.info(`[DEBUG-LISTA-OBRIGATORIAS-NAO-ENCONTRADAS] Matérias obrigatórias não encontradas no histórico:`);
                for (const mat of materiasObrigatoriasNaoEncontradas) {
                    logger.info(`[DEBUG-LISTA-OBRIGATORIAS-NAO-ENCONTRADAS] ${mat.nome} (${mat.codigo})`);
                }

                // Após montar disciplinasCasadas e materiasObrigatoriasNaoEncontradas
                const materiasConcluidasPorEquivalencia: any[] = [];
                const materiasPendentesAjustadas: any[] = [];
                for (const materiaObrigatoria of materiasObrigatoriasNaoEncontradas) {
                    const codigoObrigatoria = materiaObrigatoria.codigo; // deve ser o codigo_materia
                    const idMateriaObrigatoria = materiaObrigatoria.id_materia;
                    let cumpridaPorEquivalencia = false;
                    // Verifica equivalência explícita do PDF
                    const eqPdf = dados_extraidos.equivalencias_pdf.find((eq: any) => eq.cumpriu === codigoObrigatoria);
                    if (eqPdf) {
                        materiasConcluidasPorEquivalencia.push({
                            ...materiaObrigatoria,
                            status_fluxograma: 'concluida_equivalencia_pdf',
                            equivalencia: eqPdf.nome_equivalente
                        });
                        logger.info(`[DEBUG-EQUIV-PDF] Matéria obrigatória '${materiaObrigatoria.nome}' (${materiaObrigatoria.codigo}) marcada como concluída por equivalência explícita do PDF com '${eqPdf.nome_equivalente}' (${eqPdf.atraves_de})`);
                        continue; // pula para a próxima obrigatória
                    }
                    // Buscar equivalências para a obrigatória (id_materia = obrigatória)
                    const { data: equivalencias } = await SupabaseWrapper.get()
                        .from("equivalencias")
                        .select("id_equivalencia,expressao")
                        .eq("id_materia", idMateriaObrigatoria);
                    logger.info(`[DEBUG] Buscando equivalências para obrigatória '${materiaObrigatoria.nome}' (${codigoObrigatoria}) [id_materia=${idMateriaObrigatoria}]`);
                    logger.info(`[DEBUG] Resultado equivalências: ${JSON.stringify(equivalencias)}`);
                    if (equivalencias && equivalencias.length > 0) {
                        for (const eq of equivalencias) {
                            // Revisar extração de códigos de matéria da expressão
                            // Extrai todos os códigos de matéria (ex: FGA0108, MAT0038) da expressão, mesmo dentro de parênteses
                            const codigosEquivalentes = Array.from(eq.expressao.matchAll(/[A-Z]{2,}\d{3,}/gi)).map((m: any) => m[0].replace(/\s+/g, '').toUpperCase());
                            for (const codigoEq of codigosEquivalentes) {
                                const encontrada = disciplinasCasadas.find(
                                    d => d.codigo === codigoEq && (d.status === 'APR' || d.status === 'CUMP')
                                );
                                if (encontrada) {
                                    cumpridaPorEquivalencia = true;
                                    materiasConcluidasPorEquivalencia.push({
                                        ...materiaObrigatoria,
                                        status_fluxograma: 'concluida_equivalencia',
                                        equivalencia: encontrada.nome
                                    });
                                    logger.info(`[DEBUG] Matéria obrigatória '${materiaObrigatoria.nome}' (${codigoObrigatoria}) marcada como concluída por equivalência com '${encontrada.nome}' (${encontrada.codigo})`);
                                    break;
                                }
                            }
                            if (cumpridaPorEquivalencia) break;
                        }
                    }
                    if (!cumpridaPorEquivalencia) {
                        materiasPendentesAjustadas.push(materiaObrigatoria);
                    }
                }
                // Atualizar listas finais
                const todasMateriasPendentes = [...materiasPendentes, ...materiasPendentesAjustadas];
                const todasMateriasConcluidas = [...materiasConcluidas, ...materiasConcluidasPorEquivalencia];

                // Novo bloco: antes de processar as optativas, tente casar equivalências específicas para obrigatórias
                const optativasParaProcessar = [...materiasOptativasConcluidas, ...materiasOptativasPendentes];
                const optativasRestantes: any[] = [];
                for (const disciplinaOptativa of optativasParaProcessar) {
                    let marcadaComoEquivalencia = false;
                    // Debug específico para Teoria dos Números
                    if (disciplinaOptativa.codigo === 'MAT0038' || disciplinaOptativa.nome?.toUpperCase().includes('TEORIA DOS NÚMEROS')) {
                        logger.info(`[DEBUG-TEORIA] Processando Teoria dos Números: ${JSON.stringify(disciplinaOptativa)}`);
                    }
                    // Buscar se essa disciplina do histórico é equivalência de alguma obrigatória do curso
                    const { data: obrigatoriasEquivalentes } = await SupabaseWrapper.get()
                        .from("equivalencias")
                        .select("id_equivalencia,id_materia,expressao");
                    if (obrigatoriasEquivalentes && obrigatoriasEquivalentes.length > 0) {
                        for (const eq of obrigatoriasEquivalentes) {
                            // Só processa se a expressão contém o código da optativa
                            if (!eq.expressao || !eq.expressao.toUpperCase().includes(disciplinaOptativa.codigo)) continue;
                            // Buscar a obrigatória correspondente
                            const obrigatoria = materiasObrigatoriasNaoEncontradas.find((m: any) => m.id_materia === eq.id_materia);
                            if (!obrigatoria) continue;
                            // Extrai todos os códigos de matéria (ex: FGA0108, MAT0038) da expressão, mesmo dentro de parênteses
                            const codigosEquivalentes = Array.from(eq.expressao.matchAll(/[A-Z]{2,}\d{3,}/g)).map((m: any) => m[0]);
                            logger.info(`[DEBUG-TEORIA-ESPECIFICA-TRACE] Checando equivalência id=${eq.id_equivalencia}, expressao=${eq.expressao}, obrigatoria=${obrigatoria.nome} (${obrigatoria.codigo})`);
                            // Debug específico para equivalência 8522
                            if (eq.id_equivalencia === 8522 && eq.expressao.includes('MAT0038')) {
                                logger.info(`[DEBUG-TEORIA-ESPECIFICA] Verificando se Teoria dos Números (MAT0038) está sendo considerada equivalência específica para '${obrigatoria.nome}' (${obrigatoria.codigo})`);
                            }
                            for (const codigoEq of codigosEquivalentes) {
                                const encontrada = disciplinasCasadas.find(
                                    d => d.codigo === codigoEq && (d.status === 'APR' || d.status === 'CUMP')
                                );
                                if (encontrada) {
                                    if ((disciplinaOptativa.codigo === 'MAT0038' || disciplinaOptativa.nome?.toUpperCase().includes('TEORIA DOS NÚMEROS')) && eq.id_equivalencia === 8522) {
                                        logger.info(`[DEBUG-TEORIA-ESPECIFICA] Teoria dos Números (MAT0038) marcada como equivalência específica para '${obrigatoria.nome}' (${obrigatoria.codigo}) via expressão '${eq.expressao}' (id_equivalencia=8522)`);
                                    }
                                    materiasConcluidasPorEquivalencia.push({
                                        ...obrigatoria,
                                        status_fluxograma: 'concluida_equivalencia',
                                        equivalencia: disciplinaOptativa.nome
                                    });
                                    logger.info(`[DEBUG] Disciplina do histórico '${disciplinaOptativa.nome}' (${disciplinaOptativa.codigo}) marcada como equivalência específica para obrigatória '${obrigatoria.nome}' (${obrigatoria.codigo})`);
                                    marcadaComoEquivalencia = true;
                                    break;
                                }
                            }
                            if (marcadaComoEquivalencia) break;
                        }
                    }
                    if (!marcadaComoEquivalencia) {
                        optativasRestantes.push(disciplinaOptativa);
                    }
                }
                // Agora use optativasRestantes para montar todasMateriasOptativas
                const todasMateriasOptativas = [...optativasRestantes];
                
                // Calcular horas integralizadas
                let horasIntegralizadas = 0;
                logger.info("Calculando horas integralizadas:");
                for (const disciplina of disciplinasCasadas) {
                    if ((disciplina.status === 'APR' || disciplina.status === 'CUMP') && disciplina.carga_horaria) {
                        logger.info(`${disciplina.nome} - ${disciplina.carga_horaria}h (${disciplina.status})`);
                        horasIntegralizadas += disciplina.carga_horaria;
                    }
                }
                const dadosValidacao = {
                    ira: null as number | null,
                    media_ponderada: media_ponderada ? parseFloat(media_ponderada) : null,
                    frequencia_geral: frequencia_geral ? parseFloat(frequencia_geral) : null,
                    horas_integralizadas: horasIntegralizadas,
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

                // Após processar disciplinasCasadas, materiasObrigatoriasNaoEncontradas, optativasRestantes
                // Identificar módulos livres: disciplinas do histórico que não foram casadas nem como obrigatória nem optativa
                const codigosCasados = new Set([
                    ...disciplinasCasadas.map((d: any) => d.codigo),
                    ...materiasConcluidasPorEquivalencia.map((d: any) => d.equivalencia ? d.equivalencia : d.codigo),
                    ...materiasConcluidas.map((d: any) => d.codigo),
                    ...materiasOptativasConcluidas.map((d: any) => d.codigo),
                    ...materiasOptativasPendentes.map((d: any) => d.codigo)
                ]);
                const modulosLivres = dados_extraidos.extracted_data.filter((disc: any) => {
                    return (disc.tipo_dado === 'Disciplina Regular' || disc.tipo_dado === 'Disciplina CUMP') && !codigosCasados.has(disc.codigo);
                });
                logger.info(`[DEBUG] Módulos livres encontrados: ${modulosLivres.map((d: any) => d.nome + ' (' + d.codigo + ')').join(', ')}`);

                return res.status(200).json({
                    disciplinas_casadas: disciplinasCasadas,
                    materias_concluidas: todasMateriasConcluidas,
                    materias_pendentes: todasMateriasPendentes,
                    materias_optativas: todasMateriasOptativas,
                    modulos_livres: modulosLivres,
                    dados_validacao: dadosValidacao,
                    curso_extraido: curso_extraido,
                    matriz_curricular: matriz_curricular,
                    resumo: {
                        total_disciplinas: disciplinasCasadas.length,
                        total_obrigatorias_concluidas: todasMateriasConcluidas.length,
                        total_obrigatorias_pendentes: todasMateriasPendentes.length,
                        total_optativas: todasMateriasOptativas.length,
                        total_modulos_livres: modulosLivres.length,
                        percentual_conclusao_obrigatorias: todasMateriasConcluidas.length / (todasMateriasConcluidas.length + todasMateriasPendentes.length) * 100
                    }
                });

            } catch (error: any) {
                logger.error(`Erro ao casar disciplinas: ${error.message}`);
                return res.status(500).json({ error: error.message || "Erro ao casar disciplinas" });
            }
        })
    }
}
import { EndpointController, RequestType } from "../interfaces";
import { Pair } from "../utils";
import { Request, Response } from "express";
import { SupabaseWrapper } from "../supabase_wrapper";

export const TestesController: EndpointController = {
    name: "testes",
    routes: {
        "banco": new Pair(RequestType.GET, async (req: Request, res: Response) => {
            try {
                console.log("🧪 Executando teste de conexão com banco...");
                
                // Teste 1: Listar todos os cursos
                const { data: cursos, error: errorCursos } = await SupabaseWrapper.get()
                    .from("cursos")
                    .select("nome_curso");
                
                if (errorCursos) {
                    return res.status(500).json({ 
                        teste: "conexao_banco",
                        status: "erro",
                        erro: errorCursos.message 
                    });
                }

                // Teste 2: Verificar estrutura da tabela materias_por_curso
                const { data: materiasTeste, error: errorMaterias } = await SupabaseWrapper.get()
                    .from("cursos")
                    .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                    .limit(1);

                if (errorMaterias) {
                    return res.status(500).json({ 
                        teste: "estrutura_materias",
                        status: "erro",
                        erro: errorMaterias.message 
                    });
                }

                // Teste 3: Verificar se há matérias com nível 0 ou nulo
                const materiasNivelZero = materiasTeste?.[0]?.materias_por_curso?.filter((m: any) => m.nivel === 0 || m.nivel === null) || [];
                
                // Teste 4: Verificar duplicatas
                const nomesMaterias = materiasTeste?.[0]?.materias_por_curso?.map((m: any) => m.materias.nome_materia) || [];
                const nomesUnicos = [...new Set(nomesMaterias)];
                const duplicatas = nomesMaterias.filter((nome: string, index: number) => nomesMaterias.indexOf(nome) !== index);

                return res.status(200).json({
                    teste: "conexao_banco",
                    status: "sucesso",
                    resultados: {
                        total_cursos: cursos?.length || 0,
                        cursos_disponiveis: cursos?.map(c => c.nome_curso) || [],
                        estrutura_valida: materiasTeste && materiasTeste.length > 0,
                        materias_nivel_zero: materiasNivelZero.length,
                        materias_nivel_zero_lista: materiasNivelZero.map((m: any) => ({
                            nome: m.materias.nome_materia,
                            nivel: m.nivel
                        })),
                        verificar_duplicatas: {
                            total_nomes: nomesMaterias.length,
                            nomes_unicos: nomesUnicos.length,
                            tem_duplicatas: nomesMaterias.length !== nomesUnicos.length,
                            duplicatas_encontradas: [...new Set(duplicatas)]
                        }
                    }
                });

            } catch (error: any) {
                return res.status(500).json({ 
                    teste: "conexao_banco",
                    status: "erro",
                    erro: error.message 
                });
            }
        }),

        "curso": new Pair(RequestType.GET, async (req: Request, res: Response) => {
            try {
                const nome_curso = req.query.nome_curso as string;
                
                if (!nome_curso) {
                    return res.status(400).json({ 
                        teste: "busca_curso",
                        status: "erro",
                        erro: "Nome do curso não informado" 
                    });
                }

                console.log(`🧪 Testando busca do curso: "${nome_curso}"`);

                // Buscar matérias do curso no banco
                const { data: materiasBanco, error } = await SupabaseWrapper.get()
                    .from("cursos")
                    .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                    .like("nome_curso", "%" + nome_curso + "%");

                if (error) {
                    return res.status(500).json({ 
                        teste: "busca_curso",
                        status: "erro",
                        erro: error.message 
                    });
                }

                if (!materiasBanco || materiasBanco.length === 0) {
                    // Listar todos os cursos disponíveis
                    const { data: todosCursos } = await SupabaseWrapper.get()
                        .from("cursos")
                        .select("nome_curso");
                    
                    return res.status(404).json({ 
                        teste: "busca_curso",
                        status: "curso_nao_encontrado",
                        curso_buscado: nome_curso,
                        cursos_disponiveis: todosCursos?.map(c => c.nome_curso) || []
                    });
                }

                const curso = materiasBanco[0];
                const materiasBancoList = curso.materias_por_curso;
                const materiasObrigatorias = materiasBancoList.filter((m: any) => m.nivel > 0);
                const materiasOptativas = materiasBancoList.filter((m: any) => m.nivel === 0);

                // Verificar duplicatas
                const nomesMaterias = materiasBancoList.map((m: any) => m.materias.nome_materia);
                const nomesUnicos = [...new Set(nomesMaterias)];
                const duplicatas = nomesMaterias.filter((nome: string, index: number) => nomesMaterias.indexOf(nome) !== index);

                return res.status(200).json({
                    teste: "busca_curso",
                    status: "sucesso",
                    curso_encontrado: curso.nome_curso,
                    resultados: {
                        total_materias: materiasBancoList.length,
                        materias_obrigatorias: materiasObrigatorias.length,
                        materias_optativas: materiasOptativas.length,
                        verificar_duplicatas: {
                            total_nomes: nomesMaterias.length,
                            nomes_unicos: nomesUnicos.length,
                            tem_duplicatas: nomesMaterias.length !== nomesUnicos.length,
                            duplicatas_encontradas: [...new Set(duplicatas)]
                        },
                        niveis_encontrados: [...new Set(materiasBancoList.map((m: any) => m.nivel))].sort(),
                        primeiras_5_materias: materiasObrigatorias.slice(0, 5).map((m: any) => ({
                            nome: m.materias.nome_materia,
                            codigo: m.materias.codigo_materia,
                            nivel: m.nivel
                        }))
                    }
                });

            } catch (error: any) {
                return res.status(500).json({ 
                    teste: "busca_curso",
                    status: "erro",
                    erro: error.message 
                });
            }
        }),

        "casamento": new Pair(RequestType.POST, async (req: Request, res: Response) => {
            try {
                const { dados_extraidos, nome_curso } = req.body;

                if (!dados_extraidos || !nome_curso) {
                    return res.status(400).json({ 
                        teste: "casamento_disciplinas",
                        status: "erro",
                        erro: "Dados extraídos e nome do curso são obrigatórios" 
                    });
                }

                console.log(`🧪 Testando casamento de disciplinas para: "${nome_curso}"`);

                // Buscar matérias do curso no banco
                const { data: materiasBanco, error } = await SupabaseWrapper.get()
                    .from("cursos")
                    .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                    .like("nome_curso", "%" + nome_curso + "%");

                if (error) {
                    return res.status(500).json({ 
                        teste: "casamento_disciplinas",
                        status: "erro",
                        erro: error.message 
                    });
                }

                if (!materiasBanco || materiasBanco.length === 0) {
                    return res.status(404).json({ 
                        teste: "casamento_disciplinas",
                        status: "curso_nao_encontrado",
                        curso_buscado: nome_curso
                    });
                }

                const materiasBancoList = materiasBanco[0].materias_por_curso;
                const materiasObrigatorias = materiasBancoList.filter((m: any) => m.nivel > 0);
                const materiasOptativas = materiasBancoList.filter((m: any) => m.nivel === 0);
                const disciplinasCasadas: any[] = [];

                // Extrair dados de validação do PDF
                const dadosValidacao = {
                    ira: null as number | null,
                    horas_integralizadas: 0,
                    pendencias: []
                };

                // Buscar dados de validação nos dados extraídos
                for (const item of dados_extraidos.extracted_data) {
                    if (item.IRA) {
                        dadosValidacao.ira = parseFloat(item.valor);
                    }
                    if (item.tipo_dado === 'Pendencias') {
                        dadosValidacao.pendencias = item.valores || [];
                    }
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
                            // Disciplina não encontrada no banco
                            const disciplinaNaoEncontrada = {
                                ...disciplina,
                                id_materia: null,
                                encontrada_no_banco: false,
                                nivel: null,
                                tipo: 'nao_encontrada'
                            };
                            disciplinasCasadas.push(disciplinaNaoEncontrada);
                        }
                    }
                }

                // Calcular horas integralizadas
                let horasIntegralizadas = 0;
                for (const disciplina of disciplinasCasadas) {
                    if ((disciplina.status === 'APR' || disciplina.status === 'CUMP') && disciplina.carga_horaria) {
                        horasIntegralizadas += disciplina.carga_horaria;
                    }
                }
                dadosValidacao.horas_integralizadas = horasIntegralizadas;

                // Classificar disciplinas
                const materiasConcluidas = disciplinasCasadas.filter(d => 
                    (d.status === 'APR' || d.status === 'CUMP') && d.tipo !== 'optativa'
                );
                const materiasPendentes = disciplinasCasadas.filter(d => 
                    d.status !== 'APR' && d.status !== 'CUMP' && d.tipo !== 'optativa'
                );
                const materiasOptativasConcluidas = disciplinasCasadas.filter(d => 
                    (d.status === 'APR' || d.status === 'CUMP') && d.tipo === 'optativa'
                );
                const materiasOptativasPendentes = disciplinasCasadas.filter(d => 
                    d.status !== 'APR' && d.status !== 'CUMP' && d.tipo === 'optativa'
                );

                return res.status(200).json({
                    teste: "casamento_disciplinas",
                    status: "sucesso",
                    curso: nome_curso,
                    resultados: {
                        dados_validacao: dadosValidacao,
                        estatisticas: {
                            total_disciplinas_extraidas: dados_extraidos.extracted_data.filter((d: any) => 
                                d.tipo_dado === 'Disciplina Regular' || d.tipo_dado === 'Disciplina CUMP'
                            ).length,
                            total_disciplinas_casadas: disciplinasCasadas.length,
                            disciplinas_encontradas_no_banco: disciplinasCasadas.filter(d => d.encontrada_no_banco).length,
                            disciplinas_nao_encontradas: disciplinasCasadas.filter(d => !d.encontrada_no_banco).length,
                            materias_concluidas: materiasConcluidas.length,
                            materias_pendentes: materiasPendentes.length,
                            materias_optativas_concluidas: materiasOptativasConcluidas.length,
                            materias_optativas_pendentes: materiasOptativasPendentes.length
                        },
                        breakdown: {
                            materias_obrigatorias_banco: materiasObrigatorias.length,
                            materias_optativas_banco: materiasOptativas.length,
                            disciplinas_casadas: disciplinasCasadas.length,
                            materias_concluidas: materiasConcluidas.length,
                            materias_pendentes: materiasPendentes.length,
                            materias_optativas_concluidas: materiasOptativasConcluidas.length,
                            materias_optativas_pendentes: materiasOptativasPendentes.length,
                            soma_obrigatorias: materiasConcluidas.length + materiasPendentes.length,
                            total_optativas: materiasOptativasConcluidas.length + materiasOptativasPendentes.length
                        }
                    }
                });

            } catch (error: any) {
                return res.status(500).json({ 
                    teste: "casamento_disciplinas",
                    status: "erro",
                    erro: error.message 
                });
            }
        }),

        "completo": new Pair(RequestType.POST, async (req: Request, res: Response) => {
            try {
                const { dados_extraidos, nome_curso } = req.body;

                if (!dados_extraidos || !nome_curso) {
                    return res.status(400).json({ 
                        teste: "teste_completo",
                        status: "erro",
                        erro: "Dados extraídos e nome do curso são obrigatórios" 
                    });
                }

                console.log(`🧪 Executando teste completo para: "${nome_curso}"`);

                // Executar todos os testes em sequência
                const resultados: {
                    teste_banco: any;
                    teste_curso: any;
                    teste_casamento: any;
                } = {
                    teste_banco: null,
                    teste_curso: null,
                    teste_casamento: null
                };

                // Teste 1: Conexão com banco
                try {
                    const { data: cursos } = await SupabaseWrapper.get()
                        .from("cursos")
                        .select("nome_curso");
                    
                    resultados.teste_banco = {
                        status: "sucesso",
                        total_cursos: cursos?.length || 0
                    };
                } catch (error: any) {
                    resultados.teste_banco = {
                        status: "erro",
                        erro: error.message
                    };
                }

                // Teste 2: Busca do curso
                try {
                    const { data: materiasBanco, error } = await SupabaseWrapper.get()
                        .from("cursos")
                        .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                        .like("nome_curso", "%" + nome_curso + "%");

                    if (error) throw error;

                    if (!materiasBanco || materiasBanco.length === 0) {
                        resultados.teste_curso = {
                            status: "curso_nao_encontrado",
                            curso_buscado: nome_curso
                        };
                    } else {
                        const materiasBancoList = materiasBanco[0].materias_por_curso;
                        const materiasObrigatorias = materiasBancoList.filter((m: any) => m.nivel > 0);
                        const materiasOptativas = materiasBancoList.filter((m: any) => m.nivel === 0);

                        resultados.teste_curso = {
                            status: "sucesso",
                            curso_encontrado: materiasBanco[0].nome_curso,
                            total_materias: materiasBancoList.length,
                            materias_obrigatorias: materiasObrigatorias.length,
                            materias_optativas: materiasOptativas.length
                        };
                    }
                } catch (error: any) {
                    resultados.teste_curso = {
                        status: "erro",
                        erro: error.message
                    };
                }

                // Teste 3: Casamento de disciplinas (só se o curso foi encontrado)
                if (resultados.teste_curso && resultados.teste_curso.status === "sucesso") {
                    try {
                        // Lógica de casamento simplificada para teste
                        const disciplinasExtraidas = dados_extraidos.extracted_data.filter((d: any) => 
                            d.tipo_dado === 'Disciplina Regular' || d.tipo_dado === 'Disciplina CUMP'
                        );

                        resultados.teste_casamento = {
                            status: "sucesso",
                            total_disciplinas_extraidas: disciplinasExtraidas.length,
                            disciplinas_com_status: disciplinasExtraidas.filter((d: any) => d.status).length
                        };
                    } catch (error: any) {
                        resultados.teste_casamento = {
                            status: "erro",
                            erro: error.message
                        };
                    }
                } else {
                    resultados.teste_casamento = {
                        status: "pulado",
                        motivo: "Curso não encontrado"
                    };
                }

                return res.status(200).json({
                    teste: "teste_completo",
                    status: "concluido",
                    curso: nome_curso,
                    resultados: resultados,
                    resumo: {
                        testes_executados: Object.keys(resultados).length,
                        testes_sucesso: Object.values(resultados).filter((r: any) => r?.status === "sucesso").length,
                        testes_erro: Object.values(resultados).filter((r: any) => r?.status === "erro").length
                    }
                });

            } catch (error: any) {
                return res.status(500).json({ 
                    teste: "teste_completo",
                    status: "erro",
                    erro: error.message 
                });
            }
        })
    }
} 
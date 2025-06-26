import { EndpointController, RequestType } from "../interfaces";
import { Pair } from "../utils";
import { Request, Response } from "express";
import { SupabaseWrapper } from "../supabase_wrapper";
import axios from 'axios';
import FormData from 'form-data';


export const FluxogramaController: EndpointController = {
    name: "fluxograma",
    routes: {
        "fluxograma": new Pair(RequestType.GET, async (req: Request, res: Response) => {

            console.log(`Chamando fluxograma`);
            const nome_curso = req.query.nome_curso as string;

            console.log(nome_curso);
            if (!nome_curso) {
                console.log(`Nome do curso não informado`);
                return res.status(400).json({ error: "Nome do curso não informado" });
            }


            const { data, error } = await SupabaseWrapper.get().from("cursos").select("*,materias_por_curso(materias(*))").like("nome_curso","%"+req.query.nome_curso+"%");

            if (error) {
                console.log(error);
                return res.status(500).json({ error: error.message });
            }

            console.log(data);

            return res.status(200).json(data);
        }),

        "read_pdf": new Pair(RequestType.POST, async (req: Request, res: Response) => {
            try {
                if (!req.files || !req.files.pdf) {
                    return res.status(400).json({ error: "Arquivo PDF não enviado." });
                }

                const pdfFile = Array.isArray(req.files.pdf) ? req.files.pdf[0] : req.files.pdf;
                const form = new FormData();
                form.append('pdf', pdfFile.data, pdfFile.name);

                // Envia para o Python
                const response = await axios.post(
                    'http://localhost:3001/upload-pdf',
                    form,
                    { headers: form.getHeaders() }
                );

                // Retorna a resposta do Python para o frontend
                return res.status(200).json(response.data);
            } catch (error: any) {
                return res.status(500).json({ error: error.message || "Erro ao processar PDF" });
            }
        }),

        "casar_disciplinas": new Pair(RequestType.POST, async (req: Request, res: Response) => {
            console.log("🚀 Endpoint casar_disciplinas foi chamado!");
            try {
                const { dados_extraidos, nome_curso } = req.body;

                if (!dados_extraidos || !nome_curso) {
                    return res.status(400).json({ error: "Dados extraídos e nome do curso são obrigatórios" });
                }

                console.log(`🔍 Buscando curso: "${nome_curso}"`);

                // Buscar matérias do curso no banco
                const { data: materiasBanco, error } = await SupabaseWrapper.get()
                    .from("cursos")
                    .select("*,materias_por_curso(id_materia,nivel,materias(*))")
                    .like("nome_curso", "%" + nome_curso + "%");

                if (error) {
                    console.log(error);
                    return res.status(500).json({ error: error.message });
                }

                console.log(`📋 Cursos encontrados: ${materiasBanco?.length || 0}`);
                if (materiasBanco && materiasBanco.length > 0) {
                    console.log(`✅ Curso encontrado: ${materiasBanco[0].nome_curso}`);
                } else {
                    // Listar todos os cursos disponíveis para debug
                    const { data: todosCursos } = await SupabaseWrapper.get()
                        .from("cursos")
                        .select("nome_curso");
                    console.log(`📚 Cursos disponíveis no banco:`, todosCursos?.map(c => c.nome_curso));
                }

                if (!materiasBanco || materiasBanco.length === 0) {
                    return res.status(404).json({ 
                        error: "Curso não encontrado",
                        curso_buscado: nome_curso,
                        cursos_disponiveis: await SupabaseWrapper.get().from("cursos").select("nome_curso")
                    });
                }

                const materiasBancoList = materiasBanco[0].materias_por_curso;
                // Filtrar apenas matérias obrigatórias (nivel > 0)
                const materiasObrigatorias = materiasBancoList.filter((m: any) => m.nivel > 0);
                const disciplinasCasadas: any[] = [];
                const materiasConcluidas: any[] = [];
                const materiasPendentes: any[] = [];

                console.log(`📚 Total de matérias no curso: ${materiasBancoList.length}`);
                console.log(`📖 Matérias obrigatórias (nivel > 0): ${materiasObrigatorias.length}`);
                
                // Debug: verificar se há matérias com nível 0 ou nulo
                const materiasNivelZero = materiasBancoList.filter((m: any) => m.nivel === 0 || m.nivel === null);
                console.log(`🔍 Matérias com nível 0 ou nulo: ${materiasNivelZero.length}`);
                if (materiasNivelZero.length > 0) {
                    console.log(`📋 Matérias nível 0:`, materiasNivelZero.map((m: any) => `${m.materias.nome_materia} (nível: ${m.nivel})`));
                }
                
                // Debug: verificar se há matérias duplicadas
                const nomesMaterias = materiasBancoList.map((m: any) => m.materias.nome_materia);
                const nomesUnicos = [...new Set(nomesMaterias)];
                console.log(`🔍 Verificação de duplicatas:`);
                console.log(`   Total de nomes: ${nomesMaterias.length}`);
                console.log(`   Nomes únicos: ${nomesUnicos.length}`);
                if (nomesMaterias.length !== nomesUnicos.length) {
                    console.log(`⚠️  ENCONTRADAS DUPLICATAS!`);
                    const duplicatas = nomesMaterias.filter((nome: string, index: number) => nomesMaterias.indexOf(nome) !== index);
                    console.log(`   Duplicatas:`, [...new Set(duplicatas)]);
                }
                
                // Debug: ver algumas matérias para entender a estrutura
                if (materiasBancoList.length > 0) {
                    console.log(`🔍 Exemplo de matéria:`, materiasBancoList[0]);
                    console.log(`🔍 Níveis encontrados:`, materiasBancoList.map((m: any) => m.nivel));
                }
                
                // Debug: mostrar algumas matérias do banco
                console.log(`📚 PRIMEIRAS 5 MATÉRIAS DO BANCO:`);
                materiasObrigatorias.slice(0, 5).forEach((m: any, index: number) => {
                    console.log(`${index + 1}. "${m.materias.nome_materia}" (${m.materias.codigo_materia}) - Nível: ${m.nivel}`);
                });

                // Casamento das disciplinas
                for (const disciplina of dados_extraidos.extracted_data) {
                    if (disciplina.tipo_dado === 'Disciplina Regular' || disciplina.tipo_dado === 'Disciplina CUMP') {
                        
                        const materiaBanco = materiasObrigatorias.find((m: any) => {
                            const nomeMatch = m.materias.nome_materia.toLowerCase().trim() === disciplina.nome.toLowerCase().trim();
                            const codigoMatch = m.materias.codigo_materia.toLowerCase().trim() === (disciplina.codigo || '').toLowerCase().trim();
                            return nomeMatch || codigoMatch;
                        });

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
                                        nivel: materiaBanco.nivel
                                    };
                                    console.log(`🔄 Atualizando status de "${disciplina.nome}": ${statusAtual} → ${statusNovo}`);
                                }
                            } else {
                                // Primeira ocorrência da matéria
                                const disciplinaCasada = {
                                    ...disciplina,
                                    id_materia: materiaBanco.materias.id_materia,
                                    encontrada_no_banco: true,
                                    nivel: materiaBanco.nivel
                                };
                                disciplinasCasadas.push(disciplinaCasada);
                            }
                        }
                    }
                }

                // Adicionar matérias obrigatórias do banco que não foram encontradas no histórico
                const materiasNaoEncontradas = materiasObrigatorias.filter((materiaBanco: any) => {
                    // Verifica se a matéria NÃO foi encontrada em nenhuma disciplina casada
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
                    status_fluxograma: 'nao_cursada'
                }));

                // Combinar todas as matérias pendentes (apenas as que não foram encontradas no histórico)
                const todasMateriasPendentes = [...materiasPendentes, ...materiasNaoEncontradas];

                console.log(`🔍 BREAKDOWN DA CONTAGEM:`);
                console.log(`   Matérias obrigatórias no banco: ${materiasObrigatorias.length}`);
                console.log(`   Disciplinas casadas: ${disciplinasCasadas.length}`);
                console.log(`   Matérias concluídas: ${materiasConcluidas.length}`);
                console.log(`   Matérias pendentes (do histórico): ${materiasPendentes.length}`);
                console.log(`   Matérias não encontradas no histórico: ${materiasNaoEncontradas.length}`);
                console.log(`   TOTAL matérias pendentes: ${todasMateriasPendentes.length}`);
                console.log(`   SOMA: ${materiasConcluidas.length + todasMateriasPendentes.length}`);
                console.log(`   VERIFICAÇÃO: ${materiasConcluidas.length + materiasPendentes.length + materiasNaoEncontradas.length} (deveria ser ${materiasObrigatorias.length})`);
                
                // Debug detalhado das categorias
                console.log(`\n🔍 DEBUG DETALHADO:`);
                console.log(`📚 MATÉRIAS CONCLUÍDAS (${materiasConcluidas.length}):`);
                materiasConcluidas.forEach((m: any, i: number) => console.log(`   ${i+1}. ${m.nome} (${m.status})`));
                
                console.log(`📚 MATÉRIAS PENDENTES DO HISTÓRICO (${materiasPendentes.length}):`);
                materiasPendentes.forEach((m: any, i: number) => console.log(`   ${i+1}. ${m.nome} (${m.status})`));
                
                console.log(`📚 MATÉRIAS NÃO ENCONTRADAS NO HISTÓRICO (${materiasNaoEncontradas.length}):`);
                materiasNaoEncontradas.forEach((m: any, i: number) => console.log(`   ${i+1}. ${m.nome}`));
                
                // Verificar se há IDs duplicados
                const todosIds = [...materiasConcluidas, ...materiasPendentes, ...materiasNaoEncontradas].map(m => m.id_materia);
                const idsUnicos = [...new Set(todosIds)];
                console.log(`🔍 Verificação de IDs: ${todosIds.length} total, ${idsUnicos.length} únicos`);
                if (todosIds.length !== idsUnicos.length) {
                    console.log(`⚠️  IDs DUPLICADOS ENCONTRADOS!`);
                }

                // Classificar as disciplinas casadas por status
                for (const disciplinaCasada of disciplinasCasadas) {
                    if (disciplinaCasada.status === 'APR' || disciplinaCasada.status === 'CUMP') {
                        // Matéria concluída
                        materiasConcluidas.push({
                            ...disciplinaCasada,
                            status_fluxograma: 'concluida'
                        });
                    } else if (disciplinaCasada.status === 'MATR') {
                        // Matéria em andamento
                        materiasPendentes.push({
                            ...disciplinaCasada,
                            status_fluxograma: 'em_andamento'
                        });
                    } else {
                        // Matéria não concluída (REP, etc.)
                        materiasPendentes.push({
                            ...disciplinaCasada,
                            status_fluxograma: 'pendente'
                        });
                    }
                }

                return res.status(200).json({
                    disciplinas_casadas: disciplinasCasadas,
                    materias_concluidas: materiasConcluidas,
                    materias_pendentes: todasMateriasPendentes,
                    resumo: {
                        total_disciplinas: disciplinasCasadas.length,
                        total_concluidas: materiasConcluidas.length,
                        total_pendentes: todasMateriasPendentes.length,
                        percentual_conclusao: materiasConcluidas.length / (materiasConcluidas.length + todasMateriasPendentes.length) * 100
                    }
                });

            } catch (error: any) {
                console.error("Erro ao casar disciplinas:", error);
                return res.status(500).json({ error: error.message || "Erro ao casar disciplinas" });
            }
        })
    }
}
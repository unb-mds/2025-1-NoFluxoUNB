/**
 * Serviço do Agente Planejador — Executa ferramentas (tools) e loop de tool calling
 * com a API da Maritaca (sabiá-3, compatible com OpenAI).
 *
 * Responsabilidades:
 *   - Executores das 4 tools: consultar_plano, simular_cenario, ajustar_carga, mover_materia
 *   - Loop de tool calling: chamadas à Maritaca, coleta de resultados, feedback
 *   - Guard-rails: máx 5 iterações, histórico truncado em 20 mensagens
 *   - Normalização de códigos (trim + uppercase)
 *
 * Spec: docs/chat-agente-planejador-spec.md
 * Design: docs/chat-agente-planejador-design.md (status: aprovado 2026-07-04)
 */

import { gerarPlanoCompletov2 } from "./plano_formatura.service";
import { createControllerLogger } from "../utils/controller_logger";
import { SupabaseWrapper } from "../supabase_wrapper";
import { searchInternet } from "../utils/web_search";
import type {
    MateriaInput,
    PlanoFormaturav2,
    PreferenciasPlano,
    RestricoesPlano,
    MateriaPlano,
} from "../types/planejamento";

const logger = createControllerLogger("PlanejadorAgenteService", "conversar");

// =========================================================
// Tipos Públicos
// =========================================================

export interface MensagemChat {
    role: "user" | "assistant";
    content: string;
}

export interface RestricoesPlanoInternas {
    adiar: string[];
    priorizar: string[];
    limitesPersonalizados: Record<number, number>;
}

/**
 * Contexto do agente — materiais para regenerar plano com restrições atualizadas.
 */
export interface AgenteContexto {
    materias: MateriaInput[];
    cargaHorariaIntegralizada: any;
    exigidaMatriz: any;
    fluxogramaAtual: string | null | undefined;
    idUser: string;
    idCurso: string;
    numeroPeriodo: number;
    preferencias: PreferenciasPlano;
    restricoes: RestricoesPlanoInternas;
    codigosComOferta: Set<string>;
}

export interface AgenteResultado {
    reply: string;
    plano?: PlanoFormaturav2;
    restricoes: RestricoesPlanoInternas;
}

export interface LlmMessage {
    role: string;
    content: string | null;
    tool_calls?: Array<{
        id: string;
        function: { name: string; arguments: string };
    }>;
}

export type ChamarLlmFn = (
    messages: any[],
    tools: any[],
    useWebSearch?: boolean
) => Promise<LlmMessage>;

// =========================================================
// Constantes
// =========================================================

const MAX_ITERACOES = 5;
const MAX_HISTORICO = 20;
const MARITACA_URL = "https://chat.maritaca.ai/api/chat/completions";

function norm(codigo: string): string {
    return (codigo || "").trim().toUpperCase();
}

// =========================================================
// Executores de Tools
// =========================================================

function resumoDoPlano(plano: PlanoFormaturav2, ctx: AgenteContexto): Record<string, any> {
    const criticas = plano.plano
        .flatMap((s) => s.materias)
        .filter((m) => "critica" in m && (m as MateriaPlano).critica)
        .map((m) => (m as MateriaPlano).codigo);

    return {
        semestresRestantes: plano.semestresRestantes,
        formaturaEstimada: plano.formaturaEstimada ?? null,
        materiasCriticas: criticas,
        materiasNaoAlocadas: plano.materiasNaoAlocadas,
        chOptativaFaltante: plano.chOptativaFaltante,
        chComplementarFaltante: plano.chComplementarFaltante,
        cargaPorSemestre: plano.plano.map(s => ({
            indice: s.indice,
            numeroSemestre: ctx.numeroPeriodo + s.indice + 1,
            semestreLabel: s.semestre,
            creditos: s.creditos
        })),
    };
}

function gerarPlanoDoContexto(ctx: AgenteContexto): PlanoFormaturav2 {
    return gerarPlanoCompletov2(
        ctx.idUser,
        ctx.idCurso,
        ctx.numeroPeriodo,
        ctx.cargaHorariaIntegralizada,
        ctx.exigidaMatriz,
        ctx.fluxogramaAtual,
        ctx.materias,
        {
            ...ctx.preferencias,
            restricoes: {
                adiar: ctx.restricoes.adiar,
                priorizar: ctx.restricoes.priorizar,
                limitesPersonalizados: ctx.restricoes.limitesPersonalizados,
            },
        },
        ctx.codigosComOferta
    );
}

function consultarPlano(
    args: Record<string, unknown>,
    ctx: AgenteContexto
): string {
    const plano = gerarPlanoDoContexto(ctx);
    const codigo = typeof args.codigo === "string" ? norm(args.codigo) : null;

    if (!codigo) return JSON.stringify(resumoDoPlano(plano, ctx));

    for (const s of plano.plano) {
        for (const m of s.materias) {
            if ("codigo" in m && (m as MateriaPlano).codigo === codigo) {
                const mp = m as MateriaPlano;
                return JSON.stringify({
                    codigo: mp.codigo,
                    nome: mp.nome,
                    semestreIndice: s.indice,
                    semestreLabel: s.semestre ?? null,
                    creditos: mp.creditos,
                    critica: mp.critica,
                    score: mp.score,
                    desbloqueiaDireto: mp.desbloqueiaDireto,
                    desbloqueiaIndireto: mp.desbloqueiaIndireto,
                    motivo: mp.motivo,
                });
            }
        }
    }
    return JSON.stringify({
        erro: `Matéria ${codigo} não encontrada no plano. Ela pode já estar concluída, em curso, ou não pertencer ao currículo.`,
    });
}

function simularCenario(
    args: Record<string, unknown>,
    ctx: AgenteContexto
): string {
    const antes = resumoDoPlano(gerarPlanoDoContexto(ctx), ctx);

    const simCtx: AgenteContexto = {
        ...ctx,
        preferencias: { ...ctx.preferencias },
        restricoes: {
            adiar: [...ctx.restricoes.adiar],
            priorizar: [...ctx.restricoes.priorizar],
            limitesPersonalizados: { ...ctx.restricoes.limitesPersonalizados },
        },
    };

    const limite = Number(args.limiteCreditos);
    if (Number.isFinite(limite) && limite >= 8 && limite <= 32) {
        simCtx.preferencias.limiteCreditos = Math.floor(limite);
    }
    if (Array.isArray(args.adiar)) {
        for (const c of args.adiar) if (typeof c === "string") simCtx.restricoes.adiar.push(norm(c));
    }
    if (Array.isArray(args.priorizar)) {
        for (const c of args.priorizar) if (typeof c === "string") simCtx.restricoes.priorizar.push(norm(c));
    }

    const depois = resumoDoPlano(gerarPlanoDoContexto(simCtx), simCtx);
    return JSON.stringify({
        antes,
        depois,
        deltaSemestres: depois.semestresRestantes - antes.semestresRestantes,
    });
}

function ajustarCarga(
    args: Record<string, unknown>,
    ctx: AgenteContexto
): { resultado: string; planoAtualizado?: PlanoFormaturav2 } {
    const limite = Number(args.limiteCreditos);
    if (!Number.isFinite(limite) || limite < 8 || limite > 32) {
        return {
            resultado: JSON.stringify({
                erro: "limiteCreditos deve ser um inteiro entre 8 e 32.",
            }),
        };
    }
    ctx.preferencias.limiteCreditos = Math.floor(limite);
    if (args.objetivo === "velocidade" || args.objetivo === "equilibrado") {
        ctx.preferencias.objetivo = args.objetivo;
    }
    const plano = gerarPlanoDoContexto(ctx);
    return { resultado: JSON.stringify(resumoDoPlano(plano, ctx)), planoAtualizado: plano };
}

function ajustarCargaSemestre(
    args: Record<string, unknown>,
    ctx: AgenteContexto
): { resultado: string; planoAtualizado?: PlanoFormaturav2 } {
    const indice = Number(args.semestreIndice);
    const limite = Number(args.limiteCreditos);
    
    if (!Number.isFinite(indice) || indice < 0) {
        return { resultado: JSON.stringify({ erro: "semestreIndice deve ser um inteiro positivo." }) };
    }
    if (!Number.isFinite(limite) || limite < 0 || limite > 40) {
        return { resultado: JSON.stringify({ erro: "limiteCreditos deve ser um inteiro entre 0 e 40." }) };
    }

    if (!ctx.restricoes.limitesPersonalizados) {
        ctx.restricoes.limitesPersonalizados = {};
    }
    
    ctx.restricoes.limitesPersonalizados[Math.floor(indice)] = Math.floor(limite);
    
    const plano = gerarPlanoDoContexto(ctx);
    return { resultado: JSON.stringify(resumoDoPlano(plano, ctx)), planoAtualizado: plano };
}


function moverMateria(
    args: Record<string, unknown>,
    ctx: AgenteContexto
): { resultado: string; planoAtualizado?: PlanoFormaturav2 } {
    const codigo = typeof args.codigo === "string" ? norm(args.codigo) : "";
    const acao = args.acao;

    if (acao !== "adiar" && acao !== "priorizar" && acao !== "remover_restricao") {
        return {
            resultado: JSON.stringify({
                erro: "acao deve ser 'adiar', 'priorizar' ou 'remover_restricao'.",
            }),
        };
    }
    const existe = ctx.materias.some((m) => norm(m.codigo) === codigo);
    if (!existe) {
        return {
            resultado: JSON.stringify({
                erro: `Matéria ${codigo || "(vazio)"} não está entre as matérias faltantes do aluno.`,
            }),
        };
    }

    // Listas mutuamente exclusivas: entrar numa remove da outra.
    ctx.restricoes.adiar = ctx.restricoes.adiar.filter((c) => c !== codigo);
    ctx.restricoes.priorizar = ctx.restricoes.priorizar.filter((c) => c !== codigo);
    if (acao === "adiar") ctx.restricoes.adiar.push(codigo);
    if (acao === "priorizar") ctx.restricoes.priorizar.push(codigo);

    const plano = gerarPlanoDoContexto(ctx);
    return {
        resultado: JSON.stringify({
            mensagem: `Matéria ${codigo} tratada como ${acao}.`,
            planoAtualizado: resumoDoPlano(plano, ctx),
        }),
        planoAtualizado: plano,
    };
}

async function consultarInformacoesMateria(
    args: Record<string, unknown>
): Promise<string> {
    const codigo = typeof args.codigo === "string" ? norm(args.codigo) : "";
    if (!codigo) return JSON.stringify({ erro: "Código da matéria não fornecido." });

    try {
        const supabase = SupabaseWrapper.get();
        const { data, error } = await supabase
            .from("materias")
            .select("nome_materia, ementa, departamento, carga_horaria")
            .eq("codigo_materia", codigo)
            .single();

        if (error || !data) {
            return JSON.stringify({ erro: `Matéria ${codigo} não encontrada no banco de dados oficial.` });
        }

        return JSON.stringify({
            codigo,
            nome_materia: data.nome_materia,
            departamento: data.departamento,
            carga_horaria: data.carga_horaria,
            ementa: data.ementa || "Não cadastrada.",
            aviso: "Lembre-se de usar sua pesquisa web nativa (Sabiá) se o usuário perguntou sobre a dificuldade ou opiniões."
        });
    } catch (e) {
        return JSON.stringify({ erro: `Falha ao consultar informações da matéria ${codigo}.` });
    }
}

async function consultarTurmasMateria(args: Record<string, unknown>): Promise<string> {
    const codigo = typeof args.codigo === "string" ? norm(args.codigo) : "";
    if (!codigo) return JSON.stringify({ erro: "Código da matéria não fornecido." });

    try {
        const supabase = SupabaseWrapper.get();
        const { data: materiaData, error: materiaError } = await supabase
            .from("materias")
            .select("id_materia, nome_materia")
            .eq("codigo_materia", codigo)
            .single();

        if (materiaError || !materiaData) {
            return JSON.stringify({ erro: `Matéria ${codigo} não encontrada.` });
        }

        const { data: turmasRows, error: turmasError } = await supabase
            .from('turmas')
            .select('turma, docente, horario, local, vagas_ofertadas, vagas_ocupadas')
            .eq('id_materia', materiaData.id_materia)
            .order('ano_periodo', { ascending: false })
            .limit(10); // Trazer no máximo 10 turmas recentes

        if (turmasError || !turmasRows || turmasRows.length === 0) {
            return JSON.stringify({ erro: `Nenhuma turma encontrada para ${codigo} - ${materiaData.nome_materia}.` });
        }

        const turmasFormatadas = turmasRows.map(t => (
            `[TURMA|${t.turma || '?'}|${t.docente || 'A definir'}|${t.horario || '?'}|${t.local || '?'}|${t.vagas_ocupadas ?? '?'}/${t.vagas_ofertadas ?? '?'}]`
        ));

        return JSON.stringify({
            codigo,
            nome_materia: materiaData.nome_materia,
            instrucao_llm: "Para exibir as turmas, COPIE E COLE EXATAMENTE o formato gerado abaixo ([TURMA|...]). Não altere nada dentro dos colchetes, pois o frontend usa isso para desenhar a interface.",
            turmas_recentes: turmasFormatadas
        });
    } catch (e) {
        return JSON.stringify({ erro: `Falha ao consultar turmas da matéria ${codigo}.` });
    }
}

export async function executarTool(
    nome: string,
    args: Record<string, unknown>,
    ctx: AgenteContexto
): Promise<{ resultado: string; planoAtualizado?: PlanoFormaturav2 }> {
    try {
        switch (nome) {
            case "consultar_informacoes_materia":
                return { resultado: await consultarInformacoesMateria(args) };
            case "consultar_turmas_materia":
                return { resultado: await consultarTurmasMateria(args) };
            case "consultar_plano":
                return { resultado: consultarPlano(args, ctx) };
            case "simular_cenario":
                return { resultado: simularCenario(args, ctx) };
            case "ajustar_carga":
                return ajustarCarga(args, ctx);
            case "ajustar_carga_semestre":
                return ajustarCargaSemestre(args, ctx);
            case "mover_materia":
                return moverMateria(args, ctx);
            default:
                return {
                    resultado: JSON.stringify({ erro: `Tool desconhecida: ${nome}` }),
                };
        }
    } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        logger.error(`[PlanejadorAgente] Erro na tool ${nome}: ${msg}`);
        return {
            resultado: JSON.stringify({
                erro: `Falha interna na tool ${nome}: ${msg}`,
            }),
        };
    }
}

// =========================================================
// Serviço do Agente (Loop de Tool Calling)
// =========================================================

export class PlanejadorAgenteService {
    private chamarLlm: ChamarLlmFn;

    constructor(chamarLlm?: ChamarLlmFn) {
        this.chamarLlm = chamarLlm || this.chamarLlmMaritaca.bind(this);
    }

    isAvailable(): boolean {
        return !!process.env.MARITACA_API_KEY;
    }

	private shouldUseWebSearch(prompt: string): boolean {
		const p = prompt.toLowerCase();
		const dynamicSignals = [
			'hoje', 'agora', 'atual', 'atualmente', 'últimas', 'ultimas',
			'notícias', 'noticias', 'preço', 'precos', 'preço atual',
			'cotação', 'cotacao', 'lançamento', 'lancamento', 'mudou',
			'mudança', 'mudanca', 'site oficial', 'documentação',
			'documentacao', 'versão', 'versao', 'api', 'release', 'roadmap',
			'dificuldade', 'opinião', 'opiniao', 'fofoca', 'dizem'
		];
		return dynamicSignals.some(term => p.includes(term));
	}

    private async chamarLlmMaritaca(
        messages: any[],
        tools: any[],
        useWebSearch: boolean = false
    ): Promise<LlmMessage> {
        const apiKey = process.env.MARITACA_API_KEY;
        if (!apiKey) throw new Error("MARITACA_API_KEY não configurada");

        const response = await fetch(MARITACA_URL, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Key ${apiKey}`,
            },
            body: JSON.stringify({
                model: "sabia-3",
                messages,
                tools,
                tool_choice: "auto",
                web_search: useWebSearch
            }),
        });

        if (!response.ok) {
            const err = await response.text();
            throw new Error(
                `Maritaca API error: ${response.status} ${err}`
            );
        }

        const data = (await response.json()) as any;
        const choice = data.choices?.[0];
        if (!choice) throw new Error("Nenhuma resposta do LLM");

        return choice.message as LlmMessage;
    }

    async conversar(
        historico: MensagemChat[],
        ctx: AgenteContexto
    ): Promise<AgenteResultado> {
        // Truncar histórico nas últimas MAX_HISTORICO mensagens
        const historicoTruncado = historico.slice(-MAX_HISTORICO);

        const planoInicial = gerarPlanoDoContexto(ctx);
        const resumoInicialStr = JSON.stringify(resumoDoPlano(planoInicial, ctx));

        // System prompt — contexto completo para o agente
        const systemPrompt = `Você é o assistente inteligente de planejamento de formatura da plataforma NoFluxo (Universidade de Brasília — UnB).
Seu papel é ajudar alunos a entender, iterar e otimizar seu plano de formatura personalizado.

## Contexto do aluno
- Período atual: ${ctx.numeroPeriodo}
- Limite de créditos global: ${ctx.preferencias.limiteCreditos}
- Limites personalizados por semestre: ${JSON.stringify(ctx.restricoes.limitesPersonalizados || {})}
- Objetivo: ${ctx.preferencias.objetivo} (velocidade = formar rápido; equilibrado = carga balanceada)
- Trabalha/estagia: ${ctx.preferencias.trabalha ? "sim" : "não"}
- Matérias faltantes: ${ctx.materias.length}
- Restrições ativas: adiar=[${ctx.restricoes.adiar.join(", ")}], priorizar=[${ctx.restricoes.priorizar.join(", ")}]

## Resumo do Plano Atual
${resumoInicialStr}

## Suas ferramentas (tools)
Você tem ferramentas disponíveis que pode chamar diretamente:
1. **consultar_plano** — Consulta detalhes do plano (resumo geral ou matéria específica por código)
2. **simular_cenario** — Simula cenário alternativo SEM alterar o plano (mostra impacto de mudanças de carga, adiamentos, priorizações)
3. **ajustar_carga** — ALTERA o plano GLOBALMENTE: muda limite de créditos de todos os semestres
4. **ajustar_carga_semestre** — ALTERA o plano PONTUALMENTE: reduz a carga de um ÚNICO semestre específico sem alterar o ritmo global
5. **mover_materia** — ALTERA o plano: adia, prioriza ou remove restrição de uma matéria específica
6. **consultar_informacoes_materia** — Busca a ementa oficial da matéria no banco de dados.
7. **consultar_turmas_materia** — Busca professores, horários, locais e vagas das turmas de uma matéria.

## Rotas da API (referência — você NÃO chama diretamente, mas pode mencionar ao aluno)

### Planejamento (Motor 2)
- POST /planejamento/gerar-plano — Gera plano de formatura completo (currículo, matérias concluídas, preferências)
- POST /planejamento/chat — Este endpoint! O chat do agente planejador
- GET /planejamento/test-db — Teste de conexão com banco

### Fluxograma
- GET /fluxograma/fluxograma — Retorna o fluxograma do aluno (matérias + status)
- POST /fluxograma/casar_disciplinas — Compara matérias entre dois currículos (mudança de curso)
- POST /fluxograma/integralizacao — Processa integralização do histórico
- POST /fluxograma/upload-dados-fluxograma — Upload de dados do fluxograma
- DELETE /fluxograma/delete-fluxograma — Remove fluxograma salvo

### Assistente (Sabiá / RAG)
- POST /assistente/analyze — Consulta geral com RAG
- POST /assistente/analyze-sabia — Consulta via Sabiá (Maritaca AI)
- POST /assistente/analyze-sabia-stream — Consulta via Sabiá com streaming
- GET /assistente/turmas-by-codigo — Busca turmas ofertadas de uma matéria
- GET /assistente/prerequisitos-by-codigo — Busca pré-requisitos de uma matéria
- GET /assistente/health — Health check do assistente

### Matérias
- GET /materias/materias-name-by-code — Nome da matéria por código
- POST /materias/materias-from-codigos — Nomes de várias matérias por códigos

### Cursos
- GET /cursos/all-cursos — Lista todos os cursos disponíveis

### Usuários
- POST /users/register-user-with-google — Registro via Google
- GET /users/get-user-by-email — Busca usuário por email
- POST /users/registrar-user-with-email — Registro via email

## Agente Python (MCP Agent — porta 8000)
- POST http://localhost:8000/consultar — Consulta inteligente usando embeddings + Maritaca AI + Supabase
- GET http://localhost:8000/docs — Documentação Swagger do agente

## Regras de comportamento
1. Sempre responda em português brasileiro.
2. Seja conciso e direto. Evite respostas longas.
3. Use as tools para obter dados reais antes de responder — não invente informações sobre matérias, turmas ou plano.
4. Ao recomendar que o aluno "adie" ou "priorize" uma matéria, USE a tool mover_materia para aplicar a mudança.
5. Ao simular cenários, use simular_cenario (read-only) ANTES de aplicar com ajustar_carga.
6. Se o aluno perguntar sobre turmas, use a tool 'consultar_turmas_materia'. Você ESTÁ PROIBIDO de alterar ou formatar os dados da turma. Você DEVE obrigatoriamente COPIAR E COLAR exatamente os blocos [TURMA|...] devolvidos pela tool, inserindo um por linha. O frontend depende desse formato exato para renderizar a interface visual.
7. Códigos de matéria seguem padrão "DEP0000" (ex: MAT0026, CIC0004, EST0001). Sempre normalize para UPPERCASE.
8. Se não souber responder, diga que não tem essa informação e sugira consultar o coordenador do curso.
9. Ao remanejar ou reduzir carga (ex: aluno diz que um semestre está pesado), PERGUNTE SOBRE TRADE-OFFS. Ofereça explicitamente a opção de reduzir a carga apenas DAQUELE semestre (usando ajustar_carga_semestre) e pergunte se ele aceita o possível atraso na formatura.
10. INTERAÇÃO VISUAL: Sempre que fizer uma pergunta de "Sim/Não" ou apresentar opções de trade-offs, forneça botões interativos usando a sintaxe [BOTAO|Label|Mensagem enviada ao clicar]. Exemplos:
[BOTAO|Sim|Sim, pode reduzir a carga e atrasar a formatura.]
[BOTAO|Não|Não, prefiro manter o ritmo atual.]

## Regras de Busca na Web (Sabiá Native)
- Você possui capacidade nativa de buscar na web quando ativada pelo sistema.
- Se houver conflito entre fontes na web, informe a divergência com clareza.
- Não copie trechos longos de páginas; resuma com objetividade.
- Priorize fontes oficiais, documentação, páginas institucionais e veículos confiáveis (fóruns/reddit para opiniões).
- Quando a pergunta pedir opinião pública, reviews ou dificuldade prática de uma disciplina, considere a diversidade de fontes.`;

        // Definição das tools
        const tools = [
            {
                type: "function",
                function: {
                    name: "consultar_informacoes_materia",
                    description:
                        "Busca a ementa oficial da matéria no banco de dados. (Para nível de dificuldade ou opiniões, você pesquisará nativamente na internet).",
                    parameters: {
                        type: "object",
                        properties: {
                            codigo: {
                                type: "string",
                                description: "Código da matéria (ex: FGA0211). Obrigatório.",
                            },
                        },
                        required: ["codigo"],
                    },
                },
            },
            {
                type: "function",
                function: {
                    name: "consultar_turmas_materia",
                    description: "Busca as turmas ofertadas de uma matéria: Professores, horários, locais e vagas.",
                    parameters: {
                        type: "object",
                        properties: {
                            codigo: {
                                type: "string",
                                description: "Código da matéria (ex: MAT0026). Obrigatório.",
                            },
                        },
                        required: ["codigo"],
                    },
                },
            },
            {
                type: "function",
                function: {
                    name: "consultar_plano",
                    description:
                        "Consulta o plano de formatura do aluno. Se nenhum código for fornecido, retorna um resumo geral.",
                    parameters: {
                        type: "object",
                        properties: {
                            codigo: {
                                type: "string",
                                description:
                                    "Código da matéria para detalhes específicos (ex: MAT0026). Opcional.",
                            },
                        },
                    },
                },
            },
            {
                type: "function",
                function: {
                    name: "simular_cenario",
                    description:
                        "Simula um cenário alternativo sem alterar o plano atual. Mostra o impacto de mudanças.",
                    parameters: {
                        type: "object",
                        properties: {
                            limiteCreditos: {
                                type: "number",
                                description:
                                    "Créditos hipotéticos por semestre (8-32). Opcional.",
                            },
                            adiar: {
                                type: "array",
                                items: { type: "string" },
                                description:
                                    "Códigos de matérias a adiar. Opcional.",
                            },
                            priorizar: {
                                type: "array",
                                items: { type: "string" },
                                description:
                                    "Códigos de matérias a priorizar. Opcional.",
                            },
                        },
                    },
                },
            },
            {
                type: "function",
                function: {
                    name: "ajustar_carga",
                    description:
                        "Ajusta a carga semestral GLOBAL e/ou objetivo do aluno e regenera o plano.",
                    parameters: {
                        type: "object",
                        properties: {
                            limiteCreditos: {
                                type: "number",
                                description:
                                    "Novos créditos globais por semestre (8-32). Obrigatório.",
                            },
                            objetivo: {
                                type: "string",
                                enum: ["velocidade", "equilibrado"],
                                description:
                                    "Objetivo: velocidade ou equilibrado. Opcional.",
                            },
                        },
                        required: ["limiteCreditos"],
                    },
                },
            },
            {
                type: "function",
                function: {
                    name: "ajustar_carga_semestre",
                    description:
                        "Ajusta o limite de créditos de UM semestre ESPECÍFICO (usando o índice numérico dele, onde 0 é o primeiro) e regenera o plano para redistribuir a carga.",
                    parameters: {
                        type: "object",
                        properties: {
                            semestreIndice: {
                                type: "number",
                                description: "Índice interno do semestre (0, 1, 2...). Você deve mapear o número do semestre pedido pelo usuário (ex: 'Semestre 13') para o 'indice' correspondente verificando a propriedade 'numeroSemestre' no resumo do plano.",
                            },
                            limiteCreditos: {
                                type: "number",
                                description: "Novo limite máximo de créditos para ESTE semestre específico (0-40).",
                            },
                        },
                        required: ["semestreIndice", "limiteCreditos"],
                    },
                },
            },
            {
                type: "function",
                function: {
                    name: "mover_materia",
                    description:
                        "Move uma matéria: adia, prioriza ou remove restrição existente.",
                    parameters: {
                        type: "object",
                        properties: {
                            codigo: {
                                type: "string",
                                description: "Código da matéria (ex: MAT0026). Obrigatório.",
                            },
                            acao: {
                                type: "string",
                                enum: ["adiar", "priorizar", "remover_restricao"],
                                description:
                                    "Ação a executar. Obrigatório.",
                            },
                        },
                        required: ["codigo", "acao"],
                    },
                },
            },
        ];

        // Montar mensagens para o LLM
        let mensagensLlm: any[] = [
            { role: "system", content: systemPrompt },
            ...historicoTruncado.map((m) => ({
                role: m.role,
                content: m.content,
            })),
        ];

        let planoAtualizado: PlanoFormaturav2 | undefined;
        let iteracao = 0;

        // Loop de tool calling
        while (iteracao < MAX_ITERACOES) {
            iteracao++;

            // Avalia a última mensagem do usuário (ou a mais recente)
            const lastUserMsg = historicoTruncado.slice().reverse().find(m => m.role === "user");
            const useWebSearch = lastUserMsg ? this.shouldUseWebSearch(lastUserMsg.content) : false;

            logger.info(
                `[Iteração ${iteracao}] Chamando LLM com ${mensagensLlm.length} mensagens | web_search=${useWebSearch}`
            );

            // Chamar LLM
            const resposta = await this.chamarLlm(mensagensLlm, tools, useWebSearch);

            // Se conteúdo direto, não há tool call — retornar resposta
            if (resposta.content && !resposta.tool_calls) {
                logger.info(
                    `[Iteração ${iteracao}] Resposta final (sem tool call): ${resposta.content.slice(0, 50)}...`
                );
                return {
                    reply: resposta.content,
                    plano: planoAtualizado,
                    restricoes: ctx.restricoes,
                };
            }

            // Se há tool calls, executar
            if (resposta.tool_calls && resposta.tool_calls.length > 0) {
                // Adicionar resposta do assistente ao histórico
                mensagensLlm.push({
                    role: "assistant",
                    content: resposta.content,
                    tool_calls: resposta.tool_calls.map((tc) => ({
                        id: tc.id,
                        type: "function",
                        function: {
                            name: tc.function.name,
                            arguments: tc.function.arguments,
                        },
                    })),
                });

                // Executar cada tool
                for (const toolCall of resposta.tool_calls) {
                    const nome = toolCall.function.name;
                    let args: Record<string, unknown> = {};
                    try {
                        args = JSON.parse(toolCall.function.arguments);
                    } catch {
                        args = {};
                    }

                    logger.info(
                        `[Iteração ${iteracao}] Executando tool: ${nome} com args: ${JSON.stringify(args)}`
                    );

                    const { resultado, planoAtualizado: novoPlano } = await executarTool(
                        nome,
                        args,
                        ctx
                    );
                    if (novoPlano) {
                        planoAtualizado = novoPlano;
                    }

                    // Adicionar resultado como mensagem de tool
                    mensagensLlm.push({
                        role: "tool",
                        tool_call_id: toolCall.id,
                        content: resultado,
                    });
                }

                // Continuar o loop
                continue;
            }

            // Caso anômalo: resposta sem conteúdo e sem tool calls
            logger.warn(`[Iteração ${iteracao}] Resposta anômala do LLM`);
            return {
                reply: "Desculpe, não consegui processar sua pergunta.",
                plano: planoAtualizado,
                restricoes: ctx.restricoes,
            };
        }

        // Guard-rail: máximo de iterações atingido
        logger.warn(
            `[Agente] Máximo de iterações (${MAX_ITERACOES}) atingido`
        );
        return {
            reply: `Desculpe, não consegui concluir sua solicitação após ${MAX_ITERACOES} tentativas. Tente reformular sua pergunta.`,
            plano: planoAtualizado,
            restricoes: ctx.restricoes,
        };
    }
}

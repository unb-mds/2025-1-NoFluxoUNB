/**
 * Serviço do Agente Planejador — Executa ferramentas (tools) e loop de tool calling
 * com a API da Maritaca (compatible com OpenAI). Modelo em config/maritaca.ts.
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

import { createControllerLogger } from "../utils/controller_logger";
import { MARITACA_URL, MARITACA_MODELS } from "../config/maritaca";
import type { PlanoFormaturav2 } from "../types/planejamento";
import {
    type MensagemChat,
    type AgenteContexto,
    type AgenteResultado,
    type LlmMessage,
    type ChamarLlmFn,
} from "./agente/context";
import { montarSystemPrompt } from "./agente/system_prompt";
import { consultarTurmasMateria } from "./agente/tools/materia_tools";
import { defaultRegistry } from "./agente/tools";

// Re-exports para compatibilidade com quem importa do service (controllers, testes).
export type {
    MensagemChat,
    RestricoesPlanoInternas,
    AgenteContexto,
    AgenteResultado,
    LlmMessage,
    ChamarLlmFn,
} from "./agente/context";

const logger = createControllerLogger("PlanejadorAgenteService", "conversar");

// =========================================================
// Constantes
// =========================================================

const MAX_ITERACOES = 5;
const MAX_HISTORICO = 20;

// =========================================================
// Executor de Tools — thin wrapper sobre o Tool Registry compartilhado.
// Mantido para compatibilidade (testes e chamadas internas via /planejamento/chat).
// =========================================================

export async function executarTool(
    nome: string,
    args: Record<string, unknown>,
    ctx: AgenteContexto
): Promise<{ resultado: string; planoAtualizado?: PlanoFormaturav2 }> {
    return defaultRegistry.execute(nome, args, ctx);
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

    private async chamarLlmMaritaca(
        messages: any[],
        tools: any[]
    ): Promise<LlmMessage> {
        const apiKey = process.env.MARITACA_API_KEY;
        if (!apiKey) throw new Error("MARITACA_API_KEY não configurada");

        const response = await fetch(MARITACA_URL, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Key ${apiKey}`,
            },
            // NÃO enviar web_search: a Maritaca ignora as tools quando ele está
            // ligado — tool_calls volta null e o modelo inventa que a ferramenta
            // falhou. As tools são o núcleo deste agente, então elas ganham.
            body: JSON.stringify({
                model: MARITACA_MODELS.AGENTE,
                messages,
                tools,
                tool_choice: "auto"
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

        // Interceptar comandos diretos (Bypass do LLM)
        const lastUserMsg = historicoTruncado.slice().reverse().find(m => m.role === "user");
        if (lastUserMsg && lastUserMsg.content.trim().toLowerCase().startsWith('/turmas ')) {
            const codigo = lastUserMsg.content.trim().substring(8).trim().toUpperCase();
            const turmasJson = await consultarTurmasMateria({ codigo });
            const turmasData = JSON.parse(turmasJson);
            
            if (turmasData.erro) {
                return {
                    reply: turmasData.erro,
                    restricoes: ctx.restricoes
                };
            }
            
            const reply = `Aqui estão as turmas que encontrei para **${turmasData.codigo} - ${turmasData.nome_materia}**:\n\n` + turmasData.turmas_recentes.join('\n');
            return {
                reply,
                restricoes: ctx.restricoes
            };
        }

        const systemPrompt = montarSystemPrompt(ctx);

        // Tools do registry compartilhado, filtradas pelo contexto: as que dependem
        // de plano ficam ocultas quando o contexto é leve (ex: aba Assistente sem login).
        const tools = defaultRegistry.schemasFor(ctx);

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

            logger.info(
                `[Iteração ${iteracao}] Chamando LLM com ${mensagensLlm.length} mensagens`
            );

            // Chamar LLM
            const resposta = await this.chamarLlm(mensagensLlm, tools);

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

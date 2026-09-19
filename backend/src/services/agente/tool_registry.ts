/**
 * Tool Registry (Command + Registry) — fonte única das tools do agente.
 *
 * Cada tool é um objeto autodescritivo (`AgentTool`): schema OpenAI + executor +
 * flag de dependência de plano. O loop de conversa monta a lista de schemas e
 * despacha a execução pelo registry, em vez de um switch/array inline. Assim os
 * dois chats (Planejamento e Assistente) compartilham exatamente as mesmas tools.
 */

import { createControllerLogger } from "../../utils/controller_logger";
import { hasPlanoContext, type AgenteContexto } from "./context";
import type { PlanoFormaturav2 } from "../../types/planejamento";

const logger = createControllerLogger("AgenteToolRegistry", "execute");

export interface ToolResult {
    resultado: string;
    planoAtualizado?: PlanoFormaturav2;
}

/** Schema de função no formato OpenAI (compatível com a Maritaca). */
export interface ToolSchema {
    type: "function";
    function: {
        name: string;
        description: string;
        parameters: Record<string, unknown>;
    };
}

export interface AgentTool {
    name: string;
    schema: ToolSchema;
    /** true = precisa de um plano de formatura carregado (aluno logado + currículo). */
    requiresPlano: boolean;
    execute(args: Record<string, unknown>, ctx: AgenteContexto): Promise<ToolResult>;
}

export class ToolRegistry {
    private tools = new Map<string, AgentTool>();

    register(tool: AgentTool): this {
        this.tools.set(tool.name, tool);
        return this;
    }

    get(name: string): AgentTool | undefined {
        return this.tools.get(name);
    }

    /** Tools disponíveis para este contexto: esconde as `requiresPlano` sem plano. */
    toolsFor(ctx: AgenteContexto): AgentTool[] {
        const temPlano = hasPlanoContext(ctx);
        return [...this.tools.values()].filter((t) => temPlano || !t.requiresPlano);
    }

    /** Array de schemas para enviar ao LLM (`tools` da API). */
    schemasFor(ctx: AgenteContexto): ToolSchema[] {
        return this.toolsFor(ctx).map((t) => t.schema);
    }

    async execute(
        nome: string,
        args: Record<string, unknown>,
        ctx: AgenteContexto
    ): Promise<ToolResult> {
        const tool = this.tools.get(nome);
        if (!tool) {
            return { resultado: JSON.stringify({ erro: `Tool desconhecida: ${nome}` }) };
        }
        // Guard: tool de plano chamada sem contexto de plano (LLM alucinou a tool).
        if (tool.requiresPlano && !hasPlanoContext(ctx)) {
            return {
                resultado: JSON.stringify({
                    erro: `A tool ${nome} precisa de um plano de formatura carregado. Faça login e gere seu plano para usá-la.`,
                }),
            };
        }
        try {
            return await tool.execute(args, ctx);
        } catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            logger.error(`[AgenteToolRegistry] Erro na tool ${nome}: ${msg}`);
            return {
                resultado: JSON.stringify({ erro: `Falha interna na tool ${nome}: ${msg}` }),
            };
        }
    }
}

/**
 * darcyAgent — Fase 1 do orquestrador de chat (docs/chatbot-orquestrador.md).
 *
 * Agente único, sem tools (a Fase 2 introduz o orquestrador + atuadores especializados
 * via agent.asTool()). O único objetivo desta fase é provar que o histórico persistido
 * (SupabaseSession) chega inteiro pro modelo — por isso as instruções pedem
 * explicitamente pra usar o que já foi dito na conversa em vez de pedir repetição.
 */

import { Agent } from "@openai/agents";
import { createMaritacaModel } from "./model_provider";

const INSTRUCOES = `Você é o Darcy, assistente de planejamento acadêmico do No Fluxo (UnB).

1. Sempre responda em português brasileiro, de forma direta e concisa.
2. Use o histórico da conversa: se o aluno já informou algo (créditos, matérias, plano) em
   uma mensagem anterior, responda com base nisso — NUNCA peça pra ele reenviar
   informação que já está no histórico da conversa.
3. Esta fase ainda não tem acesso a ferramentas de consulta ao banco de dados do aluno —
   se a pergunta exigir dados que não estão na conversa e que você não pode saber, diga
   isso claramente em vez de inventar números.`;

export function createDarcyAgent(): Agent {
    return new Agent({
        name: "Darcy",
        instructions: INSTRUCOES,
        model: createMaritacaModel(),
    });
}

/**
 * Orquestrador — Fase 2 do orquestrador de chat (docs/chatbot-orquestrador.md).
 *
 * Substitui o darcyAgent monolítico da Fase 1 (mantido em darcy_agent.ts pra
 * referência/rollback) como entrada de produção do /chat/send. Classifica a
 * intenção da mensagem e delega para o atuador certo via agent.asTool() — o
 * orquestrador continua sempre no controle da resposta final ao usuário
 * (padrão "agents-as-tools", não handoffs).
 */

import { z } from "zod";
import { Agent, tool } from "@openai/agents";
import { createMaritacaModel } from "./model_provider";
import { createIntegralizacaoAgent, runIntegralizacaoComRevisao } from "./actuators/integralizacao_actuator";
import { createOptativasAgent } from "./actuators/optativas_actuator";

const INSTRUCOES = `Você é o Darcy, orquestrador de planejamento acadêmico do No Fluxo (UnB).

Você NÃO responde diretamente perguntas que dependem de dados do aluno ou de busca de
disciplinas — você DELEGA para o atuador certo:
- Perguntas sobre créditos, integralização, progresso, carga horária, obrigatórias
  pendentes: delegue para a tool "consultar_integralizacao".
- Perguntas pedindo pra buscar/sugerir disciplinas optativas por tema ou assunto:
  delegue para a tool "buscar_optativas".

Para qualquer outra pergunta (saudações, dúvidas gerais sobre o curso, navegação),
responda diretamente, em português brasileiro, de forma direta e concisa.

Use sempre o histórico da conversa: se o aluno já informou algo antes, nunca peça pra
ele reenviar informação que já está na conversa.`;

export function createOrquestradorAgent(email: string, apenasComOferta: boolean = false): Agent {
    const integralizacao = createIntegralizacaoAgent(email);
    const optativas = createOptativasAgent(apenasComOferta);

    // Fase 3: não usa agent.asTool() puro pro atuador de integralização — precisa do
    // wrapper runIntegralizacaoComRevisao pra reexecutar com o motivo da reprovação
    // quando o revisor numérico (outputGuardrail) disparar (docs/chatbot-orquestrador.md).
    const consultarIntegralizacaoTool = tool({
        name: "consultar_integralizacao",
        description: "Delega para o atuador de integralização: créditos, carga horária e progresso do aluno.",
        parameters: z.object({ input: z.string() }),
        execute: async ({ input }) => runIntegralizacaoComRevisao(integralizacao, input),
    });

    return new Agent({
        name: "DarcyOrquestrador",
        instructions: INSTRUCOES,
        model: createMaritacaModel(),
        tools: [
            consultarIntegralizacaoTool,
            optativas.asTool({
                toolName: "buscar_optativas",
                toolDescription: "Delega para o atuador de busca de disciplinas optativas por tema.",
            }),
        ],
    });
}

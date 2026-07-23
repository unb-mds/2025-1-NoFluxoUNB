/**
 * ChatController — Fase 1+2 do orquestrador de chat (docs/chatbot-orquestrador.md).
 *
 * POST /chat/send — roda o orquestrador (SDK @openai/agents, Fase 2) com sessão
 * persistida no Supabase (SupabaseSession, Fase 1). O cliente manda só a mensagem
 * nova; o histórico completo é reconstruído a partir da sessão antes de chamar o
 * modelo.
 *
 * session_id = uuid do usuário autenticado (auth.users.id), extraído do token, não do
 * corpo da requisição — evita que um cliente forje o histórico de outro usuário. O
 * e-mail (também do token) alimenta os atuadores que precisam resolver o id_user
 * legado (bigint) do aluno.
 *
 * Isolado do Darcy legado (PlanejadorAgenteService / /assistente/chat /
 * /planejamento/chat) — esta rota não toca nesses arquivos.
 */

import { EndpointController, RequestType } from "../interfaces";
import { Pair } from "../utils";
import { Request, Response } from "express";
import { run } from "@openai/agents";
import { createControllerLogger } from "../utils/controller_logger";
import { SupabaseWrapper } from "../supabase_wrapper";
import { SupabaseSession } from "../services/chat/supabase_session";
import { createOrquestradorAgent } from "../services/chat/orquestrador_agent";
import { isMaritacaConfigured } from "../services/chat/model_provider";

export const ChatController: EndpointController = {
    name: "chat",
    routes: {
        send: new Pair(RequestType.POST, async (req: Request, res: Response) => {
            const logger = createControllerLogger("ChatController", "send");

            const authorization = req.headers["authorization"];
            if (!authorization || typeof authorization !== "string") {
                return res.status(401).json({ error: "Header 'Authorization' é obrigatório." });
            }
            const token = authorization.startsWith("Bearer ") ? authorization.slice(7) : authorization;

            const { message } = req.body ?? {};
            if (!message || typeof message !== "string" || !message.trim()) {
                return res.status(400).json({ error: "O campo 'message' é obrigatório." });
            }

            if (!isMaritacaConfigured()) {
                logger.error("Maritaca não configurada");
                return res.status(503).json({ error: "Serviço de chat indisponível." });
            }

            try {
                const { data: authData, error: erroAuth } = await SupabaseWrapper.get().auth.getUser(token);
                if (erroAuth || !authData?.user?.id) {
                    logger.error(`Token inválido: ${erroAuth?.message}`);
                    return res.status(401).json({ error: "Token inválido." });
                }

                const session = new SupabaseSession(authData.user.id);
                const orquestrador = createOrquestradorAgent(
                    authData.user.email ?? "",
                    req.body?.contexto === "montador"
                );
                const resultado = await run(orquestrador, message, { session });

                return res.status(200).json({ reply: resultado.finalOutput });
            } catch (error) {
                const msg = error instanceof Error ? error.message : String(error);
                logger.error(`Erro no chat: ${msg}`);
                return res.status(500).json({ error: `Erro interno no servidor: ${msg}` });
            }
        }),
    },
};

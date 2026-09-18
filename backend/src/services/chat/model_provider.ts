/**
 * Model provider — Fase 1 do orquestrador de chat (docs/chatbot-orquestrador.md).
 *
 * A API da Maritaca fala o protocolo de Chat Completions da OpenAI nativamente, então
 * basta um client `openai` apontado pro base_url da Maritaca + `OpenAIChatCompletionsModel`
 * do @openai/agents — sem LiteLLM nem adapter próprio.
 */

import OpenAI from "openai";
import { OpenAIChatCompletionsModel } from "@openai/agents";
import { MARITACA_MODELS } from "../../config/maritaca";

const MARITACA_BASE_URL = "https://chat.maritaca.ai/api";

export function isMaritacaConfigured(): boolean {
    return !!process.env.MARITACA_API_KEY;
}

export function createMaritacaModel(): OpenAIChatCompletionsModel {
    const apiKey = process.env.MARITACA_API_KEY;
    if (!apiKey) {
        throw new Error("MARITACA_API_KEY não configurada");
    }

    const client = new OpenAI({ apiKey, baseURL: MARITACA_BASE_URL });
    return new OpenAIChatCompletionsModel(client, MARITACA_MODELS.AGENTE);
}

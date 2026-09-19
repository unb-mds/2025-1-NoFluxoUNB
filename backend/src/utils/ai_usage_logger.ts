/**
 * Logger compartilhado de uso de IA — grava em `ai_usage_log` (custo no
 * dashboard admin, `get_ai_cost_metrics` faz JOIN com `ai_pricing` por `model`).
 *
 * Extraído de assistente_controller.ts pra ser reusado por qualquer endpoint
 * que chame um LLM (Sabiá, PlanejadorAgenteService, orquestrador via
 * @openai/agents) — antes só o endpoint de recomendação Sabiá logava, e nem
 * esse é o caminho que o chat de verdade usa hoje.
 */

import { SupabaseWrapper } from '../supabase_wrapper';

export interface LlmUsage {
    model: string;
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
}

/**
 * Registra uso de IA em ai_usage_log. Fire-and-forget: nunca lança nem
 * bloqueia a resposta ao usuário.
 */
export function logAiUsage(params: {
    endpoint: string;
    durationMs: number;
    success: boolean;
    requestExcerpt: string;
    usage?: LlmUsage[];
}): void {
    void (async () => {
        try {
            const calls = params.usage && params.usage.length > 0
                ? params.usage
                : [{ model: 'desconhecido', prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 }];
            const rows = calls.map((u) => ({
                endpoint: params.endpoint,
                model: u.model,
                prompt_tokens: u.prompt_tokens ?? 0,
                completion_tokens: u.completion_tokens ?? 0,
                total_tokens: u.total_tokens ?? 0,
                duration_ms: params.durationMs,
                success: params.success,
                request_excerpt: params.requestExcerpt.slice(0, 120)
            }));
            const { error } = await SupabaseWrapper.get().from('ai_usage_log').insert(rows);
            if (error) console.error('[logAiUsage] insert falhou:', error.message);
        } catch (e) {
            console.error('[logAiUsage] erro inesperado:', e);
        }
    })();
}

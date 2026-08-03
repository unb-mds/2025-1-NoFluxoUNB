/**
 * SupabaseSession — Fase 1 do orquestrador de chat (docs/chatbot-orquestrador.md).
 *
 * Implementa a interface `Session` do @openai/agents sobre duas tabelas do Supabase:
 *   - chat_sessions: uma linha por sessão (session_id = uuid do usuário, uma sessão
 *     contínua por aluno — ver docs/chatbot-orquestrador.md)
 *   - chat_items: log append-only dos AgentInputItem da sessão, em ordem de created_at
 *
 * Sem estado em memória entre instâncias — uma instância nova com o mesmo session_id
 * sempre reconstrói o histórico a partir do banco (é isso que faz a sessão sobreviver
 * a reinício do processo).
 */

import type { AgentInputItem } from "@openai/agents";
import type { Session } from "@openai/agents";
import { SupabaseWrapper } from "../../supabase_wrapper";

export class SupabaseSession implements Session {
    constructor(private readonly sessionId: string) {}

    async getSessionId(): Promise<string> {
        const { data: existente, error: erroBusca } = await SupabaseWrapper.get()
            .from("chat_sessions")
            .select("session_id")
            .eq("session_id", this.sessionId)
            .maybeSingle();

        if (erroBusca) {
            throw new Error(`Falha ao buscar sessão ${this.sessionId}: ${erroBusca.message}`);
        }
        if (existente?.session_id) {
            return existente.session_id as string;
        }

        const { error: erroCriacao } = await SupabaseWrapper.get()
            .from("chat_sessions")
            .insert({ session_id: this.sessionId, user_id: this.sessionId });

        if (erroCriacao) {
            throw new Error(`Falha ao criar sessão ${this.sessionId}: ${erroCriacao.message}`);
        }
        return this.sessionId;
    }

    async getItems(limit?: number): Promise<AgentInputItem[]> {
        await this.getSessionId();

        let query = SupabaseWrapper.get()
            .from("chat_items")
            .select("item, created_at")
            .eq("session_id", this.sessionId)
            .order("created_at", { ascending: !limit });

        if (limit) {
            query = query.limit(limit);
        }

        const { data, error } = await query;
        if (error) {
            throw new Error(`Falha ao carregar histórico da sessão ${this.sessionId}: ${error.message}`);
        }

        const linhas = (data ?? []) as Array<{ item: AgentInputItem }>;
        const itens = linhas.map((linha) => linha.item);
        // Quando limitado, a ordenação acima é decrescente (pega os N mais recentes) —
        // a interface exige devolver em ordem cronológica, então reverte de volta.
        return limit ? itens.reverse() : itens;
    }

    async addItems(items: AgentInputItem[]): Promise<void> {
        if (items.length === 0) return;

        await this.getSessionId();

        const linhas = items.map((item) => ({ session_id: this.sessionId, item }));
        const { error: erroInsercao } = await SupabaseWrapper.get().from("chat_items").insert(linhas);
        if (erroInsercao) {
            throw new Error(`Falha ao salvar mensagens da sessão ${this.sessionId}: ${erroInsercao.message}`);
        }

        await SupabaseWrapper.get()
            .from("chat_sessions")
            .update({ updated_at: new Date().toISOString() })
            .eq("session_id", this.sessionId);
    }

    async popItem(): Promise<AgentInputItem | undefined> {
        const { data, error } = await SupabaseWrapper.get()
            .from("chat_items")
            .select("id, item")
            .eq("session_id", this.sessionId)
            .order("created_at", { ascending: false })
            .limit(1);

        if (error) {
            throw new Error(`Falha ao ler último item da sessão ${this.sessionId}: ${error.message}`);
        }
        const linhas = (data ?? []) as Array<{ id: number; item: AgentInputItem }>;
        if (linhas.length === 0) return undefined;

        const [ultimo] = linhas;
        await SupabaseWrapper.get().from("chat_items").delete().eq("id", ultimo.id);
        return ultimo.item;
    }

    async clearSession(): Promise<void> {
        await SupabaseWrapper.get().from("chat_items").delete().eq("session_id", this.sessionId);
    }
}

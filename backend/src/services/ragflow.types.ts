/**
 * Type definitions for the RAGFlow API integration.
 */

export interface RagflowCompletionPayload {
    materia?: string;
    question?: string;
    session_id?: string;
    stream: boolean;
}

export interface RagflowResponse {
    code: number;
    data: {
        answer: string;
        session_id: string;
        id?: string;
        param?: Array<{
            key: string;
            name: string;
            optional: boolean;
            type: string;
            value: string;
        }>;
        reference?: Record<string, unknown>;
        [key: string]: unknown;
    };
    message?: string;
}

export interface RankingItem {
    disciplina: string;
    codigo: string;
    unidade: string;
    pontuacao: string;
    justificativa: string;
    ementa: string;
}

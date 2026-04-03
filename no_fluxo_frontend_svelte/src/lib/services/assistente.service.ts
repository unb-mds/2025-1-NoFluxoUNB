/**
 * AI Assistant Service
 * Proxies messages to the AI agent backend
 * Supports both RAGFlow and Sabiá AI agents
 */

import { config } from '$lib/config';

interface AssistenteRequest {
    materia: string;
    matriz_curricular?: string; // 1. ADICIONADO: Nova propriedade para enviar ao backend
}

interface AssistenteResponse {
    resultado?: string;
    erro?: string;
    agente?: 'ragflow' | 'sabia';
    disciplinas?: Array<{
        codigo: string;
        nome: string;
        nota: number;
        justificativa: string;
    }>;
}

export type AgentType = 'ragflow' | 'sabia';

export interface StreamEvent {
    stage: 'thinking' | 'searching' | 'generating' | 'disciplina' | 'done' | 'error';
    message?: string;
    data?: {
        codigo: string;
        nome: string;
        nota: number;
        justificativa: string;
    };
    resultado?: string;
}

export class AssistenteService {
    private readonly ragflowEndpoint = '/assistente/analyze';
    private readonly sabiaEndpoint = '/assistente/analyze-sabia';
    private readonly sabiaStreamEndpoint = '/assistente/analyze-sabia-stream';

    /**
     * Send a message to the AI assistant using the specified agent
     * @param message The user's message
     * @param agent Which AI agent to use ('ragflow' or 'sabia')
     * @returns The AI response text
     */
    async sendMessage(message: string, agent: AgentType = 'sabia'): Promise<string> {
        const endpoint = agent === 'sabia' ? this.sabiaEndpoint : this.ragflowEndpoint;
        const url = `${config.apiUrl}${endpoint}`;

        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ materia: message } satisfies AssistenteRequest)
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data: AssistenteResponse = await response.json();

            if (data.erro) {
                throw new Error(data.erro);
            }

            return data.resultado || 'Sem resposta da IA.';
        } catch (error) {
            if (error instanceof Error) {
                throw new Error(`Erro ao se comunicar com a IA: ${error.message}`);
            }
            throw new Error('Erro ao se comunicar com a IA.');
        }
    }

    /**
     * Send a message specifically to the Sabiá AI agent
     * @param message The user's message
     * @returns The AI response with structured data
     */
    async sendMessageToSabia(message: string): Promise<AssistenteResponse> {
        const url = `${config.apiUrl}${this.sabiaEndpoint}`;

        try {
            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ materia: message } satisfies AssistenteRequest)
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data: AssistenteResponse = await response.json();

            if (data.erro) {
                throw new Error(data.erro);
            }

            return data;
        } catch (error) {
            if (error instanceof Error) {
                throw new Error(`Erro ao se comunicar com o Sabiá: ${error.message}`);
            }
            throw new Error('Erro ao se comunicar com o Sabiá.');
        }
    }

    /**
     * Stream a message to the Sabiá AI agent via SSE
     * @param message The user's message
     * @param matrizCurricular A matriz curricular extraída do frontend (NOVO PARÂMETRO)
     * @param onEvent Callback for each streamed event
     */
    async streamMessageFromSabia(
        message: string,
        matrizCurricularOrOnEvent: string | ((event: StreamEvent) => void),
        onEventMaybe?: (event: StreamEvent) => void
    ): Promise<void> {
        const url = `${config.apiUrl}${this.sabiaStreamEndpoint}`;

        // Backward-compatible signatures:
        // - streamMessageFromSabia(message, onEvent)
        // - streamMessageFromSabia(message, matrizCurricular, onEvent)
        const hasMatriz = typeof matrizCurricularOrOnEvent === 'string';
        const matrizCurricular = hasMatriz ? matrizCurricularOrOnEvent : undefined;
        const onEvent = hasMatriz ? onEventMaybe : matrizCurricularOrOnEvent;

        if (typeof onEvent !== 'function') {
            throw new Error('Callback de stream inválido.');
        }

        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            // 3. ADICIONADO: Injetando a matriz_curricular no payload
            body: JSON.stringify({ 
                materia: message,
                matriz_curricular: matrizCurricular 
            } satisfies AssistenteRequest)
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        if (!response.body) {
            throw new Error('No response body');
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';

        while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            buffer += decoder.decode(value, { stream: true });

            // Parse SSE events from the buffer
            const lines = buffer.split('\n');
            buffer = lines.pop() || ''; // Keep incomplete line in buffer

            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    try {
                        const event: StreamEvent = JSON.parse(line.slice(6));
                        onEvent(event);
                    } catch {
                        // Skip malformed events
                    }
                }
            }
        }

        // Process any remaining buffer
        if (buffer.startsWith('data: ')) {
            try {
                const event: StreamEvent = JSON.parse(buffer.slice(6));
                onEvent(event);
            } catch {
                // Skip malformed events
            }
        }
    }
}

// Singleton
export const assistenteService = new AssistenteService();
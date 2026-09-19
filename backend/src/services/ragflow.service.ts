/**
 * RAGFlow API client service.
 * Replaces the Python ai_agent — calls RAGFlow directly from TypeScript.
 */

import axios, { AxiosError } from 'axios';
import logger from '../logger';
import { RagflowResponse } from './ragflow.types';

export class RagflowService {
    private readonly agentId: string;
    private readonly baseUrl: string;
    private readonly apiKey: string;
    private readonly url: string;
    private readonly available: boolean;

    constructor() {
        this.apiKey = process.env.RAGFLOW_API_KEY || '';
        this.baseUrl = process.env.RAGFLOW_BASE_URL || '';
        this.agentId = process.env.RAGFLOW_AGENT_ID || '';
        this.url = `${this.baseUrl}/api/v1/agents/${this.agentId}/completions`;

        this.available = !!(this.apiKey && this.baseUrl && this.agentId);

        if (!this.available) {
            logger.warn('[RagflowService] RAGFlow configuration incomplete — AI assistant will be unavailable');
            logger.warn('[RagflowService] Required env vars: RAGFLOW_API_KEY, RAGFLOW_BASE_URL, RAGFLOW_AGENT_ID');
        } else {
            logger.info(`[RagflowService] Initialized — endpoint: ${this.url}`);
        }
    }

    /** Whether the RAGFlow service is properly configured */
    isAvailable(): boolean {
        return this.available;
    }

    /**
     * Start a new session with the RAGFlow agent.
     * Returns the session_id to be used in subsequent analysis calls.
     */
    async startSession(materia: string): Promise<string> {
        if (!this.available) {
            throw new Error('RAGFlow service is not configured');
        }

        logger.info(`[RagflowService] Starting session for materia: "${materia}"`);

        const payload = { materia, stream: false };

        try {
            const response = await axios.post<RagflowResponse>(this.url, payload, {
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json',
                },
                timeout: 30_000,
            });

            const data = response.data;
            const sessionId = data?.data?.session_id;

            if (!sessionId) {
                logger.error(`[RagflowService] No session_id in response: ${JSON.stringify(data)}`);
                throw new Error('session_id not found in RAGFlow API response');
            }

            logger.info(`[RagflowService] Session started: ${sessionId}`);
            return sessionId;
        } catch (error) {
            this.logAxiosError('startSession', error);
            throw error;
        }
    }

    /**
     * Analyze a materia using an existing session.
     * Returns the full RAGFlow response with the ranking data.
     */
    async analyzeMateria(materia: string, sessionId: string): Promise<RagflowResponse> {
        if (!this.available) {
            throw new Error('RAGFlow service is not configured');
        }

        logger.info(`[RagflowService] Analyzing materia: "${materia}" (session: ${sessionId})`);

        const payload = {
            question: materia,
            session_id: sessionId,
            stream: false,
        };

        try {
            const response = await axios.post<RagflowResponse>(this.url, payload, {
                headers: {
                    'Authorization': `Bearer ${this.apiKey}`,
                    'Content-Type': 'application/json',
                },
                timeout: 60_000,
            });

            const data = response.data;
            logger.info(`[RagflowService] Analysis complete — code: ${data.code}`);
            return data;
        } catch (error) {
            this.logAxiosError('analyzeMateria', error);
            throw error;
        }
    }

    private logAxiosError(operation: string, error: unknown): void {
        if (error instanceof AxiosError) {
            logger.error(`[RagflowService] ${operation} failed — ${error.message}`);
            if (error.response) {
                logger.error(`[RagflowService] Status: ${error.response.status}, Body: ${JSON.stringify(error.response.data)}`);
            }
        } else if (error instanceof Error) {
            logger.error(`[RagflowService] ${operation} failed — ${error.message}`);
        }
    }
}

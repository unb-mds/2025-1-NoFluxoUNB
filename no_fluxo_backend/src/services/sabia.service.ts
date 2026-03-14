/**
 * Sabiá AI Agent Service
 * Integrates with the FastAPI-based Sabiá agent (api_producao.py).
 * Makes HTTP requests to the Python FastAPI server for AI recommendations.
 */

import logger from '../logger';

export interface SabiaDisciplina {
    codigo: string;
    nome: string;
    nota: number;
    justificativa: string;
}

export interface SabiaResponse {
    success: boolean;
    disciplinas?: SabiaDisciplina[];
    resposta_completa?: string;
    error?: string;
}

export class SabiaService {
    private readonly apiUrl: string;
    private readonly available: boolean;

    constructor() {
        this.apiUrl = process.env.SABIA_API_URL ?? 'http://localhost:8000';

        // Check if required env vars are set
        logger.info('[SabiaService] Checking environment variables...');
        logger.info(`[SabiaService] SABIA_API_URL: ${this.apiUrl}`);
        logger.info(`[SabiaService] MARITACA_API_KEY: ${process.env.MARITACA_API_KEY ? process.env.MARITACA_API_KEY.substring(0, 20) + '...' : 'MISSING'}`);
        logger.info(`[SabiaService] GOOGLE_API_KEY: ${process.env.GOOGLE_API_KEY ? process.env.GOOGLE_API_KEY.substring(0, 20) + '...' : 'MISSING'}`);
        logger.info(`[SabiaService] SUPABASE_URL: ${process.env.SUPABASE_URL ? process.env.SUPABASE_URL.substring(0, 30) + '...' : 'MISSING'}`);
        
        const hasMaritaca = !!process.env.MARITACA_API_KEY;
        const hasGoogle = !!process.env.GOOGLE_API_KEY;
        const hasSupabase = !!(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY);
        
        this.available = hasMaritaca && hasGoogle && hasSupabase;

        if (!this.available) {
            logger.warn('[SabiaService] Sabiá AI agent unavailable — missing configuration');
            if (!hasMaritaca) logger.warn('[SabiaService] Missing: MARITACA_API_KEY');
            if (!hasGoogle) logger.warn('[SabiaService] Missing: GOOGLE_API_KEY (for Gemini embeddings)');
            if (!hasSupabase) logger.warn('[SabiaService] Missing: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
        } else {
            logger.info('[SabiaService] ✅ Sabiá AI agent initialized and ready');
            logger.info(`[SabiaService] API URL: ${this.apiUrl}`);
        }
    }

    /** Whether the Sabiá service is properly configured */
    isAvailable(): boolean {
        return this.available;
    }

    /**
     * Analyze a subject interest and return recommended disciplines using Sabiá AI.
     * Makes an HTTP POST request to the FastAPI server (api_producao.py).
     * 
     * @param interesse - The subject/interest to analyze (e.g., "inteligência artificial")
     * @returns Promise with the Sabiá response containing disciplinas and justifications
     */
    async analyzarInteresse(interesse: string): Promise<SabiaResponse> {
        if (!this.available) {
            throw new Error('Sabiá service is not configured');
        }

        logger.info(`[SabiaService] Analyzing interesse: "${interesse}"`);
        const startTime = Date.now();

        try {
            // Make HTTP POST request to FastAPI server
            const response = await fetch(`${this.apiUrl}/recomendar`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ interesse }),
            });

            if (!response.ok) {
                const errorText = await response.text();
                throw new Error(`FastAPI returned ${response.status}: ${errorText}`);
            }

            const result = await response.json() as SabiaResponse;
            const duration = Date.now() - startTime;

            if (result.success) {
                logger.info(`[SabiaService] ✅ Analysis completed in ${duration}ms — ${result.disciplinas?.length || 0} disciplinas found`);
            } else {
                logger.error(`[SabiaService] ❌ Analysis failed: ${result.error || 'Unknown error'}`);
            }

            return result;
        } catch (error) {
            const duration = Date.now() - startTime;
            const msg = error instanceof Error ? error.message : String(error);
            logger.error(`[SabiaService] Error after ${duration}ms: ${msg}`);
            
            // Check if it's a connection error
            if (msg.includes('ECONNREFUSED') || msg.includes('fetch failed')) {
                throw new Error('Cannot connect to Sabiá API. Make sure api_producao.py is running on ' + this.apiUrl);
            }
            
            throw error;
        }
    }

    /**
     * Format the Sabiá response as Markdown ranking (compatible with frontend expectations).
     * Similar format to RAGFlow output.
     */
    formatAsMarkdown(response: SabiaResponse): string {
        if (!response.success || !response.disciplinas || response.disciplinas.length === 0) {
            return 'Esta plataforma destina-se exclusivamente à recomendação de disciplinas acadêmicas. Por gentileza, lembre-se de que a consulta é apenas sobre disciplinas acadêmicas. Reoriente sua pergunta para temas relacionados a áreas de estudo. Exemplo: "Quero aprender sobre inteligência artificial e suas aplicações".';
        }

        let markdown = `### 🎓 Disciplinas Recomendadas pelo Sabiá\n\n`;
        markdown += `Encontramos **${response.disciplinas.length} disciplinas** relacionadas ao seu interesse:\n\n`;

        response.disciplinas.forEach((disc, index) => {
            const emoji = disc.nota >= 9 ? '🌟' : disc.nota >= 7 ? '✨' : '📚';
            markdown += `${index + 1}. ${emoji} **${disc.codigo} - ${disc.nome}**\n`;
            markdown += `   - **Relevância:** ${disc.nota}/10\n`;
            markdown += `   - **Justificativa:** ${disc.justificativa}\n\n`;
        });

        if (response.resposta_completa) {
            markdown += `\n---\n\n**Análise Completa:**\n${response.resposta_completa}`;
        }

        return markdown;
    }
}

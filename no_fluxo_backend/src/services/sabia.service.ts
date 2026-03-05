/**
 * Sabiá AI Agent Service
 * Integrates the Python-based Sabiá agent with the TypeScript backend.
 * Calls the Python script via child_process and returns structured results.
 */

import { spawn } from 'child_process';
import path from 'path';
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
    private readonly pythonScriptPath: string;
    private readonly pythonExePath: string;
    private readonly available: boolean;

    constructor() {
        // Path to the unified Python script (works in both interactive and API mode)
        this.pythonScriptPath = path.join(__dirname, '../../..', 'mcp_agent', 'agente_sabia.py');
        
        // Path to Python executable in venv
        this.pythonExePath = path.join(__dirname, '../../..', 'venv', 'Scripts', 'python.exe');
        
        // Check if required env vars are set
        logger.info('[SabiaService] Checking environment variables...');
        logger.info(`[SabiaService] MARITACA_API_KEY: ${process.env.MARITACA_API_KEY ? process.env.MARITACA_API_KEY.substring(0, 20) + '...' : 'MISSING'}`);
        logger.info(`[SabiaService] SUPABASE_URL: ${process.env.SUPABASE_URL ? process.env.SUPABASE_URL.substring(0, 30) + '...' : 'MISSING'}`);
        logger.info(`[SabiaService] SUPABASE_KEY: ${process.env.SUPABASE_KEY ? process.env.SUPABASE_KEY.substring(0, 20) + '...' : 'MISSING'}`);
        
        const hasMaritaca = !!process.env.MARITACA_API_KEY;
        const hasSupabase = !!(process.env.SUPABASE_URL && process.env.SUPABASE_KEY);
        
        this.available = hasMaritaca && hasSupabase;

        if (!this.available) {
            logger.warn('[SabiaService] Sabiá AI agent unavailable — missing configuration');
            if (!hasMaritaca) logger.warn('[SabiaService] Missing: MARITACA_API_KEY');
            if (!hasSupabase) logger.warn('[SabiaService] Missing: SUPABASE_URL or SUPABASE_KEY');
        } else {
            logger.info('[SabiaService] ✅ Sabiá AI agent initialized and ready');
            logger.info(`[SabiaService] Python exe: ${this.pythonExePath}`);
            logger.info(`[SabiaService] Python script: ${this.pythonScriptPath}`);
        }
    }

    /** Whether the Sabiá service is properly configured */
    isAvailable(): boolean {
        return this.available;
    }

    /**
     * Analyze a subject interest and return recommended disciplines using Sabiá AI.
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

        return new Promise((resolve, reject) => {
            // Spawn Python process with absolute path
            logger.info(`[SabiaService] Spawning: ${this.pythonExePath} ${this.pythonScriptPath}`);
            
            const python = spawn(this.pythonExePath, [this.pythonScriptPath], {
                env: {
                    ...process.env,
                    MARITACA_API_KEY: process.env.MARITACA_API_KEY,
                    SUPABASE_URL: process.env.SUPABASE_URL,
                    SUPABASE_KEY: process.env.SUPABASE_KEY,
                },
            });

            let stdoutData = '';
            let stderrData = '';

            // Collect stdout
            python.stdout.on('data', (data) => {
                const chunk = data.toString();
                stdoutData += chunk;
                logger.debug(`[SabiaService] stdout chunk: ${chunk.substring(0, 100)}...`);
            });

            // Collect stderr (for debugging)
            python.stderr.on('data', (data) => {
                const chunk = data.toString();
                stderrData += chunk;
                logger.debug(`[SabiaService] stderr: ${chunk}`);
            });

            // Handle process completion
            python.on('close', (code) => {
                const duration = Date.now() - startTime;

                logger.info(`[SabiaService] Process closed with code ${code} after ${duration}ms`);
                
                if (stderrData) {
                    logger.info(`[SabiaService] stderr output:\n${stderrData}`);
                }

                if (code !== 0) {
                    logger.error(`[SabiaService] Python process exited with code ${code}`);
                    
                    return reject(new Error(`Python script failed with code ${code}: ${stderrData || 'Unknown error'}`));
                }

                try {
                    const result: SabiaResponse = JSON.parse(stdoutData);
                    
                    if (result.success) {
                        logger.info(`[SabiaService] ✅ Analysis completed — ${result.disciplinas?.length || 0} disciplinas found`);
                    } else {
                        logger.error(`[SabiaService] ❌ Analysis failed: ${result.error}`);
                    }

                    resolve(result);
                } catch (parseError) {
                    logger.error(`[SabiaService] Failed to parse Python output: ${parseError}`);
                    logger.error(`[SabiaService] Raw output: ${stdoutData}`);
                    reject(new Error(`Failed to parse Sabiá response: ${parseError}`));
                }
            });

            // Handle process errors
            python.on('error', (error) => {
                logger.error(`[SabiaService] Failed to start Python process: ${error.message}`);
                logger.error(`[SabiaService] Stack: ${error.stack}`);
                reject(new Error(`Failed to execute Sabiá agent: ${error.message}`));
            });

            // Send input JSON to Python via stdin with explicit UTF-8 encoding
            const input = JSON.stringify({ interesse });
            python.stdin.write(input, 'utf8');
            python.stdin.end();
        });
    }

    /**
     * Format the Sabiá response as Markdown ranking (compatible with frontend expectations).
     * Similar format to RAGFlow output.
     */
    formatAsMarkdown(response: SabiaResponse): string {
        if (!response.success || !response.disciplinas || response.disciplinas.length === 0) {
            return 'Nenhuma disciplina encontrada para o tema especificado. Tente reformular sua consulta.';
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

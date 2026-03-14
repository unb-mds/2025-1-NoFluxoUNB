/**
 * Assistente Controller — AI assistant endpoint.
 * Replaces the standalone Python/Flask AI agent server.
 *
 * POST /assistente/analyze        — Analyze a materia using RAGFlow.
 * POST /assistente/analyze-sabia  — Analyze a materia using Sabiá AI (Maritaca).
 * GET  /assistente/health         — Health check for the AI service.
 */

import { EndpointController, RequestType } from '../interfaces';
import { Pair } from '../utils';
import { Request, Response } from 'express';
import { RagflowService } from '../services/ragflow.service';
import { SabiaService } from '../services/sabia.service';
import { removeAccents } from '../utils/text.utils';
import { formatRanking } from '../utils/ranking.formatter';
import { createControllerLogger } from '../utils/controller_logger';

const ragflow = new RagflowService();
const sabia = new SabiaService();

export const AssistenteController: EndpointController = {
    name: 'assistente',
    routes: {
        analyze: new Pair(RequestType.POST, async (req: Request, res: Response) => {
            const logger = createControllerLogger('AssistenteController', 'analyze');
            const startTime = Date.now();

            // Validate input
            const { materia } = req.body;
            if (!materia || typeof materia !== 'string' || !materia.trim()) {
                logger.error('Missing or empty "materia" field');
                return res.status(400).json({ erro: "O campo 'materia' é obrigatório no corpo da requisição JSON." });
            }

            // Check if RAGFlow is configured
            if (!ragflow.isAvailable()) {
                logger.error('RAGFlow service not configured');
                return res.status(503).json({ erro: 'Serviço de IA indisponível. Configuração do RAGFlow ausente.' });
            }

            try {
                // Preprocess: remove accents and uppercase
                const processed = removeAccents(materia).toUpperCase();
                logger.info(`Processing materia: "${materia}" → "${processed}"`);

                // Call RAGFlow: create session → analyze
                const sessionId = await ragflow.startSession(processed);
                logger.info(`Session created: ${sessionId}`);

                const result = await ragflow.analyzeMateria(processed, sessionId);

                if (result.code !== 0) {
                    const errorMsg = result.message || 'Erro desconhecido na API do agente.';
                    logger.error(`RAGFlow API error: code=${result.code}, message=${errorMsg}`);
                    return res.status(500).json({ erro: `Erro na API do agente: ${errorMsg}` });
                }

                // Format response as Markdown ranking
                const formatted = formatRanking(result);
                const duration = Date.now() - startTime;
                logger.info(`Request completed in ${duration}ms`);

                return res.json({ resultado: formatted });
            } catch (error) {
                const duration = Date.now() - startTime;
                const msg = error instanceof Error ? error.message : String(error);
                logger.error(`Error after ${duration}ms: ${msg}`);
                return res.status(500).json({ erro: `Ocorreu um erro interno no servidor: ${msg}` });
            }
        }),

        health: new Pair(RequestType.GET, async (_req: Request, res: Response) => {
            return res.json({
                status: ragflow.isAvailable() || sabia.isAvailable() ? 'healthy' : 'degraded',
                service: 'AI Assistant',
                ragflowConfigured: ragflow.isAvailable(),
                sabiaConfigured: sabia.isAvailable(),
                timestamp: new Date().toISOString(),
            });
        }),

        'analyze-sabia-stream': new Pair(RequestType.POST, async (req: Request, res: Response) => {
            const logger = createControllerLogger('AssistenteController', 'analyze-sabia-stream');

            const { materia } = req.body;
            if (!materia || typeof materia !== 'string' || !materia.trim()) {
                logger.error('Missing or empty "materia" field');
                return res.status(400).json({ erro: "O campo 'materia' é obrigatório no corpo da requisição JSON." });
            }

            if (!sabia.isAvailable()) {
                logger.error('Sabiá service not configured');
                return res.status(503).json({ erro: 'Serviço Sabiá indisponível.' });
            }

            // Set SSE headers
            res.setHeader('Content-Type', 'text/event-stream');
            res.setHeader('Cache-Control', 'no-cache');
            res.setHeader('Connection', 'keep-alive');
            res.setHeader('X-Accel-Buffering', 'no');
            res.flushHeaders();

            try {
                logger.info(`Streaming with Sabiá: "${materia}"`);
                await sabia.analyzarInteresseStream(materia, res);
                return;
            } catch (error) {
                const msg = error instanceof Error ? error.message : String(error);
                logger.error(`Stream error: ${msg}`);
                const errorEvent = `data: ${JSON.stringify({ stage: 'error', message: msg })}\n\n`;
                res.write(errorEvent);
                res.end();
                return;
            }
        }),

        'analyze-sabia': new Pair(RequestType.POST, async (req: Request, res: Response) => {
            const logger = createControllerLogger('AssistenteController', 'analyze-sabia');
            const startTime = Date.now();

            // Validate input
            const { materia } = req.body;
            if (!materia || typeof materia !== 'string' || !materia.trim()) {
                logger.error('Missing or empty "materia" field');
                return res.status(400).json({ erro: "O campo 'materia' é obrigatório no corpo da requisição JSON." });
            }

            // Check if Sabiá is configured
            if (!sabia.isAvailable()) {
                logger.error('Sabiá service not configured');
                return res.status(503).json({ erro: 'Serviço Sabiá indisponível. Configure MARITACA_API_KEY, SUPABASE_URL e SUPABASE_KEY.' });
            }

            try {
                logger.info(`Processing with Sabiá: "${materia}"`);

                // Call Sabiá AI service
                const result = await sabia.analyzarInteresse(materia);

                if (!result.success) {
                    const errorMsg = result.error || 'Erro desconhecido no agente Sabiá.';
                    logger.error(`Sabiá error: ${errorMsg}`);
                    return res.status(500).json({ erro: `Erro no agente Sabiá: ${errorMsg}` });
                }

                // Format response as Markdown
                const formatted = sabia.formatAsMarkdown(result);
                const duration = Date.now() - startTime;
                logger.info(`Sabiá request completed in ${duration}ms — ${result.disciplinas?.length || 0} disciplinas`);

                return res.json({ 
                    resultado: formatted,
                    disciplinas: result.disciplinas,
                    agente: 'sabia'
                });
            } catch (error) {
                const duration = Date.now() - startTime;
                const msg = error instanceof Error ? error.message : String(error);
                logger.error(`Error after ${duration}ms: ${msg}`);
                return res.status(500).json({ erro: `Ocorreu um erro interno no servidor: ${msg}` });
            }
        }),
    },
};

/**
 * Ingestão de scores de risco de evasão, enviados em lote pelo serviço de ML
 * (nofluxo-ml).
 *
 * Endpoint: POST /internal/ml/scores
 *
 * Não é uma rota de usuário — sem JWT/User-ID. Autenticação por header
 * X-API-Key, comparado em tempo constante contra ML_PUSH_API_KEY.
 *
 * Fail-fast: sem ML_PUSH_API_KEY configurada, o módulo lança no carregamento
 * (import em index.ts acontece antes de app.listen) — o processo não sobe
 * aceitando requests sem uma checagem real por trás.
 *
 * Body: { scores: [{ id_user, risk, model_version, computed_at }, ...] }
 * (até 500 itens; cada item validado por tipo e faixa, sem coagir tipo).
 *
 * Upsert em public.ml_risco_scores (chave id_user, upsert = idempotente).
 * Tabela e migration pertencem ao repo nofluxo-ml — este backend só lê/escreve
 * nela via service role, igual ao resto do schema.
 */

import crypto from "crypto";
import { EndpointController, RequestType } from "../interfaces";
import { Pair } from "../utils";
import { Request, Response } from "express";
import { SupabaseWrapper } from "../supabase_wrapper";
import { createControllerLogger } from "../utils/controller_logger";

const MAX_SCORES_PER_REQUEST = 500;

const ML_PUSH_API_KEY = process.env.ML_PUSH_API_KEY;
if (!ML_PUSH_API_KEY) {
    throw new Error(
        "ML_PUSH_API_KEY não está definida. Configure a env var antes de subir o servidor — " +
        "POST /internal/ml/scores não pode aceitar requests sem uma checagem de autenticação real."
    );
}

/** Comparação em tempo constante — timingSafeEqual exige buffers do mesmo tamanho. */
function isValidApiKey(provided: unknown): boolean {
    if (typeof provided !== "string" || !provided) return false;
    const expected = Buffer.from(ML_PUSH_API_KEY as string, "utf8");
    const actual = Buffer.from(provided, "utf8");
    if (expected.length !== actual.length) return false;
    return crypto.timingSafeEqual(expected, actual);
}

interface ScoreInput {
    id_user: number;
    risk: number;
    model_version: string;
    computed_at: string;
    codigo_materia_critico: string | null;
}

function isPlainObject(v: unknown): v is Record<string, unknown> {
    return typeof v === "object" && v !== null && !Array.isArray(v);
}

function validateScoreItem(item: unknown, index: number): { value?: ScoreInput; error?: string } {
    if (!isPlainObject(item)) {
        return { error: `scores[${index}] deve ser um objeto` };
    }

    const { id_user, risk, model_version, computed_at } = item;

    if (typeof id_user !== "number" || !Number.isInteger(id_user) || id_user <= 0) {
        return { error: `scores[${index}].id_user deve ser um inteiro positivo` };
    }
    if (typeof risk !== "number" || !Number.isFinite(risk) || risk < 0 || risk > 1) {
        return { error: `scores[${index}].risk deve ser um número entre 0 e 1` };
    }
    if (typeof model_version !== "string" || !model_version.trim()) {
        return { error: `scores[${index}].model_version deve ser uma string não vazia` };
    }
    if (typeof computed_at !== "string" || Number.isNaN(Date.parse(computed_at))) {
        return { error: `scores[${index}].computed_at deve ser uma data ISO 8601 válida` };
    }

    let codigo_materia_critico: string | null = null;
    if ("codigo_materia_critico" in item && item.codigo_materia_critico !== null) {
        if (typeof item.codigo_materia_critico !== "string" || !item.codigo_materia_critico.trim()) {
            return { error: `scores[${index}].codigo_materia_critico deve ser uma string não vazia ou null` };
        }
        codigo_materia_critico = item.codigo_materia_critico;
    }

    return { value: { id_user, risk, model_version, computed_at, codigo_materia_critico } };
}

/**
 * Deduplica por id_user mantendo a ÚLTIMA ocorrência do lote.
 *
 * Necessário porque o upsert do PostgREST usa ON CONFLICT (id_user) DO UPDATE:
 * mandar duas linhas com o mesmo id_user na MESMA chamada de upsert faz o
 * Postgres estourar "21000: ON CONFLICT DO UPDATE command cannot affect row
 * a second time". "Último item do lote vence" replica o que aconteceria se
 * cada duplicata fosse enviada em uma chamada de upsert separada.
 */
function dedupeByIdUser(scores: ScoreInput[]): ScoreInput[] {
    const byId = new Map<number, ScoreInput>();
    for (const s of scores) byId.set(s.id_user, s);
    return [...byId.values()];
}

function validateBody(body: unknown): { scores?: ScoreInput[]; error?: string } {
    if (!isPlainObject(body)) {
        return { error: "Body inválido" };
    }

    const { scores } = body;
    if (!Array.isArray(scores) || scores.length === 0) {
        return { error: "scores deve ser um array não vazio" };
    }
    if (scores.length > MAX_SCORES_PER_REQUEST) {
        return { error: `scores excede o máximo de ${MAX_SCORES_PER_REQUEST} itens por request` };
    }

    const validated: ScoreInput[] = [];
    for (let i = 0; i < scores.length; i++) {
        const { value, error } = validateScoreItem(scores[i], i);
        if (error) return { error };
        validated.push(value as ScoreInput);
    }
    return { scores: validated };
}

export const MlIngestController: EndpointController = {
    name: "internal/ml",
    routes: {
        scores: new Pair(RequestType.POST, async (req: Request, res: Response) => {
            const logger = createControllerLogger("MlIngestController", "scores");

            if (!isValidApiKey(req.headers["x-api-key"])) {
                logger.warn("X-API-Key ausente ou inválida");
                return res.status(401).json({ error: "API key inválida ou ausente" });
            }

            const { scores, error: bodyError } = validateBody(req.body);
            if (bodyError) {
                logger.warn(`Body inválido: ${bodyError}`);
                return res.status(400).json({ error: bodyError });
            }

            const dedupedScores = dedupeByIdUser(scores as ScoreInput[]);

            const { error } = await SupabaseWrapper.get()
                .from("ml_risco_scores")
                .upsert(dedupedScores, { onConflict: "id_user" });

            if (error) {
                logger.error(`Erro ao fazer upsert de scores: ${error.message}`);
                return res.status(500).json({ error: error.message });
            }

            logger.info(`Upsert de ${dedupedScores.length} score(s) concluído`);
            return res.status(200).json({ ok: true, upserted: dedupedScores.length });
        }),
    },
};

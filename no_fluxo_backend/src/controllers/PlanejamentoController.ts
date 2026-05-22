/**
 * Controller do Motor 2 — Cadeia de formatura personalizada.
 *
 * Endpoint: POST /planejamento/gerar-plano
 *
 * Entrada (PlanoInput):
 *   {
 *     curriculoCompleto: "8117/-2 - 2018.2",
 *     completedCodes: ["MAT0026", ...],
 *     numeroPeriodo: 3,
 *     preferencias: { limiteCreditos: 24, objetivo: "equilibrado", trabalha: false },
 *     materiasFaltantes?: MateriaInput[]   // opcional — se informado, pula o DB lookup
 *   }
 *
 * Saida (PlanoFormatura):
 *   { semestresRestantes, plano: SemestrePlano[], materiasNaoAlocadas: string[] }
 *
 * Spec: docs/motor2.md
 */

import { EndpointController, RequestType } from "../interfaces";
import { Pair } from "../utils";
import { Request, Response } from "express";
import { SupabaseWrapper } from "../supabase_wrapper";
import { createControllerLogger } from "../utils/controller_logger";
import { gerarPlano } from "../services/plano_formatura.service";
import type {
    MateriaInput,
    PlanoInput,
    PreferenciasPlano,
} from "../types/planejamento";

// =============================================================
// Helpers
// =============================================================

function isObject(v: unknown): v is Record<string, unknown> {
    return typeof v === "object" && v !== null && !Array.isArray(v);
}

function validatePreferencias(raw: unknown): PreferenciasPlano | null {
    if (!isObject(raw)) return null;
    const limite = Number(raw.limiteCreditos);
    if (!Number.isFinite(limite) || limite <= 0) return null;
    const objetivo = raw.objetivo;
    if (objetivo !== "velocidade" && objetivo !== "equilibrado") return null;
    if (typeof raw.trabalha !== "boolean") return null;
    return {
        limiteCreditos: Math.floor(limite),
        objetivo,
        trabalha: raw.trabalha,
    };
}

/**
 * Valida e normaliza o body do endpoint.
 * Retorna `{ input }` ou `{ error }` (com 400-friendly message).
 */
function parseBody(body: unknown): { input?: PlanoInput; error?: string } {
    if (!isObject(body)) return { error: "Body inválido" };

    const curriculoCompleto = body.curriculoCompleto;
    if (typeof curriculoCompleto !== "string" || !curriculoCompleto.trim()) {
        return { error: "curriculoCompleto é obrigatório" };
    }

    const completedCodes = body.completedCodes;
    if (!Array.isArray(completedCodes) || !completedCodes.every((c) => typeof c === "string")) {
        return { error: "completedCodes deve ser array de strings" };
    }

    const numeroPeriodo = Number(body.numeroPeriodo);
    if (!Number.isFinite(numeroPeriodo) || numeroPeriodo < 1) {
        return { error: "numeroPeriodo deve ser inteiro >= 1" };
    }

    const preferencias = validatePreferencias(body.preferencias);
    if (!preferencias) {
        return {
            error:
                "preferencias inválidas (formato: { limiteCreditos: number, objetivo: 'velocidade'|'equilibrado', trabalha: boolean })",
        };
    }

    let materiasFaltantes: MateriaInput[] | undefined;
    if (body.materiasFaltantes !== undefined) {
        if (!Array.isArray(body.materiasFaltantes)) {
            return { error: "materiasFaltantes deve ser array" };
        }
        materiasFaltantes = body.materiasFaltantes as MateriaInput[];
    }

    return {
        input: {
            curriculoCompleto: curriculoCompleto.trim(),
            completedCodes,
            numeroPeriodo: Math.floor(numeroPeriodo),
            preferencias,
            materiasFaltantes,
        },
    };
}

interface MatrizRow {
    id_matriz: number;
    id_curso: number;
    curriculo_completo: string;
}

async function resolveMatriz(
    curriculoCompleto: string
): Promise<MatrizRow | null> {
    const cc = curriculoCompleto.trim();

    // Tenta match exato primeiro.
    const { data: exato } = await SupabaseWrapper.get()
        .from("matrizes")
        .select("id_matriz, id_curso, curriculo_completo")
        .eq("curriculo_completo", cc)
        .maybeSingle();
    if (exato) return exato as MatrizRow;

    // Fallback: prefixo (ex: "8117/-2" -> "8117/-2 - 2018.2").
    if (cc.includes("/")) {
        const prefix = cc.split(" - ")[0]?.trim() ?? cc;
        const { data: rows } = await SupabaseWrapper.get()
            .from("matrizes")
            .select("id_matriz, id_curso, curriculo_completo")
            .like("curriculo_completo", prefix + "%")
            .order("curriculo_completo")
            .limit(1);
        if (rows && rows.length > 0) return rows[0] as MatrizRow;
    }

    return null;
}

interface MateriaPorCursoRow {
    id_materia: number;
    nivel: number;
    tipo_natureza: number | null;
    materias: {
        id_materia: number;
        codigo_materia: string;
        nome_materia: string;
        carga_horaria: number | null;
    } | null;
}

/**
 * Busca as materias faltantes do aluno para um determinado curriculo.
 * "Faltante" = pertence ao curriculo E codigo nao esta em `completedCodes`.
 */
async function buscarMateriasFaltantes(
    matriz: MatrizRow,
    completedCodes: Set<string>
): Promise<MateriaInput[]> {
    // Busca todas as materias do curso via cursos -> materias_por_curso (mesmo padrao do fluxograma_controller).
    const { data: cursos, error } = await SupabaseWrapper.get()
        .from("cursos")
        .select("id_curso,materias_por_curso(id_materia,nivel,tipo_natureza,materias(id_materia,codigo_materia,nome_materia,carga_horaria))")
        .eq("id_curso", matriz.id_curso);
    if (error) throw new Error(`Erro ao buscar materias_por_curso: ${error.message}`);
    if (!cursos || cursos.length === 0) return [];

    const mpcRows: MateriaPorCursoRow[] = (cursos[0] as any).materias_por_curso ?? [];
    const idsMaterias = mpcRows
        .map((r) => r.materias?.id_materia)
        .filter((id): id is number => typeof id === "number");

    if (idsMaterias.length === 0) return [];

    // Busca pre-requisitos + co-requisitos das materias do curriculo.
    const [{ data: preRows }, { data: coRows }] = await Promise.all([
        SupabaseWrapper.get()
            .from("pre_requisitos")
            .select("id_materia, expressao_logica")
            .in("id_materia", idsMaterias),
        SupabaseWrapper.get()
            .from("co_requisitos")
            .select("id_materia, expressao_logica")
            .in("id_materia", idsMaterias),
    ]);

    const preByMateria = new Map<number, unknown>();
    for (const r of preRows ?? []) {
        if (typeof (r as any).id_materia === "number") {
            preByMateria.set((r as any).id_materia, (r as any).expressao_logica);
        }
    }
    const coByMateria = new Map<number, unknown>();
    for (const r of coRows ?? []) {
        if (typeof (r as any).id_materia === "number") {
            coByMateria.set((r as any).id_materia, (r as any).expressao_logica);
        }
    }

    const completedUpper = new Set<string>();
    for (const c of completedCodes) completedUpper.add(c.trim().toUpperCase());

    const out: MateriaInput[] = [];
    for (const row of mpcRows) {
        const mat = row.materias;
        if (!mat?.codigo_materia) continue;
        const codigo = mat.codigo_materia.trim().toUpperCase();
        if (completedUpper.has(codigo)) continue; // ja concluida

        const creditos = mat.carga_horaria != null ? Math.round(mat.carga_horaria / 15) : 4;
        out.push({
            codigo,
            nome: mat.nome_materia ?? codigo,
            creditos,
            nivel: row.nivel ?? 0,
            obrigatoria: (row.tipo_natureza ?? 0) === 0,
            preRequisitos: preByMateria.get(mat.id_materia) ?? null,
            coRequisitos: coByMateria.get(mat.id_materia) ?? null,
        });
    }
    return out;
}

// =============================================================
// Endpoint
// =============================================================

export const PlanejamentoController: EndpointController = {
    name: "planejamento",
    routes: {
        "gerar-plano": new Pair(
            RequestType.POST,
            async (req: Request, res: Response) => {
                const logger = createControllerLogger("PlanejamentoController", "gerar-plano");

                const parsed = parseBody(req.body);
                if (parsed.error || !parsed.input) {
                    logger.warn(`Body invalido: ${parsed.error}`);
                    return res.status(400).json({ error: parsed.error });
                }
                const input = parsed.input;

                logger.info(
                    `Gerando plano: curriculo="${input.curriculoCompleto}", concluidas=${input.completedCodes.length}, numeroPeriodo=${input.numeroPeriodo}, limiteCreditos=${input.preferencias.limiteCreditos}`
                );

                // Se materiasFaltantes foi enviado no body, pula o DB lookup.
                let materiasFaltantes = input.materiasFaltantes;
                if (!materiasFaltantes) {
                    const matriz = await resolveMatriz(input.curriculoCompleto);
                    if (!matriz) {
                        logger.warn(`Matriz nao encontrada: ${input.curriculoCompleto}`);
                        return res.status(404).json({
                            error: "Matriz não encontrada para o currículo informado",
                            curriculoCompleto: input.curriculoCompleto,
                        });
                    }
                    materiasFaltantes = await buscarMateriasFaltantes(
                        matriz,
                        new Set(input.completedCodes)
                    );
                    logger.info(`Materias faltantes do curriculo: ${materiasFaltantes.length}`);
                }

                const plano = gerarPlano({ ...input, materiasFaltantes });
                logger.info(
                    `Plano gerado: ${plano.semestresRestantes} semestres, ${plano.materiasNaoAlocadas.length} nao-alocadas`
                );

                return res.status(200).json(plano);
            }
        ),
    },
};

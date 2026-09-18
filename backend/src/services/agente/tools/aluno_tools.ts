/**
 * Tools de leitura do HISTÓRICO/situação real do aluno (requiresPlano: true).
 *
 * Dão ao agente acesso aos dados de banco do aluno como contexto: matérias
 * concluídas e em curso (do fluxograma_atual), integralização, e IRA/percentual
 * oficiais (de historicos_usuarios). Sem isso o agente adivinha — foi a origem
 * do bug "177 créditos".
 */

import { SupabaseWrapper } from "../../../supabase_wrapper";
import { parseFluxograma } from "../../plano_formatura.service";
import { norm, type AgenteContexto } from "../context";
import type { AgentTool } from "../tool_registry";

/**
 * Situação acadêmica resumida a partir do contexto (fluxograma + integralização).
 * Reutilizada no system prompt para ancorar TODA resposta em dados reais.
 */
export function resumoSituacaoAluno(ctx: AgenteContexto): Record<string, any> {
    const { completed, currentSemester } = parseFluxograma(ctx.fluxogramaAtual);
    const exig = ctx.exigidaMatriz || {};
    const integ = ctx.cargaHorariaIntegralizada || {};
    const total = Number(exig.total || 0);
    const feito = Number(integ.total || 0);
    const percentual = total > 0 ? Math.round((feito / total) * 100) : 0;

    return {
        semestreAtual: ctx.numeroPeriodo,
        // Progresso por CARGA HORÁRIA (horas feitas ÷ exigidas). Difere do
        // percentual por CONTAGEM de disciplinas obrigatórias (ver consultar_historico_aluno).
        percentualConcluidoPorHoras: percentual,
        integralizacaoHoras: {
            total: `${feito}/${total}`,
            obrigatoria: `${Number(integ.obrigatoria || 0)}/${Number(exig.obrigatoria || 0)}`,
            optativa: `${Number(integ.optativa || 0)}/${Number(exig.optativa || 0)}`,
            complementar: `${Number(integ.complementar || 0)}/${Number(exig.complementar || 0)}`,
        },
        totalConcluidas: completed.size,
        emCurso: currentSemester.map((m) => m.codigo),
    };
}

async function consultarHistoricoAluno(ctx: AgenteContexto): Promise<string> {
    const { completed, currentSemester } = parseFluxograma(ctx.fluxogramaAtual);
    const base = resumoSituacaoAluno(ctx);

    // Enriquecer com IRA/percentual OFICIAIS de historicos_usuarios (última entrada).
    let ira: number | null = null;
    let mediaPonderada: number | null = null;
    let percentualPorContagem: number | null = null;
    let obrigatoriasConcluidas: number | null = null;
    let totalObrigatorias: number | null = null;
    let obrigatoriasPendentes: number | null = null;
    try {
        const { data } = await SupabaseWrapper.get()
            .from("historicos_usuarios")
            .select("ira, media_ponderada, percentual_conclusao, total_obrigatorias, total_obrigatorias_concluidas, total_obrigatorias_pendentes")
            .eq("id_user", ctx.idUser)
            .order("created_at", { ascending: false })
            .limit(1)
            .maybeSingle();
        if (data) {
            ira = data.ira ?? null;
            mediaPonderada = data.media_ponderada ?? null;
            percentualPorContagem = data.percentual_conclusao ?? null;
            totalObrigatorias = data.total_obrigatorias ?? null;
            obrigatoriasConcluidas = data.total_obrigatorias_concluidas ?? null;
            obrigatoriasPendentes = data.total_obrigatorias_pendentes ?? null;
        }
    } catch {
        /* sem histórico salvo → segue com os dados do contexto */
    }

    return JSON.stringify({
        ...base,
        ira,
        mediaPonderada,
        // Progresso por CONTAGEM de disciplinas obrigatórias (concluídas ÷ total).
        // NÃO é horas — diverge de percentualConcluidoPorHoras de propósito.
        progressoObrigatorias: {
            concluidas: obrigatoriasConcluidas,
            total: totalObrigatorias,
            pendentes: obrigatoriasPendentes,
            percentualPorContagem,
        },
        nota_percentuais:
            "Há DUAS medidas de progresso e elas divergem de propósito: 'percentualConcluidoPorHoras' (base: CARGA HORÁRIA, ver integralizacaoHoras) e 'progressoObrigatorias.percentualPorContagem' (base: CONTAGEM de disciplinas obrigatórias). Ao citar um percentual, diga a base; NUNCA apresente um percentual ao lado de horas que não batem sem explicar que são métricas diferentes.",
        concluidas: [...completed].sort(),
        emCursoDetalhe: currentSemester.map((m) => ({ codigo: m.codigo, nome: m.nome ?? null })),
    });
}

function consultarStatusMateria(args: Record<string, unknown>, ctx: AgenteContexto): string {
    const codigo = typeof args.codigo === "string" ? norm(args.codigo) : "";
    if (!codigo) return JSON.stringify({ erro: "Código da matéria não fornecido." });

    const { completed, currentSemester } = parseFluxograma(ctx.fluxogramaAtual);
    const pertenceAoCurriculo = ctx.materias.some((m) => norm(m.codigo) === codigo);

    let status: "concluida" | "em_curso" | "pendente" | "fora_do_curriculo";
    if (completed.has(codigo)) status = "concluida";
    else if (currentSemester.some((m) => norm(m.codigo) === codigo)) status = "em_curso";
    else if (pertenceAoCurriculo) status = "pendente";
    else status = "fora_do_curriculo";

    return JSON.stringify({ codigo, status, pertenceAoCurriculo });
}

export const consultarHistoricoAlunoTool: AgentTool = {
    name: "consultar_historico_aluno",
    requiresPlano: true,
    schema: {
        type: "function",
        function: {
            name: "consultar_historico_aluno",
            description:
                "Consulta a situação acadêmica REAL do aluno: matérias já concluídas e em curso, integralização (horas feitas/exigidas), IRA, média e percentual de conclusão. Use SEMPRE que o aluno perguntar sobre o que já fez, quanto falta, IRA/notas ou progresso.",
            parameters: { type: "object", properties: {} },
        },
    },
    execute: async (_args, ctx) => ({ resultado: await consultarHistoricoAluno(ctx) }),
};

export const consultarStatusMateriaTool: AgentTool = {
    name: "consultar_status_materia",
    requiresPlano: true,
    schema: {
        type: "function",
        function: {
            name: "consultar_status_materia",
            description:
                "Diz o status de UMA matéria no histórico do aluno: 'concluida', 'em_curso', 'pendente' (falta cursar, está no currículo) ou 'fora_do_curriculo'. Use para responder 'já fiz X?' ou 'ainda preciso de X?'.",
            parameters: {
                type: "object",
                properties: {
                    codigo: {
                        type: "string",
                        description: "Código da matéria (ex: MAT0025). Obrigatório.",
                    },
                },
                required: ["codigo"],
            },
        },
    },
    execute: async (args, ctx) => ({ resultado: consultarStatusMateria(args, ctx) }),
};

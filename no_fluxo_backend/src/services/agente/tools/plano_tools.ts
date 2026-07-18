/**
 * Tools que dependem de plano (requiresPlano: true) — geram/mutam/simulam o
 * plano de formatura do aluno. Só aparecem quando o contexto tem plano carregado.
 */

import {
    norm,
    resumoDoPlano,
    gerarPlanoDoContexto,
    type AgenteContexto,
} from "../context";
import type { AgentTool, ToolResult } from "../tool_registry";
import type { MateriaPlano } from "../../../types/planejamento";

function consultarPlano(args: Record<string, unknown>, ctx: AgenteContexto): string {
    const plano = gerarPlanoDoContexto(ctx);
    const codigo = typeof args.codigo === "string" ? norm(args.codigo) : null;

    if (!codigo) return JSON.stringify(resumoDoPlano(plano, ctx));

    for (const s of plano.plano) {
        for (const m of s.materias) {
            if ("codigo" in m && (m as MateriaPlano).codigo === codigo) {
                const mp = m as MateriaPlano;
                return JSON.stringify({
                    codigo: mp.codigo,
                    nome: mp.nome,
                    semestreIndice: s.indice,
                    semestreLabel: s.semestre ?? null,
                    creditos: mp.creditos,
                    critica: mp.critica,
                    score: mp.score,
                    desbloqueiaDireto: mp.desbloqueiaDireto,
                    desbloqueiaIndireto: mp.desbloqueiaIndireto,
                    motivo: mp.motivo,
                });
            }
        }
    }
    return JSON.stringify({
        erro: `Matéria ${codigo} não encontrada no plano. Ela pode já estar concluída, em curso, ou não pertencer ao currículo.`,
    });
}

function simularCenario(args: Record<string, unknown>, ctx: AgenteContexto): string {
    const antes = resumoDoPlano(gerarPlanoDoContexto(ctx), ctx);

    const simCtx: AgenteContexto = {
        ...ctx,
        preferencias: { ...ctx.preferencias },
        restricoes: {
            adiar: [...ctx.restricoes.adiar],
            priorizar: [...ctx.restricoes.priorizar],
            limitesPersonalizados: { ...ctx.restricoes.limitesPersonalizados },
        },
    };

    const limite = Number(args.limiteCreditos);
    if (Number.isFinite(limite) && limite >= 8 && limite <= 32) {
        simCtx.preferencias.limiteCreditos = Math.floor(limite);
    }
    if (Array.isArray(args.adiar)) {
        for (const c of args.adiar) if (typeof c === "string") simCtx.restricoes.adiar.push(norm(c));
    }
    if (Array.isArray(args.priorizar)) {
        for (const c of args.priorizar) if (typeof c === "string") simCtx.restricoes.priorizar.push(norm(c));
    }

    const depois = resumoDoPlano(gerarPlanoDoContexto(simCtx), simCtx);
    return JSON.stringify({
        antes,
        depois,
        deltaSemestres: depois.semestresRestantes - antes.semestresRestantes,
    });
}

function ajustarCarga(args: Record<string, unknown>, ctx: AgenteContexto): ToolResult {
    const limite = Number(args.limiteCreditos);
    if (!Number.isFinite(limite) || limite < 8 || limite > 32) {
        return {
            resultado: JSON.stringify({ erro: "limiteCreditos deve ser um inteiro entre 8 e 32." }),
        };
    }
    ctx.preferencias.limiteCreditos = Math.floor(limite);
    if (args.objetivo === "velocidade" || args.objetivo === "equilibrado") {
        ctx.preferencias.objetivo = args.objetivo;
    }
    const plano = gerarPlanoDoContexto(ctx);
    return { resultado: JSON.stringify(resumoDoPlano(plano, ctx)), planoAtualizado: plano };
}

function ajustarCargaSemestre(args: Record<string, unknown>, ctx: AgenteContexto): ToolResult {
    const indice = Number(args.semestreIndice);
    const limite = Number(args.limiteCreditos);

    if (!Number.isFinite(indice) || indice < 0) {
        return { resultado: JSON.stringify({ erro: "semestreIndice deve ser um inteiro positivo." }) };
    }
    if (!Number.isFinite(limite) || limite < 0 || limite > 40) {
        return { resultado: JSON.stringify({ erro: "limiteCreditos deve ser um inteiro entre 0 e 40." }) };
    }

    if (!ctx.restricoes.limitesPersonalizados) {
        ctx.restricoes.limitesPersonalizados = {};
    }

    ctx.restricoes.limitesPersonalizados[Math.floor(indice)] = Math.floor(limite);

    const plano = gerarPlanoDoContexto(ctx);
    return { resultado: JSON.stringify(resumoDoPlano(plano, ctx)), planoAtualizado: plano };
}

function moverMateria(args: Record<string, unknown>, ctx: AgenteContexto): ToolResult {
    const codigo = typeof args.codigo === "string" ? norm(args.codigo) : "";
    const acao = args.acao;

    if (acao !== "adiar" && acao !== "priorizar" && acao !== "remover_restricao") {
        return {
            resultado: JSON.stringify({
                erro: "acao deve ser 'adiar', 'priorizar' ou 'remover_restricao'.",
            }),
        };
    }
    const existe = ctx.materias.some((m) => norm(m.codigo) === codigo);
    if (!existe) {
        return {
            resultado: JSON.stringify({
                erro: `Matéria ${codigo || "(vazio)"} não está entre as matérias faltantes do aluno.`,
            }),
        };
    }

    // Listas mutuamente exclusivas: entrar numa remove da outra.
    ctx.restricoes.adiar = ctx.restricoes.adiar.filter((c) => c !== codigo);
    ctx.restricoes.priorizar = ctx.restricoes.priorizar.filter((c) => c !== codigo);
    if (acao === "adiar") ctx.restricoes.adiar.push(codigo);
    if (acao === "priorizar") ctx.restricoes.priorizar.push(codigo);

    const plano = gerarPlanoDoContexto(ctx);
    return {
        resultado: JSON.stringify({
            mensagem: `Matéria ${codigo} tratada como ${acao}.`,
            planoAtualizado: resumoDoPlano(plano, ctx),
        }),
        planoAtualizado: plano,
    };
}

export const consultarPlanoTool: AgentTool = {
    name: "consultar_plano",
    requiresPlano: true,
    schema: {
        type: "function",
        function: {
            name: "consultar_plano",
            description:
                "Consulta o plano de formatura do aluno. Se nenhum código for fornecido, retorna um resumo geral.",
            parameters: {
                type: "object",
                properties: {
                    codigo: {
                        type: "string",
                        description: "Código da matéria para detalhes específicos (ex: MAT0026). Opcional.",
                    },
                },
            },
        },
    },
    execute: async (args, ctx) => ({ resultado: consultarPlano(args, ctx) }),
};

export const simularCenarioTool: AgentTool = {
    name: "simular_cenario",
    requiresPlano: true,
    schema: {
        type: "function",
        function: {
            name: "simular_cenario",
            description: "Simula um cenário alternativo sem alterar o plano atual. Mostra o impacto de mudanças.",
            parameters: {
                type: "object",
                properties: {
                    limiteCreditos: {
                        type: "number",
                        description: "Créditos hipotéticos por semestre (8-32). Opcional.",
                    },
                    adiar: {
                        type: "array",
                        items: { type: "string" },
                        description: "Códigos de matérias a adiar. Opcional.",
                    },
                    priorizar: {
                        type: "array",
                        items: { type: "string" },
                        description: "Códigos de matérias a priorizar. Opcional.",
                    },
                },
            },
        },
    },
    execute: async (args, ctx) => ({ resultado: simularCenario(args, ctx) }),
};

export const ajustarCargaTool: AgentTool = {
    name: "ajustar_carga",
    requiresPlano: true,
    schema: {
        type: "function",
        function: {
            name: "ajustar_carga",
            description: "Ajusta a carga semestral GLOBAL e/ou objetivo do aluno e regenera o plano.",
            parameters: {
                type: "object",
                properties: {
                    limiteCreditos: {
                        type: "number",
                        description: "Novos créditos globais por semestre (8-32). Obrigatório.",
                    },
                    objetivo: {
                        type: "string",
                        enum: ["velocidade", "equilibrado"],
                        description: "Objetivo: velocidade ou equilibrado. Opcional.",
                    },
                },
                required: ["limiteCreditos"],
            },
        },
    },
    execute: async (args, ctx) => ajustarCarga(args, ctx),
};

export const ajustarCargaSemestreTool: AgentTool = {
    name: "ajustar_carga_semestre",
    requiresPlano: true,
    schema: {
        type: "function",
        function: {
            name: "ajustar_carga_semestre",
            description:
                "Ajusta o limite de créditos de UM semestre ESPECÍFICO (usando o índice numérico dele, onde 0 é o primeiro) e regenera o plano para redistribuir a carga.",
            parameters: {
                type: "object",
                properties: {
                    semestreIndice: {
                        type: "number",
                        description:
                            "Índice interno do semestre (0, 1, 2...). Você deve mapear o número do semestre pedido pelo usuário (ex: 'Semestre 13') para o 'indice' correspondente verificando a propriedade 'numeroSemestre' no resumo do plano.",
                    },
                    limiteCreditos: {
                        type: "number",
                        description: "Novo limite máximo de créditos para ESTE semestre específico (0-40).",
                    },
                },
                required: ["semestreIndice", "limiteCreditos"],
            },
        },
    },
    execute: async (args, ctx) => ajustarCargaSemestre(args, ctx),
};

export const moverMateriaTool: AgentTool = {
    name: "mover_materia",
    requiresPlano: true,
    schema: {
        type: "function",
        function: {
            name: "mover_materia",
            description: "Move uma matéria: adia, prioriza ou remove restrição existente.",
            parameters: {
                type: "object",
                properties: {
                    codigo: {
                        type: "string",
                        description: "Código da matéria (ex: MAT0026). Obrigatório.",
                    },
                    acao: {
                        type: "string",
                        enum: ["adiar", "priorizar", "remover_restricao"],
                        description: "Ação a executar. Obrigatório.",
                    },
                },
                required: ["codigo", "acao"],
            },
        },
    },
    execute: async (args, ctx) => moverMateria(args, ctx),
};

/**
 * Tools genéricas (requiresPlano: false) — só consultam o banco por código de
 * matéria, sem depender de um plano de formatura. Disponíveis em qualquer chat,
 * inclusive na aba Assistente sem login.
 */

import { SupabaseWrapper } from "../../../supabase_wrapper";
import { SabiaService } from "../../sabia.service";
import { norm, type AgenteContexto } from "../context";
import { removeAccents } from "../../../utils/text.utils";
import type { AgentTool } from "../tool_registry";

// Instância única do proxy para o agente Python (busca semântica por embeddings).
const sabia = new SabiaService();

/** Executor cru — também usado pelo atalho `/turmas CODIGO` (bypass do LLM). */
export async function consultarTurmasMateria(args: Record<string, unknown>): Promise<string> {
    const codigo = typeof args.codigo === "string" ? norm(args.codigo) : "";
    if (!codigo) return JSON.stringify({ erro: "Código da matéria não fornecido." });

    try {
        const supabase = SupabaseWrapper.get();
        const { data: materiaData, error: materiaError } = await supabase
            .from("materias")
            .select("id_materia, nome_materia")
            .eq("codigo_materia", codigo)
            .single();

        if (materiaError || !materiaData) {
            return JSON.stringify({ erro: `Matéria ${codigo} não encontrada.` });
        }

        // Tentar obter o período letivo atual via RPC do Supabase
        const { data: periodoAtual } = await supabase.rpc("periodo_letivo_atual");

        let turmasQuery = supabase
            .from("turmas")
            .select("turma, docente, horario, local, vagas_ofertadas, vagas_ocupadas, ano_periodo")
            .eq("id_materia", materiaData.id_materia);

        if (periodoAtual) {
            turmasQuery = turmasQuery.eq("ano_periodo", periodoAtual);
        }

        let { data: turmasRows, error: turmasError } = await turmasQuery
            .order("ano_periodo", { ascending: false })
            .limit(10);

        // Fallback: se não houver ofertas no período letivo atual, buscar as mais recentes registradas
        if (!turmasRows || turmasRows.length === 0) {
            const { data: fallbackRows } = await supabase
                .from("turmas")
                .select("turma, docente, horario, local, vagas_ofertadas, vagas_ocupadas, ano_periodo")
                .eq("id_materia", materiaData.id_materia)
                .order("ano_periodo", { ascending: false })
                .limit(10);
            turmasRows = fallbackRows;
        }

        if (turmasError || !turmasRows || turmasRows.length === 0) {
            return JSON.stringify({ erro: `Nenhuma turma encontrada para ${codigo} - ${materiaData.nome_materia}.` });
        }

        const turmasFormatadas = turmasRows.map((t) => (
            `[TURMA|${t.turma || "?"}|${t.docente || "A definir"}|${t.horario || "?"}|${t.local || "?"}|${t.vagas_ocupadas ?? "?"}/${t.vagas_ofertadas ?? "?"}|${t.ano_periodo || "?"}]`
        ));

        return JSON.stringify({
            codigo,
            nome_materia: materiaData.nome_materia,
            periodo: periodoAtual || (turmasRows[0]?.ano_periodo ?? null),
            instrucao_llm: "Para exibir as turmas, COPIE E COLE EXATAMENTE o formato gerado abaixo ([TURMA|...]). Não altere nada dentro dos colchetes, pois o frontend usa isso para desenhar a interface.",
            turmas_recentes: turmasFormatadas,
        });
    } catch (e) {
        return JSON.stringify({ erro: `Falha ao consultar turmas da matéria ${codigo}.` });
    }
}

async function consultarInformacoesMateria(args: Record<string, unknown>): Promise<string> {
    const codigo = typeof args.codigo === "string" ? norm(args.codigo) : "";
    if (!codigo) return JSON.stringify({ erro: "Código da matéria não fornecido." });

    try {
        const supabase = SupabaseWrapper.get();
        const { data, error } = await supabase
            .from("materias")
            .select("nome_materia, ementa, departamento, carga_horaria")
            .eq("codigo_materia", codigo)
            .single();

        if (error || !data) {
            return JSON.stringify({ erro: `Matéria ${codigo} não encontrada no banco de dados oficial.` });
        }

        return JSON.stringify({
            codigo,
            nome_materia: data.nome_materia,
            departamento: data.departamento,
            carga_horaria: data.carga_horaria,
            ementa: data.ementa || "Não cadastrada.",
            aviso: "Lembre-se de usar sua pesquisa web nativa (Sabiá) se o usuário perguntou sobre a dificuldade ou opiniões.",
        });
    } catch (e) {
        return JSON.stringify({ erro: `Falha ao consultar informações da matéria ${codigo}.` });
    }
}

export const consultarInformacoesMateriaTool: AgentTool = {
    name: "consultar_informacoes_materia",
    requiresPlano: false,
    schema: {
        type: "function",
        function: {
            name: "consultar_informacoes_materia",
            description:
                "Busca a ementa oficial da matéria no banco de dados. (Para nível de dificuldade ou opiniões, você pesquisará nativamente na internet).",
            parameters: {
                type: "object",
                properties: {
                    codigo: {
                        type: "string",
                        description: "Código da matéria (ex: FGA0211). Obrigatório.",
                    },
                },
                required: ["codigo"],
            },
        },
    },
    execute: async (args) => ({ resultado: await consultarInformacoesMateria(args) }),
};

type MateriaBusca = { codigo: string; nome: string; similaridade: number };

/**
 * Mantém só as matérias com turma ofertada no período letivo ativo.
 * Usado quando o chat está embutido no Montador de Grade (ctx.apenasComOferta):
 * não faz sentido recomendar optativa que o aluno não consegue matricular agora.
 */
async function filtrarPorOfertaAtiva(materias: MateriaBusca[]): Promise<MateriaBusca[]> {
    const codigos = materias.map((m) => norm(m.codigo)).filter(Boolean);
    if (codigos.length === 0) return [];

    const supabase = SupabaseWrapper.get();
    const { data: periodo } = await supabase.rpc("periodo_letivo_atual");
    if (!periodo) return materias; // sem período conhecido → não filtra

    const { data: mats } = await supabase
        .from("materias")
        .select("id_materia, codigo_materia")
        .in("codigo_materia", codigos);
    const idPorCodigo = new Map<string, number>(
        (mats ?? []).map((m: any) => [norm(m.codigo_materia), Number(m.id_materia)])
    );
    const ids = [...idPorCodigo.values()];
    if (ids.length === 0) return [];

    const { data: turmas } = await supabase
        .from("turmas")
        .select("id_materia")
        .eq("ano_periodo", periodo)
        .in("id_materia", ids);
    const idsComOferta = new Set<number>((turmas ?? []).map((t: any) => Number(t.id_materia)));

    return materias.filter((m) => {
        const id = idPorCodigo.get(norm(m.codigo));
        return id != null && idsComOferta.has(id);
    });
}

async function buscarMateriasUnb(args: Record<string, unknown>, ctx: AgenteContexto): Promise<string> {
    const raw = Array.isArray(args.termos_busca) ? args.termos_busca : [];
    const termos = raw
        .filter((t): t is string => typeof t === "string" && t.trim().length > 0)
        .map(t => removeAccents(t.trim()).toUpperCase());

    if (termos.length === 0) {
        return JSON.stringify({ erro: "Informe ao menos um termo de busca em 'termos_busca'." });
    }
    let materias = await sabia.buscarMaterias(termos);

    if (ctx.apenasComOferta && materias.length > 0) {
        materias = await filtrarPorOfertaAtiva(materias);
        if (materias.length === 0) {
            return JSON.stringify({
                aviso: "Nenhuma disciplina sobre esse tema tem turma ofertada no período atual.",
                materias: [],
            });
        }
    }

    if (materias.length === 0) {
        return JSON.stringify({
            aviso: "Nenhuma disciplina encontrada (ou o serviço de busca semântica está indisponível).",
            materias: [],
        });
    }
    return JSON.stringify({ materias });
}

export const buscarMateriasUnbTool: AgentTool = {
    name: "buscar_materias_unb",
    requiresPlano: false,
    schema: {
        type: "function",
        function: {
            name: "buscar_materias_unb",
            description:
                "Descobre/recomenda disciplinas da UnB sobre um assunto ou interesse usando busca semântica (embeddings). Use quando o aluno quiser explorar matérias por tema (ex: 'quero aprender sobre redes').",
            parameters: {
                type: "object",
                properties: {
                    termos_busca: {
                        type: "array",
                        items: { type: "string" },
                        description:
                            "1 a 4 termos de busca sobre o assunto (o termo principal + sinônimos/termos relacionados melhoram a recall). Ex: ['redes de computadores', 'protocolos', 'internet'].",
                    },
                },
                required: ["termos_busca"],
            },
        },
    },
    execute: async (args, ctx) => ({ resultado: await buscarMateriasUnb(args, ctx) }),
};

/**
 * Busca matérias pelo LOCAL/campus das turmas ofertadas (ex.: "FGA", "FCTE",
 * "FCE", "FUP", "UAC", "UED", "BSA", "ICC"). O campo turmas.local é texto livre
 * com o prédio/campus; um ILIKE por termo já pega as ofertas certas.
 */
async function buscarMateriasPorLocal(args: Record<string, unknown>): Promise<string> {
    const raw = Array.isArray(args.locais) ? args.locais : [];
    const termos = raw
        .filter((t): t is string => typeof t === "string" && t.trim().length > 0)
        // Só alfanumérico/espaço/hífen: evita quebrar/injetar no filtro .or() do PostgREST.
        .map((t) => t.replace(/[^A-Za-z0-9 -]/g, " ").trim())
        .filter(Boolean);

    if (termos.length === 0) {
        return JSON.stringify({ erro: "Informe ao menos um local/campus em 'locais' (ex: ['FGA','FCTE'])." });
    }

    try {
        const supabase = SupabaseWrapper.get();
        const { data: periodo } = await supabase.rpc("periodo_letivo_atual");

        const orFilter = termos.map((t) => `local.ilike.%${t}%`).join(",");
        let query = supabase
            .from("turmas")
            .select("id_materia, turma, local, ano_periodo")
            .or(orFilter)
            .limit(400);
        if (periodo) query = query.eq("ano_periodo", periodo);

        const { data: turmas, error } = await query;
        if (error) {
            return JSON.stringify({ erro: "Falha ao buscar turmas por local." });
        }
        if (!turmas || turmas.length === 0) {
            return JSON.stringify({
                aviso: `Nenhuma turma encontrada nos locais: ${termos.join(", ")} (período ${periodo ?? "atual"}).`,
                materias: [],
            });
        }

        const ids = [...new Set(turmas.map((t) => t.id_materia))];
        const { data: mats } = await supabase
            .from("materias")
            .select("id_materia, codigo_materia, nome_materia")
            .in("id_materia", ids);
        const infoById = new Map<number, { codigo: string; nome: string }>(
            (mats ?? []).map((m: any) => [Number(m.id_materia), { codigo: m.codigo_materia, nome: m.nome_materia }])
        );

        const porMateria = new Map<string, { codigo: string; nome: string; qtd_turmas: number }>();
        for (const t of turmas) {
            const info = infoById.get(Number(t.id_materia));
            if (!info) continue;
            const atual = porMateria.get(info.codigo) ?? { codigo: info.codigo, nome: info.nome, qtd_turmas: 0 };
            atual.qtd_turmas += 1;
            porMateria.set(info.codigo, atual);
        }

        const materias = [...porMateria.values()].sort((a, b) => a.codigo.localeCompare(b.codigo)).slice(0, 40);
        return JSON.stringify({
            periodo: periodo ?? null,
            locais_buscados: termos,
            total_materias: materias.length,
            materias,
            instrucao_llm: "Liste os códigos das matérias (o app os transforma em botões clicáveis). Se houver muitas, resuma e cite as principais.",
        });
    } catch {
        return JSON.stringify({ erro: "Falha ao buscar matérias por local." });
    }
}

export const buscarMateriasPorLocalTool: AgentTool = {
    name: "buscar_materias_por_local",
    requiresPlano: false,
    schema: {
        type: "function",
        function: {
            name: "buscar_materias_por_local",
            description:
                "Lista matérias ofertadas em um CAMPUS/LOCAL específico, buscando no campo 'local' das turmas do período atual. Use quando o aluno perguntar por matérias de um campus/prédio (ex: 'matérias da FGA', 'e da FCTE?', 'o que tem no BSA', 'disciplinas na FCE/FUP/UAC/UED/ICC').",
            parameters: {
                type: "object",
                properties: {
                    locais: {
                        type: "array",
                        items: { type: "string" },
                        description:
                            "1 a 4 termos de local/campus a casar no campo local da turma (ex: ['FGA','FCTE'] para o campus Gama, ['BSA'] para salas do Darcy, ['FCE'] Ceilândia, ['FUP'] Planaltina).",
                    },
                },
                required: ["locais"],
            },
        },
    },
    execute: async (args) => ({ resultado: await buscarMateriasPorLocal(args) }),
};

export const consultarTurmasMateriaTool: AgentTool = {
    name: "consultar_turmas_materia",
    requiresPlano: false,
    schema: {
        type: "function",
        function: {
            name: "consultar_turmas_materia",
            description: "Busca as turmas ofertadas de uma matéria: Professores, horários, locais e vagas.",
            parameters: {
                type: "object",
                properties: {
                    codigo: {
                        type: "string",
                        description: "Código da matéria (ex: MAT0026). Obrigatório.",
                    },
                },
                required: ["codigo"],
            },
        },
    },
    execute: async (args) => ({ resultado: await consultarTurmasMateria(args) }),
};

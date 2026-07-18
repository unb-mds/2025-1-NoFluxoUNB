/**
 * Tools genéricas (requiresPlano: false) — só consultam o banco por código de
 * matéria, sem depender de um plano de formatura. Disponíveis em qualquer chat,
 * inclusive na aba Assistente sem login.
 */

import { SupabaseWrapper } from "../../../supabase_wrapper";
import { SabiaService } from "../../sabia.service";
import { norm } from "../context";
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

        const { data: turmasRows, error: turmasError } = await supabase
            .from("turmas")
            .select("turma, docente, horario, local, vagas_ofertadas, vagas_ocupadas")
            .eq("id_materia", materiaData.id_materia)
            .order("ano_periodo", { ascending: false })
            .limit(10); // Trazer no máximo 10 turmas recentes

        if (turmasError || !turmasRows || turmasRows.length === 0) {
            return JSON.stringify({ erro: `Nenhuma turma encontrada para ${codigo} - ${materiaData.nome_materia}.` });
        }

        const turmasFormatadas = turmasRows.map((t) => (
            `[TURMA|${t.turma || "?"}|${t.docente || "A definir"}|${t.horario || "?"}|${t.local || "?"}|${t.vagas_ocupadas ?? "?"}/${t.vagas_ofertadas ?? "?"}]`
        ));

        return JSON.stringify({
            codigo,
            nome_materia: materiaData.nome_materia,
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

async function buscarMateriasUnb(args: Record<string, unknown>): Promise<string> {
    const raw = Array.isArray(args.termos_busca) ? args.termos_busca : [];
    const termos = raw
        .filter((t): t is string => typeof t === "string" && t.trim().length > 0)
        .map(t => removeAccents(t.trim()).toUpperCase());

    if (termos.length === 0) {
        return JSON.stringify({ erro: "Informe ao menos um termo de busca em 'termos_busca'." });
    }
    const materias = await sabia.buscarMaterias(termos);
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
    execute: async (args) => ({ resultado: await buscarMateriasUnb(args) }),
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

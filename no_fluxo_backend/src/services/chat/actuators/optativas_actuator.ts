/**
 * Atuador de busca de optativas — Fase 2 do orquestrador de chat
 * (docs/chatbot-orquestrador.md).
 *
 * Isolado e testável sozinho de propósito: o relatório de qualidade apontou um bug
 * de filtro não-funcional na busca de optativas do Darcy legado
 * (src/services/agente/tools/materia_tools.ts, buscarMateriasUnb + filtrarPorOfertaAtiva).
 * Isolar esse caminho aqui — reimplementado, não reexportado, pra não acoplar a este
 * atuador a mudanças no Darcy legado — permite testar o filtro por oferta ativa sem
 * o resto do loop de tool-calling em volta.
 */

import { z } from "zod";
import { Agent, tool } from "@openai/agents";
import { SupabaseWrapper } from "../../../supabase_wrapper";
import { SabiaService } from "../../sabia.service";
import { norm } from "../../agente/context";
import { createMaritacaModel } from "../model_provider";

type MateriaBusca = { codigo: string; nome: string; similaridade: number };

const sabia = new SabiaService();

/** Mantém só as matérias com turma ofertada no período letivo ativo. */
export async function filtrarPorOfertaAtiva(materias: MateriaBusca[]): Promise<MateriaBusca[]> {
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

export async function buscarOptativas(termosBusca: string[], apenasComOferta: boolean): Promise<string> {
    if (termosBusca.length === 0) {
        return JSON.stringify({ erro: "Informe ao menos um termo de busca." });
    }

    let materias = await sabia.buscarMaterias(termosBusca);

    if (apenasComOferta && materias.length > 0) {
        materias = await filtrarPorOfertaAtiva(materias);
    }

    if (materias.length === 0) {
        return JSON.stringify({
            aviso: apenasComOferta
                ? "Nenhuma optativa sobre esse tema tem turma ofertada no período atual."
                : "Nenhuma optativa encontrada para esse tema.",
            materias: [],
        });
    }
    return JSON.stringify({ materias });
}

export function createOptativasAgent(apenasComOferta: boolean = false): Agent {
    const buscarOptativasTool = tool({
        name: "buscar_optativas",
        description:
            "Busca disciplinas optativas da UnB por tema/assunto usando busca semântica (embeddings).",
        parameters: z.object({
            termos_busca: z
                .array(z.string())
                .min(1)
                .max(4)
                .describe("1 a 4 termos sobre o assunto (termo principal + sinônimos)."),
        }),
        execute: async ({ termos_busca }) => buscarOptativas(termos_busca, apenasComOferta),
    });

    return new Agent({
        name: "AtuadorOptativas",
        instructions:
            "Você responde SOMENTE perguntas sobre buscar/sugerir disciplinas optativas por tema ou assunto. " +
            "Sempre use a tool buscar_optativas. Responda em português brasileiro, listando código e nome das " +
            "disciplinas encontradas.",
        model: createMaritacaModel(),
        tools: [buscarOptativasTool],
    });
}

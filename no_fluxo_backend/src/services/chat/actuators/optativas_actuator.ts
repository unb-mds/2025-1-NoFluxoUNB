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
import { parseFluxograma } from "../../plano_formatura.service";
import {
    parseExpressaoLogicaFromDb,
    satisfazExpressaoLogica,
} from "../../../utils/expressao_logica";

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

/** Tira da lista as matérias que o aluno já cumpriu. Função pura. */
export function filtrarJaCursadas(
    materias: MateriaBusca[],
    jaCumpridas: Set<string>
): MateriaBusca[] {
    if (jaCumpridas.size === 0) return materias;
    const cumpridas = new Set([...jaCumpridas].map((c) => norm(c)));
    return materias.filter((m) => !cumpridas.has(norm(m.codigo)));
}

/**
 * O que o aluno já cursou: aprovadas/dispensadas ∪ em curso (MATR).
 *
 * MATR entra porque estará concluída antes do semestre que ele vai cursar — mesma
 * regra do AtuadorGrade e do Motor 2. Degrada pra conjunto vazio (nenhum filtro) se
 * o aluno não tiver cadastro ou fluxograma: a busca continua funcionando.
 */
async function cumpridasDoAluno(email: string): Promise<Set<string>> {
    const vazio = new Set<string>();
    try {
        const supabase = SupabaseWrapper.get();
        const { data: user } = await supabase
            .from("users")
            .select("id_user")
            .eq("email", email)
            .maybeSingle();
        if (!user?.id_user) return vazio;

        const { data: dados } = await supabase
            .from("dados_users")
            .select("fluxograma_atual")
            .eq("id_user", user.id_user)
            .maybeSingle();
        if (!dados?.fluxograma_atual) return vazio;

        const { completed, currentSemester } = parseFluxograma(dados.fluxograma_atual);
        const out = new Set<string>(completed);
        for (const m of currentSemester) out.add(norm(m.codigo));
        return out;
    } catch {
        return vazio;
    }
}

/**
 * Entre os candidatos da busca, quais o aluno já tem cumpridos — direto ou porque a
 * EQUIVALÊNCIA do candidato é satisfeita pelo que ele cursou ("quem fez X está
 * dispensado de Y": sugerir Y seria mandar cursar algo que ele já tem crédito).
 *
 * Passe único, igual a expandirCumpridasComEquivalencias (commit 7e7075f4): compara
 * sempre contra o que foi cursado de verdade. A busca semântica varre o catálogo
 * inteiro da UnB, não só a matriz, então a equivalência precisa ser resolvida aqui —
 * o fluxograma só pré-resolve as da matriz do aluno.
 */
async function candidatosJaCumpridos(
    codigosCandidatos: string[],
    cumpridas: Set<string>
): Promise<Set<string>> {
    const jaCumpridos = new Set<string>();
    if (cumpridas.size === 0) return jaCumpridos;

    const codigos = codigosCandidatos.map((c) => norm(c)).filter(Boolean);
    for (const c of codigos) if (cumpridas.has(c)) jaCumpridos.add(c);

    try {
        const supabase = SupabaseWrapper.get();
        const { data: mats } = await supabase
            .from("materias")
            .select("id_materia, codigo_materia")
            .in("codigo_materia", codigos);
        const codigoPorId = new Map<number, string>(
            (mats ?? []).map((m: any) => [Number(m.id_materia), norm(m.codigo_materia)])
        );
        if (codigoPorId.size === 0) return jaCumpridos;

        const { data: equivs } = await supabase
            .from("equivalencias")
            .select("id_materia, expressao_logica")
            .in("id_materia", [...codigoPorId.keys()]);

        for (const row of (equivs ?? []) as any[]) {
            const cod = codigoPorId.get(Number(row.id_materia));
            if (!cod || jaCumpridos.has(cod)) continue;
            const expr = parseExpressaoLogicaFromDb(row.expressao_logica) ?? row.expressao_logica;
            if (expr && satisfazExpressaoLogica(expr, cumpridas)) jaCumpridos.add(cod);
        }
    } catch {
        // Degrada: mantém só o filtro direto, sem a parte de equivalência.
    }

    return jaCumpridos;
}

export async function buscarOptativas(
    termosBusca: string[],
    apenasComOferta: boolean,
    /**
     * E-mail do aluno. Quando presente, o resultado exclui o que ele já cursou —
     * sem isso a busca semântica sugeria matéria já aprovada (ex.: CIC0004 aparecendo
     * numa busca por "algoritmos" pra quem passou nela). Ausente = chat deslogado.
     */
    email?: string
): Promise<string> {
    if (termosBusca.length === 0) {
        return JSON.stringify({ erro: "Informe ao menos um termo de busca." });
    }

    let materias = await sabia.buscarMaterias(termosBusca);

    if (apenasComOferta && materias.length > 0) {
        materias = await filtrarPorOfertaAtiva(materias);
    }

    let filtrouPorHistorico = false;
    if (email && materias.length > 0) {
        const cumpridas = await cumpridasDoAluno(email);
        const jaCumpridos = await candidatosJaCumpridos(
            materias.map((m) => m.codigo),
            cumpridas
        );
        if (jaCumpridos.size > 0) {
            const antes = materias.length;
            materias = filtrarJaCursadas(materias, jaCumpridos);
            filtrouPorHistorico = materias.length < antes;
        }
    }

    if (materias.length === 0) {
        return JSON.stringify({
            aviso: filtrouPorHistorico
                ? "As optativas encontradas sobre esse tema você já cursou (ou está cursando)."
                : apenasComOferta
                  ? "Nenhuma optativa sobre esse tema tem turma ofertada no período atual."
                  : "Nenhuma optativa encontrada para esse tema.",
            materias: [],
        });
    }
    return JSON.stringify({ materias });
}

export function createOptativasAgent(apenasComOferta: boolean = false, email?: string): Agent {
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
        execute: async ({ termos_busca }) => buscarOptativas(termos_busca, apenasComOferta, email),
    });

    return new Agent({
        name: "AtuadorOptativas",
        instructions:
            "Você responde SOMENTE perguntas sobre buscar/sugerir disciplinas optativas por tema ou assunto. " +
            "Sempre use a tool buscar_optativas. Responda em português brasileiro, listando código e nome das " +
            "disciplinas encontradas. A tool já exclui o que o aluno cursou — nunca reintroduza um código que " +
            "não veio dela, e se vier só o campo 'aviso', repasse o aviso sem inventar sugestão.",
        model: createMaritacaModel(),
        tools: [buscarOptativasTool],
    });
}

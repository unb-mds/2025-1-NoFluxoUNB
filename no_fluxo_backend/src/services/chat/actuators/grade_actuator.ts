/**
 * Atuador de recomendação por horário livre — Fase 2 (extensão) do orquestrador
 * de chat (docs/chatbot-orquestrador.md), spec em
 * docs/superpowers/specs/2026-07-30-recomendacao-horario-livre-design.md.
 *
 * Filtro de horário é sempre determinístico (bitmask) — nunca passa pela IA.
 * Coerência temática (Task 7) é só ranking por cima do que já passou aqui.
 *
 * NOTA sobre o schema de `turmas`: a tabela só tem `id_materia` (sem
 * `codigo_materia` denormalizado) — confirmado em
 * PlanejamentoController.ts (a query "3. Busca materias com oferta real em
 * turmas" seleciona só `id_materia`) e no padrão já usado por
 * `filtrarPorOfertaAtiva` (optativas_actuator.ts), que resolve código →
 * id_materia via a tabela `materias` antes de consultar `turmas`. Este
 * atuador segue o mesmo padrão de dois passos.
 */
import { SupabaseWrapper } from "../../../supabase_wrapper";
import { montarDadosPlano } from "../../../controllers/PlanejamentoController";
import { parseFluxograma } from "../../plano_formatura.service";
import { slotMaskFromHorario } from "../../../utils/horario_slots";
import type { PlanoInput } from "../../../types/planejamento";

export interface CandidatoGrade {
    codigo: string;
    nome: string;
    creditos: number;
    obrigatoria: boolean;
    nivel: number;
}

const PLANO_INPUT_PADRAO: Omit<PlanoInput, "curriculoCompleto"> = {
    completedCodes: [],
    numeroPeriodo: 1,
    preferencias: { limiteCreditos: 24, objetivo: "equilibrado", trabalha: false },
};

function norm(codigo: string): string {
    return (codigo || "").trim().toUpperCase();
}

function parseEmbeddingVector(raw: unknown): number[] | null {
    if (Array.isArray(raw)) return raw.map(Number);
    if (typeof raw === "string") {
        try {
            const parsed = JSON.parse(raw);
            return Array.isArray(parsed) ? parsed.map(Number) : null;
        } catch {
            return null;
        }
    }
    return null;
}

/** Vetor médio das matérias já concluídas — "perfil temático" do aluno. */
async function calcularVetorPerfil(completedCodes: string[]): Promise<number[] | null> {
    if (completedCodes.length === 0) return null;
    const { data, error } = await SupabaseWrapper.get()
        .from("materias_vetorizadas")
        .select("codigo_materia, embedding")
        .in("codigo_materia", completedCodes);
    if (error || !data) return null;

    const vetores = (data as any[])
        .map((r) => parseEmbeddingVector(r.embedding))
        .filter((v): v is number[] => v !== null && v.length > 0);
    if (vetores.length === 0) return null;

    const dim = vetores[0].length;
    const soma = new Array(dim).fill(0);
    for (const v of vetores) for (let i = 0; i < dim; i++) soma[i] += v[i] ?? 0;
    return soma.map((s) => s / vetores.length);
}

/** codigo_materia -> similaridade (0..1) via RPC match_materias. Degrada pra Map vazio em qualquer falha. */
async function buscarSimilaridades(vetorPerfil: number[]): Promise<Map<string, number>> {
    const mapa = new Map<string, number>();
    try {
        const { data, error } = await SupabaseWrapper.get().rpc("match_materias", {
            query_embedding: vetorPerfil,
            match_threshold: 0.0,
            match_count: 100,
        });
        if (error || !data) return mapa;
        for (const item of data as any[]) {
            const cod = norm(String(item.codigo_materia ?? ""));
            if (cod) mapa.set(cod, Number(item.similaridade) || 0);
        }
    } catch {
        // Degrada graciosamente — ranking cai pro neutro, horário livre não é afetado.
    }
    return mapa;
}

export async function recomendarPorHorarioLivre(
    idUser: string,
    curriculoCompleto: string,
    freeMaskStr: string,
    periodoAtivo: string
): Promise<{ candidatos: CandidatoGrade[] } | { erro: string }> {
    const freeMask = BigInt(freeMaskStr || "0");
    if (freeMask === 0n) {
        return { candidatos: [] };
    }

    const { dados, error } = await montarDadosPlano(idUser, { ...PLANO_INPUT_PADRAO, curriculoCompleto });
    if (error || !dados) {
        return { erro: error ?? "Não foi possível carregar o currículo do aluno." };
    }

    const { completed } = parseFluxograma(dados.fluxogramaAtual);

    const elegiveis = dados.materiasMapeadas.filter((m) => {
        const cod = norm(m.codigo);
        if (m.obrigatoria) return !completed.has(cod);
        return dados.codigosComOferta.has(cod);
    });
    if (elegiveis.length === 0) return { candidatos: [] };

    const codigos = elegiveis.map((m) => norm(m.codigo));

    // Passo 1: código -> id_materia (turmas não tem codigo_materia direto).
    const supabase = SupabaseWrapper.get();
    const { data: materiasRows, error: erroMaterias } = await supabase
        .from("materias")
        .select("id_materia, codigo_materia")
        .in("codigo_materia", codigos);

    if (erroMaterias) {
        return { erro: "Não foi possível resolver as matérias do currículo." };
    }

    const idPorCodigo = new Map<string, number>(
        (materiasRows ?? []).map((m: any) => [norm(m.codigo_materia), Number(m.id_materia)])
    );
    const codigoPorId = new Map<number, string>([...idPorCodigo.entries()].map(([cod, id]) => [id, cod]));
    const ids = [...idPorCodigo.values()];
    if (ids.length === 0) return { candidatos: [] };

    // Passo 2: turmas do período ativo para esses id_materia.
    const { data: turmas, error: erroTurmas } = await supabase
        .from("turmas")
        .select("id_materia, horario")
        .eq("ano_periodo", periodoAtivo)
        .in("id_materia", ids);

    if (erroTurmas || !turmas) {
        return { erro: "Não foi possível consultar as turmas do período." };
    }

    const codigosComTurmaNoLivre = new Set<string>();
    for (const t of turmas as any[]) {
        const cod = codigoPorId.get(Number(t.id_materia));
        if (!cod) continue;
        const turmaMask = slotMaskFromHorario(t.horario);
        if ((turmaMask & freeMask) === turmaMask) codigosComTurmaNoLivre.add(cod);
    }

    // Ranking por coerência temática (Task 7): perfil = média dos embeddings das
    // matérias já concluídas; similaridade via RPC match_materias. Só afeta a
    // ORDEM entre optativas já elegíveis pelo filtro de horário acima — nunca filtra.
    const codigosCompletos = [...completed];
    const vetorPerfil = await calcularVetorPerfil(codigosCompletos);
    const similaridades = vetorPerfil ? await buscarSimilaridades(vetorPerfil) : new Map<string, number>();

    const candidatos: CandidatoGrade[] = elegiveis
        .filter((m) => codigosComTurmaNoLivre.has(norm(m.codigo)))
        .map((m) => ({
            codigo: norm(m.codigo),
            nome: m.nome,
            creditos: m.creditos,
            obrigatoria: m.obrigatoria,
            nivel: m.nivel,
        }))
        .sort((a, b) => {
            if (a.obrigatoria !== b.obrigatoria) return a.obrigatoria ? -1 : 1;
            if (a.obrigatoria) return a.nivel - b.nivel;
            return (similaridades.get(b.codigo) ?? 0) - (similaridades.get(a.codigo) ?? 0);
        })
        .slice(0, 6);

    return { candidatos };
}

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
            return a.nivel - b.nivel;
        });

    return { candidatos };
}

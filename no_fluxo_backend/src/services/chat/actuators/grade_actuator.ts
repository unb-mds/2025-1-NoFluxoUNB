/**
 * Atuador de recomendação por horário livre — Fase 2 (extensão) do orquestrador
 * de chat (docs/chatbot-orquestrador.md), spec em
 * docs/superpowers/specs/2026-07-30-recomendacao-horario-livre-design.md.
 *
 * O filtro de horário em si é sempre determinístico (bitmask) — a comparação de
 * máscaras nunca passa pela IA. (Nota: `montarDadosPlano`, chamado por esta função,
 * pode disparar lazy-load de dificuldade via IA para matérias sem `dificuldade_estimada`
 * — efeito colateral herdado, fora do escopo deste filtro.)
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
import { z } from "zod";
import { Agent, run, tool, OutputGuardrailTripwireTriggered } from "@openai/agents";
import type { OutputGuardrail } from "@openai/agents";
import { SupabaseWrapper } from "../../../supabase_wrapper";
import { montarDadosPlano } from "../../../controllers/PlanejamentoController";
import { parseFluxograma } from "../../plano_formatura.service";
import { slotMaskFromHorario } from "../../../utils/horario_slots";
import { createMaritacaModel } from "../model_provider";
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

/**
 * resolveIdUserPorEmail — reimplementado aqui, não reexportado de
 * integralizacao_actuator.ts, seguindo o padrão de duplicação já aceito no
 * restante do pipeline (ver `filtrarPorOfertaAtiva` em optativas_actuator.ts:
 * "reimplementado aqui — não reexportado do Darcy legado"). Mantém este
 * atuador self-contained.
 */
async function resolveIdUserPorEmail(email: string): Promise<string | null> {
    const { data, error } = await SupabaseWrapper.get()
        .from("users")
        .select("id_user")
        .eq("email", email)
        .maybeSingle();
    if (error || !data?.id_user) return null;
    return String(data.id_user);
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

function cosineSimilarity(a: number[], b: number[]): number {
    const dim = Math.min(a.length, b.length);
    let dot = 0;
    let normA = 0;
    let normB = 0;
    for (let i = 0; i < dim; i++) {
        dot += a[i] * b[i];
        normA += a[i] * a[i];
        normB += b[i] * b[i];
    }
    if (normA === 0 || normB === 0) return 0;
    return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

/**
 * codigo_materia -> similaridade de cosseno (-1..1) contra vetorPerfil, calculada em JS
 * só para `codigosCandidatos` — a lista pequena (~6) já filtrada pelo horário livre, NUNCA
 * uma busca no universo inteiro de materias_vetorizadas (~26k linhas). Substitui a antiga
 * `buscarSimilaridades` via RPC `match_materias`: pedir o top-100 global e procurar os
 * candidatos ali dentro era estatisticamente quase sempre 0 (candidatos são uma fração
 * ínfima de 26k linhas), tornando o ranking por afinidade temática um no-op silencioso.
 * Degrada pra Map vazio em qualquer falha — nunca derruba um candidato que já passou pelo
 * filtro de horário, só perde o ranking por afinidade (cai pra ordem neutra).
 */
async function calcularSimilaridadesCandidatos(
    vetorPerfil: number[],
    codigosCandidatos: string[]
): Promise<Map<string, number>> {
    const mapa = new Map<string, number>();
    if (codigosCandidatos.length === 0) return mapa;
    try {
        const { data, error } = await SupabaseWrapper.get()
            .from("materias_vetorizadas")
            .select("codigo_materia, embedding")
            .in("codigo_materia", codigosCandidatos);
        if (error || !data) return mapa;
        for (const item of data as any[]) {
            const cod = norm(String(item.codigo_materia ?? ""));
            const vetor = parseEmbeddingVector(item.embedding);
            if (!cod || !vetor || vetor.length === 0) continue;
            mapa.set(cod, cosineSimilarity(vetorPerfil, vetor));
        }
    } catch {
        // Degrada graciosamente — ranking cai pro neutro, horário livre não é afetado.
    }
    return mapa;
}

export async function recomendarPorHorarioLivre(
    email: string,
    curriculoCompleto: string,
    freeMaskStr: string,
    periodoAtivo: string
): Promise<{ candidatos: CandidatoGrade[] } | { erro: string }> {
    const idUser = await resolveIdUserPorEmail(email);
    if (!idUser) return { erro: "Não encontrei o cadastro deste usuário." };

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

    // Ranking por coerência temática (Task 7 / Fix 1): perfil = média dos embeddings das
    // matérias já concluídas; similaridade calculada em JS (cosseno) só para as optativas
    // candidatas que já passaram no filtro de horário acima — nunca busca no universo
    // inteiro de materias_vetorizadas. Só afeta a ORDEM entre optativas já elegíveis pelo
    // filtro de horário — nunca filtra.
    const codigosCandidatosOptativas = elegiveis
        .filter((m) => !m.obrigatoria && codigosComTurmaNoLivre.has(norm(m.codigo)))
        .map((m) => norm(m.codigo));
    const codigosCompletos = [...completed];
    const vetorPerfil = await calcularVetorPerfil(codigosCompletos);
    const similaridades = vetorPerfil
        ? await calcularSimilaridadesCandidatos(vetorPerfil, codigosCandidatosOptativas)
        : new Map<string, number>();

    // Fix 4: dedupe por código antes do slice — a mesma matéria pode em tese aparecer em
    // dois níveis de materiasMapeadas (ex.: currículos com duplicação de nível); sem isso
    // ela ocuparia duas das seis vagas finais consigo mesma. Mantém a 1ª ocorrência.
    const codigosVistos = new Set<string>();
    const candidatos: CandidatoGrade[] = elegiveis
        .filter((m) => codigosComTurmaNoLivre.has(norm(m.codigo)))
        .filter((m) => {
            const cod = norm(m.codigo);
            if (codigosVistos.has(cod)) return false;
            codigosVistos.add(cod);
            return true;
        })
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

/**
 * Fase 3 — revisor de horário (docs/chatbot-orquestrador.md): guarda os candidatos
 * brutos retornados pela última chamada à tool nesta closure (uma por agente/request —
 * createGradeAgent é sempre chamado de novo por requisição) e rejeita qualquer código
 * citado na tag [MONTAR_GRADE|...] que não esteja entre eles. Como o filtro de horário
 * já é 100% determinístico (bitmask, nunca passa pela IA), qualquer código fora da lista
 * só pode ser alucinação do agente — não uma matéria que "quase" cabe.
 *
 * extrairCodigosDaTag usa a flag global (/g) e varre TODA ocorrência da tag na resposta —
 * uma resposta pode, em teoria, conter mais de um [MONTAR_GRADE|...] e cada uma precisa
 * ser verificada, não só a primeira.
 *
 * Escopo: este guardrail verifica só a resposta do sub-agente AtuadorGrade (o que roda
 * dentro de createGradeAgent/runGradeComRevisao, abaixo). O orquestrador que compõe a
 * resposta final ao usuário (orquestrador_agent.ts, createOrquestradorAgent) não tem
 * outputGuardrails próprios e, em tese, poderia compor uma tag [MONTAR_GRADE|...] com um
 * código não verificado por este revisor. Isso é um limite de escopo conhecido e aceito,
 * não um bug: o montador de grade do frontend faz backtracking sem conflito de horário de
 * qualquer forma, então um código não verificado no pior caso fica sem alocar — nunca gera
 * um conflito real de horário.
 */
function extrairCodigosDaTag(texto: string): string[] {
    const codigos: string[] = [];
    const regex = /\[MONTAR_GRADE\|([^|\]]*)\|?[^\]]*\]/g;
    let m: RegExpExecArray | null;
    while ((m = regex.exec(texto)) !== null) {
        codigos.push(
            ...(m[1] ?? "")
                .split(",")
                .map((c) => c.trim().toUpperCase())
                .filter(Boolean)
        );
    }
    return codigos;
}

function criarRevisorHorario(getUltimosCandidatos: () => CandidatoGrade[] | null): OutputGuardrail {
    return {
        name: "revisor_horario_grade",
        execute: async ({ agentOutput }) => {
            const texto = typeof agentOutput === "string" ? agentOutput : JSON.stringify(agentOutput);
            const codigosCitados = extrairCodigosDaTag(texto);

            // Nada citado (resposta puramente conversacional) — nada pra verificar, aprova.
            // Verificação de citação vem SEMPRE antes da checagem de candidatos: se a
            // resposta citar um código sem a tool ter rodado nesta execução (candidatos
            // ainda null), isso NÃO é "nada a verificar" — é uma citação não verificada,
            // e deve ser tratada como código inválido (mesmo caminho de rejeição abaixo).
            if (codigosCitados.length === 0) {
                return { tripwireTriggered: false, outputInfo: null };
            }

            const candidatos = getUltimosCandidatos();
            const codigosValidos = new Set((candidatos ?? []).map((c) => c.codigo));
            const codigoInvalido = codigosCitados.find((c) => !codigosValidos.has(c));

            if (codigoInvalido) {
                const motivo = candidatos
                    ? `A resposta prioriza ${codigoInvalido}, que não está entre os candidatos que cabem no horário livre.`
                    : `A resposta cita ${codigoInvalido} sem antes ter chamado a tool recomendar_por_horario_livre — nada foi verificado.`;
                return {
                    tripwireTriggered: true,
                    outputInfo: { motivo },
                };
            }
            return { tripwireTriggered: false, outputInfo: null };
        },
    };
}

export function createGradeAgent(
    email: string,
    curriculoCompleto: string,
    freeMaskStr: string,
    periodoAtivo: string
): Agent {
    let ultimosCandidatos: CandidatoGrade[] | null = null;

    const recomendarTool = tool({
        name: "recomendar_por_horario_livre",
        description: "Lista matérias (obrigatórias pendentes e optativas com oferta) cuja turma cabe inteira no horário livre atual do aluno, ordenadas por afinidade com o que ele já cursou.",
        parameters: z.object({}),
        execute: async () => {
            const resultado = await recomendarPorHorarioLivre(email, curriculoCompleto, freeMaskStr, periodoAtivo);
            ultimosCandidatos = "candidatos" in resultado ? resultado.candidatos : [];
            return JSON.stringify(resultado);
        },
    });

    return new Agent({
        name: "AtuadorGrade",
        instructions:
            "Você responde SOMENTE pedidos de preencher horário livre / buraco na grade do Montador de Grade. " +
            "Sempre use a tool recomendar_por_horario_livre antes de responder — nunca cite uma matéria que não veio dela. " +
            "Se a lista de candidatos vier vazia, diga que não achou nada que caiba nesse horário, sem inventar código. " +
            "Se o aluno topar montar/priorizar, confirme em uma frase curta e inclua no final [MONTAR_GRADE|CODIGOS] com os códigos escolhidos. " +
            "Responda em português brasileiro, direto e conciso.",
        model: createMaritacaModel(),
        tools: [recomendarTool],
        outputGuardrails: [criarRevisorHorario(() => ultimosCandidatos)],
    });
}

/**
 * Resposta padrão de escalonamento — nunca inventa nem repassa um código que não
 * sobreviveu ao revisor duas vezes seguidas.
 */
export const RESPOSTA_ESCALONAMENTO_GRADE =
    "Não achei nada certeiro pro seu horário livre agora — dá uma olhada nas optativas manualmente na lista ao lado.";

function motivoDaReprovacaoGrade(erro: OutputGuardrailTripwireTriggered<any>): string {
    return (
        (erro.result.output.outputInfo as { motivo?: string } | null)?.motivo ??
        "a resposta citou algo que não cabe no horário livre"
    );
}

/**
 * Roda o atuador e, se o revisor reprovar a resposta (código fora dos candidatos),
 * reexecuta UMA vez com o motivo da reprovação injetado no prompt. Se a reexecução
 * TAMBÉM for reprovada (reprovou duas vezes seguidas), escalona pra resposta padrão
 * em vez de devolver um código não verificado ou estourar erro pro usuário — nunca
 * tenta uma terceira vez.
 */
export async function runGradeComRevisao(agent: Agent, input: string): Promise<string> {
    try {
        const resultado = await run(agent, input);
        return String(resultado.finalOutput ?? "");
    } catch (erro) {
        if (!(erro instanceof OutputGuardrailTripwireTriggered)) throw erro;

        const motivo = motivoDaReprovacaoGrade(erro);
        try {
            const resultadoCorrigido = await run(
                agent,
                `${input}\n\n[Revisão automática] Sua resposta anterior foi rejeitada: ${motivo}. ` +
                    "Responda de novo, citando só códigos que vieram da tool recomendar_por_horario_livre."
            );
            return String(resultadoCorrigido.finalOutput ?? "");
        } catch (segundoErro) {
            if (!(segundoErro instanceof OutputGuardrailTripwireTriggered)) throw segundoErro;
            return RESPOSTA_ESCALONAMENTO_GRADE;
        }
    }
}

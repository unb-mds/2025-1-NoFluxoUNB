/**
 * Motor 2 — Servico de geracao da cadeia de formatura personalizada.
 *
 * Funcoes puras (sem IO/DB) que recebem as materias faltantes e devolvem
 * um plano semestre a semestre. O controller eh responsavel por buscar
 * as materias faltantes no banco e chamar `gerarPlano`.
 *
 * Spec: docs/motor2.md
 */

import {
    parseExpressaoLogicaFromDb,
    satisfazExpressaoLogica,
    getCodigosFromExpressaoLogica,
    type ExpressaoLogicaRecursiva,
} from "../utils/expressao_logica";
import type {
    MateriaInput,
    MateriaPlano,
    PlanoFormatura,
    PlanoInput,
    PreferenciasPlano,
    SemestrePlano,
} from "../types/planejamento";

// =============================================================
// Constantes do scoring
// =============================================================

const SCORE_OBRIGATORIA = 3;
const SCORE_PESO_DIRETO = 2;
const SCORE_PESO_INDIRETO = 1;
const SCORE_ATRASADA = 2;

// Top 30% dos scores -> critica (alem do criterio de atrasada).
const PERC_CRITICA = 0.3;

// Guard-rail contra loops infinitos no greedy.
const MAX_SEMESTRES = 40;

// =============================================================
// Util interno
// =============================================================

function norm(codigo: string): string {
    return (codigo || "").trim().toUpperCase();
}

function parseExprOrNull(raw: unknown): ExpressaoLogicaRecursiva | null {
    if (raw == null) return null;
    // Aceita: objeto recursivo "puro", string, ou objeto vindo do DB.
    if (typeof raw === "object" && raw !== null && "condicoes" in (raw as object)) {
        return raw as ExpressaoLogicaRecursiva;
    }
    return parseExpressaoLogicaFromDb(raw);
}

function isAtrasada(mat: MateriaInput, semestreAtual: number): boolean {
    // nivel=0 indica optativa (nao tem semestre esperado).
    return mat.nivel > 0 && mat.nivel < semestreAtual;
}

// =============================================================
// 1) Grafo reverso de dependencias
// =============================================================

/**
 * Constroi mapa: codigo -> conjunto de materias (entre as faltantes) que
 * tem `codigo` como pre-requisito direto.
 *
 * Operadores E/OU sao tratados igual aqui — o que importa eh que
 * concluir `codigo` *pode* desbloquear a materia dependente.
 */
export function buildReverseDependencyGraph(
    materias: MateriaInput[]
): Map<string, Set<string>> {
    const graph = new Map<string, Set<string>>();

    // Inicializa entrada para cada materia (mesmo sem dependentes).
    for (const m of materias) {
        graph.set(norm(m.codigo), new Set());
    }

    for (const m of materias) {
        const expr = parseExprOrNull(m.preRequisitos);
        if (!expr) continue;
        const codigosPreReq = getCodigosFromExpressaoLogica(expr).map(norm);
        for (const pr of codigosPreReq) {
            if (!graph.has(pr)) graph.set(pr, new Set());
            graph.get(pr)!.add(norm(m.codigo));
        }
    }

    return graph;
}

// =============================================================
// 2) Dependentes transitivos
// =============================================================

/**
 * Quantidade de materias que `codigo` destrava transitivamente
 * (cadeia completa, sem contar duplicados nem entrar em loop).
 */
export function computeTransitiveDependents(
    codigo: string,
    graph: Map<string, Set<string>>
): number {
    const visitados = new Set<string>();
    const fila: string[] = [];
    const start = norm(codigo);

    const diretos = graph.get(start) ?? new Set<string>();
    for (const d of diretos) fila.push(d);

    while (fila.length > 0) {
        const cur = fila.shift()!;
        if (visitados.has(cur)) continue;
        visitados.add(cur);
        const filhos = graph.get(cur) ?? new Set<string>();
        for (const f of filhos) {
            if (!visitados.has(f) && f !== start) fila.push(f);
        }
    }

    return visitados.size;
}

// =============================================================
// 3) Score
// =============================================================

export function calcularScore(
    materia: MateriaInput,
    desbloqueiaDireto: number,
    desbloqueiaIndireto: number,
    semestreAtual: number
): number {
    let score = 0;
    if (materia.obrigatoria) score += SCORE_OBRIGATORIA;
    score += SCORE_PESO_DIRETO * desbloqueiaDireto;
    score += SCORE_PESO_INDIRETO * desbloqueiaIndireto;
    if (isAtrasada(materia, semestreAtual)) score += SCORE_ATRASADA;
    return score;
}

// =============================================================
// 4) isDesbloqueada
// =============================================================

export function isDesbloqueada(
    materia: MateriaInput,
    completedCodes: Set<string>
): boolean {
    const expr = parseExprOrNull(materia.preRequisitos);
    if (!expr) return true; // sem pre-requisito -> sempre desbloqueada
    // Normaliza completedCodes
    const normCompleted = new Set<string>();
    for (const c of completedCodes) normCompleted.add(norm(c));
    return satisfazExpressaoLogica(expr, normCompleted);
}

// =============================================================
// 5) Distribuicao gulosa por semestres
// =============================================================

interface MateriaComScore {
    materia: MateriaInput;
    score: number;
    desbloqueiaDireto: number;
    desbloqueiaIndireto: number;
}

/**
 * Pre-calcula score / desbloqueios para cada materia faltante.
 * Os valores nao mudam ao longo da distribuicao — sao baseados no
 * grafo original e nao no estado atual de candidatas.
 */
function precomputarScores(
    materias: MateriaInput[],
    semestreAtual: number
): Map<string, MateriaComScore> {
    const graph = buildReverseDependencyGraph(materias);
    const out = new Map<string, MateriaComScore>();
    for (const m of materias) {
        const cod = norm(m.codigo);
        const diretos = (graph.get(cod) ?? new Set()).size;
        const indiretos = Math.max(0, computeTransitiveDependents(cod, graph) - diretos);
        const score = calcularScore(m, diretos, indiretos, semestreAtual);
        out.set(cod, {
            materia: m,
            score,
            desbloqueiaDireto: diretos,
            desbloqueiaIndireto: indiretos,
        });
    }
    return out;
}

/**
 * Distribui as materias faltantes em semestres futuros respeitando:
 *   - limite de creditos
 *   - pre-requisitos (uma materia so entra quando seus pre-req estao
 *     concluidos em semestres anteriores ou no completedCodes inicial)
 *   - prioridade por score desc dentro do conjunto de candidatas
 *
 * O primeiro semestre eh marcado como "recomendado"; os demais
 * como "estimado".
 *
 * `numeroPeriodo` eh o semestre atual do aluno e influencia apenas o
 * calculo do bonus "atrasada" no score.
 */
export function distribuirPorSemestres(
    materias: MateriaInput[],
    completedCodes: Set<string>,
    preferencias: PreferenciasPlano,
    numeroPeriodo: number
): SemestrePlano[] {
    if (materias.length === 0) return [];

    const scores = precomputarScores(materias, numeroPeriodo);

    // Estado mutavel: materias ainda nao alocadas (por codigo).
    const restantes = new Set<string>(materias.map((m) => norm(m.codigo)));
    // Codigos ja "concluidos" no contexto da simulacao (incluindo os ja feitos).
    const cumulados = new Set<string>();
    for (const c of completedCodes) cumulados.add(norm(c));

    const semestres: SemestrePlano[] = [];

    let indiceSemestre = 0;
    while (restantes.size > 0 && indiceSemestre < MAX_SEMESTRES) {
        // 1. Candidatas: materias restantes com pre-req cumpridos pelo `cumulados`.
        const candidatas: MateriaComScore[] = [];
        for (const cod of restantes) {
            const info = scores.get(cod)!;
            if (isDesbloqueada(info.materia, cumulados)) {
                candidatas.push(info);
            }
        }

        // Sem candidatas -> ciclo ou pre-req externo faltando. Aborta.
        if (candidatas.length === 0) break;

        // 2. Ordena por score desc. Tie-breaker: nivel asc (atrasada primeiro),
        //    depois codigo asc (determinismo nos testes).
        candidatas.sort((a, b) => {
            if (b.score !== a.score) return b.score - a.score;
            if (a.materia.nivel !== b.materia.nivel) return a.materia.nivel - b.materia.nivel;
            return a.materia.codigo.localeCompare(b.materia.codigo);
        });

        // 3. Preenche o semestre respeitando limite de creditos.
        const escolhidas: MateriaComScore[] = [];
        let creditosUsados = 0;
        for (const c of candidatas) {
            if (creditosUsados + c.materia.creditos <= preferencias.limiteCreditos) {
                escolhidas.push(c);
                creditosUsados += c.materia.creditos;
            }
        }

        // Edge-case: nenhuma materia coube (todas excedem limite individualmente).
        // Pega a de menor creditos para nao travar.
        if (escolhidas.length === 0) {
            const menor = [...candidatas].sort((a, b) => a.materia.creditos - b.materia.creditos)[0];
            escolhidas.push(menor);
            creditosUsados = menor.materia.creditos;
        }

        // 4. Materializa o SemestrePlano (sem motivo/critica — preenchidos em gerarPlano).
        const materiasPlano: MateriaPlano[] = escolhidas.map((e) => ({
            codigo: norm(e.materia.codigo),
            nome: e.materia.nome,
            creditos: e.materia.creditos,
            critica: false,
            desbloqueiaDireto: e.desbloqueiaDireto,
            desbloqueiaIndireto: e.desbloqueiaIndireto,
            score: e.score,
            motivo: "",
        }));

        semestres.push({
            indice: indiceSemestre,
            tipo: indiceSemestre === 0 ? "recomendado" : "estimado",
            creditos: creditosUsados,
            materias: materiasPlano,
        });

        // 5. Avanca estado: escolhidas saem de restantes e entram em cumulados.
        for (const e of escolhidas) {
            const cod = norm(e.materia.codigo);
            restantes.delete(cod);
            cumulados.add(cod);
        }

        indiceSemestre++;
    }

    return semestres;
}

// =============================================================
// 6) Marcacao de criticas + motivos textuais
// =============================================================

function calcularThresholdCritica(scoresOrdenados: number[]): number {
    if (scoresOrdenados.length === 0) return Number.POSITIVE_INFINITY;
    // Top 30% pelo *valor* — corte no quantil 0.7 (i.e. percentil 70).
    // Para conjuntos pequenos, usa pelo menos o maior score como referencia.
    const sorted = [...scoresOrdenados].sort((a, b) => a - b);
    const idx = Math.floor(sorted.length * (1 - PERC_CRITICA));
    const clamped = Math.min(sorted.length - 1, Math.max(0, idx));
    return sorted[clamped];
}

function montarMotivo(m: MateriaPlano, atrasada: boolean): string {
    const partes: string[] = [];
    if (m.desbloqueiaDireto > 0) {
        const total = m.desbloqueiaDireto + m.desbloqueiaIndireto;
        partes.push(`desbloqueia ${total} materia${total !== 1 ? "s" : ""}`);
    }
    if (atrasada) partes.push("esta atrasada");
    if (partes.length === 0) partes.push("alocada para manter ritmo de formatura");
    return partes.join(" e ");
}

// =============================================================
// 7) gerarPlano (orquestracao)
// =============================================================

export function gerarPlano(input: PlanoInput): PlanoFormatura {
    const materias = input.materiasFaltantes ?? [];
    const completedSet = new Set<string>(input.completedCodes.map(norm));

    const semestres = distribuirPorSemestres(
        materias,
        completedSet,
        input.preferencias,
        input.numeroPeriodo
    );

    // Marca criticas + motivo.
    if (semestres.length > 0) {
        const todosScores: number[] = [];
        for (const s of semestres) for (const m of s.materias) todosScores.push(m.score);
        const threshold = calcularThresholdCritica(todosScores);

        // Para "atrasada" precisamos do nivel — buscar pela materia original.
        const nivelByCodigo = new Map<string, number>();
        for (const m of materias) nivelByCodigo.set(norm(m.codigo), m.nivel);

        for (const s of semestres) {
            for (const m of s.materias) {
                const nivel = nivelByCodigo.get(m.codigo) ?? 0;
                const atrasada = nivel > 0 && nivel < input.numeroPeriodo;
                m.critica = atrasada || m.score >= threshold;
                m.motivo = montarMotivo(m, atrasada);
            }
        }
    }

    // Detecta materias nao alocadas (ciclos, pre-req externo faltando, etc).
    const alocadas = new Set<string>();
    for (const s of semestres) for (const m of s.materias) alocadas.add(m.codigo);
    const naoAlocadas: string[] = [];
    for (const m of materias) {
        const cod = norm(m.codigo);
        if (!alocadas.has(cod)) naoAlocadas.push(cod);
    }
    naoAlocadas.sort();

    return {
        semestresRestantes: semestres.length,
        plano: semestres,
        materiasNaoAlocadas: naoAlocadas,
    };
}

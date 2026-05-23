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
    PlanoFormaturav2,
    OptativaSlot,
    ComplementarSlot,
    CargaIntegralizada,
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
    if (typeof raw === "object" && raw !== null && "condicoes" in (raw as object)) {
        return raw as ExpressaoLogicaRecursiva;
    }
    return parseExpressaoLogicaFromDb(raw);
}

function isAtrasada(mat: MateriaInput, semestreAtual: number): boolean {
    return mat.nivel > 0 && mat.nivel < semestreAtual;
}

/**
 * Converte Créditos em Carga Horária (1 crédito = 15h)
 */
function creditosParaHoras(creditos: number): number {
    return (creditos || 0) * 15;
}

function getHorasSafely(materia: Partial<MateriaInput> & { creditos?: number; carga_horaria?: number }): number {
    if (materia.carga_horaria != null) return materia.carga_horaria;
    return creditosParaHoras(materia.creditos ?? 4);
}

/**
 * Retorna os créditos de uma matéria. Faz fallback usando carga_horaria se necessário.
 */
function getCreditosSafely(materia: Partial<MateriaInput> & { creditos?: number; carga_horaria?: number }): number {
    if (materia.creditos) return materia.creditos;
    if (materia.carga_horaria) return Math.ceil(materia.carga_horaria / 15);
    return 4; // Valor padrão genérico UnB
}

// =============================================================
// 1) Grafo reverso de dependencias
// =============================================================

export function buildReverseDependencyGraph(
    materias: MateriaInput[]
): Map<string, Set<string>> {
    const graph = new Map<string, Set<string>>();

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
    if (!expr) return true;
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

export function distribuirPorSemestres(
    materias: MateriaInput[],
    completedCodes: Set<string>,
    preferencias: PreferenciasPlano,
    numeroPeriodo: number
): SemestrePlano[] {
    if (materias.length === 0) return [];

    const scores = precomputarScores(materias, numeroPeriodo);
    const restantes = new Set<string>(materias.map((m) => norm(m.codigo)));
    const cumulados = new Set<string>();
    for (const c of completedCodes) cumulados.add(norm(c));

    const semestres: SemestrePlano[] = [];
    let indiceSemestre = 0;

    while (restantes.size > 0 && indiceSemestre < MAX_SEMESTRES) {
        const candidatas: MateriaComScore[] = [];
        for (const cod of restantes) {
            const info = scores.get(cod)!;
            if (isDesbloqueada(info.materia, cumulados)) {
                candidatas.push(info);
            }
        }

        if (candidatas.length === 0) break;

        candidatas.sort((a, b) => {
            if (b.score !== a.score) return b.score - a.score;
            if (a.materia.nivel !== b.materia.nivel) return a.materia.nivel - b.materia.nivel;
            return a.materia.codigo.localeCompare(b.materia.codigo);
        });

        const escolhidas: MateriaComScore[] = [];
        let horasUsadas = 0;
        const limiteHoras = Math.min(preferencias.limiteCreditos * 15, 480);

        // B4: Mapa para lookup rápido de matérias por código
        const materiasPorCodigo = new Map<string, MateriaInput>();
        for (const m of materias) {
            materiasPorCodigo.set(norm(m.codigo), m);
        }

        for (const c of candidatas) {
            // Skip if already chosen in this semester
            if (!restantes.has(norm(c.materia.codigo))) continue;

            const horas = getHorasSafely(c.materia);

            // B4: Verificar co-requisitos
            const coReqExpr = parseExprOrNull(c.materia.coRequisitos);
            let coReqCodigos: string[] = [];
            if (coReqExpr) {
                coReqCodigos = getCodigosFromExpressaoLogica(coReqExpr).map(norm);
            }

            // B4: Calcular horas totais necessárias (candidata + todos os co-requisitos)
            let horasNeeded = horas;
            const coReqsDisponiveis: { codigo: string; materia: MateriaInput; horas: number }[] = [];

            for (const coReqCod of coReqCodigos) {
                // Só considerar co-requisitos que ainda estão em restantes
                if (restantes.has(coReqCod)) {
                    const coReqMateria = materiasPorCodigo.get(coReqCod);
                    if (coReqMateria) {
                        const horasCoReq = getHorasSafely(coReqMateria);
                        coReqsDisponiveis.push({ codigo: coReqCod, materia: coReqMateria, horas: horasCoReq });
                        horasNeeded += horasCoReq;
                    }
                }
            }

            // B4: Tentar alocar candidata + todos os co-requisitos juntos
            if (horasUsadas + horasNeeded <= limiteHoras) {
                // Adicionar candidata
                escolhidas.push(c);
                horasUsadas += horas;

                // Adicionar todos os co-requisitos
                for (const coReq of coReqsDisponiveis) {
                    const coReqScore = scores.get(coReq.codigo);
                    if (coReqScore) {
                        escolhidas.push(coReqScore);
                        horasUsadas += coReq.horas;
                    }
                }
            }
        }

        if (escolhidas.length === 0) {
            const menor = [...candidatas].sort((a, b) => getHorasSafely(a.materia) - getHorasSafely(b.materia))[0];
            escolhidas.push(menor);
            horasUsadas = getHorasSafely(menor.materia);
        }

        const materiasPlano: MateriaPlano[] = escolhidas.map((e) => ({
            codigo: norm(e.materia.codigo),
            nome: e.materia.nome,
            creditos: getCreditosSafely(e.materia),
            critica: false,
            desbloqueiaDireto: e.desbloqueiaDireto,
            desbloqueiaIndireto: e.desbloqueiaIndireto,
            score: e.score,
            motivo: "",
        }));

        semestres.push({
            indice: indiceSemestre,
            tipo: indiceSemestre === 0 ? "recomendado" : "estimado",
            creditos: Math.ceil(horasUsadas / 15),
            materias: materiasPlano,
        });

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
// 7) gerarPlano (orquestracao Motor 1 Legado)
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

    if (semestres.length > 0) {
        const todosScores: number[] = [];
        for (const s of semestres) for (const m of s.materias) if ('score' in m) todosScores.push((m as any).score);
        const threshold = calcularThresholdCritica(todosScores);

        const nivelByCodigo = new Map<string, number>();
        for (const m of materias) nivelByCodigo.set(norm(m.codigo), m.nivel);

        for (const s of semestres) {
            for (const m of s.materias as MateriaPlano[]) {
                if (!m.codigo) continue;
                const nivel = nivelByCodigo.get(m.codigo) ?? 0;
                const atrasada = nivel > 0 && nivel < input.numeroPeriodo;
                m.critica = atrasada || m.score >= threshold;
                m.motivo = montarMotivo(m, atrasada);
            }
        }
    }

    const alocadas = new Set<string>();
    for (const s of semestres) for (const m of s.materias) if ('codigo' in m) alocadas.add((m as any).codigo);
    
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

// =============================================================
// 8) Motor 2 v2 — gerarPlanoCompletov2
// =============================================================

interface DisciplinaFluxo {
    codigo: string;
    status?: "APR" | "REP" | "MATR" | null;
    ano_periodo?: string;
    tipo_dado?: string;
    nome?: string;
    creditos?: number;
}

function parseFluxograma(fluxograma_atual_str: string | null | undefined): {
    completed: Set<string>;
    currentSemester: DisciplinaFluxo[];
} {
    const completed = new Set<string>();
    const currentSemester: DisciplinaFluxo[] = [];

    if (!fluxograma_atual_str) {
        return { completed, currentSemester };
    }

    try {
        let fluxogramaData: any;
        if (typeof fluxograma_atual_str === "string") {
            fluxogramaData = JSON.parse(fluxograma_atual_str);
        } else {
            fluxogramaData = fluxograma_atual_str;
        }

        const dadosFluxograma = fluxogramaData.dados_fluxograma;
        if (!Array.isArray(dadosFluxograma)) {
            return { completed, currentSemester };
        }

        for (const semestre of dadosFluxograma) {
            if (!Array.isArray(semestre)) continue;

            for (const disc of semestre) {
                if (!disc || typeof disc !== "object") continue;

                const codigo = norm(disc.codigo);
                if (!codigo) continue;

                const status = disc.status?.toUpperCase();

                if (status === "APR" || status === "CUMP") {
                    completed.add(codigo);
                } else if (status === "MATR") {
                    currentSemester.push({
                        codigo,
                        status: "MATR",
                        ano_periodo: disc.ano_periodo,
                        tipo_dado: disc.tipo_dado,
                        nome: disc.nome,
                        creditos: disc.creditos,
                    });
                }
            }
        }
    } catch (err) {
        console.error("Erro ao parsear fluxograma_atual:", err);
    }

    return { completed, currentSemester };
}

function isEstagioOuTCC(materia: MateriaInput): boolean {
    const nomeLower = (materia.nome || "").toLowerCase();
    return (
        nomeLower.includes("estág") ||
        nomeLower.includes("tcc") ||
        nomeLower.includes("trabalho de conclus") ||
        nomeLower.includes("trabalho de graduação") ||
        nomeLower.includes("projeto final") ||
        nomeLower.includes("monografia")
    );
}

/**
 * Distribui slots de optativa e complementar nos semestres futuros.
 * Trabalha com a matemática convertendo o espaço do semestre para Horas para
 * evitar estourar o limite de créditos do plano.
 */
function distribuirSlots(
    semestres: SemestrePlano[],
    chOptativaFaltante: number,
    chComplementarFaltante: number,
    limiteCreditosMax: number
): {
    semestres: SemestrePlano[];
    optativaAlocada: number;
    complementarAlocado: number;
} {
    let optativaAlocada = 0;
    let complementarAlocado = 0;
    const limiteHorasMax = Math.min(limiteCreditosMax * 15, 480); 

    for (const semestre of semestres) {
        let horasUsadasNoSemestre = creditosParaHoras(semestre.creditos);
        let espacoDisponivelHoras = limiteHorasMax - horasUsadasNoSemestre;

        if (espacoDisponivelHoras <= 0) continue;

        // 1) Aloca slots de Optativas
        if (optativaAlocada < chOptativaFaltante) {
            const chParaAlocar = Math.min(chOptativaFaltante - optativaAlocada, espacoDisponivelHoras);
            if (chParaAlocar > 0) {
                const slot: OptativaSlot = {
                    tipo: "optativa_slot",
                    ch: chParaAlocar,
                    descricao: `Slot de Optativa (~${chParaAlocar}h)`
                };
                (semestre.materias as any[]).push(slot);
                horasUsadasNoSemestre += chParaAlocar;
                semestre.creditos += Math.ceil(chParaAlocar / 15); 
                optativaAlocada += chParaAlocar;
            }
        }

        // 2) Aloca slots de Atividades Complementares
        let espacoRestanteHoras = limiteHorasMax - horasUsadasNoSemestre;
        if (espacoRestanteHoras > 0 && complementarAlocado < chComplementarFaltante) {
            const chParaAlocarComp = Math.min(chComplementarFaltante - complementarAlocado, espacoRestanteHoras);
            if (chParaAlocarComp > 0) {
                const slot: ComplementarSlot = {
                    tipo: "complementar_slot",
                    ch: chParaAlocarComp,
                    descricao: `Atividades Complementares (~${chParaAlocarComp}h)`
                };
                (semestre.materias as any[]).push(slot);
                semestre.creditos += Math.ceil(chParaAlocarComp / 15);
                complementarAlocado += chParaAlocarComp;
            }
        }
    }

    return { semestres, optativaAlocada, complementarAlocado };
}

function distribuirObrigatorias(
    obrigatorias: MateriaInput[],
    completedCodes: Set<string>,
    preferencias: PreferenciasPlano,
    numeroPeriodo: number
): {
    semestres: SemestrePlano[];
    naoAlocadas: string[];
} {
    const regular = obrigatorias.filter((m) => !isEstagioOuTCC(m));
    const estagioTCC = obrigatorias.filter((m) => isEstagioOuTCC(m));

    let semestres = distribuirPorSemestres(
        regular,
        completedCodes,
        preferencias,
        numeroPeriodo
    );

    // Se há estágio/TCC mas nenhum semestre foi criado, criar semestre vazio receptor
    if (estagioTCC.length > 0 && semestres.length === 0) {
        semestres.push({
            indice: 0,
            tipo: "estimado",
            creditos: 0,
            materias: [],
        });
    }

    // Ordenar estágio/TCC por nome para garantir TCC 1 antes de TCC 2
    const estagioTCCOrdenado = [...estagioTCC].sort((a, b) =>
        (a.nome || "").localeCompare(b.nome || "")
    );

    const estagioTCCRestantes = new Set<string>(
        estagioTCCOrdenado.map((m) => norm(m.codigo))
    );
    const cumulados = new Set<string>(completedCodes);

    for (const s of semestres) {
        for (const m of s.materias) {
            if (typeof m === "object" && "codigo" in m) {
                cumulados.add(norm((m as any).codigo));
            }
        }
    }

    // Novo loop de alocação com garantia de ordem e posicionamento
    for (const materia of estagioTCCOrdenado) {
        const cod = norm(materia.codigo);

        if (!estagioTCCRestantes.has(cod)) continue;
        if (!isDesbloqueada(materia, cumulados)) continue;

        // Determinar qual semestre usar:
        // - Se é o ÚLTIMO item: sempre no semestre final
        // - Senão: nos últimos 3 semestres (como era antes)
        const isLast = estagioTCCOrdenado.indexOf(materia) === estagioTCCOrdenado.length - 1;
        const targetIdx = isLast
            ? semestres.length - 1
            : Math.max(0, semestres.length - 3);

        // Tentar alocar do targetIdx até o final
        for (let i = targetIdx; i < semestres.length; i++) {
            const mPlano: MateriaPlano = {
                codigo: cod,
                nome: materia.nome,
                creditos: getCreditosSafely(materia),
                critica: true,
                desbloqueiaDireto: 0,
                desbloqueiaIndireto: 0,
                score: 100,
                motivo: "obrigatória, deve estar ao final do curso",
            };

            (semestres[i].materias as any[]).push(mPlano);
            semestres[i].creditos += getCreditosSafely(materia);
            estagioTCCRestantes.delete(cod);
            cumulados.add(cod);
            break;  // Alocado, sair do loop
        }
    }

    const naoAlocadas = Array.from(estagioTCCRestantes).sort();
    return { semestres, naoAlocadas };
}

export function gerarPlanoCompletov2(
    idUser: string,
    idCurso: string,
    semestreAtual: number,
    cargaHorariaIntegralizada: CargaIntegralizada,
    exigidaMatriz: CargaIntegralizada,
    fluxogramaAtualJson: string | null | undefined,
    materias: MateriaInput[],
    preferencias?: PreferenciasPlano
): PlanoFormaturav2 {
    
    const prefs: PreferenciasPlano = preferencias ?? {
        limiteCreditos: 24, 
        objetivo: "equilibrado",
        trabalha: false,
    };

    const { completed, currentSemester } = parseFluxograma(fluxogramaAtualJson);

    // Mapeamento preciso da Carga Horária das disciplinas MATR 
    const horasSemestreAtual = {
        obrigatoria: 0,
        optativa: 0,
        complementar: 0,
    };

    for (const m of currentSemester) {
        const matInfo = materias.find(mat => norm(mat.codigo) === norm(m.codigo));
        const chMateria = matInfo ? getHorasSafely(matInfo) : creditosParaHoras(m.creditos ?? 4);

        if (matInfo?.obrigatoria) {
            horasSemestreAtual.obrigatoria += chMateria;
        } else {
            horasSemestreAtual.optativa += chMateria;
        }
    }

    // Calcula CH faltante real = Exigida - Feita - Em Curso
    const chFaltante = {
        total: Math.max(0, exigidaMatriz.total - cargaHorariaIntegralizada.total),
        obrigatoria: Math.max(0, exigidaMatriz.obrigatoria - cargaHorariaIntegralizada.obrigatoria),
        optativa: Math.max(0, exigidaMatriz.optativa - cargaHorariaIntegralizada.optativa - horasSemestreAtual.optativa),
        complementar: Math.max(0, exigidaMatriz.complementar - cargaHorariaIntegralizada.complementar)
    };

    const materiasFaltantes = materias.filter((m) => !completed.has(norm(m.codigo)));

    const obrigatorias = materiasFaltantes.filter((m) => m.obrigatoria);

    const { semestres, naoAlocadas } = distribuirObrigatorias(
        obrigatorias,
        completed,
        prefs,
        semestreAtual
    );

    const { semestres: semestresComSlots, optativaAlocada, complementarAlocado } = distribuirSlots(
        semestres,
        chFaltante.optativa,
        chFaltante.complementar,
        prefs.limiteCreditos
    );

    const chOptativaRestante = Math.max(0, chFaltante.optativa - optativaAlocada);
    const chComplementarRestante = Math.max(0, chFaltante.complementar - complementarAlocado);

    // Calcula quantas obrigatórias conseguimos alocar (CH em horas)
    let chObrigatoriaAlocada = 0;
    for(const sem of semestresComSlots) {
        for(const m of sem.materias) {
            if('codigo' in m && m.codigo) {
                const matInfo = materias.find(x => norm(x.codigo) === norm(m.codigo));
                if(matInfo?.obrigatoria) {
                    chObrigatoriaAlocada += matInfo.carga_horaria ?? creditosParaHoras(getCreditosSafely(matInfo));
                }
            }
        }
    }

    const resultado: PlanoFormaturav2 = {
        semestreAtual: currentSemester.length > 0 ? {
            tipo: "em_curso",
            materias: currentSemester.map((m) => ({
                codigo: m.codigo,
                nome: m.nome || "Disciplina em Curso",
                creditos: m.creditos || 0,
                status: "MATR",
            })),
        } : undefined,
        semestresRestantes: semestresComSlots.length,
        formaturaEstimada: undefined,
        plano: semestresComSlots,
        materiasNaoAlocadas: naoAlocadas,
        chObrigatoriaFaltante: Math.max(0, chFaltante.obrigatoria - chObrigatoriaAlocada),
        chOptativaFaltante: chOptativaRestante,
        chComplementarFaltante: chComplementarRestante,
    };

    return resultado;
}
/**
 * Tipos para Motor 2 — Cadeia de formatura personalizada.
 *
 * O Motor 2 gera uma sequencia de semestres futuros com as materias
 * recomendadas para o aluno se formar no menor tempo possivel, dadas:
 *   - materias ja concluidas
 *   - grafo de pre-requisitos / co-requisitos
 *   - preferencias do aluno (limite de creditos, objetivo, se trabalha)
 *
 * Spec completa: docs/motor2.md
 */

/** Objetivo do aluno — afeta priorizacao na distribuicao por semestres. */
export type ObjetivoPlano = "velocidade" | "equilibrado";

/** Tipo do semestre na saida do plano. */
export type TipoSemestre = "recomendado" | "estimado";

/**
 * Restricoes opcionais impostas pelo aluno no planejamento.
 * Codigos sempre normalizados (trim + uppercase) antes do uso.
 */
export interface RestricoesPlano {
    /** Codigos que NAO podem entrar no proximo semestre (indice 0 do plano). */
    adiar: string[];
    /** Codigos forcados para o semestre mais cedo possivel (respeitando pre-requisitos). */
    priorizar: string[];
}

/**
 * Preferencias do aluno (coletadas no onboarding e persistidas em
 * dados_users.preferencias_plano).
 */
export interface PreferenciasPlano {
    /** Limite de creditos por semestre (16 / 24 / 32 — ou outro valor inteiro). */
    limiteCreditos: number;
    /** Objetivo: "velocidade" = formar o mais rapido; "equilibrado" = carga balanceada. */
    objetivo: ObjetivoPlano;
    /** Se o aluno trabalha/estagia (impacta carga sugerida). */
    trabalha: boolean;
    /** Restricoes de alocacao impostas pelo aluno. Opcional — ausente = sem restricoes. */
    restricoes?: RestricoesPlano;
}

/**
 * Materia de entrada para o algoritmo. Representa uma materia faltante
 * (ainda nao concluida) que candidata a entrar no plano.
 *
 * As estruturas seguem o formato ja usado em outros pontos do backend:
 * codigo no padrao "DEP0000" e expressao_logica em formato recursivo.
 */
export interface MateriaInput {
    /** Codigo da materia (ex: "CIC0110"). */
    codigo: string;
    /** Nome para exibicao. */
    nome: string;
    /** Creditos (carga horaria / 15, geralmente). */
    creditos: number;
    /** Semestre esperado no fluxo padrao (materias_por_curso.nivel). 0 = optativa. */
    nivel: number;
    /** Se a materia eh obrigatoria (uso legado, prefira tipo_natureza). */
    obrigatoria: boolean;
    
    // === NOVOS CAMPOS ADICIONADOS PARA SUPORTE REAL DO BANCO (UNB) ===
    /** Natureza da matéria extraída de materias_por_curso (0 = Obrigatória). */
    tipo_natureza?: number;
    /** Carga horária total da matéria em horas (ex: 60) */
    carga_horaria?: number;

    /** Codigos diretos dos pre-requisitos (suporta AND/OR via expressao_logica). */
    preRequisitos?: unknown;
    /** Codigos diretos dos co-requisitos. */
    coRequisitos?: unknown;
}

/**
 * Entrada do endpoint POST /planejamento/gerar-plano.
 *
 * Nao depende de id_user — o caller pode chamar com qualquer combinacao
 * de curriculo + completedCodes. Isso permite recomputar planos sem
 * tocar no banco (preview de impacto, etc).
 */
export interface PlanoInput {
    /**
     * Curriculo completo (ex: "8117/-2 - 2018.2"). Usado para resolver a
     * matriz / materias obrigatorias e pre-requisitos.
     */
    curriculoCompleto: string;
    /** Codigos de materias ja concluidas pelo aluno. */
    completedCodes: string[];
    /** Numero do semestre atual do aluno (1..N), usado para detectar materias atrasadas. */
    numeroPeriodo: number;
    /** Preferencias usadas no algoritmo. */
    preferencias: PreferenciasPlano;
    /**
     * Lista opcional de materias faltantes — se nao fornecida, o controller
     * resolve via DB. Util para testes unitarios e callers que ja tem a lista.
     */
    materiasFaltantes?: MateriaInput[];
}

/** Materia ja distribuida num semestre do plano. */
export interface MateriaPlano {
    /** Codigo da materia. */
    codigo: string;
    /** Nome para exibicao. */
    nome: string;
    /** Creditos. */
    creditos: number;
    /** Materia critica (score alto ou atrasada). Nunca removida em carga reduzida. */
    critica: boolean;
    /** Quantidade de materias que esta destrava diretamente (pre-req de 1 nivel). */
    desbloqueiaDireto: number;
    /** Quantidade total de materias que esta destrava transitivamente (cadeia completa). */
    desbloqueiaIndireto: number;
    /** Score calculado (debug / ordenacao). */
    score: number;
    /** Motivo textual da recomendacao (ex: "desbloqueia 3 materias e esta atrasada"). */
    motivo: string;
}

/** Slot generico para optativas (nao especifica materia). */
export interface OptativaSlot {
    tipo: "optativa_slot";
    ch: number;
    descricao: string;
}

/** Slot generico para complementares. */
export interface ComplementarSlot {
    tipo: "complementar_slot";
    ch: number;
    descricao: string;
}

/** Um semestre do plano (proximo = recomendado; demais = estimado). */
export interface SemestrePlano {
    /** Rotulo do semestre (ex: "2025.2"). Pode ser opcional se o caller nao quiser calcular datas. */
    semestre?: string;
    /** Indice (0-based) do semestre dentro do plano. */
    indice: number;
    /** Tipo: o proximo semestre eh "recomendado"; os demais sao "estimado". */
    tipo: TipoSemestre;
    /** Soma de creditos do semestre. */
    creditos: number;
    /**
     * INTERNO: Valor exato em horas para evitar arredondamento duplo.
     * Evita perda de ~3-14h por semestre causada por conversão horas→creditos→horas.
     * Preenchido em distribuirPorSemestres; consumido em distribuirSlots.
     */
    _horasInternas?: number;
    /** Materias daquele semestre. Agora aceita Slots Genéricos também! */
    materias: (MateriaPlano | OptativaSlot | ComplementarSlot)[];
}

/** Materia em curso (status MATR no fluxograma_atual). */
export interface MateriaSemestreAtual {
    codigo: string;
    nome?: string;
    creditos: number;
    status: "MATR";
}

/** CH integralizada por tipo. */
export interface CargaIntegralizada {
    total: number;
    obrigatoria: number;
    optativa: number;
    complementar: number;
}

/** Saida completa do Motor 2 v2 (com semestre atual, slots genericos). */
export interface PlanoFormaturav2 {
    /** Semestre em andamento (materias com status MATR). */
    semestreAtual?: {
        tipo: "em_curso";
        materias: MateriaSemestreAtual[];
    };
    /** Numero de semestres futuros estimados ate a formatura. */
    semestresRestantes: number;
    /**
     * Rotulo do semestre estimado de formatura (ex: "2027.1"). Opcional —
     * algumas configuracoes nao calculam datas absolutas.
     */
    formaturaEstimada?: string;
    /** Plano semestre a semestre (futuro, apos semestre atual). */
    plano: SemestrePlano[];
    /** Materias que nao foram alocadas (ciclos, pre-req externo, etc). */
    materiasNaoAlocadas: string[];
    /** CH faltante para obrigatorias restantes. (Sem acento) */
    chObrigatoriaFaltante: number;
    /** CH faltante para optativas. */
    chOptativaFaltante: number;
    /** CH faltante para complementares. */
    chComplementarFaltante: number;
}

/** Saida completa do Motor 2 (versao anterior para compatibilidade). */
export interface PlanoFormatura {
    /** Numero de semestres futuros estimados ate a formatura. */
    semestresRestantes: number;
    /**
     * Rotulo do semestre estimado de formatura (ex: "2027.1"). Opcional —
     * algumas configuracoes nao calculam datas absolutas.
     */
    formaturaEstimada?: string;
    /** Plano semestre a semestre. */
    plano: SemestrePlano[];
    /** Materias que nao foram alocadas (degree audit incompleto, ciclos, etc). */
    materiasNaoAlocadas: string[];
}
/**
 * Frontend types for Motor 2 — Plano de Formatura.
 * Mirrors the backend response shape from POST /planejamento/gerar-plano.
 */

// ─── Restrições de alocação ──────────────────────────────────────────────────

export interface RestricoesPlano {
	/** Códigos que não entram no próximo semestre. */
	adiar: string[];
	/** Códigos priorizados para entrar no semestre mais cedo. */
	priorizar: string[];
}

// ─── Mensagens de chat ───────────────────────────────────────────────────────

export type PlannerChatRole = 'user' | 'assistant';

export interface PlannerChatMessage {
	role: PlannerChatRole;
	content: string;
}

export interface PlannerChatResponse {
	reply: string;
	plano?: PlanoFormaturav2;
	restricoes: RestricoesPlano;
}

// ─── Preferências do usuário (onboarding) ───────────────────────────────────

export type ObjetivoPlano = 'velocidade' | 'equilibrio';

export interface PreferenciasPlano {
	/** Limite de créditos por semestre — slider de 8 a 32 (valor em créditos). */
	limiteCreditos: number;
	/** Objetivo de formatura: velocidade máxima ou equilíbrio. */
	objetivo: ObjetivoPlano;
	/** Indica se o aluno trabalha ou estagia. */
	trabalha: boolean;
	/** Indica se o onboarding já foi concluído pelo aluno. */
	onboardingConcluido: boolean;
}

export const DEFAULT_PREFERENCIAS: PreferenciasPlano = {
	limiteCreditos: 24,
	objetivo: 'equilibrio',
	trabalha: false,
	onboardingConcluido: false
};

// ─── Matéria no plano (item do semestre) ─────────────────────────────────────

export type TipoMateriaPlano = 'recomendado' | 'estimado' | 'critico';

export interface MateriaPlano {
	/** Código da disciplina (ex: "CIC0110"). */
	codigo: string;
	/** Nome completo da disciplina. */
	nome: string;
	/** Carga horária em créditos. */
	creditos: number;
	/** Indica se a matéria é crítica (atrasa a formatura se não cursada). */
	critica: boolean;
	/** Quantidade de matérias desbloqueadas diretamente por esta. */
	desbloqueia_direto: number;
	/** Quantidade de matérias desbloqueadas indiretamente (cadeia completa). */
	desbloqueia_indireto: number;
	/** Motivo pelo qual a matéria está neste semestre. */
	motivo: string;
	/** Dificuldade estimada pela IA (1 a 10). */
	dificuldadeEstimada?: number;
	/** Justificativa da IA para a dificuldade calculada. */
	motivoDificuldade?: string;
}

// ─── Slots genéricos para créditos ────────────────────────────────────────────

export interface OptativaSlot {
	tipo: 'optativa_slot';
	ch: number;
	descricao: string;
}

export interface ComplementarSlot {
	tipo: 'complementar_slot';
	ch: number;
	descricao: string;
}

// ─── Semestre no plano ────────────────────────────────────────────────────────

export type TipoSemestre = 'recomendado' | 'estimado' | 'em_curso';

export type ItemSemestre = MateriaPlano | OptativaSlot | ComplementarSlot;

export interface SemestrePlano {
	/** Identificador do semestre (ex: "2025.2"). */
	semestre?: string;
	/** Índice 0-based do semestre dentro do plano. */
	indice: number;
	/** Tipo: "em_curso" (semestre atual), "recomendado" (próximo), ou "estimado" (futuros). */
	tipo: TipoSemestre;
	/** Total de créditos neste semestre. */
	creditos: number;
	/**
	 * INTERNO: Valor exato em horas para evitar arredondamento duplo.
	 * Evita perda de ~3-14h por semestre causada por conversão horas→creditos→horas.
	 * Preenchido pelo backend em distribuirPorSemestres; consumido em distribuirSlots.
	 */
	_horasInternas?: number;
	/** Lista de matérias planejadas ou slots genéricos para este semestre. */
	materias: ItemSemestre[];
}

// ─── Matéria em curso (semestre atual) ────────────────────────────────────────

export interface MateriaSemestreAtual {
	/** Código da disciplina. */
	codigo: string;
	/** Nome da disciplina (opcional). */
	nome?: string;
	/** Créditos. */
	creditos: number;
	/** Status fixo. */
	status: 'MATR';
}

// ─── Plano de formatura completo ──────────────────────────────────────────────

/**
 * Legacy PlanoFormatura v1 interface (snake_case fields).
 * Kept for backwards compatibility.
 */
export interface PlanoFormaturav1 {
	/** Número de semestres restantes até a formatura. */
	semestres_restantes: number;
	/** Semestre estimado de formatura (ex: "2027.1"). */
	formatura_estimada: string;
	/** Sequência de semestres com matérias planejadas. */
	plano: SemestrePlano[];
}

/**
 * PlanoFormatura v2 interface (camelCase fields).
 * Matches the backend PlanoFormaturav2 response from Motor 2.
 */
export interface PlanoFormaturav2 {
	/** Número de semestres restantes até a formatura. */
	semestresRestantes: number;
	/** Semestre estimado de formatura (ex: "2027.1"). */
	formaturaEstimada?: string;
	/** Semestre atual com matérias em curso (opcional). */
	semestreAtual?: {
		tipo: 'em_curso';
		materias: MateriaSemestreAtual[];
	};
	/** Sequência de semestres com matérias planejadas. */
	plano: SemestrePlano[];
	/** Matérias não alocadas no plano. */
	materiasNaoAlocadas: string[];
	/** Créditos obrigatórios faltando. */
	chObrigatoriaFaltante: number;
	/** Créditos optativos faltando. */
	chOptativaFaltante: number;
	/** Créditos complementares faltando. */
	chComplementarFaltante: number;
}

/**
 * Tipo compatível com ambas as versões.
 */
export type PlanoFormatura = PlanoFormaturav1 | PlanoFormaturav2;

// ─── Utilitários ─────────────────────────────────────────────────────────────

/**
 * Dado o semestre atual do aluno e a quantidade de semestres restantes,
 * computa o semestre estimado de formatura no formato "AAAA.P".
 *
 * Exemplo: semestreAtual=3, semestresRestantes=5, anoBase=2025, periodo=2
 * → avança 5 semestres a partir de 2025.2 → 2028.1
 */
export function computeFormaturaEstimada(
	semestresRestantes: number,
	anoBase: number = new Date().getFullYear(),
	periodoBase: 1 | 2 = (new Date().getMonth() < 7 ? 1 : 2) as 1 | 2
): string {
	if (semestresRestantes <= 0) return `${anoBase}.${periodoBase}`;

	let ano = anoBase;
	let periodo = periodoBase;

	for (let i = 0; i < semestresRestantes; i++) {
		if (periodo === 1) {
			periodo = 2;
		} else {
			periodo = 1;
			ano += 1;
		}
	}

	return `${ano}.${periodo}`;
}

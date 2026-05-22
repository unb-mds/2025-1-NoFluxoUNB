/**
 * Frontend types for Motor 2 — Plano de Formatura.
 * Mirrors the backend response shape from POST /planejamento/gerar-plano.
 */

// ─── Preferências do usuário (onboarding) ───────────────────────────────────

export type ObjetivoPlano = 'velocidade' | 'equilibrio';

export interface PreferenciasPlano {
	/** Limite de créditos por semestre escolhido pelo aluno. */
	limiteCreditos: 16 | 24 | 32;
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
}

// ─── Semestre no plano ────────────────────────────────────────────────────────

export type TipoSemestre = 'recomendado' | 'estimado';

export interface SemestrePlano {
	/** Identificador do semestre (ex: "2025.2"). */
	semestre: string;
	/** Tipo: "recomendado" (próximo semestre) ou "estimado" (futuros). */
	tipo: TipoSemestre;
	/** Total de créditos neste semestre. */
	creditos: number;
	/** Lista de matérias planejadas para este semestre. */
	materias: MateriaPlano[];
}

// ─── Plano de formatura completo ──────────────────────────────────────────────

export interface PlanoFormatura {
	/** Número de semestres restantes até a formatura. */
	semestres_restantes: number;
	/** Semestre estimado de formatura (ex: "2027.1"). */
	formatura_estimada: string;
	/** Sequência de semestres com matérias planejadas. */
	plano: SemestrePlano[];
}

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

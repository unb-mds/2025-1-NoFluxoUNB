export interface DashboardOverview {
	total_users: number;
	com_historico: number;
	com_fluxograma: number;
	tickets_abertos: number;
	novos_users_30d: number;
	taxa_ativacao: number;
}

export interface UserGrowthPoint {
	bucket: string;
	novos: number;
	acumulado: number;
}

export interface TopCurso {
	curso: string;
	usuarios: number;
}

export interface TicketMetrics {
	total: number;
	por_status: Record<string, number>;
	por_categoria: Record<string, number>;
	tempo_medio_horas: number;
}

export type GrowthBucket = 'day' | 'week' | 'month';

export interface AiModelCost {
	requisicoes: number;
	tokens: number;
	custo: number;
}

export interface AiCostDay {
	dia: string;
	custo: number;
	requisicoes: number;
}

export interface AiCostMetrics {
	moeda: string;
	total_requisicoes: number;
	total_tokens: number;
	custo_total: number;
	tokens_medios_por_req: number;
	por_modelo: Record<string, AiModelCost>;
	por_dia: AiCostDay[];
	precos_nao_configurados: boolean;
}

export interface TurmaConcorrida {
	codigo: string;
	nome: string;
	ofertadas: number;
	ocupadas: number;
	ocupacao: number;
}

export interface TurmasDemanda {
	periodo: string;
	periodos: string[];
	vagas_ofertadas: number;
	vagas_ocupadas: number;
	vagas_sobrando: number;
	taxa_ocupacao: number;
	top_concorridas: TurmaConcorrida[];
}

export interface ScrapingHealth {
	turmas_atualizado_em: string | null;
	turmas_mais_antigo_em: string | null;
	materias_total: number;
	materias_sem_ementa: number;
	materias_sem_ementa_pct: number;
	cursos_sem_matriz: number;
}

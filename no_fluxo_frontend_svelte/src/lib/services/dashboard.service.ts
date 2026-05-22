import { createSupabaseBrowserClient } from '$lib/supabase/client';
import type {
	AiCostMetrics,
	DashboardOverview,
	GrowthBucket,
	ScrapingHealth,
	TicketMetrics,
	TopCurso,
	TurmasDemanda,
	UserGrowthPoint
} from '$lib/types/dashboard';

export class DashboardService {
	private supabase = createSupabaseBrowserClient();

	async getOverview(): Promise<DashboardOverview> {
		const { data, error } = await this.supabase.rpc('get_dashboard_overview');
		if (error) throw new Error(error.message);
		return data as DashboardOverview;
	}

	async getUserGrowth(days = 30, bucket: GrowthBucket = 'day'): Promise<UserGrowthPoint[]> {
		const { data, error } = await this.supabase.rpc('get_user_growth', {
			p_days: days,
			p_bucket: bucket
		});
		if (error) throw new Error(error.message);
		return (data ?? []) as UserGrowthPoint[];
	}

	async getTopCursos(limit = 10): Promise<TopCurso[]> {
		const { data, error } = await this.supabase.rpc('get_top_cursos', { p_limit: limit });
		if (error) throw new Error(error.message);
		return (data ?? []) as TopCurso[];
	}

	async getTicketMetrics(): Promise<TicketMetrics> {
		const { data, error } = await this.supabase.rpc('get_ticket_metrics');
		if (error) throw new Error(error.message);
		return data as TicketMetrics;
	}

	async getAiCostMetrics(days = 30): Promise<AiCostMetrics> {
		const { data, error } = await this.supabase.rpc('get_ai_cost_metrics', { p_days: days });
		if (error) throw new Error(error.message);
		return data as AiCostMetrics;
	}

	async getTurmasDemanda(periodo: string | null = null): Promise<TurmasDemanda> {
		const { data, error } = await this.supabase.rpc('get_turmas_demanda', {
			p_periodo: periodo
		});
		if (error) throw new Error(error.message);
		return data as TurmasDemanda;
	}

	async getScrapingHealth(): Promise<ScrapingHealth> {
		const { data, error } = await this.supabase.rpc('get_scraping_health');
		if (error) throw new Error(error.message);
		return data as ScrapingHealth;
	}
}

export const dashboardService = new DashboardService();

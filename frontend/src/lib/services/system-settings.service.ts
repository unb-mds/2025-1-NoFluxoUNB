import { createSupabaseBrowserClient } from '$lib/supabase/client';

export type ScrapingTurmasModo = 'auto' | 'on' | 'off';

/** Cadência resultante: o que o cron do GitHub Actions vai de fato fazer. */
export type ScrapingTurmasCadencia = 'rapida' | 'diaria' | 'nenhuma';

/**
 * Decisão efetiva do scraping de turmas, como devolvida pela RPC
 * `scraping_turmas_decisao` — o modo configurado cruzado com a fase do
 * calendário acadêmico. Mostrar só o modo esconderia o que "auto" faz hoje.
 */
export interface ScrapingTurmasStatus {
	/** Período letivo vigente segundo `calendario_academico` (ex.: "2026.2"). */
	periodo: string;
	fase: 'pre_matricula' | 'matricula' | 'letivo' | 'recesso' | 'desconhecido';
	/** Datas ISO do período. Nulas quando o calendário não cobre hoje. */
	data_inicio: string | null;
	data_fim: string | null;
	/** Teto para inclusão de disciplina: 25% do semestre (Res. CEG 0003/2021). */
	limite_matricula_25pct: string | null;
	modo: ScrapingTurmasModo;
	/** Só no modo 'on': data_fim do período, depois da qual volta pro automático. */
	ativo_ate: string | null;
	cadencia: ScrapingTurmasCadencia;
}

export class SystemSettingsService {
	private supabase = createSupabaseBrowserClient();

	async getSetting<T = unknown>(key: string): Promise<T> {
		const { data, error } = await this.supabase.rpc('get_system_setting', { p_key: key });
		if (error) throw new Error(error.message);
		return data as T;
	}

	async setSetting<T = unknown>(key: string, value: T): Promise<T> {
		const { data, error } = await this.supabase.rpc('set_system_setting', {
			p_key: key,
			p_value: value
		});
		if (error) throw new Error(error.message);
		return data as T;
	}

	/**
	 * Lê a decisão efetiva (modo + fase do calendário + cadência resultante).
	 * Vai na RPC em vez de `get_system_setting` porque o registro sozinho diria
	 * só "auto", sem revelar o que auto está fazendo hoje.
	 */
	async getScrapingTurmasStatus(): Promise<ScrapingTurmasStatus> {
		const { data, error } = await this.supabase.rpc('scraping_turmas_decisao');
		if (error) throw new Error(error.message);
		// A RPC devolve TABLE -> PostgREST responde com um array de uma linha.
		const row = (Array.isArray(data) ? data[0] : data) as ScrapingTurmasStatus | undefined;
		if (!row) throw new Error('scraping_turmas_decisao não devolveu nenhuma linha.');
		return row;
	}

	/**
	 * Troca o modo. Em 'on', o banco resolve sozinho o `ativo_ate` a partir do
	 * calendário — o frontend nunca calcula data de período.
	 */
	async setScrapingTurmasModo(modo: ScrapingTurmasModo): Promise<ScrapingTurmasStatus> {
		const { data, error } = await this.supabase.rpc('set_scraping_turmas_modo', {
			p_modo: modo
		});
		if (error) throw new Error(error.message);
		const row = (Array.isArray(data) ? data[0] : data) as ScrapingTurmasStatus | undefined;
		if (!row) throw new Error('set_scraping_turmas_modo não devolveu nenhuma linha.');
		return row;
	}
}

export const systemSettingsService = new SystemSettingsService();

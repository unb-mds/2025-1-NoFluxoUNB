import { createSupabaseBrowserClient } from '$lib/supabase/client';

export interface ScrapingTurmasRapidoValue {
	enabled: boolean;
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

	async getScrapingTurmasRapido(): Promise<boolean> {
		const value = await this.getSetting<ScrapingTurmasRapidoValue>('scraping_turmas_rapido');
		return Boolean(value?.enabled);
	}

	async setScrapingTurmasRapido(enabled: boolean): Promise<void> {
		await this.setSetting('scraping_turmas_rapido', { enabled });
	}
}

export const systemSettingsService = new SystemSettingsService();

import { createSupabaseBrowserClient } from '$lib/supabase/client';
import type { Notificacao, VagaAssinatura } from '$lib/types/notificacao';

export class VagaNotificacaoService {
	private supabase = createSupabaseBrowserClient();

	async seguirMateria(
		idMateria: number,
		turma: string | null,
		anoPeriodo: string
	): Promise<VagaAssinatura> {
		const { data, error } = await this.supabase.rpc('seguir_materia', {
			p_id_materia: idMateria,
			p_turma: turma,
			p_ano_periodo: anoPeriodo
		});
		if (error) throw new Error(error.message);
		return data as VagaAssinatura;
	}

	async deixarDeSeguir(idAssinatura: number): Promise<void> {
		const { error } = await this.supabase.rpc('deixar_de_seguir_materia', {
			p_id_assinatura: idAssinatura
		});
		if (error) throw new Error(error.message);
	}

	async listarMinhasAssinaturas(): Promise<VagaAssinatura[]> {
		const { data, error } = await this.supabase.rpc('listar_minhas_assinaturas');
		if (error) throw new Error(error.message);
		return (data ?? []) as VagaAssinatura[];
	}

	async listarNotificacoes(
		limit = 30,
		somenteNaoLidas = false
	): Promise<{ items: Notificacao[]; totalNaoLidas: number }> {
		const { data, error } = await this.supabase.rpc('listar_notificacoes', {
			p_limit: limit,
			p_somente_nao_lidas: somenteNaoLidas
		});
		if (error) throw new Error(error.message);
		const result = (data ?? {}) as { items?: Notificacao[]; total_nao_lidas?: number };
		return {
			items: result.items ?? [],
			totalNaoLidas: result.total_nao_lidas ?? 0
		};
	}

	async marcarComoLida(idNotificacao?: number): Promise<void> {
		const { error } = await this.supabase.rpc('marcar_notificacao_lida', {
			p_id_notificacao: idNotificacao ?? null
		});
		if (error) throw new Error(error.message);
	}
}

export const vagaNotificacaoService = new VagaNotificacaoService();

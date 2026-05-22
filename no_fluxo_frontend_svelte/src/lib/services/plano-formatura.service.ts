/**
 * Plano Formatura Service — Motor 2
 * Calls POST /planejamento/gerar-plano on the backend.
 * Also handles loading/saving user preferences via supabaseDataService.
 */

import { config } from '$lib/config';
import type { PlanoFormatura, PreferenciasPlano } from '$lib/types/plano-formatura';
import { DEFAULT_PREFERENCIAS } from '$lib/types/plano-formatura';
import { supabaseDataService } from './supabase-data.service';

export interface GerarPlanoPayload {
	/** Código completo do currículo (curriculo_completo). */
	curriculoCompleto: string;
	/** Conjunto de códigos de disciplinas já concluídas (uppercase). */
	codigosConcluidos: string[];
	/** Semestre atual do aluno (número ordinal). */
	semestreAtual: number;
	/** Limite de créditos por semestre escolhido no onboarding. */
	limiteCreditos: 16 | 24 | 32;
}

export interface GerarPlanoError {
	message: string;
	status?: number;
}

class PlanoFormaturaService {
	/**
	 * Chama o backend (Motor 2) para gerar o plano de formatura personalizado.
	 * Retorna null se o backend não estiver disponível — a UI deve mostrar estado de erro.
	 */
	async gerarPlano(payload: GerarPlanoPayload): Promise<PlanoFormatura | null> {
		const url = `${config.apiUrl}/planejamento/gerar-plano`;

		const response = await fetch(url, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				curriculo_completo: payload.curriculoCompleto,
				codigos_concluidos: payload.codigosConcluidos,
				semestre_atual: payload.semestreAtual,
				limite_creditos: payload.limiteCreditos
			})
		});

		if (!response.ok) {
			const text = await response.text().catch(() => '');
			throw new Error(
				`Erro ${response.status} ao gerar plano: ${text || response.statusText}`
			);
		}

		const data = (await response.json()) as PlanoFormatura;
		return data;
	}

	/**
	 * Carrega as preferências de planejamento do usuário a partir do Supabase.
	 * Retorna DEFAULT_PREFERENCIAS se não houver preferências salvas.
	 */
	async loadPreferencias(idUser: number): Promise<PreferenciasPlano> {
		try {
			const prefs = await supabaseDataService.getPreferenciasPlano(idUser);
			if (!prefs) return { ...DEFAULT_PREFERENCIAS };
			return prefs;
		} catch {
			return { ...DEFAULT_PREFERENCIAS };
		}
	}

	/**
	 * Persiste as preferências de planejamento do usuário no Supabase.
	 */
	async savePreferencias(idUser: number, preferencias: PreferenciasPlano): Promise<void> {
		await supabaseDataService.savePreferenciasPlano(idUser, preferencias);
	}
}

export const planoFormaturaService = new PlanoFormaturaService();

/**
 * Preferência de turno/professor por matéria, confirmada pelo aluno no chat da
 * Darcy (banner "Aceitar"/"Manter grade anterior" no Montador de Grade) e
 * persistida na tabela `preferencias_grade` — para reaplicar automaticamente
 * nas próximas montagens, mesmo em outro dispositivo/sessão.
 */
import { apiRequest } from '$lib/utils/api';

export interface PreferenciaGrade {
	codigo_materia: string;
	turnos: string[];
	docente: string | null;
}

export class PreferenciasGradeService {
	async listar(): Promise<PreferenciaGrade[]> {
		const { data, error } = await apiRequest<{ preferencias: PreferenciaGrade[] }>(
			'/planejamento/preferencias-grade-listar'
		);
		if (error || !data) return []; // não bloqueia a tela do montador por causa disso
		return data.preferencias;
	}

	async salvar(codigo: string, opts: { turnos?: string[]; docente?: string | null }): Promise<void> {
		await apiRequest('/planejamento/preferencias-grade-salvar', {
			method: 'POST',
			body: { codigo, turnos: opts.turnos ?? [], docente: opts.docente ?? null }
		});
	}

	async remover(codigo: string): Promise<void> {
		await apiRequest('/planejamento/preferencias-grade-remover', {
			method: 'POST',
			body: { codigo }
		});
	}
}

export const preferenciasGradeService = new PreferenciasGradeService();

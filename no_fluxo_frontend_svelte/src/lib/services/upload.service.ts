import { supabaseDataService } from './supabase-data.service';
import { createSupabaseBrowserClient } from '$lib/supabase/client';
import { parsePdf, type ParsedPdfResult } from './pdf/pdfParser';

/**
 * Upload service — CLIENT-SIDE approach:
 *   - parsePdfLocally()  → runs entirely in the browser (PDF.js + regex)
 *   - casarDisciplinas() → Supabase RPC (plpgsql function, single DB round-trip)
 *   - saveFluxograma()   → DIRECT Supabase (via supabaseDataService)
 *
 * See plans 16 (CLIENT-SIDE-PDF-PARSING.md) and 22 (SSR-REMOVAL) for architecture.
 */

export type UploadPdfResponse = ParsedPdfResult;

export interface CasarDisciplinasResponse {
	disciplinas_casadas: Record<string, unknown>[];
	materias_concluidas: Record<string, unknown>[];
	materias_pendentes: Record<string, unknown>[];
	materias_optativas: Record<string, unknown>[];
	curso_extraido?: string;
	matriz_curricular?: string;
	resumo: {
		percentual_conclusao_obrigatorias: number;
		total_disciplinas: number;
		total_obrigatorias: number;
		total_obrigatorias_concluidas: number;
		total_obrigatorias_pendentes: number;
		total_optativas: number;
	};
	// total_disciplinas = todas casadas (inclui optativas). total_obrigatorias = só nivel > 0 (concluídas + pendentes obrig.)
	dados_validacao: {
		ira?: number;
		media_ponderada?: number;
		horas_integralizadas?: number;
	};
}

export interface CourseSelectionError {
	type: 'COURSE_SELECTION';
	message: string;
	cursos_disponiveis: { nome_curso: string; id_curso?: number; matriz_curricular?: string; turno?: string }[];
	palavras_chave_encontradas?: string[];
	matriz_extraida_pdf?: string | null;
}

class UploadService {
	/**
	 * Parse PDF file entirely in the browser using PDF.js + regex.
	 * REPLACES the old uploadPdf() that called the Python backend.
	 */
	async parsePdfLocally(file: File): Promise<UploadPdfResponse> {
		return parsePdf(file);
	}

	/**
	 * Match extracted disciplines with database.
	 * Uses Supabase RPC (plpgsql function) — single database round-trip.
	 * Strips full_text (not needed by the RPC) to reduce payload size.
	 * Aborts after 30s to prevent infinite spinner.
	 */
	async casarDisciplinas(
		dadosExtraidos: unknown
	): Promise<CasarDisciplinasResponse | CourseSelectionError> {
		const supabase = createSupabaseBrowserClient();

		// Strip full_text — the PL/pgSQL function never reads it, and it adds 20-100KB to the payload
		const { full_text: _stripped, ...payload } = dadosExtraidos as Record<string, unknown>;

		const payloadSize = JSON.stringify(payload).length;
		console.log(`[Upload] RPC payload size: ${(payloadSize / 1024).toFixed(1)} KB`);
		console.time('[Upload] casarDisciplinas RPC');

		const controller = new AbortController();
		const timeout = setTimeout(() => controller.abort(), 30_000);

		let data: unknown;
		let error: { message?: string } | null;

		try {
			const result = await supabase.rpc('casar_disciplinas', {
				p_dados: payload
			}, { signal: controller.signal } as unknown as Record<string, unknown>);
			data = result.data;
			error = result.error;
		} catch (err) {
			clearTimeout(timeout);
			console.timeEnd('[Upload] casarDisciplinas RPC');
			if (err instanceof DOMException && err.name === 'AbortError') {
				throw new Error('O processamento demorou mais de 30 segundos. Tente novamente ou use um PDF menor.');
			}
			throw err;
		}

		clearTimeout(timeout);
		console.timeEnd('[Upload] casarDisciplinas RPC');

		if (error) {
			throw new Error(error.message || 'Erro ao processar disciplinas');
		}

		const result = data as Record<string, unknown>;
		console.log(`[Upload] RPC response size: ${(JSON.stringify(result).length / 1024).toFixed(1)} KB`);

		// Check if the response is a course selection prompt
		if (result?.cursos_disponiveis && !result?.disciplinas_casadas) {
			return {
				type: 'COURSE_SELECTION',
				message: result.message,
				cursos_disponiveis: result.cursos_disponiveis,
				palavras_chave_encontradas: result.palavras_chave_encontradas,
				matriz_extraida_pdf: result.matriz_extraida_pdf
			} as CourseSelectionError;
		}

		// Check for business errors returned in the JSON
		if (result?.error && !result?.disciplinas_casadas) {
			if (result?.cursos_disponiveis) {
				return {
					type: 'COURSE_SELECTION',
					message: result.message || result.error,
					cursos_disponiveis: result.cursos_disponiveis
				} as CourseSelectionError;
			}
			throw new Error(result.error as string);
		}

		return result as unknown as CasarDisciplinasResponse;
	}

	/**
	 * Save flowchart data to database.
	 * DIRECT SUPABASE — no backend call needed.
	 */
	async saveFluxogramaToDB(userId: number, fluxogramaData: unknown, semestre?: number) {
		return supabaseDataService.saveFluxogramaData(userId, fluxogramaData, semestre);
	}
}

export const uploadService = new UploadService();

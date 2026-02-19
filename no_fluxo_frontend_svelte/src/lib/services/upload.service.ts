import { supabaseDataService } from './supabase-data.service';
import { parsePdf, type ParsedPdfResult } from './pdf/pdfParser';

/**
 * Upload service — CLIENT-SIDE approach:
 *   - parsePdfLocally()  → runs entirely in the browser (PDF.js + regex)
 *   - casarDisciplinas() → SvelteKit server route /api/casar-disciplinas
 *   - saveFluxograma()   → DIRECT Supabase (via supabaseDataService)
 *
 * See plan 16 (CLIENT-SIDE-PDF-PARSING.md) for architecture details.
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
	cursos_disponiveis: { nome_curso: string; id_curso?: number; matriz_curricular?: string }[];
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
	 * NOW USES SvelteKit server route instead of Express backend.
	 */
	async casarDisciplinas(
		dadosExtraidos: unknown
	): Promise<CasarDisciplinasResponse | CourseSelectionError> {
		const response = await fetch('/api/casar-disciplinas', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ dados_extraidos: dadosExtraidos })
		});

		if (!response.ok) {
			const errorBody = await response.text();
			try {
				const errorData = JSON.parse(errorBody);

				// Check if it's a course selection error (multiple matches)
				if (errorData.cursos_disponiveis) {
					return {
						type: 'COURSE_SELECTION',
						message: errorData.message,
						cursos_disponiveis: errorData.cursos_disponiveis,
						palavras_chave_encontradas: errorData.palavras_chave_encontradas
					} as CourseSelectionError;
				}

				throw new Error(
					errorData.error || `Erro ao processar disciplinas: ${response.status}`
				);
			} catch (e) {
				if (e instanceof SyntaxError) {
					throw new Error(`Erro ao processar disciplinas: ${response.status}`);
				}
				throw e;
			}
		}

		return response.json();
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

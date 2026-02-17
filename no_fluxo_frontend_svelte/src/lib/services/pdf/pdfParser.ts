/**
 * PDF Parser — Client-side PDF parsing entry point.
 *
 * Orchestrates text extraction (PDF.js) + data extraction (regex)
 * to produce the same JSON structure previously returned by the
 * Python Flask microservice at POST /upload-pdf.
 */

import { extractTextFromPdf, extractMatriculaFromFilename } from './pdfExtractor';
import {
	extrairDadosAcademicos,
	type DisciplinaExtraida,
	type EquivalenciaExtraida,
	type DadosAcademicos
} from './pdfDataExtractor';

const LOG_PREFIX = '[PDF-Parser]';

export type { DisciplinaExtraida, EquivalenciaExtraida, DadosAcademicos };

export interface ParsedPdfResult {
	message: string;
	filename: string;
	matricula: string;
	curso_extraido: string | null;
	matriz_curricular: string | null;
	media_ponderada: number | null;
	frequencia_geral: null;
	full_text: string;
	extracted_data: DisciplinaExtraida[];
	equivalencias_pdf: EquivalenciaExtraida[];
	semestre_atual: string | null;
	numero_semestre: number | null;
	suspensoes: string[];
}

/**
 * Parse a PDF file entirely in the browser.
 * Returns the same structure as the old Python endpoint `POST /upload-pdf`.
 */
export async function parsePdf(file: File): Promise<ParsedPdfResult> {
	console.log(`${LOG_PREFIX} ========================================`);
	console.log(`${LOG_PREFIX} Starting client-side PDF parsing`);
	console.log(`${LOG_PREFIX} File: "${file.name}" (${(file.size / 1024).toFixed(1)} KB)`);
	console.log(`${LOG_PREFIX} ========================================`);
	const startTime = performance.now();

	// 1. Extract raw text from PDF using PDF.js
	const textoTotal = await extractTextFromPdf(file);

	if (!textoTotal.trim()) {
		console.error(`${LOG_PREFIX} No text extracted from PDF — aborting`);
		throw new Error(
			'Nenhuma informação textual pôde ser extraída do PDF. ' +
				'O PDF pode ser uma imagem de baixa qualidade, estar vazio ou corrompido.'
		);
	}

	console.log(`${LOG_PREFIX} Text extraction done — ${textoTotal.length} chars`);

	// 2. Extract matrícula from filename
	const matricula = extractMatriculaFromFilename(file.name);

	// 3. Run regex-based academic data extraction
	const dados: DadosAcademicos = extrairDadosAcademicos(textoTotal);

	const elapsed = (performance.now() - startTime).toFixed(0);
	const regularCount = dados.disciplinas.filter(d => d.tipo_dado === 'Disciplina Regular').length;
	const pendingCount = dados.disciplinas.filter(d => d.tipo_dado === 'Disciplina Pendente').length;
	console.log(`${LOG_PREFIX} ========================================`);
	console.log(`${LOG_PREFIX} Parsing complete in ${elapsed}ms`);
	console.log(`${LOG_PREFIX} Course: ${dados.curso ?? '(not found)'}`);
	console.log(`${LOG_PREFIX} Matrix: ${dados.matriz_curricular ?? '(not found)'}`);
	console.log(`${LOG_PREFIX} IRA: ${dados.ira ?? 'N/A'} | MP: ${dados.media_ponderada ?? 'N/A'}`);
	console.log(`${LOG_PREFIX} Disciplines: ${regularCount} regular, ${pendingCount} pending`);
	console.log(`${LOG_PREFIX} Equivalencies: ${dados.equivalencias.length}`);
	console.log(`${LOG_PREFIX} Semester: ${dados.semestre_atual ?? 'N/A'} (#${dados.numero_semestre})`);
	console.log(`${LOG_PREFIX} ========================================`);

	// 4. Build response matching the old Flask JSON shape
	return {
		message: 'PDF processado com sucesso!',
		filename: file.name,
		matricula,
		curso_extraido: dados.curso,
		matriz_curricular: dados.matriz_curricular,
		media_ponderada: dados.media_ponderada,
		frequencia_geral: null,
		full_text: textoTotal,
		extracted_data: dados.disciplinas,
		equivalencias_pdf: dados.equivalencias,
		semestre_atual: dados.semestre_atual,
		numero_semestre: dados.numero_semestre,
		suspensoes: dados.suspensoes
	};
}

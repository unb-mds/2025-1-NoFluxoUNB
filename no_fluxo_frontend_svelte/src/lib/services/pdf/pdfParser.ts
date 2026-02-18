/**
 * PDF Parser — Client-side PDF parsing entry point.
 *
 * Orchestrates:
 *   1. Position-based discipline extraction (using x,y coordinates from PDF.js)
 *   2. Regex-based metadata extraction (curso, IRA, MP, suspensões, etc.)
 *   3. Regex-based pending disciplines + equivalências extraction
 *
 * The position-based approach replaces the old regex-only discipline extraction,
 * fixing issues with multi-line professor names and long discipline name wrapping.
 */

import { extractTextFromPdf, extractPositionedItems, extractMatriculaFromFilename } from './pdfExtractor';
import {
	extrairCurso,
	extrairMatrizCurricular,
	extrairSuspensoes,
	extrairSemestreAtual,
	calcularNumeroSemestre,
	type DisciplinaExtraida,
	type EquivalenciaExtraida,
	type DadosAcademicos
} from './pdfDataExtractor';
import { extractDisciplinasFromPositions } from './pdfPositionExtractor';

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

// ─── Regex-based extractors for non-discipline data ───

function extrairEquivalencias(text: string): EquivalenciaExtraida[] {
	const equivalencias: EquivalenciaExtraida[] = [];
	const reEquiv =
		/Cumpriu\s+([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9-]+?)\s*\((\d+)h\)\s*atrav[eé]s\s*de\s*([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9-]+?)\s*\((\d+)h\)/gi;

	let eqMatch: RegExpExecArray | null;
	while ((eqMatch = reEquiv.exec(text)) !== null) {
		equivalencias.push({
			cumpriu: eqMatch[1],
			nome_cumpriu: eqMatch[2].trim(),
			atraves_de: eqMatch[4],
			nome_equivalente: eqMatch[5].trim(),
			ch_cumpriu: eqMatch[3],
			ch_equivalente: eqMatch[6],
		});
	}

	return equivalencias;
}

function extrairDisciplinasPendentes(text: string): DisciplinaExtraida[] {
	const disciplinas: DisciplinaExtraida[] = [];

	const pendMatch = text.match(
		/Componentes Curriculares Obrigat[óo]rios Pendentes:\s*(\d+)/i
	);
	if (!pendMatch) return disciplinas;

	const pendIdx = text.indexOf(pendMatch[0]);
	const pendSection = text.substring(pendIdx);
	const linhas = pendSection.split('\n');

	const reHeader = /^C[óo]digo\s+Componente/i;
	let started = false;

	for (const linha of linhas) {
		if (reHeader.test(linha.trim())) {
			started = true;
			continue;
		}
		if (!started) continue;

		if (
			/^(Observações|Equivalências|Para verificar|Atenção|SIGAA|Componentes Curriculares Optativos)/i.test(
				linha.trim()
			)
		) {
			break;
		}

		const m = linha.match(
			/^\s*([A-Z]{2,}\d{3,}|ENADE|-)\s+(.+?)\s+(?:(Matriculado(?:\s+em\s+Equivalente)?)\s+)?(\d+)\s*h/i
		);
		if (m) {
			const [, codigo, nome, matriculado, chStr] = m;
			if (codigo === '-') continue;
			if (/^(?:Dr\.|Dra\.|MSc\.|Prof\.)\s/i.test(nome.trim())) continue;
			if (/\(\d+h\)/i.test(nome)) continue;

			const cleanNome = nome
				.replace(/^[^a-zA-ZÀ-ÿ0-9]+/, '')
				.replace(/[^a-zA-ZÀ-ÿ0-9]+$/, '')
				.replace(/\s{2,}/g, ' ')
				.trim();

			disciplinas.push({
				tipo_dado: 'Disciplina Pendente',
				nome: cleanNome,
				status: matriculado ? 'MATR' : 'PENDENTE',
				mencao: '-',
				creditos: Math.floor(parseInt(chStr) / 15),
				codigo: codigo === 'ENADE' ? 'ENADE' : codigo,
				carga_horaria: parseInt(chStr),
				ano_periodo: '',
				prefixo: '',
				professor: '',
				turma: '',
				frequencia: null,
				nota: null,
				...(matriculado ? { observacao: matriculado } : {}),
			});
		}
	}

	return disciplinas;
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

	// 1. Extract both flat text (for metadata) and positioned items (for disciplines)
	const [textoTotal, positionedPages] = await Promise.all([
		extractTextFromPdf(file),
		extractPositionedItems(file)
	]);

	if (!textoTotal.trim()) {
		console.error(`${LOG_PREFIX} No text extracted from PDF — aborting`);
		throw new Error(
			'Nenhuma informação textual pôde ser extraída do PDF. ' +
				'O PDF pode ser uma imagem de baixa qualidade, estar vazio ou corrompido.'
		);
	}

	console.log(`${LOG_PREFIX} Text extraction done — ${textoTotal.length} chars, ${positionedPages.length} pages of positioned items`);

	// 2. Extract matrícula from filename
	const matricula = extractMatriculaFromFilename(file.name);

	// 3. Position-based discipline extraction (replaces regex)
	const isDetailed = textoTotal.includes('EMENTA:') && /APROVADO\(A\)|REPROVADO\(A\)/.test(textoTotal);
	let disciplinas: DisciplinaExtraida[];

	if (isDetailed) {
		// Detailed format (with EMENTA, OBJETIVOS) — fall back to regex for this format
		// as it has a completely different layout
		const { extrairDadosAcademicos } = await import('./pdfDataExtractor');
		const dados = extrairDadosAcademicos(textoTotal);
		disciplinas = dados.disciplinas.filter(d => d.tipo_dado === 'Disciplina Regular');
		console.log(`${LOG_PREFIX} Used regex fallback for detailed format — ${disciplinas.length} disciplines`);
	} else {
		// Standard format — use position-based extraction
		disciplinas = extractDisciplinasFromPositions(positionedPages);
		console.log(`${LOG_PREFIX} Position-based extraction — ${disciplinas.length} disciplines`);
	}

	// 4. Regex-based metadata extraction (these are simple single-line patterns)
	const curso = extrairCurso(textoTotal);
	const matrizCurricular = extrairMatrizCurricular(textoTotal);
	const suspensoes = extrairSuspensoes(textoTotal);

	let ira: number | null = null;
	const iraMatch = textoTotal.match(/IRA[:\s]+(\d+[.,]\d+)/i);
	if (iraMatch) ira = parseFloat(iraMatch[1].replace(',', '.'));

	let mediaPonderada: number | null = null;
	const mpMatch = textoTotal.match(/MP[:\s]+(\d+[.,]\d+)/i);
	if (mpMatch) mediaPonderada = parseFloat(mpMatch[1].replace(',', '.'));

	// 5. Pending disciplines (regex on flat text — these are in a separate section)
	const pendentes = extrairDisciplinasPendentes(textoTotal);

	// 6. Equivalências (regex)
	const equivalencias = extrairEquivalencias(textoTotal);

	// 7. Build the full disciplinas array with metadata entries
	const allDisciplinas: DisciplinaExtraida[] = [...disciplinas, ...pendentes];

	// Add status count entry
	const countMap: Record<string, number> = {};
	const rePendencias = /\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b/gi;
	let statMatch: RegExpExecArray | null;
	while ((statMatch = rePendencias.exec(textoTotal)) !== null) {
		const key = statMatch[1].toUpperCase();
		countMap[key] = (countMap[key] || 0) + 1;
	}
	if (Object.keys(countMap).length > 0) {
		allDisciplinas.push({
			tipo_dado: 'Pendencias',
			nome: '', status: '', mencao: '', creditos: 0, codigo: '', carga_horaria: 0,
			ano_periodo: '', prefixo: '', professor: '', turma: '', frequencia: null, nota: null,
			valores: countMap,
		});
	}

	// Add IRA entry
	if (ira !== null) {
		allDisciplinas.push({
			tipo_dado: 'IRA',
			nome: '', status: '', mencao: '', creditos: 0, codigo: '', carga_horaria: 0,
			ano_periodo: '', prefixo: '', professor: '', turma: '', frequencia: null, nota: null,
			IRA: 'IRA', valor: ira,
		});
	}

	const semestreAtual = extrairSemestreAtual(allDisciplinas);
	const numeroSemestre = calcularNumeroSemestre(allDisciplinas);

	const elapsed = (performance.now() - startTime).toFixed(0);
	const regularCount = disciplinas.length;
	const pendingCount = pendentes.length;
	console.log(`${LOG_PREFIX} ========================================`);
	console.log(`${LOG_PREFIX} Parsing complete in ${elapsed}ms`);
	console.log(`${LOG_PREFIX} Course: ${curso ?? '(not found)'}`);
	console.log(`${LOG_PREFIX} Matrix: ${matrizCurricular ?? '(not found)'}`);
	console.log(`${LOG_PREFIX} IRA: ${ira ?? 'N/A'} | MP: ${mediaPonderada ?? 'N/A'}`);
	console.log(`${LOG_PREFIX} Disciplines: ${regularCount} regular, ${pendingCount} pending`);
	console.log(`${LOG_PREFIX} Equivalencies: ${equivalencias.length}`);
	console.log(`${LOG_PREFIX} Semester: ${semestreAtual ?? 'N/A'} (#${numeroSemestre})`);
	console.log(`${LOG_PREFIX} ========================================`);

	return {
		message: 'PDF processado com sucesso!',
		filename: file.name,
		matricula,
		curso_extraido: curso,
		matriz_curricular: matrizCurricular,
		media_ponderada: mediaPonderada,
		frequencia_geral: null,
		full_text: textoTotal,
		extracted_data: allDisciplinas,
		equivalencias_pdf: equivalencias,
		semestre_atual: semestreAtual,
		numero_semestre: numeroSemestre,
		suspensoes
	};
}

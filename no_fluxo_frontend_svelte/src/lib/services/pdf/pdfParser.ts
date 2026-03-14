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

import {
	loadPdf,
	extractTextFromPdfDoc,
	extractPositionedItemsFromDoc,
	extractMatriculaFromFilename,
	sanitizeMatriculaFromFilename
} from './pdfExtractor';
import {
	extrairCurso,
	extrairMatrizCurricular,
	extrairMatriculaFromText,
	extrairSuspensoes,
	extrairSemestreAtual,
	extrairCargaHorariaIntegralizada,
	debugCargaHorariaIntegralizada,
	calcularNumeroSemestre,
	extrairDadosAcademicos,
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
	/** CH integralizada (obrigatória, optativa, complementar) da tabela "Carga Horária Integralizada/Pendente" */
	carga_horaria_integralizada: {
		obrigatoria: number;
		optativa: number;
		complementar: number;
		total: number;
	} | null;
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

	// 1. Load PDF once, then extract both text and positioned items from the shared instance
	const pdf = await loadPdf(file);

	const [textoTotal, positionedPages] = await Promise.all([
		extractTextFromPdfDoc(pdf),
		extractPositionedItemsFromDoc(pdf)
	]);

	if (!textoTotal.trim()) {
		console.error(`${LOG_PREFIX} No text extracted from PDF — aborting`);
		throw new Error(
			'Nenhuma informação textual pôde ser extraída do PDF. ' +
				'O PDF pode ser uma imagem de baixa qualidade, estar vazio ou corrompido.'
		);
	}

	console.log(`${LOG_PREFIX} Text extraction done — ${textoTotal.length} chars, ${positionedPages.length} pages of positioned items (${(performance.now() - startTime).toFixed(0)}ms elapsed)`);

	// 2. Matrícula: prioridade do texto do PDF (evita lixo do nome do arquivo, ex.: "231026330 (2)")
	const matriculaFromText = extrairMatriculaFromText(textoTotal);
	const matricula =
		matriculaFromText ??
		sanitizeMatriculaFromFilename(extractMatriculaFromFilename(file.name));
	if (matriculaFromText) {
		console.log(`${LOG_PREFIX} Matrícula extraída do PDF: ${matriculaFromText}`);
	} else if (matricula !== 'desconhecida') {
		console.log(`${LOG_PREFIX} Matrícula do nome do arquivo (sanitizada): ${matricula}`);
	}

	// 3. Position-based discipline extraction (replaces regex)
	const isDetailed = textoTotal.includes('EMENTA:') && /APROVADO\(A\)|REPROVADO\(A\)/.test(textoTotal);
	let disciplinas: DisciplinaExtraida[];

	console.time(`${LOG_PREFIX} disciplineExtraction`);
	if (isDetailed) {
		// Detailed format (with EMENTA, OBJETIVOS) — fall back to regex for this format
		// as it has a completely different layout
		const dados = extrairDadosAcademicos(textoTotal);
		disciplinas = dados.disciplinas.filter(d => d.tipo_dado === 'Disciplina Regular');
		console.log(`${LOG_PREFIX} Used regex fallback for detailed format — ${disciplinas.length} disciplines`);
	} else {
		// Standard format — use position-based extraction
		disciplinas = extractDisciplinasFromPositions(positionedPages);
		console.log(`${LOG_PREFIX} Position-based extraction — ${disciplinas.length} disciplines`);
	}
	console.timeEnd(`${LOG_PREFIX} disciplineExtraction`);

	// 4. Regex-based metadata extraction (these are simple single-line patterns)
	console.time(`${LOG_PREFIX} metadataExtraction`);
	// Extrair matriz primeiro para ancorar o curso ao bloco correto (evitar pegar outro curso no PDF)
	const matrizCurricular = extrairMatrizCurricular(textoTotal);
	let textoParaCurso = textoTotal;
	if (matrizCurricular) {
		// Encontrar a posição do código do currículo no texto (ex.: 8184/1 - 2019.2)
		const codeMatch = matrizCurricular.match(/^(\d+)\//);
		if (codeMatch) {
			const code = codeMatch[1];
			let idx = textoTotal.indexOf(code + '/');
			if (idx === -1) idx = textoTotal.indexOf(matrizCurricular);
			if (idx > 0) {
				// Usar só o trecho até o currículo + margem: curso e "Discente" estão nessa região
				const fim = Math.min(idx + matrizCurricular.length + 400, textoTotal.length);
				textoParaCurso = textoTotal.substring(0, fim);
			}
		}
	}
	const curso = extrairCurso(textoParaCurso);

	// Debug: Log lines around "Discente" and "Curso" to diagnose extraction issues
	if (!curso) {
		const lines = textoTotal.split('\n');
		console.log(`${LOG_PREFIX} [DEBUG] Course extraction failed. First 25 lines of text:`);
		for (let i = 0; i < Math.min(lines.length, 25); i++) {
			console.log(`${LOG_PREFIX} [DEBUG] Line ${i}: "${lines[i]}"`);
		}
	}

	const suspensoes = extrairSuspensoes(textoTotal);

	let ira: number | null = null;
	const iraMatch = textoTotal.match(/IRA[:\s]+(\d+[.,]\d+)/i);
	if (iraMatch) ira = parseFloat(iraMatch[1].replace(',', '.'));

	let mediaPonderada: number | null = null;
	const mpMatch = textoTotal.match(/MP[:\s]+(\d+[.,]\d+)/i);
	if (mpMatch) mediaPonderada = parseFloat(mpMatch[1].replace(',', '.'));
	console.timeEnd(`${LOG_PREFIX} metadataExtraction`);

	// 5. Pending disciplines (regex on flat text — these are in a separate section)
	console.time(`${LOG_PREFIX} pendingDisciplines`);
	const pendentes = extrairDisciplinasPendentes(textoTotal);
	console.timeEnd(`${LOG_PREFIX} pendingDisciplines`);

	// 6. Equivalências (regex)
	console.time(`${LOG_PREFIX} equivalencias`);
	const equivalencias = extrairEquivalencias(textoTotal);
	console.timeEnd(`${LOG_PREFIX} equivalencias`);

	// 6b. Carga horária integralizada (tabela "Carga Horária Integralizada/Pendente")
	const cargaHorariaIntegralizada = extrairCargaHorariaIntegralizada(textoTotal);

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
	if (cargaHorariaIntegralizada) {
		console.log(`${LOG_PREFIX} CH Integralizada: ${JSON.stringify(cargaHorariaIntegralizada)}`);
	} else {
		const debug = debugCargaHorariaIntegralizada(textoTotal);
		console.log(`${LOG_PREFIX} CH Integralizada: (not found)${debug.found ? ` — snippet: "${debug.snippet?.slice(0, 200)}..."` : ' — "Integralizado" não encontrado no texto'}`);
	}
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
		suspensoes,
		carga_horaria_integralizada: cargaHorariaIntegralizada
	};
}

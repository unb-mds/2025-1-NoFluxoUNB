/**
 * pdfDataExtractor.mjs — NEW ROBUST ALGORITHM
 * 
 * Extracts academic data from SIGAA histórico escolar text.
 * 
 * Supports 4 distinct PDF text formats:
 * 
 *   FORMAT A: "Name-above" — discipline name on separate line, data on next
 *     Line 1: ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES
 *     Line 2: 2019.1  * CIC0004          90    AA   92,0  MM   APR
 *     Line 3: Dr. FABRICIO ATAIDES BRAZ (90h)
 *
 *   FORMAT B: "Single-line" — code + name + data all on one line
 *     2021.1  * CIC0004ALGORITMOS E PROG...  90    AA  100,0  SS   APR
 *
 *   FORMAT C: "Prof-embedded" — professor between code and CH on data line
 *     Line 1: ALGORITMOS E PROGRAMAÇÃO DECOMPUTADORES
 *     Line 2: 2022.2  & CIC0004Dr. GIOVANNI...(90h)  90  08  --  -  TRANC
 *
 *   FORMAT D: "Detailed" — includes EMENTA, OBJETIVOS, PROGRAMA per discipline
 *     Line 1: ALGORITMOS E PROG...          90    APROVADO(A)
 *     ...many lines of ementa/objectives/programa...
 *     Hidden: 2021.1*CIC0004
 *
 *   SPECIAL: CUMP with "--" instead of period:
 *     --   * FGA0221INTELIGÊNCIA ARTIFICIAL  60  --  --  -  CUMP
 *
 * Also extracts: curso, IRA, MP, matriz curricular, suspensões,
 *                equivalências, pending disciplines, semester info.
 * 
 * Uses the same interfaces as the Svelte frontend pdfDataExtractor.ts.
 */

// ─── Interfaces (matching TS types) ───

/**
 * @typedef {{
 *   tipo_dado: string;
 *   nome: string;
 *   status: string;
 *   mencao: string;
 *   creditos: number;
 *   codigo: string;
 *   carga_horaria: number;
 *   ano_periodo: string;
 *   prefixo: string;
 *   professor: string;
 *   turma: string;
 *   frequencia: string|null;
 *   nota: null;
 *   observacao?: string;
 *   IRA?: string;
 *   valor?: number;
 *   valores?: Record<string, number>;
 * }} DisciplinaExtraida
 */

/**
 * @typedef {{
 *   cumpriu: string;
 *   nome_cumpriu: string;
 *   atraves_de: string;
 *   nome_equivalente: string;
 *   ch_cumpriu: string;
 *   ch_equivalente: string;
 * }} EquivalenciaExtraida
 */

/**
 * @typedef {{
 *   disciplinas: DisciplinaExtraida[];
 *   equivalencias: EquivalenciaExtraida[];
 *   curso: string|null;
 *   matriz_curricular: string|null;
 *   media_ponderada: number|null;
 *   ira: number|null;
 *   semestre_atual: string|null;
 *   numero_semestre: number|null;
 *   suspensoes: string[];
 * }} DadosAcademicos
 */

const LOG_PREFIX = '[PDF-DataExtractor]';

// ─── Helper functions ───

export function normalizar(s) {
  return s
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toUpperCase();
}

export function limparNomeDisciplina(nome) {
  let cleaned = nome;
  cleaned = cleaned.replace(/^\d{4}\.\d\s*/, '');
  cleaned = cleaned.replace(/^--\s*/, '');
  cleaned = cleaned.replace(/^[^a-zA-ZÀ-ÿ0-9]+/, '');
  cleaned = cleaned.replace(/[^a-zA-ZÀ-ÿ0-9]+$/, '');
  cleaned = cleaned.replace(/\s{2,}/g, ' ');
  return cleaned.trim();
}

export function limparNomeProfessor(nome) {
  let cleaned = nome;
  cleaned = cleaned.replace(
    /^(?:Dr\.|Dra\.|MSc\.|Prof\.|PhD\.?|Me\.|Ma\.)\s*/gi,
    ''
  );
  cleaned = cleaned.replace(/[^a-zA-ZÀ-ÿ\s]+$/, '');
  cleaned = cleaned.replace(/\s{2,}/g, ' ');
  return cleaned.trim();
}

// Map "APROVADO(A)" style to status codes
const SITUACAO_MAP = {
  'APROVADO(A)': 'APR',
  'APROVADO': 'APR',
  'REPROVADO(A)': 'REP',
  'REPROVADO': 'REP',
  'CANCELADO(A)': 'CANC',
  'CANCELADO': 'CANC',
  'DISPENSADO(A)': 'DISP',
  'DISPENSADO': 'DISP',
  'TRANCADO(A)': 'TRANC',
  'TRANCADO': 'TRANC',
  'MATRICULADO(A)': 'MATR',
  'MATRICULADO': 'MATR',
  'CUMPRIU': 'CUMP',
};

// ─── Metadata extractors ───

export function extrairCurso(texto) {
  // Pattern 1: "Curso:\n<NAME>/CAMPUS - ..."
  let m = texto.match(
    /Curso:\s*\n([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+(?:DE\s+[A-ZÀ-ÿ\s]+)*)\/[A-Z]+ - [A-ZÀ-ÿ\s]+ - [A-ZÀ-ÿ]+/mi
  );
  if (m) return m[1].trim();

  // Pattern 2: "Curso:          NAME/CAMPUS-..."  (with varying whitespace and hyphens)
  m = texto.match(
    /Curso:\s+([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+(?:DE\s+[A-ZÀ-ÿ\s]+)*)\/[A-Z]+\s*-/mi
  );
  if (m) return m[1].trim();

  // Pattern 3: "Curso: NAME Status:"
  m = texto.match(/Curso[:\s]+([A-ZÀ-Ÿ\s/\\-]+?)(?:\s+Status:|$)/mi);
  if (m) return m[1].trim();

  return null;
}

export function extrairMatrizCurricular(texto) {
  // "Currículo:    6360/1 - 2017.1"
  let m = texto.match(/Curr[ií]culo:\s*\n?(\d+\/\d+)\s*-\s*(\d{4}\.\d)/mi);
  if (m) return m[2];

  m = texto.match(/(\d+\/\d+\s*-\s*(\d{4}\.\d))/m);
  if (m) return m[2];

  return null;
}

export function extrairSuspensoes(texto) {
  const m = texto.match(
    /Suspens[õo]es:\s+(.+)/i
  );
  if (m) {
    const val = m[1].trim();
    if (/nenhum/i.test(val)) return [];
    const periods = val.match(/\d{4}\.\d/g);
    return periods || [];
  }
  return [];
}

export function extrairSemestreAtual(disciplinas) {
  const semestres = [];
  for (const d of disciplinas) {
    if (d.status === 'MATR' && d.ano_periodo && /^\d{4}\.\d$/.test(d.ano_periodo)) {
      semestres.push(d.ano_periodo);
    }
  }
  if (semestres.length === 0) return null;
  semestres.sort((a, b) => {
    const [ya, sa] = a.split('.').map(Number);
    const [yb, sb] = b.split('.').map(Number);
    return ya !== yb ? ya - yb : sa - sb;
  });
  return semestres[semestres.length - 1];
}

export function calcularNumeroSemestre(disciplinas) {
  const validStatuses = new Set(['APR', 'REP', 'REPF', 'REPMF', 'CUMP']);
  const uniqueSemesters = new Set();
  for (const d of disciplinas) {
    if (validStatuses.has(d.status) && d.ano_periodo) {
      uniqueSemesters.add(d.ano_periodo);
    }
  }
  const count = uniqueSemesters.size;
  return count > 0 ? count + 1 : 1;
}

// ─── Core discipline extraction ───

/**
 * Main regex for discipline data lines. Matches lines like:
 *   "2019.1  * CIC0004          90    AA   92,0  MM   APR"
 *   "2021.1  * CIC0004ALGORITMOS E PROG...  90    AA  100,0  SS   APR"
 *   "--   * FGA0221INTELIGÊNCIA ARTIFICIAL  60    --    --    -   CUMP"
 *   "2022.2  & CIC0004Dr. GIOVANNI...(90h)  90    08   --    -   TRANC"
 * 
 * Groups:
 *   1: ano_periodo (or --)
 *   2: prefixo symbols (* # & e @ § %)
 *   3: codigo
 *   4: middle text (may contain name and/or professor)
 *   5-...: CH, turma, freq, nota, situacao (extracted separately after middle)
 */
function extrairDisciplinasDaLinha(text, linhas) {
  const disciplinas = [];
  const usedLines = new Set();

  // === REGEX FOR ALL SINGLE/DATA LINE FORMATS ===
  // Captures: periodo, symbols, code, then everything up to the trailing data fields
  //
  // The trailing pattern is:  CH  TURMA  FREQ  NOTA  SITUACAO
  // where CH = 2-3 digit number
  //       TURMA = 1-4 alphanumeric chars
  //       FREQ = number with comma or --
  //       NOTA = SS|MS|MM|MI|II|SR|- or ---
  //       SITUACAO = APR|REP|REPF|REPMF|CANC|DISP|TRANC|MATR|CUMP
  
  // Regex that captures the trailing data fields:
  // allows for flexible spacing between fields
  const reSituacao = /\b(APR|REP|REPF|REPMF|CANC|DISP|TRANC|MATR|CUMP)\b/;
  
  // Match a discipline data line
  // Start: period or "--"
  // Then: optional symbols
  // Then: discipline code
  // Then: anything (name, professor embedded, etc.)
  // End: ...CH  TURMA  FREQ  NOTA  SITUACAO
  const reDataLine = /^(\d{4}\.?\d?|--)\s+([*&#e@§%]*)\s*([A-Z]{2,}\d{3,})(.*?)\s{2,}(\d{2,3})\s+(\S{1,4})\s+(\d{1,3}[,.]?\d*|--)\s+(SS|MS|MM|MI|II|SR|-|---)\s+(APR|REP|REPF|REPMF|CANC|DISP|TRANC|MATR|CUMP)\b/;

  for (let i = 0; i < linhas.length; i++) {
    if (usedLines.has(i)) continue;
    const line = linhas[i];
    
    // Skip header/footer/legend lines
    if (/^(SIGAA|UnB|DEG|SAA|Campus|Credenciada|na seção|Histórico|Dados|Nome:|Data de|Nacionalidade|Nº do|Curso:|Status:|Índices|Ênfase|IRA:|Currículo|Reconhecimento|Ano \/|Forma de|Período Letivo Atual|Suspensões|Prorrogações|Tipo Saída|Data de Saída|Trabalho|Data da|Componentes Curriculares Cursados|Ano\/Período|Letivo\s+Componente|Legenda|SIGLA|Para verificar|Página|e o código|Carga Horária|Obrigatórias|Exigido|Integralizado|Pendente\s|Código\s+Componente|Observações|Atenção|Menções)/i.test(line.trim())) {
      continue;
    }
    
    const match = line.match(reDataLine);
    if (!match) continue;

    const [, periodo, prefixo, codigo, middleText, chStr, turma, freq, nota, situacao] = match;
    
    usedLines.add(i);
    
    // Determine the discipline name
    let nome = '';
    let professor = '';
    
    // Check if middleText contains the name (Format B: single-line with name concatenated)
    const middleTrimmed = middleText.trim();
    
    if (middleTrimmed) {
      // Check for embedded professor (Format C): "Dr. NAME(XXh)"
      const profMatch = middleTrimmed.match(/^((?:Dr\.|Dra\.|MSc\.|Prof\.)\s+[A-ZÀ-ÿ][A-ZÀ-ÿ\s.]+?)\s*\((\d+)h\)/i);
      if (profMatch) {
        professor = limparNomeProfessor(profMatch[1]);
        // Name is everything after the professor part (might be empty if name is on prev line)
        const afterProf = middleTrimmed.substring(profMatch[0].length).trim();
        if (afterProf) nome = afterProf;
      } else {
        // middleText is the discipline name (Format B)
        nome = middleTrimmed;
      }
    }
    
    // If no name found yet, look at the previous line (Format A or C with name above)
    if (!nome && i > 0) {
      const prevLine = linhas[i - 1].trim();
      // Must look like a discipline name: starts with uppercase letter, 
      // doesn't match period pattern, not a data line, not a footer, etc.
      if (
        prevLine.length > 2 &&
        /^[A-ZÀ-ÿ]/.test(prevLine) &&
        !reDataLine.test(prevLine) &&
        !reSituacao.test(prevLine) &&
        !/^(SIGAA|UnB|DEG|SAA|Campus|Credenciada|Legenda|Para verificar|Página|Histórico|Nome:|Componentes|Ano\/Período|Letivo\s+Component|SIGLA|Código|Observações|Atenção|Menções|Carga Horária|Obrigatórias|Exigido|Integralizado|Pendente\s|Equivalências)/i.test(prevLine) &&
        !/^\d{4}\.\d/.test(prevLine)
      ) {
        nome = prevLine;
        usedLines.add(i - 1);
      }
    }
    
    // If still no name and the line itself has code+name concatenated
    // e.g. in "CIC0004ALGORITMOS..." — the name IS in the middleText
    // This was already handled above
    
    // If still no name, check for professor-embedded format where professor is between code and spaces
    // and name is on line above
    if (!nome && middleTrimmed) {
      // Check if middle has multi-professor format: "Dr. NAME (Xh), Dra. NAME2 (Yh)"
      const multiProfMatch = middleTrimmed.match(
        /^((?:(?:Dr\.|Dra\.|MSc\.|Prof\.)\s+[A-ZÀ-ÿ][A-ZÀ-ÿ\s.]+?\s*\(\d+h\)(?:\s*,\s*)?)+)/i
      );
      if (multiProfMatch) {
        professor = multiProfMatch[1].trim();
      }
    }
    
    // Check line after for professor (Format A)
    if (!professor && i + 1 < linhas.length && !usedLines.has(i + 1)) {
      const nextLine = linhas[i + 1].trim();
      const profLineMatch = nextLine.match(
        /^((?:Dr\.|Dra\.|MSc\.|Prof\.)\s+[A-ZÀ-ÿ][A-ZÀ-ÿ\s.,]+(?:\(\d+h\)(?:\s*,\s*(?:Dr\.|Dra\.|MSc\.|Prof\.)\s+[A-ZÀ-ÿ][A-ZÀ-ÿ\s.,]+\(\d+h\))*)?)/i
      );
      if (profLineMatch) {
        professor = profLineMatch[1].trim();
        usedLines.add(i + 1);
      }
    }

    // Clean up the name  
    nome = limparNomeDisciplina(nome);
    
    // Handle menção: "---" means no grade
    const mencao = (nota === '---' || nota === '-') ? '-' : nota;
    
    // Parse carga horaria
    const cargaH = parseInt(chStr) || 0;
    
    // Normalize periodo: "2020." -> "2020.0" (handle malformed periods)
    let anoPeriodo = periodo === '--' ? '' : periodo;
    if (anoPeriodo && !anoPeriodo.match(/^\d{4}\.\d$/)) {
      // Try to fix malformed period like "2020."
      if (/^\d{4}\.$/.test(anoPeriodo)) {
        anoPeriodo = anoPeriodo + '0';
      }
    }
    
    // Skip disciplines with menção II, MI, or SR (as per original algorithm)
    // Actually NO — we should keep them and let the frontend decide
    // The original algorithm skips them but that loses data
    // We'll keep them for now and add a flag

    disciplinas.push({
      tipo_dado: 'Disciplina Regular',
      nome,
      status: situacao,
      mencao,
      creditos: cargaH > 0 ? Math.floor(cargaH / 15) : 0,
      codigo,
      carga_horaria: cargaH,
      ano_periodo: anoPeriodo,
      prefixo: prefixo || '',
      professor: limparNomeProfessor(professor),
      turma,
      frequencia: freq !== '--' ? freq : null,
      nota: null,
    });
  }
  
  return disciplinas;
}

/**
 * Extract disciplines from DETAILED format (with EMENTA, OBJETIVOS, etc.)
 * This format has:
 *   DISCIPLINE NAME          CH    APROVADO(A)
 *   EMENTA: ...
 *   OBJETIVOS: ...
 *   PROGRAMA: ...
 *   2021.1*CIC0004
 *   REFERÊNCIAS: ...
 */
function extrairDisciplinasDetalhado(text, linhas) {
  const disciplinas = [];
  
  // Pattern: "DISCIPLINE NAME          CH    APROVADO(A)|REPROVADO(A)|..."
  const reDetailed = /^([A-ZÀ-ÿ][A-ZÀ-ÿ\s0-9-]+?)\s{2,}(\d{2,3})\s+(APROVADO\(A\)|REPROVADO\(A\)|CANCELADO\(A\)|DISPENSADO\(A\)|TRANCADO\(A\)|MATRICULADO\(A\)|CUMPRIU|APROVADO|REPROVADO)/i;
  
  // Pattern for hidden period+code line (may have trailing text from PDF content)
  // Examples:
  //   "2021.1*CIC0004"
  //   "2021.1   FGA0163"
  //   "2021.1   FGA0168        332 p"
  //   "2022.1eMAT0053"
  //   "2021.1   MAT0025planas, comprimento de curvas..."
  const rePeriodCode = /^(\d{4}\.\d)\s*([*&#e@§%]*)\s*([A-Z]{2,}\d{3,})/;
  
  for (let i = 0; i < linhas.length; i++) {
    const match = linhas[i].match(reDetailed);
    if (!match) continue;
    
    const [, nome, chStr, situacaoLong] = match;
    const status = SITUACAO_MAP[situacaoLong.toUpperCase()] || situacaoLong;
    const cargaH = parseInt(chStr) || 0;
    
    // Search forward for the period+code line (within next ~60 lines)
    let codigo = '';
    let anoPeriodo = '';
    let prefixo = '';
    
    for (let j = i + 1; j < Math.min(i + 60, linhas.length); j++) {
      const pcMatch = linhas[j].match(rePeriodCode);
      if (pcMatch) {
        anoPeriodo = pcMatch[1];
        prefixo = pcMatch[2] || '';
        codigo = pcMatch[3];
        break;
      }
      // Stop if we hit the next discipline header
      if (reDetailed.test(linhas[j])) break;
    }
    
    disciplinas.push({
      tipo_dado: 'Disciplina Regular',
      nome: limparNomeDisciplina(nome),
      status,
      mencao: '-', // detailed format doesn't show menção
      creditos: cargaH > 0 ? Math.floor(cargaH / 15) : 0,
      codigo,
      carga_horaria: cargaH,
      ano_periodo: anoPeriodo,
      prefixo,
      professor: '',
      turma: '',
      frequencia: null,
      nota: null,
    });
  }
  
  return disciplinas;
}

/**
 * Extract pending disciplines from the "Componentes Curriculares Obrigatórios Pendentes" section.
 * Format:
 *   MAT0026    CÁLCULO 2          90 h
 *   FGA0138    MÉTODOS DE DESENVOLVIMENTO DE SOFTWARE    Matriculado em Equivalente    60 h
 *   -      CADEIA DE SELETIVIDADE - 6360/1 - Cadeia 6 (CH Mínima: 60 h)          60 h
 *   ENADE    ENADE CONCLUINTE PENDENTE          0 h
 */
function extrairDisciplinasPendentes(text) {
  const disciplinas = [];
  
  // Find the pending section
  const pendMatch = text.match(/Componentes Curriculares Obrigat[óo]rios Pendentes:\s*(\d+)/i);
  if (!pendMatch) return disciplinas;
  
  const pendIdx = text.indexOf(pendMatch[0]);
  const pendSection = text.substring(pendIdx);
  const linhas = pendSection.split('\n');
  
  // Skip header lines ("Código    Componente Curricular    CH")
  const reHeader = /^C[óo]digo\s+Componente/i;
  let started = false;
  
  for (const linha of linhas) {
    if (reHeader.test(linha.trim())) {
      started = true;
      continue;
    }
    if (!started) continue;
    
    // Stop at "Observações:", "Equivalências:", "Para verificar", etc. 
    if (/^(Observações|Equivalências|Para verificar|Atenção|SIGAA|Componentes Curriculares Optativos)/i.test(linha.trim())) {
      break;
    }
    
    // Try to match: CODE    NAME    [Matriculado|Matriculado em Equivalente]    CH h
    const m = linha.match(
      /^\s*([A-Z]{2,}\d{3,}|ENADE|-)\s+(.+?)\s+(?:(Matriculado(?:\s+em\s+Equivalente)?)\s+)?(\d+)\s*h/i
    );
    if (m) {
      const [, codigo, nome, matriculado, chStr] = m;
      if (codigo === '-') continue; // Skip "CADEIA DE SELETIVIDADE" entries
      
      disciplinas.push({
        tipo_dado: 'Disciplina Pendente',
        nome: limparNomeDisciplina(nome),
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
 * Extract equivalências.
 * Format: "Cumpriu MAT0025 - CÁLCULO 1 (90h) através de MAT0137 - CÁLCULO 1 - SEMIPRESENCIAL (90h)"
 */
function extrairEquivalencias(text) {
  const equivalencias = [];
  const reEquiv =
    /Cumpriu\s+([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9-]+?)\s*\((\d+)h\)\s*atrav[eé]s\s*de\s*([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9-]+?)\s*\((\d+)h\)/gi;
  
  let eqMatch;
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

// ─── Main extraction function ───

/**
 * @param {string} textoTotal - Full extracted text from PDF
 * @returns {DadosAcademicos}
 */
export function extrairDadosAcademicos(textoTotal) {
  console.log(`${LOG_PREFIX} === STARTING ACADEMIC DATA EXTRACTION ===`);
  console.log(`${LOG_PREFIX} Input: ${textoTotal.length} chars, ${textoTotal.split('\n').length} lines`);

  const linhas = textoTotal.split('\n');

  // ─── Metadata ───
  const curso = extrairCurso(textoTotal);
  const matrizCurricular = extrairMatrizCurricular(textoTotal);
  const suspensoes = extrairSuspensoes(textoTotal);

  let ira = null;
  const iraMatch = textoTotal.match(/IRA[:\s]+(\d+[.,]\d+)/i);
  if (iraMatch) ira = parseFloat(iraMatch[1].replace(',', '.'));

  let mediaPonderada = null;
  const mpMatch = textoTotal.match(/MP[:\s]+(\d+[.,]\d+)/i);
  if (mpMatch) mediaPonderada = parseFloat(mpMatch[1].replace(',', '.'));

  console.log(`${LOG_PREFIX} [CURSO] ${curso ?? '(not found)'}`);
  console.log(`${LOG_PREFIX} [MATRIZ] ${matrizCurricular ?? '(not found)'}`);
  console.log(`${LOG_PREFIX} [IRA] ${ira ?? '(not found)'}`);
  console.log(`${LOG_PREFIX} [MP] ${mediaPonderada ?? '(not found)'}`);
  console.log(`${LOG_PREFIX} [SUSPENSÕES] ${suspensoes.length > 0 ? suspensoes.join(', ') : '(none)'}`);

  // ─── Detect format type ───
  const isDetailed = textoTotal.includes('EMENTA:') && /APROVADO\(A\)|REPROVADO\(A\)/.test(textoTotal);
  console.log(`${LOG_PREFIX} [FORMAT] ${isDetailed ? 'DETAILED (with EMENTA)' : 'SIMPLE'}`);

  // ─── Extract disciplines ───
  let disciplinas = [];

  if (isDetailed) {
    disciplinas = extrairDisciplinasDetalhado(textoTotal, linhas);
  } else {
    disciplinas = extrairDisciplinasDaLinha(textoTotal, linhas);
  }

  const regularCount = disciplinas.length;
  console.log(`${LOG_PREFIX} [DISCIPLINAS] Found ${regularCount} regular disciplines`);

  // ─── Pending disciplines ───
  const pendentes = extrairDisciplinasPendentes(textoTotal);
  disciplinas.push(...pendentes);
  console.log(`${LOG_PREFIX} [PENDENTES] Found ${pendentes.length} pending disciplines`);

  // ─── Equivalências ───
  const equivalencias = extrairEquivalencias(textoTotal);
  console.log(`${LOG_PREFIX} [EQUIVALENCIAS] Found ${equivalencias.length} equivalencies`);

  // ─── Status counts ───
  const countMap = {};
  const rePendencias = /\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b/gi;
  let statMatch;
  while ((statMatch = rePendencias.exec(textoTotal)) !== null) {
    const key = statMatch[1].toUpperCase();
    countMap[key] = (countMap[key] || 0) + 1;
  }
  if (Object.keys(countMap).length > 0) {
    disciplinas.push({
      tipo_dado: 'Pendencias',
      nome: '', status: '', mencao: '', creditos: 0, codigo: '', carga_horaria: 0,
      ano_periodo: '', prefixo: '', professor: '', turma: '', frequencia: null, nota: null,
      valores: countMap,
    });
  }

  // ─── IRA entry ───
  if (ira !== null) {
    disciplinas.push({
      tipo_dado: 'IRA',
      nome: '', status: '', mencao: '', creditos: 0, codigo: '', carga_horaria: 0,
      ano_periodo: '', prefixo: '', professor: '', turma: '', frequencia: null, nota: null,
      IRA: 'IRA', valor: ira,
    });
  }

  // ─── Semester ───
  const semestreAtual = extrairSemestreAtual(disciplinas);
  const numeroSemestre = calcularNumeroSemestre(disciplinas);

  console.log(`${LOG_PREFIX} [SEMESTRE] Current: ${semestreAtual ?? '(not found)'}, Number: ${numeroSemestre}`);
  console.log(`${LOG_PREFIX} === EXTRACTION COMPLETE: ${disciplinas.length} total items ===`);

  return {
    disciplinas,
    equivalencias,
    curso,
    matriz_curricular: matrizCurricular,
    media_ponderada: mediaPonderada,
    ira,
    semestre_atual: semestreAtual,
    numero_semestre: numeroSemestre,
    suspensoes,
  };
}

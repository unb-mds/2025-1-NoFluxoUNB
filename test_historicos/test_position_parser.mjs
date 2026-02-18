/**
 * test_position_parser.mjs
 * 
 * Tests the NEW position-based extractor against all test histórico PDFs.
 * Extracts positioned items with pdfjs-dist, runs the position-based parser,
 * and validates results including the known edge cases (DSC0172, FGA0412, etc.)
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import {
  extractDisciplinasFromPositions,
  extractPositionedItemsFromFile,
} from './pdfPositionExtractor.mjs';
import {
  extrairCurso,
  extrairMatrizCurricular,
  extrairSuspensoes,
  extrairSemestreAtual,
  calcularNumeroSemestre,
} from './pdfDataExtractor.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pdfDir = path.join(__dirname, 'historicos');
const textDir = path.join(__dirname, 'extracted_texts');

// ─── Constants for space-based text extraction (for metadata) ───
const Y_PROXIMITY_THRESHOLD = 3;
const SPACE_GAP_THRESHOLD = 10;
const CHAR_WIDTH_ESTIMATE = 6;
const MAX_SPACES = 10;

function groupItemsIntoLines(items) {
  const lines = new Map();
  for (const item of items) {
    let assignedY = null;
    for (const existingY of lines.keys()) {
      if (Math.abs(item.y - existingY) <= Y_PROXIMITY_THRESHOLD) {
        assignedY = existingY;
        break;
      }
    }
    if (assignedY !== null) lines.get(assignedY).push(item);
    else lines.set(item.y, [item]);
  }
  return lines;
}

function reconstructLine(items) {
  items.sort((a, b) => a.x - b.x);
  let result = '';
  let lastX = -Infinity;
  for (const item of items) {
    if (lastX > -Infinity && item.x > lastX + SPACE_GAP_THRESHOLD) {
      const gap = item.x - lastX;
      const spaceCount = Math.min(Math.max(1, Math.floor(gap / CHAR_WIDTH_ESTIMATE)), MAX_SPACES);
      result += ' '.repeat(spaceCount);
    }
    result += item.text;
    const textWidth = item.width > 0 ? item.width : item.text.length * CHAR_WIDTH_ESTIMATE;
    lastX = item.x + textWidth;
  }
  return result;
}

function buildFlatText(pages) {
  const allLines = [];
  for (let pageIdx = 0; pageIdx < pages.length; pageIdx++) {
    const lineGroups = groupItemsIntoLines(pages[pageIdx]);
    for (const [y, lineItems] of lineGroups.entries()) {
      const lineText = reconstructLine([...lineItems]);
      if (lineText.trim()) {
        allLines.push([y, lineText, pageIdx + 1]);
      }
    }
  }
  allLines.sort((a, b) => {
    if (a[2] !== b[2]) return a[2] - b[2];
    return b[0] - a[0];
  });
  return allLines.map(([, text]) => text).join('\n');
}

// ─── Pending disciplines (regex, from flat text) ───

function extrairDisciplinasPendentes(text) {
  const disciplinas = [];
  const pendMatch = text.match(/Componentes Curriculares Obrigat[óo]rios Pendentes:\s*(\d+)/i);
  if (!pendMatch) return disciplinas;
  const pendIdx = text.indexOf(pendMatch[0]);
  const pendSection = text.substring(pendIdx);
  const linhas = pendSection.split('\n');
  const reHeader = /^C[óo]digo\s+Componente/i;
  let started = false;
  for (const linha of linhas) {
    if (reHeader.test(linha.trim())) { started = true; continue; }
    if (!started) continue;
    if (/^(Observações|Equivalências|Para verificar|Atenção|SIGAA|Componentes Curriculares Optativos)/i.test(linha.trim())) break;
    const m = linha.match(/^\s*([A-Z]{2,}\d{3,}|ENADE|-)\s+(.+?)\s+(?:(Matriculado(?:\s+em\s+Equivalente)?)\s+)?(\d+)\s*h/i);
    if (m) {
      const [, codigo, nome, matriculado, chStr] = m;
      if (codigo === '-') continue;
      if (/^(?:Dr\.|Dra\.|MSc\.|Prof\.)\s/i.test(nome.trim())) continue;
      if (/\(\d+h\)/i.test(nome)) continue;
      disciplinas.push({
        tipo_dado: 'Disciplina Pendente',
        nome: nome.replace(/^[^a-zA-ZÀ-ÿ0-9]+/, '').replace(/[^a-zA-ZÀ-ÿ0-9]+$/, '').replace(/\s{2,}/g, ' ').trim(),
        status: matriculado ? 'MATR' : 'PENDENTE',
        mencao: '-',
        creditos: Math.floor(parseInt(chStr) / 15),
        codigo: codigo === 'ENADE' ? 'ENADE' : codigo,
        carga_horaria: parseInt(chStr),
        ano_periodo: '', prefixo: '', professor: '', turma: '', frequencia: null, nota: null,
        ...(matriculado ? { observacao: matriculado } : {}),
      });
    }
  }
  return disciplinas;
}

function extrairEquivalencias(text) {
  const equivalencias = [];
  const reEquiv = /Cumpriu\s+([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9-]+?)\s*\((\d+)h\)\s*atrav[eé]s\s*de\s*([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9-]+?)\s*\((\d+)h\)/gi;
  let eqMatch;
  while ((eqMatch = reEquiv.exec(text)) !== null) {
    equivalencias.push({
      cumpriu: eqMatch[1], nome_cumpriu: eqMatch[2].trim(),
      atraves_de: eqMatch[4], nome_equivalente: eqMatch[5].trim(),
      ch_cumpriu: eqMatch[3], ch_equivalente: eqMatch[6],
    });
  }
  return equivalencias;
}

// ─── Expected values for validation ───
const EXPECTED = {
  'historico_190012579 (5) (1).pdf': {
    curso: 'ENGENHARIA DE SOFTWARE',
    ira: 2.9863,
    mp: 3.2191,
    suspensoes: ['2020.1', '2024.1'],
    minDisciplinas: 35,
    pendentes: 20,
    equivalencias: 0,
  },
  'historico_211029503 (1).pdf': {
    curso: 'ENGENHARIA DE SOFTWARE',
    ira: 3.7389,
    mp: 3.7437,
    suspensoes: [],
    minDisciplinas: 20,
    pendentes: 0,
    equivalencias: 0,
    isDetailed: true,  // This one might be detailed format
  },
  'historico_211029503-2 copy.pdf': {
    curso: 'ENGENHARIA DE SOFTWARE',
    ira: 3.4674,
    mp: 3.7171,
    suspensoes: [],
    minDisciplinas: 18,
    pendentes: 0,
    equivalencias: 0,
  },
  'historico_222006202 (1).pdf': {
    curso: 'ENGENHARIA DE SOFTWARE',
    ira: 3.2333,
    mp: 3.5094,
    suspensoes: [],
    minDisciplinas: 25,
    pendentes: 0,
    equivalencias: 1,
  },
  'historico_222037700-1.pdf': {
    curso: 'ENGENHARIA DE SOFTWARE',
    ira: 4.3664,
    mp: 4.0855,
    suspensoes: [],
    minDisciplinas: 30,
    pendentes: 0,
    equivalencias: 1,
    // Edge case checks
    checkDSC0172: 3,       // Should find all 3 DSC0172 entries
    checkFGA0412: true,    // Should find FGA0412 MONITORIA
    checkProfessorClean: true, // No (Xh) artifacts in professor names
  },
  'historico_222038485.pdf': {
    curso: null,  // unknown
    minDisciplinas: 0,
    pendentes: 0,
    equivalencias: 0,
  },
  'historico_232021516.pdf': {
    curso: 'ENGENHARIA',
    ira: 0.0,
    mp: 0.0,
    suspensoes: [],
    minDisciplinas: 5,
    pendentes: 20,
    equivalencias: 0,
  },
};

// ─── Test runner ───

console.log(`\n${'='.repeat(70)}`);
console.log('  POSITION-BASED PDF PARSER TEST SUITE');
console.log(`${'='.repeat(70)}\n`);

const pdfFiles = fs.readdirSync(pdfDir).filter(f => f.endsWith('.pdf'));
console.log(`Found ${pdfFiles.length} PDF files\n`);

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(label, condition, actual, expected) {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`    ✅ ${label}`);
  } else {
    failedTests++;
    console.log(`    ❌ ${label}`);
    console.log(`       Expected: ${JSON.stringify(expected)}`);
    console.log(`       Got:      ${JSON.stringify(actual)}`);
  }
}

const allResults = [];

for (const pdfFile of pdfFiles) {
  const filePath = path.join(pdfDir, pdfFile);
  const expected = EXPECTED[pdfFile] || {};

  console.log(`\n${'─'.repeat(60)}`);
  console.log(`  FILE: ${pdfFile}`);
  console.log(`${'─'.repeat(60)}`);

  try {
    // Suppress warnings
    const origWarn = console.warn;
    console.warn = () => {};

    // Extract positioned items
    const pages = await extractPositionedItemsFromFile(filePath);

    // Build flat text for metadata extraction
    const flatText = buildFlatText(pages);

    // Check if detailed format
    const isDetailed = flatText.includes('EMENTA:') && /APROVADO\(A\)|REPROVADO\(A\)/.test(flatText);

    let regularDisciplinas;
    if (isDetailed) {
      // For detailed format, fall back to regex (import dynamically)
      const { extrairDadosAcademicos } = await import('./pdfDataExtractor.mjs');
      const origLog = console.log;
      console.log = () => {};
      const dados = extrairDadosAcademicos(flatText);
      console.log = origLog;
      regularDisciplinas = dados.disciplinas.filter(d => d.tipo_dado === 'Disciplina Regular');
      console.log(`  [FORMAT: DETAILED — used regex fallback]`);
    } else {
      // Position-based extraction
      regularDisciplinas = extractDisciplinasFromPositions(pages);
      console.log(`  [FORMAT: STANDARD — position-based]`);
    }

    console.warn = origWarn;

    // Metadata (always regex-based)
    const origLog2 = console.log;
    console.log = () => {};
    const curso = extrairCurso(flatText);
    const matrizCurricular = extrairMatrizCurricular(flatText);
    const suspensoes = extrairSuspensoes(flatText);
    console.log = origLog2;

    let ira = null;
    const iraMatch = flatText.match(/IRA[:\s]+(\d+[.,]\d+)/i);
    if (iraMatch) ira = parseFloat(iraMatch[1].replace(',', '.'));

    let mp = null;
    const mpMatch = flatText.match(/MP[:\s]+(\d+[.,]\d+)/i);
    if (mpMatch) mp = parseFloat(mpMatch[1].replace(',', '.'));

    const pendentes = extrairDisciplinasPendentes(flatText);
    const equivalencias = extrairEquivalencias(flatText);

    const allDisc = [...regularDisciplinas, ...pendentes];
    const semestreAtual = extrairSemestreAtual(allDisc);
    const numeroSemestre = calcularNumeroSemestre(allDisc);

    console.log(`\n  Summary:`);
    console.log(`    Curso: ${curso}`);
    console.log(`    IRA: ${ira}`);
    console.log(`    MP: ${mp}`);
    console.log(`    Regular disciplines: ${regularDisciplinas.length}`);
    console.log(`    Pending disciplines: ${pendentes.length}`);
    console.log(`    Equivalências: ${equivalencias.length}`);
    console.log(`    Semestre atual: ${semestreAtual}`);

    // Print first few disciplines
    console.log(`\n  First 5 disciplines:`);
    for (const d of regularDisciplinas.slice(0, 5)) {
      console.log(`    ${(d.ano_periodo || '--').padEnd(7)} | ${d.codigo.padEnd(8)} | ${d.nome.substring(0, 40).padEnd(40)} | ${d.status.padEnd(5)} | ${d.mencao.padEnd(3)} | prof: ${(d.professor || '-').substring(0, 30)}`);
    }
    if (regularDisciplinas.length > 5) {
      console.log(`    ... and ${regularDisciplinas.length - 5} more`);
    }

    // ─── Assertions ───
    console.log(`\n  Tests:`);

    if (expected.curso) {
      assert(
        'Course contains expected name',
        curso && curso.toUpperCase().includes(expected.curso.toUpperCase()),
        curso,
        `contains "${expected.curso}"`,
      );
    }

    if (expected.ira !== undefined) {
      assert(
        `IRA matches (${expected.ira})`,
        ira === expected.ira,
        ira,
        expected.ira,
      );
    }

    if (expected.mp !== undefined) {
      assert(
        `MP matches (${expected.mp})`,
        mp === expected.mp,
        mp,
        expected.mp,
      );
    }

    if (expected.suspensoes) {
      assert(
        `Suspensões match`,
        JSON.stringify(suspensoes) === JSON.stringify(expected.suspensoes),
        suspensoes,
        expected.suspensoes,
      );
    }

    if (expected.minDisciplinas > 0) {
      assert(
        `Has at least ${expected.minDisciplinas} regular disciplines`,
        regularDisciplinas.length >= expected.minDisciplinas,
        regularDisciplinas.length,
        `>= ${expected.minDisciplinas}`,
      );
    }

    // Check that all disciplines have codes
    const withCodes = regularDisciplinas.filter(d => d.codigo);
    assert(
      `All regular disciplines have codes`,
      withCodes.length === regularDisciplinas.length,
      `${withCodes.length}/${regularDisciplinas.length}`,
      'all have codes',
    );

    // Check that most disciplines have names
    const withNames = regularDisciplinas.filter(d => d.nome && d.nome.length > 2);
    assert(
      `Most regular disciplines have names (>80%)`,
      withNames.length >= regularDisciplinas.length * 0.8,
      `${withNames.length}/${regularDisciplinas.length}`,
      '>80%',
    );

    // Check that all disciplines have valid statuses
    const validStatuses = new Set(['APR', 'REP', 'REPF', 'REPMF', 'CANC', 'DISP', 'TRANC', 'MATR', 'CUMP']);
    const withValidStatus = regularDisciplinas.filter(d => validStatuses.has(d.status));
    assert(
      `All disciplines have valid status`,
      withValidStatus.length === regularDisciplinas.length,
      `${withValidStatus.length}/${regularDisciplinas.length}`,
      'all valid',
    );

    if (expected.pendentes > 0) {
      assert(
        `Has pending disciplines (expected ~${expected.pendentes})`,
        pendentes.length > 0,
        pendentes.length,
        `>= 1`,
      );
    }

    if (expected.equivalencias > 0) {
      assert(
        `Has ${expected.equivalencias} equivalência(s)`,
        equivalencias.length === expected.equivalencias,
        equivalencias.length,
        expected.equivalencias,
      );
    }

    // ─── Edge-case checks for 222037700 ───
    if (expected.checkDSC0172) {
      const dsc = regularDisciplinas.filter(d => d.codigo === 'DSC0172');
      assert(
        `DSC0172 found ${expected.checkDSC0172} times (multi-line professor fix)`,
        dsc.length === expected.checkDSC0172,
        dsc.length,
        expected.checkDSC0172,
      );

      // Check that DSC0172 entries have proper names (not professor names)
      const dscWithProperName = dsc.filter(d => d.nome.includes('VIGIL'));
      assert(
        `DSC0172 entries have proper discipline name`,
        dscWithProperName.length === dsc.length,
        dscWithProperName.map(d => d.nome),
        'all contain "VIGIL"',
      );
    }

    if (expected.checkFGA0412) {
      const fga = regularDisciplinas.filter(d => d.codigo === 'FGA0412');
      assert(
        `FGA0412 found (monitoria with 0h professor)`,
        fga.length >= 1,
        fga.length,
        '>= 1',
      );
    }

    if (expected.checkProfessorClean) {
      const profIssues = regularDisciplinas.filter(d => d.professor && /\(\d+h/.test(d.professor));
      assert(
        `No professors with leftover (Xh) artifacts`,
        profIssues.length === 0,
        profIssues.map(d => `${d.codigo}: ${d.professor}`),
        'none',
      );
    }

    allResults.push({
      file: pdfFile,
      curso,
      ira,
      mp,
      regular: regularDisciplinas.length,
      pending: pendentes.length,
      equivalencias: equivalencias.length,
      semestre: semestreAtual,
      suspensoes,
    });

  } catch (err) {
    console.log(`    ❌ Error processing: ${err.message}`);
    failedTests++;
    totalTests++;
  }
}

// ─── Final summary ───
console.log(`\n\n${'='.repeat(70)}`);
console.log('  POSITION-BASED PARSER TEST RESULTS');
console.log(`${'='.repeat(70)}`);
console.log(`  Total: ${totalTests} | Passed: ${passedTests} | Failed: ${failedTests}`);
console.log(`  Pass rate: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
console.log(`${'='.repeat(70)}`);

console.log(`\n  Summary table:`);
console.log(`  ${'File'.padEnd(42)} ${'Regular'.padStart(8)} ${'Pending'.padStart(8)} ${'Equiv'.padStart(6)} ${'IRA'.padStart(7)}`);
console.log(`  ${'─'.repeat(42)} ${'─'.repeat(8)} ${'─'.repeat(8)} ${'─'.repeat(6)} ${'─'.repeat(7)}`);
for (const r of allResults) {
  console.log(`  ${r.file.substring(0, 42).padEnd(42)} ${String(r.regular).padStart(8)} ${String(r.pending).padStart(8)} ${String(r.equivalencias).padStart(6)} ${String(r.ira ?? 'N/A').padStart(7)}`);
}

// Save results
const resultsPath = path.join(__dirname, 'test_results_position.json');
fs.writeFileSync(resultsPath, JSON.stringify({
  timestamp: new Date().toISOString(),
  totalTests, passedTests, failedTests,
  results: allResults,
}, null, 2));
console.log(`\n  Results saved to: ${resultsPath}`);

console.log(`\n${'='.repeat(70)}\n`);

if (failedTests > 0) {
  process.exit(1);
}

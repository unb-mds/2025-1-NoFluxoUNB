/**
 * test_parser.mjs
 * 
 * Tests the new pdfDataExtractor against all test histórico PDFs.
 * Extracts text with pdfjs-dist, runs the parser, and reports results
 * with expected values for validation.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { extrairDadosAcademicos } from './pdfDataExtractor.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const textDir = path.join(__dirname, 'extracted_texts');

// ─── Expected values for validation ───
const EXPECTED = {
  'historico_190012579 (5) (1).txt': {
    curso: 'ENGENHARIA DE SOFTWARE',
    ira: 2.9863,
    mp: 3.2191,
    matriz: '2017.1',
    suspensoes: ['2020.1', '2024.1'],
    minDisciplinas: 47,
    pendentes: 22,
  },
  'historico_211029503 (1).txt': {
    curso: 'ENGENHARIA DE SOFTWARE',
    ira: 3.7389,
    mp: 3.7437,
    matriz: null, // detailed format may not have it easily
    suspensoes: [],
    minDisciplinas: 28,
    pendentes: 25,
  },
  'historico_211029503-2 copy.txt': {
    curso: 'ENGENHARIA DE SOFTWARE',
    ira: 3.4674,
    mp: 3.7171,
    suspensoes: [],
    minDisciplinas: 21,
    pendentes: 29,
  },
  'historico_222006202 (1).txt': {
    curso: 'ENGENHARIA DE SOFTWARE',
    ira: 3.2333,
    mp: 3.5094,
    matriz: '2017.1',
    suspensoes: [],
    minDisciplinas: 34,
    pendentes: 31,
    equivalencias: 1,
  },
  'historico_222037700-1.txt': {
    curso: 'ENGENHARIA DE SOFTWARE',
    ira: 4.3664,
    mp: 4.0855,
    matriz: '2017.1',
    suspensoes: [],
    minDisciplinas: 38,
    pendentes: 25,
    equivalencias: 2,
  },
  'historico_222038485.txt': {
    curso: 'GESTÃO DE POLÍTICAS PÚBLICAS',
    ira: 4.1975,
    mp: 4.1099,
    matriz: '2019.2',
    suspensoes: [],
    minDisciplinas: 32,
    pendentes: 6,
  },
  'historico_231014508-5_250711_141618.txt': {
    curso: 'DIREITO',
    ira: 4.9209,
    mp: 4.9015,
    matriz: '2019.2',
    suspensoes: [],
    minDisciplinas: 43,
    pendentes: 31,
  },
  'historico_231026330.txt': {
    curso: 'ENGENHARIA DE SOFTWARE',
    ira: 3.5551,
    mp: 3.4828,
    matriz: '2017.1',
    suspensoes: [],
    minDisciplinas: 35,
    pendentes: 18,
    equivalencias: 5,
  },
  'historico_232014010 (7).txt': {
    curso: 'CIÊNCIA DA COMPUTAÇÃO',
    ira: 3.9034,
    mp: 3.8421,
    matriz: '2025.1',
    suspensoes: [],
    minDisciplinas: 40,
    pendentes: 19,
    equivalencias: 4,
  },
  'historico_232021516.txt': {
    curso: 'ENGENHARIA',
    ira: 0.0,
    mp: 0.0,
    suspensoes: [],
    minDisciplinas: 6,
    pendentes: 21,
  },
};

// ─── Test runner ───

console.log(`\n${'='.repeat(70)}`);
console.log('  PDF PARSER TEST SUITE');
console.log(`${'='.repeat(70)}\n`);

const txtFiles = fs.readdirSync(textDir).filter(
  f => f.endsWith('.txt') && !f.includes('_numbered') && !f.startsWith('_')
);

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

for (const txtFile of txtFiles) {
  const text = fs.readFileSync(path.join(textDir, txtFile), 'utf-8');
  const expected = EXPECTED[txtFile];
  
  console.log(`\n${'─'.repeat(60)}`);
  console.log(`  FILE: ${txtFile}`);
  console.log(`${'─'.repeat(60)}`);
  
  const result = extrairDadosAcademicos(text);
  
  const regularDisciplinas = result.disciplinas.filter(d => d.tipo_dado === 'Disciplina Regular');
  const pendenteDisciplinas = result.disciplinas.filter(d => d.tipo_dado === 'Disciplina Pendente');
  
  console.log(`\n  Summary:`);
  console.log(`    Curso: ${result.curso}`);
  console.log(`    IRA: ${result.ira}`);
  console.log(`    MP: ${result.media_ponderada}`);
  console.log(`    Matriz: ${result.matriz_curricular}`);
  console.log(`    Regular disciplines: ${regularDisciplinas.length}`);
  console.log(`    Pending disciplines: ${pendenteDisciplinas.length}`);
  console.log(`    Equivalências: ${result.equivalencias.length}`);
  console.log(`    Semestre atual: ${result.semestre_atual}`);
  console.log(`    Nº semestre: ${result.numero_semestre}`);
  console.log(`    Suspensões: ${result.suspensoes.join(', ') || '(none)'}`);
  
  // Print first few disciplines
  console.log(`\n  First 5 disciplines:`);
  for (const d of regularDisciplinas.slice(0, 5)) {
    console.log(`    ${d.ano_periodo || '--'} | ${d.codigo.padEnd(8)} | ${d.nome.substring(0, 40).padEnd(40)} | ${d.status} | ${d.mencao} | ${d.turma} | ${d.carga_horaria}h`);
  }
  if (regularDisciplinas.length > 5) {
    console.log(`    ... and ${regularDisciplinas.length - 5} more`);
  }
  
  if (pendenteDisciplinas.length > 0) {
    console.log(`\n  First 3 pending:`);
    for (const d of pendenteDisciplinas.slice(0, 3)) {
      console.log(`    ${d.codigo.padEnd(8)} | ${d.nome.substring(0, 40).padEnd(40)} | ${d.status}`);
    }
  }
  
  if (result.equivalencias.length > 0) {
    console.log(`\n  Equivalências:`);
    for (const eq of result.equivalencias) {
      console.log(`    ${eq.cumpriu} (${eq.nome_cumpriu}) ← ${eq.atraves_de} (${eq.nome_equivalente})`);
    }
  }
  
  // ─── Assertions ───
  console.log(`\n  Tests:`);
  
  if (expected) {
    if (expected.curso) {
      assert(
        'Course contains expected name',
        result.curso && result.curso.toUpperCase().includes(expected.curso.toUpperCase()),
        result.curso,
        `contains "${expected.curso}"`
      );
    }
    
    if (expected.ira !== undefined) {
      assert(
        `IRA matches (${expected.ira})`,
        result.ira === expected.ira,
        result.ira,
        expected.ira
      );
    }
    
    if (expected.mp !== undefined) {
      assert(
        `MP matches (${expected.mp})`,
        result.media_ponderada === expected.mp,
        result.media_ponderada,
        expected.mp
      );
    }
    
    if (expected.matriz) {
      assert(
        `Matriz curricular matches (${expected.matriz})`,
        result.matriz_curricular === expected.matriz,
        result.matriz_curricular,
        expected.matriz
      );
    }
    
    assert(
      `Suspensões match`,
      JSON.stringify(result.suspensoes) === JSON.stringify(expected.suspensoes),
      result.suspensoes,
      expected.suspensoes
    );
    
    assert(
      `Has at least ${expected.minDisciplinas} regular disciplines`,
      regularDisciplinas.length >= expected.minDisciplinas,
      regularDisciplinas.length,
      `>= ${expected.minDisciplinas}`
    );
    
    // Check that disciplines have codes
    const withCodes = regularDisciplinas.filter(d => d.codigo);
    assert(
      `All regular disciplines have codes`,
      withCodes.length === regularDisciplinas.length,
      `${withCodes.length}/${regularDisciplinas.length}`,
      'all have codes'
    );
    
    // Check that disciplines have names
    const withNames = regularDisciplinas.filter(d => d.nome);
    assert(
      `Most regular disciplines have names (>80%)`,
      withNames.length >= regularDisciplinas.length * 0.8,
      `${withNames.length}/${regularDisciplinas.length}`,
      '>80%'
    );
    
    // Check that disciplines have valid statuses
    const validStatuses = new Set(['APR', 'REP', 'REPF', 'REPMF', 'CANC', 'DISP', 'TRANC', 'MATR', 'CUMP']);
    const withValidStatus = regularDisciplinas.filter(d => validStatuses.has(d.status));
    assert(
      `All disciplines have valid status`,
      withValidStatus.length === regularDisciplinas.length,
      `${withValidStatus.length}/${regularDisciplinas.length}`,
      'all valid'
    );
    
    if (expected.pendentes > 0) {
      assert(
        `Pending disciplines count matches (expected ${expected.pendentes})`,
        pendenteDisciplinas.length === expected.pendentes,
        pendenteDisciplinas.length,
        expected.pendentes
      );
    }
    
    if (expected.equivalencias) {
      assert(
        `Has ${expected.equivalencias} equivalência(s)`,
        result.equivalencias.length === expected.equivalencias,
        result.equivalencias.length,
        expected.equivalencias
      );
    }
  }
  
  allResults.push({
    file: txtFile,
    curso: result.curso,
    ira: result.ira,
    mp: result.media_ponderada,
    regular: regularDisciplinas.length,
    pending: pendenteDisciplinas.length,
    equivalencias: result.equivalencias.length,
    semestre: result.semestre_atual,
    suspensoes: result.suspensoes,
  });
}

// ─── Final summary ───
console.log(`\n\n${'='.repeat(70)}`);
console.log('  TEST RESULTS');
console.log(`${'='.repeat(70)}`);
console.log(`  Total: ${totalTests} | Passed: ${passedTests} | Failed: ${failedTests}`);
console.log(`  Pass rate: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
console.log(`${'='.repeat(70)}`);

console.log(`\n  Summary table:`);
console.log(`  ${'File'.padEnd(40)} ${'Regular'.padStart(8)} ${'Pending'.padStart(8)} ${'Equiv'.padStart(6)} ${'IRA'.padStart(7)}`);
console.log(`  ${'─'.repeat(40)} ${'─'.repeat(8)} ${'─'.repeat(8)} ${'─'.repeat(6)} ${'─'.repeat(7)}`);
for (const r of allResults) {
  console.log(`  ${r.file.substring(0, 40).padEnd(40)} ${String(r.regular).padStart(8)} ${String(r.pending).padStart(8)} ${String(r.equivalencias).padStart(6)} ${String(r.ira ?? 'N/A').padStart(7)}`);
}

// Save results to JSON
const resultsPath = path.join(__dirname, 'test_results.json');
fs.writeFileSync(resultsPath, JSON.stringify({ 
  timestamp: new Date().toISOString(),
  totalTests, passedTests, failedTests,
  results: allResults 
}, null, 2));
console.log(`\n  Results saved to: ${resultsPath}`);

console.log(`\n${'='.repeat(70)}\n`);

if (failedTests > 0) {
  process.exit(1);
}

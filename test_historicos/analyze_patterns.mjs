/**
 * analyze_patterns.mjs
 * 
 * Analyzes extracted text from all PDFs to identify and classify patterns.
 * This is the research phase — understanding how data appears in the extracted text
 * across different PDF formats, before building the parser.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const textDir = path.join(__dirname, 'extracted_texts');

// ─── Regexes for pattern detection ───

const RE_SITUACAO = /\b(APR|REP|REPF|REPMF|CANC|DISP|TRANC|MATR|CUMP)\b/;
const RE_SITUACAO_LONG = /\b(APROVADO\(A\)|REPROVADO\(A\)|CANCELADO\(A\)|DISPENSADO\(A\)|TRANCADO\(A\)|MATRICULADO\(A\)|CUMPRIU)\b/i;
const RE_ANO_PERIODO = /\b(\d{4}\.\d)\b/;
const RE_CODIGO = /\b([A-Z]{2,}\d{3,})\b/;
const RE_CH = /\b(\d{2,3})\s*h?\b/;
const RE_MENCAO = /\b(SS|MS|MM|MI|II|SR)\b/;
const RE_PROFESSOR = /(?:Dr\.|Dra\.|MSc\.|Prof\.)\s+[A-ZÀ-ÿ]/;

console.log(`\n${'='.repeat(70)}`);
console.log('  PATTERN ANALYSIS');
console.log(`${'='.repeat(70)}\n`);

const txtFiles = fs.readdirSync(textDir).filter(f => f.endsWith('.txt') && !f.includes('_numbered') && !f.startsWith('_'));

for (const txtFile of txtFiles) {
  const text = fs.readFileSync(path.join(textDir, txtFile), 'utf-8');
  const lines = text.split('\n');
  
  console.log(`\n${'─'.repeat(60)}`);
  console.log(`  FILE: ${txtFile}`);
  console.log(`  Lines: ${lines.length}, Chars: ${text.length}`);
  console.log(`${'─'.repeat(60)}`);
  
  // Detect format type
  const hasEmenta = text.includes('EMENTA:');
  const hasLongSituacao = RE_SITUACAO_LONG.test(text);
  const hasProfessorSeparate = lines.some((l, i) => 
    i > 0 && RE_PROFESSOR.test(l) && !RE_CODIGO.test(l.slice(0, 20))
  );
  
  console.log(`  Has EMENTA (detailed format): ${hasEmenta}`);
  console.log(`  Has long situação (APROVADO(A)): ${hasLongSituacao}`);
  console.log(`  Has separate professor lines: ${hasProfessorSeparate}`);
  
  // ─── Classify discipline lines ───
  
  // Pattern: single-line discipline (code + name on same line)
  // e.g. "2021.1  * CIC0004ALGORITMOS E PROG...  90  AA  100,0  SS  APR"
  const singleLineRegex = /^(\d{4}\.\d)\s+([*&#e@§%]*)\s*([A-Z]{2,}\d{3,})(.+?)\s+(\d{2,3})\s+(\S+)\s+(\d{1,3}[,.]?\d*|--)\s+(SS|MS|MM|MI|II|SR|-|---)\s+(APR|REP|REPF|REPMF|CANC|DISP|TRANC|MATR|CUMP)\b/;
  
  // Pattern: data line with separate name above
  // e.g. "2019.1  * CIC0004          90    AA   92,0  MM   APR"  
  const dataLineRegex = /^(\d{4}\.\d)\s+([*&#e@§%]*)\s*([A-Z]{2,}\d{3,})\s+(\d{2,3})\s+(\S+)\s+(\d{1,3}[,.]?\d*|--)\s+(SS|MS|MM|MI|II|SR|-|---)\s+(APR|REP|REPF|REPMF|CANC|DISP|TRANC|MATR|CUMP)\b/;
  
  // Pattern: data line with professor embedded
  // e.g. "2022.2  & CIC0004Dr. GIOVANNI...(90h)  90  08  --  -  TRANC"
  const profEmbeddedRegex = /^(\d{4}\.\d)\s+([*&#e@§%]*)\s*([A-Z]{2,}\d{3,})(?:Dr\.|Dra\.|MSc\.|Prof\.)/;
  
  // Pattern: CUMP/DISP without period on separate line
  // e.g. "--   * FGA0221INTELIGÊNCIA ARTIFICIAL  60  --  --  -  CUMP"
  const cumpRegex = /^--\s+([*&#e@§%]*)\s*([A-Z]{2,}\d{3,})/;
  
  // Pattern: detailed format discipline line
  // e.g. "ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES          90    APROVADO(A)"
  const detailedLineRegex = /^([A-ZÀ-ÿ][A-ZÀ-ÿ\s0-9]+)\s+(\d{2,3})\s+(APROVADO|REPROVADO|CANCELADO|DISPENSADO|TRANCADO|MATRICULADO|CUMPRIU)/i;
  
  let singleLineCount = 0;
  let dataLineCount = 0;
  let profEmbeddedCount = 0;
  let cumpCount = 0;
  let detailedCount = 0;
  let unmatchedSituacao = 0;
  
  const disciplineExamples = [];
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    if (detailedLineRegex.test(line)) {
      detailedCount++;
      if (detailedCount <= 3) disciplineExamples.push({ type: 'DETAILED', line: i, text: line.substring(0, 100) });
      continue;
    }
    
    if (profEmbeddedRegex.test(line)) {
      profEmbeddedCount++;
      if (profEmbeddedCount <= 3) disciplineExamples.push({ type: 'PROF_EMBEDDED', line: i, text: line.substring(0, 100) });
      continue;
    }
    
    if (cumpRegex.test(line)) {
      cumpCount++;
      if (cumpCount <= 2) disciplineExamples.push({ type: 'CUMP_NOPRD', line: i, text: line.substring(0, 100) });
      continue;
    }
    
    // Check if it's a single-line (code+name together) vs data-line (code alone, name above)
    if (singleLineRegex.test(line) && !dataLineRegex.test(line)) {
      singleLineCount++;
      if (singleLineCount <= 3) disciplineExamples.push({ type: 'SINGLE_LINE', line: i, text: line.substring(0, 100) });
      continue;
    }
    
    if (dataLineRegex.test(line)) {
      // Check if there's a name on the line above
      const prevLine = i > 0 ? lines[i - 1] : '';
      const hasNameAbove = /^[A-ZÀ-ÿ][A-ZÀ-ÿ\s0-9-]+$/.test(prevLine.trim());
      dataLineCount++;
      if (dataLineCount <= 3) disciplineExamples.push({ 
        type: hasNameAbove ? 'DATA_WITH_NAME_ABOVE' : 'DATA_ONLY', 
        line: i, 
        text: line.substring(0, 100),
        prevLine: prevLine.substring(0, 60)
      });
      continue;
    }
    
    // Check for unmatched lines that contain situação
    if (RE_SITUACAO.test(line) && RE_CODIGO.test(line) && !line.includes('SIGLA') && !line.includes('SIGNIFICADO')) {
      unmatchedSituacao++;
      if (unmatchedSituacao <= 5) disciplineExamples.push({ type: 'UNMATCHED', line: i, text: line.substring(0, 120) });
    }
  }
  
  console.log(`\n  Pattern counts:`);
  console.log(`    Single-line (code+name):     ${singleLineCount}`);
  console.log(`    Data-line (name separate):   ${dataLineCount}`);
  console.log(`    Prof-embedded:               ${profEmbeddedCount}`);
  console.log(`    CUMP (no period):            ${cumpCount}`);
  console.log(`    Detailed (with ementa):      ${detailedCount}`);
  console.log(`    Unmatched with situação:     ${unmatchedSituacao}`);
  
  console.log(`\n  Examples:`);
  for (const ex of disciplineExamples) {
    console.log(`    [${ex.type}] L${ex.line}: ${ex.text}`);
    if (ex.prevLine) console.log(`      prev: ${ex.prevLine}`);
  }
  
  // ─── Extract metadata ───
  const iraMatch = text.match(/IRA[:\s]+(\d+[.,]\d+)/i);
  const mpMatch = text.match(/MP[:\s]+(\d+[.,]\d+)/i);
  const cursoMatch = text.match(/Curso:\s+(.+?)(?:\n|Status)/);
  
  console.log(`\n  Metadata:`);
  console.log(`    IRA: ${iraMatch ? iraMatch[1] : 'NOT FOUND'}`);
  console.log(`    MP: ${mpMatch ? mpMatch[1] : 'NOT FOUND'}`);
  console.log(`    Curso: ${cursoMatch ? cursoMatch[1].trim().substring(0, 60) : 'NOT FOUND'}`);
}

// ─── Equivalências analysis ───
console.log(`\n\n${'='.repeat(70)}`);
console.log('  EQUIVALÊNCIAS ANALYSIS');
console.log(`${'='.repeat(70)}`);

for (const txtFile of txtFiles) {
  const text = fs.readFileSync(path.join(textDir, txtFile), 'utf-8');
  
  const eqRegex = /Cumpriu\s+([A-Z]{2,}\d{3,})\s*-\s*(.+?)\s*\((\d+)h\)\s*atrav[eé]s\s*de\s*([A-Z]{2,}\d{3,})\s*-\s*(.+?)\s*\((\d+)h\)/gi;
  const matches = [...text.matchAll(eqRegex)];
  
  if (matches.length > 0) {
    console.log(`\n  ${txtFile}: ${matches.length} equivalências`);
    for (const m of matches.slice(0, 3)) {
      console.log(`    ${m[1]} (${m[2].trim().substring(0, 30)}) ← ${m[4]} (${m[5].trim().substring(0, 30)})`);
    }
  }
}

// ─── Pending disciplines analysis ───
console.log(`\n\n${'='.repeat(70)}`);
console.log('  PENDING DISCIPLINES ANALYSIS');
console.log(`${'='.repeat(70)}`);

for (const txtFile of txtFiles) {
  const text = fs.readFileSync(path.join(textDir, txtFile), 'utf-8');
  
  // Look for "Pendentes" section
  const pendIdx = text.indexOf('Pendentes');
  if (pendIdx > -1) {
    const pendSection = text.substring(pendIdx, pendIdx + 800);
    console.log(`\n  ${txtFile} - Pending section found:`);
    const pendLines = pendSection.split('\n').slice(0, 15);
    for (const pl of pendLines) {
      console.log(`    ${pl.substring(0, 100)}`);
    }
  }
}

console.log(`\n${'='.repeat(70)}`);
console.log('  ANALYSIS COMPLETE');
console.log(`${'='.repeat(70)}\n`);

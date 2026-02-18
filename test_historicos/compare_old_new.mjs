/**
 * compare_old_new.mjs
 * 
 * Runs BOTH the old (current Svelte) algorithm and the new algorithm
 * side-by-side, comparing results to quantify the improvement.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { extrairDadosAcademicos as newParser } from './pdfDataExtractor.mjs';
import { extrairDadosAcademicos as oldParser } from './old_parser.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const textDir = path.join(__dirname, 'extracted_texts');

console.log(`\n${'='.repeat(70)}`);
console.log('  OLD vs NEW PARSER COMPARISON');
console.log(`${'='.repeat(70)}\n`);

const txtFiles = fs.readdirSync(textDir).filter(
  f => f.endsWith('.txt') && !f.includes('_numbered') && !f.startsWith('_')
);

console.log(`${'File'.padEnd(42)} ${'Old Reg'.padStart(8)} ${'New Reg'.padStart(8)} ${'Old Pnd'.padStart(8)} ${'New Pnd'.padStart(8)} ${'Old Eq'.padStart(7)} ${'New Eq'.padStart(7)}`);
console.log(`${'─'.repeat(42)} ${'─'.repeat(8)} ${'─'.repeat(8)} ${'─'.repeat(8)} ${'─'.repeat(8)} ${'─'.repeat(7)} ${'─'.repeat(7)}`);

for (const txtFile of txtFiles) {
  const text = fs.readFileSync(path.join(textDir, txtFile), 'utf-8');
  
  // Suppress console.log during parsing
  const origLog = console.log;
  console.log = () => {};
  
  let oldResult, newResult;
  try {
    oldResult = oldParser(text);
  } catch (e) {
    oldResult = { disciplinas: [], equivalencias: [] };
  }
  newResult = newParser(text);
  
  console.log = origLog;
  
  const oldRegular = oldResult.disciplinas.filter(d => d.tipo_dado === 'Disciplina Regular').length;
  const newRegular = newResult.disciplinas.filter(d => d.tipo_dado === 'Disciplina Regular').length;
  const oldPending = oldResult.disciplinas.filter(d => d.tipo_dado === 'Disciplina Pendente').length;
  const newPending = newResult.disciplinas.filter(d => d.tipo_dado === 'Disciplina Pendente').length;
  const oldEq = oldResult.equivalencias.length;
  const newEq = newResult.equivalencias.length;
  
  const regDiff = newRegular - oldRegular;
  const pndDiff = newPending - oldPending;
  
  console.log(
    `${txtFile.substring(0, 42).padEnd(42)} ` +
    `${String(oldRegular).padStart(8)} ` +
    `${String(newRegular).padStart(8)} ` +
    `${String(oldPending).padStart(8)} ` +
    `${String(newPending).padStart(8)} ` +
    `${String(oldEq).padStart(7)} ` +
    `${String(newEq).padStart(7)}` +
    (regDiff !== 0 ? `  [reg: ${regDiff > 0 ? '+' : ''}${regDiff}]` : '') +
    (pndDiff !== 0 ? `  [pnd: ${pndDiff > 0 ? '+' : ''}${pndDiff}]` : '')
  );
}

console.log(`\n${'='.repeat(70)}\n`);

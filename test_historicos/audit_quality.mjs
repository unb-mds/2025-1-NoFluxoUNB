import {extrairDadosAcademicos} from './pdfDataExtractor.mjs';
import fs from 'fs';
const text = fs.readFileSync('/tmp/hist_222037700.txt','utf8');
const r = extrairDadosAcademicos(text);
const all = r.disciplinas.filter(x => x.tipo_dado === 'Disciplina Regular');

// Show disciplines with empty or suspicious names
const bad = all.filter(x => {
  if (!x.nome || x.nome.length < 3) return true;
  if (/^Dr\.|^Dra\.|^MSc\./i.test(x.nome)) return true;
  return false;
});

console.log('Total regular:', all.length);
console.log('Bad/empty names:', bad.length);
bad.forEach(d => console.log(d.codigo, '|', JSON.stringify(d.nome), '|', d.ano_periodo, '|', d.status));

// Count unique codigos
const codes = new Set(all.map(x => x.codigo));
console.log('Unique codes:', codes.size);

// Count how many expected DSC0172 entries (3 in the file)
console.log('DSC0172 entries found:', all.filter(x => x.codigo === 'DSC0172').length, '(expected 3)');

// Check professors with leftover (30h stuff
const profIssues = all.filter(x => x.professor && /\(\d+h/.test(x.professor));
console.log('Professors with leftover (Xh):', profIssues.length);
profIssues.forEach(d => console.log('  ', d.codigo, '|', d.professor));

// Count disciplines per semester to spot missing ones
const bySem = {};
all.forEach(d => { bySem[d.ano_periodo] = (bySem[d.ano_periodo] || 0) + 1; });
console.log('By semester:', bySem);

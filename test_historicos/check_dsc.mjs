import {extrairDadosAcademicos} from './pdfDataExtractor.mjs';
import fs from 'fs';
const text = fs.readFileSync('/tmp/hist_222037700.txt','utf8');
const r = extrairDadosAcademicos(text);
// Find bad entries 
const bad = r.disciplinas.filter(x => /LIGIA|CANTARINO/i.test(x.nome));
console.log('--- Teacher-as-name entries:', bad.length);
bad.forEach(d => console.log(JSON.stringify(d, null, 2)));
// Also find all DSC0172
const dsc = r.disciplinas.filter(x => x.codigo === 'DSC0172');
console.log('--- DSC0172 entries:', dsc.length);
dsc.forEach(d => console.log(JSON.stringify(d, null, 2)));
// Also check FGA0108
const fga = r.disciplinas.filter(x => x.codigo === 'FGA0108');
console.log('--- FGA0108 entries:', fga.length);
fga.forEach(d => console.log(JSON.stringify(d, null, 2)));

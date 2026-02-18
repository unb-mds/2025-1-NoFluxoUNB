/**
 * old_parser.mjs — The CURRENT algorithm from pdfDataExtractor.ts
 * Ported directly to JS for comparison testing.
 * This is the 8-consecutive-lines pattern matching approach.
 */

function normalizar(s) {
  return s.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toUpperCase();
}

function limparNomeDisciplina(nome) {
  let cleaned = nome;
  cleaned = cleaned.replace(/^\d{4}\.\d\s*/, '');
  cleaned = cleaned.replace(/^--\s*/, '');
  cleaned = cleaned.replace(/^[^a-zA-ZÀ-ÿ0-9]+/, '');
  cleaned = cleaned.replace(/[^a-zA-ZÀ-ÿ0-9]+$/, '');
  cleaned = cleaned.replace(/\s{2,}/g, ' ');
  return cleaned.trim();
}

function limparNomeProfessor(nome) {
  let cleaned = nome;
  cleaned = cleaned.replace(/^(?:Dr\.|Dra\.|MSc\.|Prof\.|PhD\.?|Me\.|Ma\.)\s*/gi, '');
  cleaned = cleaned.replace(/[^a-zA-ZÀ-ÿ\s]+$/, '');
  cleaned = cleaned.replace(/\s{2,}/g, ' ');
  return cleaned.trim();
}

function extrairCurso(texto) {
  let m = texto.match(/Curso:\s*\n([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+(?:DE\s+[A-ZÀ-ÿ\s]+)*)\/[A-Z]+ - [A-ZÀ-ÿ\s]+ - [A-ZÀ-ÿ]+/mi);
  if (m) return m[1].trim();
  m = texto.match(/^([A-ZÀ-ÿ\s]+(?:DE\s+[A-ZÀ-ÿ\s]+)*)\/[A-Z]+ - [A-ZÀ-ÿ\s]+ - [A-ZÀ-ÿ]+/mi);
  if (m) return m[1].trim();
  m = texto.match(/Curso[:\s]+([A-ZÀ-Ÿ\s/\\-]+?)(?:\s+Status:|$)/mi);
  if (m) return m[1].trim();
  return null;
}

function extrairMatrizCurricular(texto) {
  let m = texto.match(/Curr[ií]culo:\s*\n(\d+\/\d+)\s*-\s*(\d{4}\.\d)/mi);
  if (m) return m[2];
  m = texto.match(/(\d+\/\d+\s*-\s*(\d{4}\.\d))/m);
  if (m) return m[2];
  return null;
}

function extrairSuspensoes(texto) {
  const m = texto.match(/Suspens[õo]es:\s*\n((?:\d{4}\.\d(?:\s*,\s*\d{4}\.\d)*)?)/mi);
  if (m && m[1]?.trim()) {
    return m[1].split(',').map(s => s.trim()).filter(Boolean);
  }
  return [];
}

function extrairSemestreAtual(disciplinas) {
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

function calcularNumeroSemestre(disciplinas) {
  const validStatuses = new Set(['APR', 'REP', 'REPF', 'REPMF', 'CUMP']);
  const uniqueSemesters = new Set();
  for (const d of disciplinas) {
    if (validStatuses.has(d.status) && d.ano_periodo) {
      uniqueSemesters.add(d.ano_periodo);
    }
  }
  return uniqueSemesters.size > 0 ? uniqueSemesters.size + 1 : 1;
}

export function extrairDadosAcademicos(textoTotal) {
  const curso = extrairCurso(textoTotal);
  const matrizCurricular = extrairMatrizCurricular(textoTotal);
  const suspensoes = extrairSuspensoes(textoTotal);

  let ira = null;
  const iraMatch = textoTotal.match(/IRA[:\s]+(\d+[.,]\d+)/i);
  if (iraMatch) ira = parseFloat(iraMatch[1].replace(',', '.'));

  let mediaPonderada = null;
  const mpMatch = textoTotal.match(/MP[:\s]+(\d+[.,]\d+)/i);
  if (mpMatch) mediaPonderada = parseFloat(mpMatch[1].replace(',', '.'));

  const disciplinas = [];
  const linhas = textoTotal.split('\n').map(l => l.trim());

  const reAnoPeriodo = /^(\d{4}\.\d)$/;
  const reNome = /^([A-ZÀ-ÿ][A-ZÀ-ÿ0-9](?:[A-ZÀ-ÿ0-9 -]*[A-ZÀ-ÿ0-9])?)$/i;
  const reTurma = /^([A-Z0-9]{1,3})$/;
  const reSituacao = /^(MATR|APR|REP|REPF|REPMF|CANC|DISP|TRANC)$/;
  const reCodigo = /^([A-Z]{2,}\d{3,})$/;
  const reCargaHoraria = /^(\d{1,3})$/;
  const reFrequencia = /^(\d{1,3}[,.]\d+|--|\d{1,3})$/;
  const reMencao = /^(SS|MS|MM|MI|II|SR|-)$/;
  const reSimbolos = /^([*&#e@§%]+)\s*$/;
  const reProfessor = /(?:Dr\.|Dra\.|MSc\.|Prof\.)?\s*([A-ZÀ-ÿ\s.]+?)\s*\((\d+)h\)/i;

  let i = 0;
  while (i < linhas.length - 7) {
    let matched = false;

    // Pattern A: ano_periodo first
    if (
      reAnoPeriodo.test(linhas[i]) &&
      reNome.test(linhas[i + 1]) &&
      reTurma.test(linhas[i + 2]) &&
      reSituacao.test(linhas[i + 3]) &&
      reCodigo.test(linhas[i + 4]) &&
      reCargaHoraria.test(linhas[i + 5]) &&
      reFrequencia.test(linhas[i + 6]) &&
      reMencao.test(linhas[i + 7])
    ) {
      const anoPeriodo = linhas[i].match(reAnoPeriodo)[1];
      const nome = linhas[i + 1].match(reNome)[1];
      const turma = linhas[i + 2].match(reTurma)[1];
      const situacao = linhas[i + 3].match(reSituacao)[1];
      const codigo = linhas[i + 4].match(reCodigo)[1];
      let cargaH = linhas[i + 5].match(reCargaHoraria)[1];
      const freq = linhas[i + 6].match(reFrequencia)[1];
      const mencao = linhas[i + 7].match(reMencao)[1];

      if (mencao === 'II' || mencao === 'MI' || mencao === 'SR') { i += 8; continue; }

      let nextIdx = i + 8;
      let simbolos = '', professor = '';

      if (nextIdx < linhas.length && reSimbolos.test(linhas[nextIdx])) {
        simbolos = linhas[nextIdx].match(reSimbolos)[1];
        nextIdx++;
      }
      if (nextIdx < linhas.length) {
        const profMatch = linhas[nextIdx].match(reProfessor);
        if (profMatch) {
          professor = profMatch[1];
          if (profMatch[2]) cargaH = profMatch[2];
          nextIdx++;
        }
      }

      const cargaHNum = parseInt(cargaH) || 0;
      disciplinas.push({
        tipo_dado: 'Disciplina Regular', nome: limparNomeDisciplina(nome), status: situacao,
        mencao: mencao !== '-' ? mencao : '-', creditos: cargaHNum > 0 ? Math.floor(cargaHNum / 15) : 0,
        codigo, carga_horaria: cargaHNum, ano_periodo: anoPeriodo, prefixo: simbolos,
        professor: limparNomeProfessor(professor), turma, frequencia: freq !== '--' ? freq : null, nota: null,
      });

      i = nextIdx;
      matched = true;
    }

    // Pattern B: nome first
    if (!matched &&
      reNome.test(linhas[i]) &&
      reAnoPeriodo.test(linhas[i + 1]) &&
      reTurma.test(linhas[i + 2]) &&
      reSituacao.test(linhas[i + 3]) &&
      reCodigo.test(linhas[i + 4]) &&
      reCargaHoraria.test(linhas[i + 5]) &&
      reFrequencia.test(linhas[i + 6]) &&
      reMencao.test(linhas[i + 7])
    ) {
      const nome = linhas[i].match(reNome)[1];
      const anoPeriodo = linhas[i + 1].match(reAnoPeriodo)[1];
      const turma = linhas[i + 2].match(reTurma)[1];
      const situacao = linhas[i + 3].match(reSituacao)[1];
      const codigo = linhas[i + 4].match(reCodigo)[1];
      let cargaH = linhas[i + 5].match(reCargaHoraria)[1];
      const freq = linhas[i + 6].match(reFrequencia)[1];
      const mencao = linhas[i + 7].match(reMencao)[1];

      if (mencao === 'II' || mencao === 'MI' || mencao === 'SR') { i += 8; continue; }

      let nextIdx = i + 8;
      let simbolos = '', professor = '';

      if (nextIdx < linhas.length && reSimbolos.test(linhas[nextIdx])) {
        simbolos = linhas[nextIdx].match(reSimbolos)[1];
        nextIdx++;
      }
      if (nextIdx < linhas.length) {
        const profMatch = linhas[nextIdx].match(reProfessor);
        if (profMatch) {
          professor = profMatch[1];
          if (profMatch[2]) cargaH = profMatch[2];
          nextIdx++;
        }
      }

      const cargaHNum = parseInt(cargaH) || 0;
      disciplinas.push({
        tipo_dado: 'Disciplina Regular', nome: limparNomeDisciplina(nome), status: situacao,
        mencao: mencao !== '-' ? mencao : '-', creditos: cargaHNum > 0 ? Math.floor(cargaHNum / 15) : 0,
        codigo, carga_horaria: cargaHNum, ano_periodo: anoPeriodo, prefixo: simbolos,
        professor: limparNomeProfessor(professor), turma, frequencia: freq !== '--' ? freq : null, nota: null,
      });

      i = nextIdx;
      matched = true;
    }

    if (!matched) i++;
  }

  // Pending disciplines
  const rePendente = /^\s+([A-ZÀ-Ÿ\s0-9]+(?:DE\s+[A-ZÀ-Ÿ\s0-9]*)*)\s+(\d+)\s*h\s+([A-Z]{2,}\d{3,})(?:\s+(Matriculado|Matriculado em Equivalente))?/gmi;
  let pendMatch;
  while ((pendMatch = rePendente.exec(textoTotal)) !== null) {
    disciplinas.push({
      tipo_dado: 'Disciplina Pendente', nome: limparNomeDisciplina(pendMatch[1]),
      status: pendMatch[4] ? 'MATR' : 'PENDENTE', mencao: '-',
      creditos: Math.floor(parseInt(pendMatch[2]) / 15), codigo: pendMatch[3],
      carga_horaria: parseInt(pendMatch[2]), ano_periodo: '', prefixo: '',
      professor: '', turma: '', frequencia: null, nota: null,
      ...(pendMatch[4] ? { observacao: pendMatch[4] } : {}),
    });
  }

  // Equivalencias
  const equivalencias = [];
  const reEquiv = /Cumpriu\s+([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9]+?)\s*\((\d+)h\)\s*atrav[eé]s\s*de\s*([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9]+?)\s*\((\d+)h\)/gmi;
  let eqMatch;
  while ((eqMatch = reEquiv.exec(textoTotal)) !== null) {
    equivalencias.push({
      cumpriu: eqMatch[1], nome_cumpriu: eqMatch[2].trim(),
      atraves_de: eqMatch[4], nome_equivalente: eqMatch[5].trim(),
      ch_cumpriu: eqMatch[3], ch_equivalente: eqMatch[6],
    });
  }

  // Pendencias count
  const countMap = {};
  const rePendencias = /\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b/gi;
  let statMatch;
  while ((statMatch = rePendencias.exec(textoTotal)) !== null) {
    const key = statMatch[1].toUpperCase();
    countMap[key] = (countMap[key] || 0) + 1;
  }
  if (Object.keys(countMap).length > 0) {
    disciplinas.push({
      tipo_dado: 'Pendencias', nome: '', status: '', mencao: '', creditos: 0,
      codigo: '', carga_horaria: 0, ano_periodo: '', prefixo: '', professor: '',
      turma: '', frequencia: null, nota: null, valores: countMap,
    });
  }

  if (ira !== null) {
    disciplinas.push({
      tipo_dado: 'IRA', nome: '', status: '', mencao: '', creditos: 0,
      codigo: '', carga_horaria: 0, ano_periodo: '', prefixo: '', professor: '',
      turma: '', frequencia: null, nota: null, IRA: 'IRA', valor: ira,
    });
  }

  const semestreAtual = extrairSemestreAtual(disciplinas);
  const numeroSemestre = calcularNumeroSemestre(disciplinas);

  return {
    disciplinas, equivalencias, curso, matriz_curricular: matrizCurricular,
    media_ponderada: mediaPonderada, ira, semestre_atual: semestreAtual,
    numero_semestre: numeroSemestre, suspensoes,
  };
}

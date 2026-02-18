/**
 * pdfPositionExtractor.mjs — Node.js version of position-based discipline extraction
 * 
 * Mirrors: no_fluxo_frontend_svelte/src/lib/services/pdf/pdfPositionExtractor.ts
 * Used for testing with test_historicos PDFs.
 */

const LOG_PREFIX = '[PDF-PositionExtractor]';

// ─── Column layout defaults ───

const DEFAULT_COLUMNS = {
  periodMax: 75,
  symbolMin: 75,
  symbolMax: 88,
  codeMin: 88,
  codeMax: 128,
  contentMin: 128,
  contentMax: 410,
  chMin: 410,
  chMax: 440,
  turmaMin: 440,
  turmaMax: 470,
  freqMin: 470,
  freqMax: 502,
  notaMin: 502,
  notaMax: 530,
  sitMin: 530,
};

// ─── Y-proximity grouping ───

const Y_PROXIMITY_THRESHOLD = 3;

function groupItemsIntoRows(items) {
  const rows = new Map();
  for (const item of items) {
    let assignedY = null;
    for (const existingY of rows.keys()) {
      if (Math.abs(item.y - existingY) <= Y_PROXIMITY_THRESHOLD) {
        assignedY = existingY;
        break;
      }
    }
    if (assignedY !== null) {
      rows.get(assignedY).push(item);
    } else {
      rows.set(item.y, [item]);
    }
  }
  return rows;
}

// ─── Column detection ───

function detectColumns(allItems) {
  for (const pageItems of allItems) {
    const rows = groupItemsIntoRows(pageItems);
    for (const [, rowItems] of rows) {
      const texts = rowItems.map(it => it.text);
      const joined = texts.join(' ');
      if (joined.includes('CH') && (joined.includes('Turma') || joined.includes('Situação'))) {
        const cols = { ...DEFAULT_COLUMNS };
        for (const item of rowItems) {
          const t = item.text;
          if (t === 'CH') {
            cols.chMin = item.x - 5;
            cols.chMax = item.x + item.width + 15;
            cols.contentMax = item.x - 5;
          } else if (t === 'Turma') {
            cols.turmaMin = item.x - 5;
            cols.turmaMax = item.x + item.width + 10;
          } else if (t.startsWith('Freq') || t === 'Freq') {
            cols.freqMin = item.x - 5;
            cols.freqMax = item.x + 25;
          } else if (t === 'Nota') {
            cols.notaMin = item.x - 5;
            cols.notaMax = item.x + item.width + 10;
          } else if (t === 'Situação') {
            cols.sitMin = item.x - 5;
          }
        }
        return cols;
      }
    }
  }
  return DEFAULT_COLUMNS;
}

// ─── Row classification ───

const RE_VALID_STATUS = /^(APR|REP|REPF|REPMF|CANC|DISP|TRANC|MATR|CUMP)$/;
const RE_PERIOD = /^(\d{4}\.?\d?|--)$/;
const RE_CODE = /^[A-Z]{2,}\d{3,}$/;
const RE_PROFESSOR_START = /(?:^|\b)(?:Dr\.|Dra\.|MSc\.|Prof\.)\s/i;
const RE_PROFESSOR_HOURS = /\(\d+h\)/;

const RE_METADATA_PATTERNS = [
  /^SIGAA\b/i, /^UnB\b/i, /^DEG\b/i, /^SAA\b/i, /^Campus\b/i,
  /^Credenciada\b/i, /^na seção/i, /^Histórico Escolar/i, /^Dados/i,
  /^Nome:/i, /^Data de/i, /^Nacionalidade/i, /^Nº do/i, /^Curso:/i,
  /^Status:/i, /^Índices/i, /^Ênfase/i, /^IRA:/i, /^Currículo/i, /^MP:/i,
  /^Reconhecimento/i, /^Ano\s*\/?\s*Período/i, /^Forma de/i,
  /^Período Letivo/i, /^Suspens[õo]es/i, /^Prorrogações/i,
  /^Tipo Saída/i, /^Data da/i, /^Trabalho de/i, /^Para verificar/i,
  /^Página/i, /^e o código/i, /^Componentes Curriculares/i,
  /^Código\s+Componente/i, /^Observações/i, /^Atenção/i, /^Menções/i,
  /^Equivalências/i, /^Matrícula/i, /^Perfil/i, /^Prazo/i,
  /^Legenda/i, /^SIGLA/i, /^Carga Horária/i, /^Obrigatórias/i, /^Optativos/i,
  /^Complementares/i, /^Total/i, /^Exigido/i, /^Integralizado/i,
  /^Pendente/i, /^Nenhum/i, /^Descrição/i, /^INGRESSANTE/i,
  /^Letivo\s+Componente/i, /^\d+\s*períodos?\s*letivos?/i,
  /^Sistema Integrado/i, /^Universidade/i, /^Decanato/i, /^Secretaria/i,
  /^Centro de Vivência/i, /^Asa Norte/i, /^CEP\b/i,
  /^Portaria/i, /^ENEM/i,
];

function isMetadataText(text) {
  for (const re of RE_METADATA_PATTERNS) {
    if (re.test(text.trim())) return true;
  }
  return false;
}

function classifyRow(y, page, items, cols) {
  const sorted = [...items].sort((a, b) => a.x - b.x);

  let period = '';
  let symbol = '';
  let code = '';
  const contentParts = [];
  const contentItems = [];
  let ch = '';
  let turma = '';
  let freq = '';
  let nota = '';
  let situacao = '';

  for (const item of sorted) {
    const x = item.x;
    const t = item.text;

    if (x < cols.periodMax) {
      if (RE_PERIOD.test(t) || /^\d{4}$/.test(t)) {
        period = period ? period + t : t;
      } else if (/^\.\d$/.test(t)) {
        period = period + t;
      }
    } else if (x >= cols.symbolMin && x < cols.symbolMax) {
      if (/^[*&#e@§%#]$/.test(t)) {
        symbol = t;
      } else if (RE_CODE.test(t)) {
        code = t;
      }
    } else if (x >= cols.codeMin && x < cols.codeMax) {
      if (RE_CODE.test(t)) {
        code = t;
      } else {
        contentParts.push(t);
        contentItems.push(item);
      }
    } else if (x >= cols.contentMin && x < cols.contentMax) {
      contentParts.push(t);
      contentItems.push(item);
    } else if (x >= cols.chMin && x < cols.chMax) {
      ch = t;
    } else if (x >= cols.turmaMin && x < cols.turmaMax) {
      if (!turma) turma = t;
      else turma += t;
    } else if (x >= cols.freqMin && x < cols.freqMax) {
      if (!freq) freq = t;
      else freq += t;
    } else if (x >= cols.notaMin && x < cols.notaMax) {
      if (!nota) nota = t;
      else nota += t;
    } else if (x >= cols.sitMin) {
      if (!situacao) situacao = t;
      else situacao += t;
    }
  }

  const content = contentParts.join(' ');

  // Determine row type
  let rowType = 'unknown';

  if (content.includes('Componente') && (content.includes('Curricular') || content.includes('CH'))) {
    rowType = 'header';
  } else if (content === 'Letivo' || /^Ano\/?Período$/i.test(content)) {
    rowType = 'header';
  } else if (isMetadataText(content) || isMetadataText(period + ' ' + content)) {
    rowType = 'metadata';
  } else if ((period || code) && RE_VALID_STATUS.test(situacao)) {
    rowType = 'data';
  } else if ((period || code) && ch && !situacao) {
    rowType = 'data';
  } else if (content && !period && !code && !ch && !turma && !situacao) {
    if (RE_PROFESSOR_HOURS.test(content) && content.length < 20) {
      rowType = 'continuation';
    } else if (RE_PROFESSOR_START.test(content)) {
      rowType = 'continuation';
    } else if (content.length > 2 && /^[A-ZÀ-ÿ(]/.test(content)) {
      rowType = 'name-only';
    }
  }

  return { y, page, period, symbol, code, content, contentItems, ch, turma, freq, nota, situacao, rowType };
}

// ─── Content splitting ───

function splitContentIntoProfessorAndName(content) {
  if (!content) return { name: '', professor: '' };

  if (RE_PROFESSOR_START.test(content)) {
    return { name: '', professor: content };
  }

  const profIdx = content.search(/(?:Dr\.|Dra\.|MSc\.|Prof\.)\s/i);
  if (profIdx > 0) {
    return {
      name: content.substring(0, profIdx).trim(),
      professor: content.substring(profIdx).trim(),
    };
  }

  return { name: content, professor: '' };
}

// ─── Cleanup ───

function cleanProfessorName(raw) {
  if (!raw) return '';

  const parts = raw.split(/,\s*/);
  const names = [];

  for (let part of parts) {
    part = part.trim();
    if (!part) continue;

    part = part.replace(/^(?:Dr\.|Dra\.|MSc\.|Prof\.|PhD\.?|Me\.|Ma\.)\s*/gi, '');
    part = part.replace(/\s*\(\d+h\)/g, '');
    part = part.replace(/[^a-zA-ZÀ-ÿ\s]+$/, '');
    part = part.replace(/^\s*[^a-zA-ZÀ-ÿ]+/, '');
    part = part.replace(/\s{2,}/g, ' ').trim();

    if (part.length > 1) {
      names.push(part);
    }
  }

  return names.join(', ');
}

function cleanDisciplineName(raw) {
  let cleaned = raw;
  cleaned = cleaned.replace(/^\d{4}\.\d\s*/, '');
  cleaned = cleaned.replace(/^--\s*/, '');
  cleaned = cleaned.replace(/^[^a-zA-ZÀ-ÿ0-9]+/, '');
  cleaned = cleaned.replace(/[^a-zA-ZÀ-ÿ0-9]+$/, '');
  cleaned = cleaned.replace(/([a-zà-ÿ])([A-ZÀ-Ÿ])/g, '$1 $2');
  cleaned = cleaned.replace(/([A-Za-zÀ-ÿ])(\d)/g, '$1 $2');
  cleaned = cleaned.replace(/(\d)([A-Za-zÀ-ÿ])/g, '$1 $2');
  cleaned = cleaned.replace(/\s{2,}/g, ' ');
  return cleaned.trim();
}

// ─── Main extraction ───

export function extractDisciplinasFromPositions(pages) {
  const cols = detectColumns(pages);

  const allRows = [];

  for (let pageIdx = 0; pageIdx < pages.length; pageIdx++) {
    const pageItems = pages[pageIdx];
    const rowGroups = groupItemsIntoRows(pageItems);

    for (const [y, items] of rowGroups) {
      const row = classifyRow(y, pageIdx + 1, items, cols);
      allRows.push(row);
    }
  }

  // Sort: page ascending, Y descending (top-to-bottom in PDF)
  allRows.sort((a, b) => {
    if (a.page !== b.page) return a.page - b.page;
    return b.y - a.y;
  });

  const disciplinas = [];

  for (let i = 0; i < allRows.length; i++) {
    const row = allRows[i];

    if (row.rowType !== 'data') continue;

    let anoPeriodo = row.period === '--' ? '' : row.period;
    if (anoPeriodo && !/^\d{4}\.\d$/.test(anoPeriodo)) {
      if (/^\d{4}\.$/.test(anoPeriodo)) {
        anoPeriodo = anoPeriodo + '0';
      }
    }

    const prefixo = row.symbol || '';
    const codigo = row.code;

    const chStr = row.ch.replace(/[^0-9]/g, '');
    const cargaH = parseInt(chStr) || 0;
    const turma = row.turma.replace(/^-+$/, '--');
    const freqRaw = row.freq.replace(/\s/g, '');
    const notaRaw = row.nota.replace(/\s/g, '');
    const situacao = row.situacao.replace(/\s/g, '');

    if (!RE_VALID_STATUS.test(situacao)) {
      continue;
    }

    const frequencia = (freqRaw === '--' || freqRaw === '-' || freqRaw === '---' || !freqRaw) ? null : freqRaw;
    const mencao = (notaRaw === '---' || notaRaw === '-' || notaRaw === '--' || !notaRaw) ? '-' : notaRaw;

    const contentSplit = splitContentIntoProfessorAndName(row.content);
    let professor = contentSplit.professor;
    let nome = contentSplit.name;

    // Look at previous rows for the discipline name
    if (i > 0) {
      const nameRows = [];
      let j = i - 1;
      while (j >= 0 && (allRows[j].rowType === 'name-only' || allRows[j].rowType === 'continuation')) {
        if (allRows[j].rowType === 'name-only') {
          nameRows.unshift(allRows[j].content);
        }
        j--;
      }

      if (nameRows.length > 0) {
        const prevName = nameRows.join(' ');
        if (!nome) {
          nome = prevName;
        } else if (/^[A-ZÀ-ÿ\s]+$/.test(prevName) && prevName.length > 5) {
          nome = prevName;
        }
        // Mark consumed
        for (let k = i - 1; k >= 0 && (allRows[k].rowType === 'name-only' || allRows[k].rowType === 'continuation'); k--) {
          allRows[k].rowType = 'unknown';
        }
      }
    }

    // Look at following rows for professor continuation
    for (let j = i + 1; j < allRows.length; j++) {
      if (allRows[j].rowType === 'continuation') {
        professor = professor ? professor + ' ' + allRows[j].content : allRows[j].content;
        allRows[j].rowType = 'unknown';
      } else {
        break;
      }
    }

    nome = cleanDisciplineName(nome);
    professor = cleanProfessorName(professor);

    disciplinas.push({
      tipo_dado: 'Disciplina Regular',
      nome,
      status: situacao,
      mencao,
      creditos: cargaH > 0 ? Math.floor(cargaH / 15) : 0,
      codigo,
      carga_horaria: cargaH,
      ano_periodo: anoPeriodo,
      prefixo,
      professor,
      turma,
      frequencia,
      nota: null,
    });
  }

  return disciplinas;
}

// ─── PDF.js positioned item extraction (for Node.js testing) ───

export async function extractPositionedItemsFromFile(filePath) {
  const fs = await import('fs');
  const pdfjsLib = await import('pdfjs-dist/legacy/build/pdf.mjs');
  
  const data = new Uint8Array(fs.readFileSync(filePath));
  const pdf = await pdfjsLib.getDocument({ data }).promise;

  const pages = [];

  for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
    const page = await pdf.getPage(pageNum);
    const textContent = await page.getTextContent();

    const items = [];
    for (const item of textContent.items) {
      if (!('str' in item)) continue;
      const text = item.str.trim();
      if (!text) continue;
      items.push({
        text,
        x: item.transform[4],
        y: item.transform[5],
        width: item.width,
      });
    }
    pages.push(items);
  }

  return pages;
}

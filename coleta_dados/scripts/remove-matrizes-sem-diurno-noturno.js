/**
 * Analisa estruturas curriculares na pasta dados/estruturas-curriculares e,
 * com --execute, remove do banco as matrizes cujo curriculo_completo NÃO contém DIURNO nem NOTURNO.
 * Também: remove duplicatas em materias_por_curso e remove órfãos (materias_por_curso cujo id_matriz não existe em matrizes).
 *
 * Uso:
 *   node scripts/remove-matrizes-sem-diurno-noturno.js                 # só estatísticas
 *   node scripts/remove-matrizes-sem-diurno-noturno.js --execute        # matrizes sem turno + duplicatas + órfãos
 *
 * Requer: SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY no .env (para --execute).
 * O script procura .env em: coleta_dados, raiz do repo e no_fluxo_backend.
 */

const fs = require('fs');
const path = require('path');

const ESTRUTURAS_DIR = path.join(__dirname, '../dados/estruturas-curriculares');

function buildCurriculoCompleto(curriculo, periodo, turno) {
  const c = (curriculo || '').trim();
  const p = (periodo || '').trim();
  const t = (turno || '').trim().toUpperCase();
  const partes = [c, p];
  if (t) partes.push(t);
  return partes.filter(Boolean).join(' - ').replace(/\s*-\s*$/, '').trim();
}

function hasDiurnoOuNoturno(curriculoCompleto) {
  const u = curriculoCompleto.toUpperCase();
  return u.includes('DIURNO') || u.includes('NOTURNO');
}

function main() {
  const execute = process.argv.includes('--execute');

  if (!fs.existsSync(ESTRUTURAS_DIR)) {
    console.error('Pasta não encontrada:', ESTRUTURAS_DIR);
    process.exit(1);
  }

  const files = fs.readdirSync(ESTRUTURAS_DIR).filter((f) => f.endsWith('.json'));
  const curriculosFromFiles = [];
  const curriculosSemTurno = [];
  const seen = new Set();

  for (const file of files) {
    const filePath = path.join(ESTRUTURAS_DIR, file);
    let data;
    try {
      const raw = fs.readFileSync(filePath, 'utf-8');
      data = JSON.parse(raw);
    } catch {
      console.warn('Arquivo inválido ou vazio:', file);
      continue;
    }

    const curriculo = data.curriculo ?? '';
    const periodo = data.periodo_letivo_vigor ?? '';
    const turno = data.turno ?? '';
    const curriculoCompleto = buildCurriculoCompleto(curriculo, periodo, turno);

    if (!curriculoCompleto) continue;

    curriculosFromFiles.push(curriculoCompleto);
    if (!hasDiurnoOuNoturno(curriculoCompleto)) {
      curriculosSemTurno.push(curriculoCompleto);
    }
    seen.add(curriculoCompleto);
  }

  const comTurno = curriculosFromFiles.filter(hasDiurnoOuNoturno).length;
  const semTurno = curriculosSemTurno.length;
  const unicos = seen.size;

  console.log('=== Estruturas curriculares (pasta JSON) ===\n');
  console.log('Total de arquivos .json:', files.length);
  console.log('curriculo_completo com DIURNO ou NOTURNO:', comTurno);
  console.log('curriculo_completo SEM DIURNO/NOTURNO (seriam excluídos):', semTurno);
  console.log('curriculo_completo únicos (distintos):', unicos);

  if (semTurno > 0) {
    console.log('\nExemplos de curriculo_completo sem turno (a excluir):');
    [...new Set(curriculosSemTurno)].slice(0, 10).forEach((c) => console.log('  -', c));
  }

  if (!execute) {
    console.log('\nPara executar a remoção no banco, rode com --execute');
    return;
  }

  // --- Execução no Supabase ---
  // Tenta .env em: coleta_dados, raiz do repo, no_fluxo_backend
  const possibleEnv = [
    path.join(__dirname, '../.env'),
    path.join(__dirname, '../../.env'),
    path.join(__dirname, '../../no_fluxo_backend/.env'),
  ];
  for (const envPath of possibleEnv) {
    if (fs.existsSync(envPath)) {
      require('dotenv').config({ path: envPath });
      break;
    }
  }

  const url = process.env.SUPABASE_URL || process.env.PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

  if (!url || !key) {
    console.error('\n[ERRO] Para --execute é necessário SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY (ou ANON) no .env');
    process.exit(1);
  }

  const { createClient } = require('@supabase/supabase-js');
  const supabase = createClient(url, key);

  const idsToRemove = [];

  (async () => {
    // --- Passo 0: remover duplicatas em materias_por_curso (mesmo id_matriz + id_materia + nivel) ---
    console.log('\n=== Removendo duplicatas em materias_por_curso ===\n');
    const allMpc = [];
    let from = 0;
    const pageSize = 1000;
    while (true) {
      const { data: page, error: errPage } = await supabase
        .from('materias_por_curso')
        .select('id_materia_curso, id_matriz, id_materia, nivel')
        .range(from, from + pageSize - 1)
        .order('id_materia_curso', { ascending: true });
      if (errPage) {
        console.error('Erro ao listar materias_por_curso:', errPage.message);
        process.exit(1);
      }
      if (!page?.length) break;
      allMpc.push(...page);
      if (page.length < pageSize) break;
      from += pageSize;
    }
    const keyFn = (r) => `${r.id_matriz}|${r.id_materia}|${r.nivel ?? ''}`;
    const seen = new Map();
    const idsDuplicatas = [];
    for (const r of allMpc) {
      const k = keyFn(r);
      if (seen.has(k)) {
        idsDuplicatas.push(r.id_materia_curso);
      } else {
        seen.set(k, r.id_materia_curso);
      }
    }
    if (idsDuplicatas.length > 0) {
      const batchSize = 200;
      for (let i = 0; i < idsDuplicatas.length; i += batchSize) {
        const batch = idsDuplicatas.slice(i, i + batchSize);
        const { error: errDel } = await supabase.from('materias_por_curso').delete().in('id_materia_curso', batch);
        if (errDel) {
          console.error('Erro ao deletar duplicatas materias_por_curso:', errDel.message);
          process.exit(1);
        }
      }
      console.log('materias_por_curso: removidas', idsDuplicatas.length, 'linhas duplicadas (mantida 1 por id_matriz+id_materia+nivel).');
    } else {
      console.log('materias_por_curso: nenhuma duplicata encontrada.');
    }

    console.log('\n=== Buscando matrizes no banco sem DIURNO/NOTURNO ===\n');

    const { data: matrizes, error: errMatrizes } = await supabase
      .from('matrizes')
      .select('id_matriz, curriculo_completo')
      .not('curriculo_completo', 'ilike', '%DIURNO%')
      .not('curriculo_completo', 'ilike', '%NOTURNO%');

    if (errMatrizes) {
      console.error('Erro ao buscar matrizes:', errMatrizes.message);
      process.exit(1);
    }

    if (!matrizes?.length) {
      console.log('Nenhuma matriz no banco sem DIURNO/NOTURNO. Nada a remover.');
      return;
    }

    for (const m of matrizes) {
      idsToRemove.push(m.id_matriz);
    }
    console.log('Matrizes a remover:', idsToRemove.length);
    matrizes.slice(0, 5).forEach((m) => console.log('  -', m.id_matriz, m.curriculo_completo));

    const BATCH_ID = 80;
    for (let i = 0; i < idsToRemove.length; i += BATCH_ID) {
      const batch = idsToRemove.slice(i, i + BATCH_ID);
      const { error: errEq } = await supabase.from('equivalencias').delete().in('id_matriz', batch);
      if (errEq) {
        if (errEq.message?.includes('column') && errEq.message?.includes('id_matriz')) {
          console.log('(equivalencias não possui id_matriz, pulando)');
          break;
        } else {
          console.error('Erro ao deletar equivalencias:', errEq.message);
        }
      }
    }
    console.log('equivalencias: linhas removidas');

    for (let i = 0; i < idsToRemove.length; i += BATCH_ID) {
      const batch = idsToRemove.slice(i, i + BATCH_ID);
      const { error: errMpc } = await supabase.from('materias_por_curso').delete().in('id_matriz', batch);
      if (errMpc) {
        console.error('Erro ao deletar materias_por_curso:', errMpc.message);
        process.exit(1);
      }
    }
    console.log('materias_por_curso: deletadas (matrizes sem turno)');

    for (let i = 0; i < idsToRemove.length; i += BATCH_ID) {
      const batch = idsToRemove.slice(i, i + BATCH_ID);
      const { error: errMat } = await supabase.from('matrizes').delete().in('id_matriz', batch);
      if (errMat) {
        console.error('Erro ao deletar matrizes:', errMat.message);
        process.exit(1);
      }
    }
    console.log('matrizes: deletadas');

    // --- Limpeza de órfãos: materias_por_curso com id_matriz que não existe mais em matrizes ---
    console.log('\n=== Limpeza de órfãos em materias_por_curso ===\n');
    const { data: idsMatrizesExistentes } = await supabase.from('matrizes').select('id_matriz');
    const setMatrizes = new Set((idsMatrizesExistentes || []).map((r) => r.id_matriz));
    const idMatrizMpc = [];
    let fromMpc = 0;
    while (true) {
      const { data: pageMpc } = await supabase
        .from('materias_por_curso')
        .select('id_matriz')
        .range(fromMpc, fromMpc + pageSize - 1);
      if (!pageMpc?.length) break;
      for (const r of pageMpc) {
        if (!setMatrizes.has(r.id_matriz)) idMatrizMpc.push(r.id_matriz);
      }
      if (pageMpc.length < pageSize) break;
      fromMpc += pageSize;
    }
    const orfaos = [...new Set(idMatrizMpc)];
    if (orfaos.length > 0) {
      for (let i = 0; i < orfaos.length; i += BATCH_ID) {
        const batch = orfaos.slice(i, i + BATCH_ID);
        const { error: errOrf } = await supabase.from('materias_por_curso').delete().in('id_matriz', batch);
        if (errOrf) {
          console.error('Erro ao deletar órfãos materias_por_curso:', errOrf.message);
          process.exit(1);
        }
      }
      console.log('materias_por_curso: removidas', orfaos.length, 'matrizes órfãs (id_matriz inexistente em matrizes).');
    } else {
      console.log('materias_por_curso: nenhum órfão encontrado.');
    }

    console.log('\nConcluído.');
  })();
}

main();

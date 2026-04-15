"""
auditar_requisitos_equivalencias.py
====================================
Audita se todas as relações de pré-requisito, co-requisito e equivalência
descritas nos JSONs locais existem no banco de dados Supabase.

Etapas:
  1. INTEGRIDADE REFERENCIAL
     Verifica se todos os códigos de matéria citados em expressões de
     pre_requisitos / co_requisitos / equivalencias existem na tabela
     `materias`. Códigos ausentes são sinalizados no log de erro.

  2. AUDITORIA DE PRÉ-REQUISITOS
     Para cada matéria com pre_requisitos no JSON, verifica se existe
     um registro correspondente em `pre_requisitos` no banco
     (chave: id_materia + expressao_original).

  3. AUDITORIA DE CO-REQUISITOS
     Idem para `co_requisitos`.

  4. AUDITORIA DE EQUIVALÊNCIAS
     Verifica `equivalencias` globais e `equivalencias_especificas`
     (chave: id_materia + expressao_original + curriculo).

  5. GERAÇÃO DE SQL DE CORREÇÃO
     Gera arquivo .sql com os INSERTs/UPDATEs necessários para normalizar
     o banco com base nos dados do JSON.

  EVITA DUPLICATAS:
     - Carrega do banco todas as chaves já existentes (id_materia + expressão
       normalizada + id_curso + curriculo para equivalências).
     - Só insere quando a chave NÃO está nesse conjunto.
     - Após cada insert, adiciona a chave ao conjunto (mesma execução não
       insere duas vezes a mesma relação).
     - Expressões são normalizadas (espaços colapsados) para que variações
       de formatação não gerem registros duplicados.

  EQUIVALÊNCIAS E id_curso:
     - Equivalências GERAIS (campo "equivalencias" da matéria): sem curriculo,
       id_curso NULL. Uma por matéria.
     - Equivalências ESPECÍFICAS (equivalencias_especificas): têm curriculo "XXXX/Y".
       id_curso = XXXX quando esse código existir na tabela cursos; caso contrário
       id_curso NULL (equivalência geral para aquela matéria/curriculo).

Uso:
  python auditar_requisitos_equivalencias.py [--dry-run] [--only-integrity]

  --dry-run        : não altera nada; apenas gera logs e SQL
  --only-integrity : executa apenas a verificação de integridade referencial
"""

import os
import sys
import json
import re
import logging
import datetime
import time
from pathlib import Path
from collections import defaultdict

from dotenv import load_dotenv
from supabase import create_client, Client
from tenacity import retry, stop_after_attempt, wait_exponential

# ---------------------------------------------------------------------------
# Configuração
# ---------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).parent
BASE_DIR   = SCRIPT_DIR.parent
PASTA_MATERIAS = BASE_DIR / 'dados' / 'materias'

load_dotenv(SCRIPT_DIR / '.env')
load_dotenv(SCRIPT_DIR.parent.parent / 'no_fluxo_backend' / '.env')

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_KEY')
if not SUPABASE_URL or not SUPABASE_KEY:
    raise RuntimeError("Defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY no .env (ver no_fluxo_backend/.env.example).")

DRY_RUN       = '--dry-run'       in sys.argv
ONLY_INTEGRITY= '--only-integrity' in sys.argv

ts       = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
log_file = SCRIPT_DIR / f'auditoria_requisitos_{ts}.log'
sql_file = SCRIPT_DIR / f'correcao_requisitos_{ts}.sql'

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8'),
        logging.StreamHandler(sys.stdout),
    ]
)
log = logging.getLogger(__name__)

if DRY_RUN:
    log.info('=== MODO DRY-RUN: nenhuma alteração será enviada ao banco ===')

# ---------------------------------------------------------------------------
# Supabase
# ---------------------------------------------------------------------------

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

@retry(stop=stop_after_attempt(5), wait=wait_exponential(multiplier=1, min=2, max=15))
def db(op, *args, **kwargs):
    return op(*args, **kwargs)

# ---------------------------------------------------------------------------
# Utilitários de expressão
# ---------------------------------------------------------------------------

def codigos_na_expressao(expr: str) -> list[str]:
    """Extrai códigos de disciplinas de uma expressão booleana."""
    if not expr or not isinstance(expr, str):
        return []
    raw = expr.upper()
    codigos = re.findall(r'[A-Z]{2,}\d{2,}[A-Z0-9]*', raw)
    if not codigos:
        codigos = re.findall(r'[A-Z]+\d+', raw)
    return list(dict.fromkeys(codigos))  # deduplicação mantendo ordem


def build_expressao_logica(expr: str) -> dict | None:
    """Converte expressão string em JSONB {'operador': ..., 'materias': [...]}."""
    if not expr or not isinstance(expr, str) or not expr.strip():
        return None
    materias = codigos_na_expressao(expr)
    eu = expr.upper()
    operador = 'OU' if ' OU ' in eu else ('E' if ' E ' in eu else None)
    return {'operador': operador, 'materias': materias}


def escape_sql_str(s: str) -> str:
    return (s or '').replace("'", "''")


def normalizar_expressao_para_chave(expr: str) -> str:
    """
    Normaliza expressão para uso como chave de unicidade (evitar duplicatas por
    diferença de espaços/parênteses). Ex: "( A OU B )" e "(A OU B)" → mesma chave.
    """
    if not expr or not isinstance(expr, str):
        return ''
    s = expr.strip()
    s = re.sub(r'\s+', ' ', s)  # colapsa espaços múltiplos
    return s


def data_vigencia_para_date(val: str | None) -> str | None:
    """
    Converte data_vigencia do JSON (ex: "2015.1", "2014.2") para formato date (YYYY-MM-DD).
    A coluna equivalencias.data_vigencia é tipo date; "2015.1" causa 400 no Supabase.
    """
    if not val or not isinstance(val, str):
        return None
    s = val.strip()
    if not s:
        return None
    # Já está em YYYY-MM-DD
    if re.match(r'^\d{4}-\d{2}-\d{2}$', s):
        return s
    # Formato ano.semestre (ex: 2015.1, 2014.2)
    m = re.match(r'^(\d{4})\.(\d)$', s)
    if m:
        ano = int(m.group(1))
        sem = int(m.group(2))
        if sem == 1:
            return f'{ano}-01-01'
        if sem == 2:
            return f'{ano}-07-01'
    return None


# ---------------------------------------------------------------------------
# Carregamento em lote do banco
# ---------------------------------------------------------------------------

BATCH = 1000

def fetch_all(tabela: str, colunas: str) -> list[dict]:
    """Busca todos os registros de uma tabela em lotes."""
    resultados = []
    offset = 0
    while True:
        res = db(supabase.table(tabela).select(colunas).range(offset, offset + BATCH - 1).execute)
        lote = res.data or []
        resultados.extend(lote)
        if len(lote) < BATCH:
            break
        offset += BATCH
    return resultados


def carregar_banco():
    """Retorna dicts com dados do banco necessários para a auditoria."""
    log.info('Carregando tabela materias...')
    mat_rows = fetch_all('materias', 'id_materia, codigo_materia, carga_horaria')
    codigo_to_id = {r['codigo_materia'].upper(): r['id_materia'] for r in mat_rows if r.get('codigo_materia')}
    log.info(f'  {len(codigo_to_id)} matérias carregadas')

    log.info('Carregando tabela pre_requisitos...')
    pre_rows = fetch_all('pre_requisitos', 'id_pre_requisito, id_materia, expressao_original')
    pre_existentes: set[tuple] = set()
    for r in pre_rows:
        pre_existentes.add((r['id_materia'], normalizar_expressao_para_chave(r.get('expressao_original') or '')))
    log.info(f'  {len(pre_existentes)} pré-requisitos carregados')

    log.info('Carregando tabela co_requisitos...')
    co_rows = fetch_all('co_requisitos', 'id_co_requisito, id_materia, expressao_original')
    co_existentes: set[tuple] = set()
    for r in co_rows:
        co_existentes.add((r['id_materia'], normalizar_expressao_para_chave(r.get('expressao_original') or '')))
    log.info(f'  {len(co_existentes)} co-requisitos carregados')

    log.info('Carregando tabela equivalencias...')
    eq_rows = fetch_all('equivalencias', 'id_equivalencia, id_materia, expressao_original, id_curso, curriculo')
    eq_existentes: set[tuple] = set()
    for r in eq_rows:
        expr_norm = normalizar_expressao_para_chave(r.get('expressao_original') or '')
        eq_existentes.add((
            r['id_materia'],
            expr_norm,
            r.get('id_curso'),
            (r.get('curriculo') or '').strip()
        ))
    log.info(f'  {len(eq_existentes)} equivalências carregadas')

    log.info('Carregando tabela cursos...')
    cur_rows = fetch_all('cursos', 'id_curso, nome_curso')
    id_to_curso = {r['id_curso']: r['nome_curso'] for r in cur_rows}
    log.info(f'  {len(id_to_curso)} cursos carregados')

    return codigo_to_id, pre_existentes, co_existentes, eq_existentes, id_to_curso


# ---------------------------------------------------------------------------
# Carregamento dos JSONs
# ---------------------------------------------------------------------------

def carregar_jsons() -> dict[str, dict]:
    """
    Retorna dict {codigo_materia: dados_materia} lendo todos os
    turmas_depto_*.json da pasta materias.
    """
    materias: dict[str, dict] = {}
    arquivos = [f for f in PASTA_MATERIAS.glob('turmas_depto_*.json')]
    log.info(f'Carregando {len(arquivos)} arquivo(s) JSON de {PASTA_MATERIAS}')
    for arq in arquivos:
        try:
            with open(arq, encoding='utf-8') as f:
                lista = json.load(f)
        except Exception as e:
            log.warning(f'  Erro ao ler {arq.name}: {e}')
            continue
        for mat in (lista or []):
            cod = (mat.get('codigo') or '').strip().upper()
            if cod:
                materias[cod] = mat
    log.info(f'  {len(materias)} matérias únicas nos JSONs')
    return materias


# ---------------------------------------------------------------------------
# Etapa 1 – Integridade Referencial
# ---------------------------------------------------------------------------

def auditar_integridade(materias_json: dict, codigo_to_id: dict) -> set[str]:
    """
    Verifica se todos os códigos citados em pré/co-requisitos e equivalências
    existem na tabela materias. Retorna set dos códigos ausentes.
    """
    log.info('\n=== ETAPA 1: INTEGRIDADE REFERENCIAL ===')

    ausentes: set[str]  = set()
    origem: dict[str, list[str]] = defaultdict(list)  # codigo_ausente -> onde foi encontrado

    for codigo, mat in materias_json.items():
        for campo in ('pre_requisitos', 'co_requisitos', 'equivalencias'):
            expr = mat.get(campo, '')
            if not expr or expr == '-':
                continue
            for ref in codigos_na_expressao(str(expr)):
                if ref not in codigo_to_id:
                    ausentes.add(ref)
                    origem[ref].append(f'{codigo}.{campo}')

        for eq_esp in (mat.get('equivalencias_especificas') or []):
            expr = eq_esp.get('expressao', '')
            if not expr:
                continue
            for ref in codigos_na_expressao(str(expr)):
                if ref not in codigo_to_id:
                    ausentes.add(ref)
                    origem[ref].append(f'{codigo}.equivalencias_especificas')

    if ausentes:
        log.warning(f'  {len(ausentes)} código(s) citados em expressões NÃO existem em materias:')
        for cod in sorted(ausentes):
            log.warning(f'    [AUSENTE] {cod}  ←  {", ".join(set(origem[cod][:5]))}')
    else:
        log.info('  ✅ Todos os códigos referenciados existem na tabela materias.')

    return ausentes

# ---------------------------------------------------------------------------
# Etapa 2/3/4 – Auditoria + geração de SQL
# ---------------------------------------------------------------------------

def auditar_e_corrigir(
    materias_json:  dict,
    codigo_to_id:   dict,
    pre_existentes: set,
    co_existentes:  set,
    eq_existentes:  set,
    id_to_curso:    dict,
    codigos_ausentes: set,
) -> tuple[int, int, int]:
    """
    Audita pré-requisitos, co-requisitos e equivalências.
    Retorna (n_pre_inseridos, n_co_inseridos, n_eq_inseridos).
    """
    log.info('\n=== ETAPA 2/3/4: AUDITORIA E CORREÇÃO ===')

    sql_lines: list[str] = [
        f'-- Correção gerada por auditar_requisitos_equivalencias.py em {ts}',
        '-- Execute com cuidado em ambiente de homologação antes de produção.',
        '',
    ]

    n_pre = n_co = n_eq = 0
    n_pre_skip = n_co_skip = n_eq_skip = 0
    erros_insert: list[str] = []
    ids_curso_validos = set(id_to_curso.keys())  # XXXX do curriculo "XXXX/Y" deve existir em cursos

    def inserir_pre(id_materia: int, expr: str):
        nonlocal n_pre
        logica = build_expressao_logica(expr)
        payload = {
            'id_materia': id_materia,
            'expressao_original': expr,
        }
        if logica:
            payload['expressao_logica'] = logica
        sql_lines.append(
            f"INSERT INTO pre_requisitos (id_materia, expressao_original, expressao_logica) "
            f"VALUES ({id_materia}, '{escape_sql_str(expr)}', "
            f"'{json.dumps(logica, ensure_ascii=False)}'::jsonb) "
            f"ON CONFLICT DO NOTHING;"
        )
        if not DRY_RUN:
            try:
                db(supabase.table('pre_requisitos').insert(payload).execute)
                n_pre += 1
            except Exception as e:
                erros_insert.append(f'pre_req id={id_materia} expr={expr[:60]}: {e}')
        else:
            n_pre += 1

    def inserir_co(id_materia: int, expr: str):
        nonlocal n_co
        logica = build_expressao_logica(expr)
        payload = {'id_materia': id_materia, 'expressao_original': expr}
        if logica:
            payload['expressao_logica'] = logica
        sql_lines.append(
            f"INSERT INTO co_requisitos (id_materia, expressao_original, expressao_logica) "
            f"VALUES ({id_materia}, '{escape_sql_str(expr)}', "
            f"'{json.dumps(logica, ensure_ascii=False)}'::jsonb) "
            f"ON CONFLICT DO NOTHING;"
        )
        if not DRY_RUN:
            try:
                db(supabase.table('co_requisitos').insert(payload).execute)
                n_co += 1
            except Exception as e:
                erros_insert.append(f'co_req id={id_materia} expr={expr[:60]}: {e}')
        else:
            n_co += 1

    def inserir_eq(id_materia: int, expr: str, id_curso, curriculo: str,
                   data_vigencia: str | None = None):
        nonlocal n_eq
        logica = build_expressao_logica(expr)
        # Schema: id_materia, id_curso, curriculo, data_vigencia, expressao_logica, expressao_original
        # data_vigencia deve ser date (YYYY-MM-DD); no JSON vem "2015.1" → converter
        data_date = data_vigencia_para_date(data_vigencia)
        payload: dict = {
            'id_materia': id_materia,
            'expressao_original': expr,
            'curriculo': curriculo,
        }
        if id_curso is not None:
            payload['id_curso'] = id_curso
        if logica:
            payload['expressao_logica'] = logica
        if data_date:
            payload['data_vigencia'] = data_date

        cur_val = f"'{escape_sql_str(str(id_curso))}'" if id_curso else 'NULL'
        data_sql = f"'{data_date}'" if data_date else 'NULL'
        sql_lines.append(
            f"INSERT INTO equivalencias (id_materia, expressao_original, expressao_logica, "
            f"id_curso, curriculo, data_vigencia) "
            f"VALUES ({id_materia}, '{escape_sql_str(expr)}', "
            f"'{json.dumps(logica, ensure_ascii=False)}'::jsonb, "
            f"{cur_val}, '{escape_sql_str(curriculo)}', "
            f"{data_sql}) "
            f"ON CONFLICT DO NOTHING;"
        )
        if not DRY_RUN:
            try:
                db(supabase.table('equivalencias').insert(payload).execute)
                n_eq += 1
            except Exception as e:
                erros_insert.append(f'equiv id={id_materia} expr={expr[:60]}: {e}')
        else:
            n_eq += 1

    for codigo, mat in materias_json.items():
        id_materia = codigo_to_id.get(codigo.upper())
        if id_materia is None:
            # A própria matéria-âncora não existe — já sinalizado na etapa 1
            continue

        # ── pré-requisitos ──────────────────────────────────────────────
        expr_pre = (mat.get('pre_requisitos') or '').strip()
        if expr_pre and expr_pre != '-':
            chave = (id_materia, normalizar_expressao_para_chave(expr_pre))
            if chave not in pre_existentes:
                log.info(f'  [PRE FALTANDO] {codigo} → "{expr_pre[:80]}"')
                inserir_pre(id_materia, expr_pre)
                pre_existentes.add(chave)
            else:
                n_pre_skip += 1

        # ── co-requisitos ───────────────────────────────────────────────
        expr_co = (mat.get('co_requisitos') or '').strip()
        if expr_co and expr_co != '-':
            chave = (id_materia, normalizar_expressao_para_chave(expr_co))
            if chave not in co_existentes:
                log.info(f'  [CO FALTANDO]  {codigo} → "{expr_co[:80]}"')
                inserir_co(id_materia, expr_co)
                co_existentes.add(chave)
            else:
                n_co_skip += 1

        # ── equivalências globais (uma por matéria, sem curriculo; id_curso NULL) ──
        expr_eq = (mat.get('equivalencias') or '').strip()
        if expr_eq and expr_eq != '-':
            chave = (id_materia, normalizar_expressao_para_chave(expr_eq), None, '')
            if chave not in eq_existentes:
                log.info(f'  [EQ FALTANDO]  {codigo} → "{expr_eq[:80]}"')
                inserir_eq(id_materia, expr_eq, None, '')
                eq_existentes.add(chave)
            else:
                n_eq_skip += 1

        # ── equivalências específicas (por curriculo); id_curso = XXXX de "XXXX/Y" se existir em cursos; senão NULL (geral)
        for eq_esp in (mat.get('equivalencias_especificas') or []):
            expr_esp  = (eq_esp.get('expressao') or '').strip()
            curriculo = (eq_esp.get('curriculo')  or '').strip()
            data_vig  = eq_esp.get('data_vigencia') or None

            if not expr_esp:
                continue

            # id_curso: XXXX de "XXXX/Y" só se existir em cursos; senão NULL (equivalência geral)
            id_curso = None
            if '/' in curriculo:
                base = curriculo.split('/', 1)[0].strip()
                if base.isdigit():
                    cod = int(base)
                    if cod in ids_curso_validos:
                        id_curso = cod

            # Chave normalizada: evita inserir duplicata se já existir no banco ou
            # se a mesma equivalência aparecer em outro JSON com formatação diferente.
            chave = (id_materia, normalizar_expressao_para_chave(expr_esp), id_curso, curriculo)
            if chave not in eq_existentes:
                log.info(f'  [EQ-ESP FALTANDO] {codigo} curriculo={curriculo} → "{expr_esp[:60]}"')
                inserir_eq(id_materia, expr_esp, id_curso, curriculo, data_vig)
                eq_existentes.add(chave)
            else:
                n_eq_skip += 1

    # Gravar SQL
    sql_content = '\n'.join(sql_lines)
    with open(sql_file, 'w', encoding='utf-8') as f:
        f.write(sql_content)
    log.info(f'\n  SQL de correção salvo em: {sql_file}')

    if erros_insert:
        log.error(f'\n  {len(erros_insert)} erro(s) ao inserir:')
        for e in erros_insert:
            log.error(f'    {e}')

    log.info(f'\n  Pré-requisitos  → inseridos: {n_pre:4d}  |  já existentes: {n_pre_skip:4d}')
    log.info(f'  Co-requisitos   → inseridos: {n_co:4d}  |  já existentes: {n_co_skip:4d}')
    log.info(f'  Equivalências   → inseridas: {n_eq:4d}  |  já existentes: {n_eq_skip:4d}')

    return n_pre, n_co, n_eq


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    inicio = time.time()
    log.info('=' * 65)
    log.info('AUDITORIA DE PRÉ-REQUISITOS, CO-REQUISITOS E EQUIVALÊNCIAS')
    log.info(f'Fonte: {PASTA_MATERIAS}')
    log.info(f'Banco: {SUPABASE_URL}')
    log.info(f'Flags: dry-run={DRY_RUN}  only-integrity={ONLY_INTEGRITY}')
    log.info('=' * 65)

    materias_json = carregar_jsons()
    (codigo_to_id,
     pre_existentes, co_existentes,
     eq_existentes, id_to_curso) = carregar_banco()

    ausentes = auditar_integridade(materias_json, codigo_to_id)

    if not ONLY_INTEGRITY:
        n_pre, n_co, n_eq = auditar_e_corrigir(
            materias_json, codigo_to_id,
            pre_existentes, co_existentes, eq_existentes,
            id_to_curso, ausentes,
        )
    else:
        n_pre = n_co = n_eq = 0

    duracao = time.time() - inicio
    log.info('\n' + '=' * 65)
    log.info('RESUMO FINAL')
    log.info(f'  Códigos ausentes no banco    : {len(ausentes)}')
    if not ONLY_INTEGRITY:
        log.info(f'  Pré-requisitos inseridos     : {n_pre}')
        log.info(f'  Co-requisitos inseridos      : {n_co}')
        log.info(f'  Equivalências inseridas      : {n_eq}')
        log.info(f'  SQL de correção              : {sql_file}')
    log.info(f'  Log de auditoria             : {log_file}')
    log.info(f'  Tempo total                  : {duracao:.1f}s')
    if DRY_RUN:
        log.info('  *** DRY-RUN: nenhuma alteração foi persistida ***')
    log.info('=' * 65)


if __name__ == '__main__':
    main()

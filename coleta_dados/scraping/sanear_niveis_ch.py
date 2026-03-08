"""
sanear_niveis_ch.py
===================
Saneamento de dados acadêmicos no Supabase, usando os JSONs de estruturas
curriculares como fonte da verdade.

Tarefas:
  1. NÍVEIS (materias_por_curso.nivel):
     - Optativas na seção "OPTATIVAS" → nivel = 0  (já é o padrão)
     - Optativas alocadas em nível específico (ex: "3° NIVEL") → atualiza para
       o nivel do JSON se o banco tiver 0 (regra: JSON prevalece sobre padrão).

  2. CARGA HORÁRIA (materias.carga_horaria):
     - Para cada matéria com ch presente nos JSONs, atualiza o campo
       carga_horaria no banco quando:
         a) o valor atual é NULL / 0
         b) o valor difere do JSON (usa o JSON como fonte da verdade)

  3. LOGS:
     - Arquivo de log com data/hora: sanear_niveis_ch_YYYYMMDD_HHMMSS.log
     - Resumo final no console.

Uso:
  python sanear_niveis_ch.py [--dry-run]

  --dry-run : apenas simula, não altera o banco (mostra o que seria feito)
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

SCRIPT_DIR   = Path(__file__).parent
BASE_DIR     = SCRIPT_DIR.parent                          # coleta_dados/
PASTA_JSON   = BASE_DIR / 'dados' / 'estruturas-curriculares'
LOG_DIR      = SCRIPT_DIR

load_dotenv(SCRIPT_DIR / '.env')
load_dotenv(SCRIPT_DIR.parent.parent / 'no_fluxo_backend' / '.env')

SUPABASE_URL  = os.getenv('SUPABASE_URL',  'https://lijmhbstgdinsukovyfl.supabase.co')
SUPABASE_KEY  = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_KEY', '')

DRY_RUN = '--dry-run' in sys.argv

# ---------------------------------------------------------------------------
# Logger
# ---------------------------------------------------------------------------

ts = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
log_file = LOG_DIR / f'sanear_niveis_ch_{ts}.log'

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
# Utilitários
# ---------------------------------------------------------------------------

def nivel_to_int(nivel_nome: str) -> int:
    """'1° NIVEL' → 1 | 'OPTATIVAS' → 0"""
    s = (nivel_nome or '').strip().upper()
    if 'OPTATIVA' in s:
        return 0
    m = re.match(r'(\d+)', s)
    return int(m.group(1)) if m else 0


def ch_to_int(val) -> int | None:
    """'60h' | 60 | '60' → 60 | None"""
    if val is None:
        return None
    s = str(val).strip().rstrip('hH')
    try:
        return int(s)
    except ValueError:
        return None


def parse_curriculo_completo(curriculo: str, periodo: str) -> str:
    """Monta curriculo_completo igual ao feito em integracao_banco.py."""
    curriculo = (curriculo or '').strip()
    periodo   = (periodo   or '').strip()
    if curriculo and periodo:
        return f"{curriculo} - {periodo}"
    return curriculo or periodo


# ---------------------------------------------------------------------------
# Passo 1 – Carregar JSONs e construir mapa de referência
# ---------------------------------------------------------------------------

def carregar_jsons():
    """
    Retorna duas estruturas:
      nivel_map  : {(curriculo_completo, codigo_materia): nivel_int}
      ch_map     : {codigo_materia: ch_int}   (usa o maior ch encontrado por código)
      optativas_posicionadas : set de (curriculo_completo, codigo_materia) onde
                               a matéria é Optativa mas está num nivel > 0
    """
    nivel_map: dict[tuple, int]      = {}
    ch_map:    dict[str, int]        = {}
    optativas_posicionadas: set      = set()

    arquivos = list(PASTA_JSON.rglob('*.json'))
    log.info(f'Carregando {len(arquivos)} arquivo(s) JSON de {PASTA_JSON}')

    for arq in arquivos:
        try:
            with open(arq, encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            log.warning(f'Erro ao ler {arq.name}: {e}')
            continue

        if not isinstance(data, dict):
            continue

        curriculo = data.get('curriculo', '')
        periodo   = data.get('periodo_letivo_vigor', '')
        curriculo_completo = parse_curriculo_completo(curriculo, periodo)

        for bloco in (data.get('niveis') or []):
            nivel_nome = bloco.get('nivel', '')
            nivel_int  = nivel_to_int(nivel_nome)

            for mat in (bloco.get('materias') or []):
                codigo    = (mat.get('codigo') or '').strip().upper()
                natureza  = (mat.get('natureza') or '').strip().lower()
                ch        = ch_to_int(mat.get('ch'))

                if not codigo:
                    continue

                chave = (curriculo_completo, codigo)
                nivel_map[chave] = nivel_int

                # Optativa posicionada: natureza optativa mas em nivel > 0
                if 'optativa' in natureza and nivel_int > 0:
                    optativas_posicionadas.add(chave)

                # ch_map: mantém o maior valor encontrado para cada código
                if ch and ch > 0:
                    if codigo not in ch_map or ch > ch_map[codigo]:
                        ch_map[codigo] = ch

    log.info(f'  {len(nivel_map)} vínculos (curriculo, materia) carregados')
    log.info(f'  {len(optativas_posicionadas)} optativas posicionadas em nivel > 0')
    log.info(f'  {len(ch_map)} códigos de matéria com CH no JSON')
    return nivel_map, ch_map, optativas_posicionadas


# ---------------------------------------------------------------------------
# Passo 2 – Sanear níveis em materias_por_curso
# ---------------------------------------------------------------------------

def sanear_niveis(nivel_map: dict, optativas_posicionadas: set):
    """
    Para cada vínculo em materias_por_curso onde nivel=0 (optativa padrão)
    mas o JSON indica nivel > 0 (optativa posicionada), atualiza o banco.
    """
    log.info('\n=== SANEAMENTO DE NÍVEIS ===')

    # Carregar todos os registros de materias_por_curso com nivel=0
    # Precisamos cruzar com a matriz para saber o curriculo_completo.
    # Estratégia: buscar todas as matrizes e construir mapa id_matriz -> curriculo_completo
    log.info('Carregando matrizes do banco...')
    res_matrizes = db(supabase.table('matrizes')
                      .select('id_matriz, curriculo_completo')
                      .execute)
    id_to_curriculo = {r['id_matriz']: r['curriculo_completo']
                       for r in (res_matrizes.data or [])}
    log.info(f'  {len(id_to_curriculo)} matrizes carregadas')

    # Carregar código_materia -> id_materia
    log.info('Carregando materias do banco...')
    res_mat = db(supabase.table('materias')
                 .select('id_materia, codigo_materia')
                 .execute)
    id_to_codigo = {r['id_materia']: r['codigo_materia']
                    for r in (res_mat.data or [])}
    codigo_to_id = {v: k for k, v in id_to_codigo.items()}
    log.info(f'  {len(id_to_codigo)} matérias carregadas')

    # Buscar todos os registros de materias_por_curso com nivel = 0
    log.info('Carregando materias_por_curso com nivel=0...')
    BATCH = 1000
    offset = 0
    registros_nivel0 = []
    while True:
        res = db(supabase.table('materias_por_curso')
                 .select('id_materia_curso, id_materia, id_matriz, nivel')
                 .eq('nivel', 0)
                 .range(offset, offset + BATCH - 1)
                 .execute)
        lote = res.data or []
        registros_nivel0.extend(lote)
        if len(lote) < BATCH:
            break
        offset += BATCH
    log.info(f'  {len(registros_nivel0)} registros com nivel=0 encontrados')

    alterados  = 0
    ignorados  = 0

    for reg in registros_nivel0:
        id_mc      = reg['id_materia_curso']
        id_materia = reg['id_materia']
        id_matriz  = reg['id_matriz']

        codigo            = id_to_codigo.get(id_materia)
        curriculo_compl   = id_to_curriculo.get(id_matriz)

        if not codigo or not curriculo_compl:
            ignorados += 1
            continue

        chave = (curriculo_compl, codigo.upper())

        if chave not in optativas_posicionadas:
            ignorados += 1
            continue

        nivel_correto = nivel_map.get(chave, 0)
        if nivel_correto == 0:
            ignorados += 1
            continue

        log.info(f'  NIVEL: {codigo} | matriz "{curriculo_compl}" | '
                 f'0 → {nivel_correto}')

        if not DRY_RUN:
            try:
                db(supabase.table('materias_por_curso')
                   .update({'nivel': nivel_correto})
                   .eq('id_materia_curso', id_mc)
                   .execute)
                alterados += 1
            except Exception as e:
                log.error(f'    Falha ao atualizar id_materia_curso={id_mc}: {e}')
        else:
            alterados += 1

    log.info(f'\n  Níveis atualizados : {alterados}')
    log.info(f'  Ignorados          : {ignorados}')
    return alterados


# ---------------------------------------------------------------------------
# Passo 3 – Atualizar carga horária em materias
# ---------------------------------------------------------------------------

def sanear_carga_horaria(ch_map: dict):
    """
    Para cada matéria no banco com carga_horaria NULL ou 0,
    atualiza com o valor do ch_map (JSON como fonte da verdade).
    Também atualiza se o valor difere do JSON.
    """
    log.info('\n=== SANEAMENTO DE CARGA HORÁRIA ===')

    log.info('Carregando materias do banco...')
    BATCH = 1000
    offset = 0
    todas_materias = []
    while True:
        res = db(supabase.table('materias')
                 .select('id_materia, codigo_materia, carga_horaria')
                 .range(offset, offset + BATCH - 1)
                 .execute)
        lote = res.data or []
        todas_materias.extend(lote)
        if len(lote) < BATCH:
            break
        offset += BATCH
    log.info(f'  {len(todas_materias)} matérias carregadas do banco')

    atualizadas = 0
    sem_ch_json = 0

    for mat in todas_materias:
        codigo    = (mat.get('codigo_materia') or '').strip().upper()
        ch_banco  = mat.get('carga_horaria') or 0
        id_mat    = mat['id_materia']

        ch_json = ch_map.get(codigo)
        if ch_json is None:
            sem_ch_json += 1
            continue

        # Atualiza se: banco é NULL/0 OU valor diverge do JSON
        if ch_banco == ch_json:
            continue

        motivo = 'NULL/0' if not ch_banco else f'{ch_banco} ≠ {ch_json} (JSON)'
        log.info(f'  CH: {codigo} | id={id_mat} | banco={ch_banco} → {ch_json} ({motivo})')

        if not DRY_RUN:
            try:
                db(supabase.table('materias')
                   .update({'carga_horaria': ch_json})
                   .eq('id_materia', id_mat)
                   .execute)
                atualizadas += 1
            except Exception as e:
                log.error(f'    Falha ao atualizar id_materia={id_mat}: {e}')
        else:
            atualizadas += 1

    log.info(f'\n  CH atualizadas             : {atualizadas}')
    log.info(f'  Matérias sem CH no JSON    : {sem_ch_json}')
    return atualizadas


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    inicio = time.time()
    log.info('=' * 60)
    log.info('SANEAMENTO DE NÍVEIS E CARGA HORÁRIA')
    log.info(f'Fonte: {PASTA_JSON}')
    log.info(f'Banco: {SUPABASE_URL}')
    if DRY_RUN:
        log.info('Modo: DRY-RUN (sem alterações)')
    log.info('=' * 60)

    nivel_map, ch_map, optativas_posicionadas = carregar_jsons()
    niveis_alterados = sanear_niveis(nivel_map, optativas_posicionadas)
    ch_atualizadas   = sanear_carga_horaria(ch_map)

    duracao = time.time() - inicio
    log.info('\n' + '=' * 60)
    log.info('RESUMO FINAL')
    log.info(f'  Níveis corrigidos          : {niveis_alterados}')
    log.info(f'  Cargas horárias atualizadas: {ch_atualizadas}')
    log.info(f'  Tempo total                : {duracao:.1f}s')
    log.info(f'  Log salvo em               : {log_file}')
    if DRY_RUN:
        log.info('  *** DRY-RUN: nenhuma alteração foi persistida ***')
    log.info('=' * 60)


if __name__ == '__main__':
    main()

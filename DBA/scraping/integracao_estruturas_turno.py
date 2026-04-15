#!/usr/bin/env python3
"""
Script para subir as novas estruturas curriculares (arquivos com - diurno.json e - noturno.json).

Baseado em integracao_banco.py e schema do banco (cursos, matrizes, materias, materias_por_curso).

- Processa APENAS arquivos que têm turno no nome (* - diurno.json, * - noturno.json)
- Inclui turno no curriculo_completo para diferenciar matrizes (ex: "8117/-2 - 2018.2 - DIURNO")
- Cria/atualiza cursos, matrizes e materias_por_curso com tipo_natureza
- NÃO processa equivalências, pré-requisitos ou co-requisitos (já estão no banco)
- Usa materias_detalhadas e DEPARTAMENTOS_MATERIAS como integracao_banco

Uso:
  cd coleta_dados/scraping
  python integracao_estruturas_turno.py
"""

import os
import re
import json
import time
import unicodedata
from supabase import create_client, Client
from tenacity import retry, stop_after_attempt, wait_exponential

# Carrega .env do backend ou raiz do projeto
try:
    from dotenv import load_dotenv
    for p in [
        os.path.join(os.path.dirname(__file__), '..', '..', 'no_fluxo_backend', '.env'),
        os.path.join(os.path.dirname(__file__), '..', '..', '.env'),
        os.path.join(os.getcwd(), '.env'),
    ]:
        if os.path.isfile(p):
            load_dotenv(p)
            break
except ImportError:
    pass

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_SERVICE_KEY') or os.getenv('SUPABASE_KEY')
if not SUPABASE_URL or not SUPABASE_KEY:
    raise RuntimeError("Defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY no .env (ver no_fluxo_backend/.env.example).")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

PASTA_ESTRUTURAS = os.path.join(os.path.dirname(__file__), '..', 'dados', 'estruturas-curriculares')
PASTA_MATERIAS = os.path.join(os.path.dirname(__file__), '..', 'dados', 'materias')

CHUNK_SIZE = 80  # alinhado com integracao_banco (tamanho_lote=80)


def reconectar_supabase():
    global supabase
    print("Reconectando ao Supabase...")
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("Reconexão bem-sucedida!")


@retry(stop=stop_after_attempt(5), wait=wait_exponential(multiplier=1, min=2, max=15))
def executar_operacao(operacao, *args, **kwargs):
    try:
        return operacao(*args, **kwargs)
    except Exception as e:
        err = str(e).lower()
        if 'duplicate key value violates unique constraint' in err:
            raise
        if any(k in err for k in ['connection', 'timeout', 'network', 'socket']):
            print(f"Erro de conexão: {e}")
            reconectar_supabase()
            time.sleep(3)
            raise
        print(f"Erro: {e}")
        reconectar_supabase()
        time.sleep(2)
        raise


def to_int(val):
    try:
        return int(val)
    except Exception:
        return None


def ch_to_int(val):
    if val is None:
        return None
    if isinstance(val, int):
        return val
    s = str(val).strip().rstrip('hH')
    return to_int(s)


def remover_acentos(txt):
    return ''.join(c for c in unicodedata.normalize('NFD', txt) if unicodedata.category(c) != 'Mn')


def extrair_codigo_base(curriculo_str):
    if not curriculo_str or not isinstance(curriculo_str, str):
        return None
    s = curriculo_str.strip()
    if '/' in s:
        base = s.split('/', 1)[0].strip()
        return base if base.isdigit() else None
    # Curriculo só com número (ex: "5584") → código base é o próprio número
    return s if s.isdigit() else None


def build_dados_matriz(curriculo_str, periodo_letivo_vigor, turno=None):
    """
    curriculo_completo = cod_curso + versão + ano + turno (ex: "8117/-2 - 2018.2 - DIURNO").
    Turno fica em CURSOS; aqui incluímos no curriculo_completo para manter UNIQUE em matrizes.
    """
    curriculo_str = (curriculo_str or '').strip()
    periodo_letivo_vigor = (periodo_letivo_vigor or '').strip()
    turno = (turno or '').strip().upper()
    partes = [curriculo_str, periodo_letivo_vigor]
    if turno:
        partes.append(turno)
    curriculo_completo = ' - '.join(p for p in partes if p).strip(' - ')
    versao = ''
    if curriculo_str and '/' in curriculo_str:
        sufixo = curriculo_str.split('/', 1)[1].strip()
        versao = sufixo.split(' - ')[0].strip() if ' - ' in sufixo else sufixo
    return {
        'curriculo_completo': curriculo_completo,
        'versao': versao or '',
        'ano_vigor': periodo_letivo_vigor or None,
    }


def prazos_cargas_to_ints(prazos_cargas):
    if not prazos_cargas or not isinstance(prazos_cargas, dict):
        return {}
    return {k: ch_to_int(v) for k, v in prazos_cargas.items()}


def nivel_to_int(nivel_nome):
    if nivel_nome is None:
        return 0
    s = (nivel_nome or '').strip().upper()
    if 'OPTATIVA' in s or s == 'OPTATIVAS':
        return 0
    m = re.match(r'(\d+)', s)
    return int(m.group(1)) if m else 0


def natureza_to_tipo(natureza):
    """Obrigatória -> 0, Optativa -> 1 (schema materias_por_curso.tipo_natureza)."""
    s = (natureza or '').strip().lower()
    return 1 if 'optativa' in s else 0


# Carregar departamentos das matérias (como integracao_banco)
DEPARTAMENTOS_MATERIAS = {}
if os.path.isdir(PASTA_MATERIAS):
    for arquivo in os.listdir(PASTA_MATERIAS):
        if arquivo.startswith('turmas_depto_') and arquivo.endswith('.json'):
            with open(os.path.join(PASTA_MATERIAS, arquivo), 'r', encoding='utf-8') as f:
                for turma in json.load(f):
                    cod = turma.get('codigo', turma.get('codigo_materia'))
                    depto = turma.get('unidade_responsavel', turma.get('departamento', turma.get('depto')))
                    if cod and depto:
                        DEPARTAMENTOS_MATERIAS[cod] = depto

# Carregar materias_detalhadas (como integracao_banco)
materias_detalhadas = {}
if os.path.isdir(PASTA_MATERIAS):
    for arquivo in os.listdir(PASTA_MATERIAS):
        if arquivo.endswith('.json'):
            try:
                with open(os.path.join(PASTA_MATERIAS, arquivo), 'r', encoding='utf-8') as f:
                    for mat in json.load(f):
                        if isinstance(mat, dict) and mat.get('codigo'):
                            materias_detalhadas[mat['codigo']] = mat
            except Exception:
                pass

# Cache codigo_materia -> id_materia
CACHE_ID_MATERIA = {}


def carregar_cache_materias():
    global CACHE_ID_MATERIA
    res = executar_operacao(supabase.table('materias').select('codigo_materia', 'id_materia').execute)
    for r in (res.data or []):
        if r.get('codigo_materia'):
            CACHE_ID_MATERIA[r['codigo_materia']] = r['id_materia']
    print(f"[Cache] {len(CACHE_ID_MATERIA)} matérias carregadas.")


def _id_curso_from_codigo_turno(codigo_base, turno):
    """id_curso = cod_curso do curriculo. DIURNO: codigo_base; NOTURNO: codigo_base + 100000."""
    base = to_int(codigo_base)
    if base is None:
        return None
    turno = (turno or '').strip().upper()
    if turno == 'NOTURNO':
        return base + 100000
    return base  # DIURNO ou vazio


def get_or_create_curso(codigo_base, nome_curso, tipo_curso, turno=None):
    """
    id_curso = cod_curso do curriculo (codigo_base). DIURNO: id=8117; NOTURNO: id=108117.
    Turno fica na tabela cursos.
    """
    turno = (turno or '').strip().upper() or None
    id_curso = _id_curso_from_codigo_turno(codigo_base, turno)
    if id_curso is None:
        return None
    result = executar_operacao(supabase.table('cursos').select('id_curso', 'nome_curso', 'tipo_curso', 'turno').eq('id_curso', id_curso).execute)
    if result.data:
        row = result.data[0]
        updates = {}
        if nome_curso and (row.get('nome_curso') or '') != nome_curso:
            updates['nome_curso'] = nome_curso
        if tipo_curso is not None and row.get('tipo_curso') != tipo_curso:
            updates['tipo_curso'] = tipo_curso
        if turno is not None and row.get('turno') != turno:
            updates['turno'] = turno
        if updates:
            executar_operacao(supabase.table('cursos').update(updates).eq('id_curso', id_curso).execute)
        return id_curso
    insert_data = {
        'id_curso': id_curso,
        'nome_curso': nome_curso,
        'tipo_curso': tipo_curso,
    }
    if turno:
        insert_data['turno'] = turno
    executar_operacao(supabase.table('cursos').insert(insert_data).execute)
    print(f"  [CRIADO] Curso {nome_curso} | turno={turno} (id={id_curso})")
    return id_curso


def get_or_create_matriz(id_curso, curriculo_completo, versao, ano_vigor, prazos_cargas):
    """
    Busca por curriculo_completo (UNIQUE). Turno fica em CURSOS (matrizes não tem turno).
    """
    curriculo_completo = curriculo_completo or ''
    result = executar_operacao(supabase.table('matrizes').select('id_matriz').eq('curriculo_completo', curriculo_completo).execute)
    if result.data:
        return result.data[0]['id_matriz']
    ch = prazos_cargas_to_ints(prazos_cargas or {})
    insert_data = {
        'id_curso': id_curso,
        'curriculo_completo': curriculo_completo,
        'versao': versao or '',
        'ano_vigor': ano_vigor,
        'ch_obrigatoria_exigida': ch.get('ch_obrigatoria_total'),
        'ch_total_exigida': ch.get('total_minima'),
        'ch_optativa_exigida': ch.get('ch_optativa_minima'),
        'ch_complementar_exigida': ch.get('ch_complementar_minima'),
    }
    insert_data = {k: v for k, v in insert_data.items() if v is not None or k in ('curriculo_completo', 'versao', 'ano_vigor')}
    try:
        res = executar_operacao(supabase.table('matrizes').insert(insert_data).execute)
        id_matriz = res.data[0]['id_matriz']
        print(f"  [CRIADO] Matriz {curriculo_completo} (id={id_matriz})")
        return id_matriz
    except Exception:
        result = executar_operacao(supabase.table('matrizes').select('id_matriz').eq('curriculo_completo', curriculo_completo).execute)
        if result.data:
            return result.data[0]['id_matriz']
        raise


def get_or_create_materia(materia):
    """Como integracao_banco: usa materias_detalhadas e DEPARTAMENTOS_MATERIAS."""
    codigo = materia.get('codigo')
    if not codigo:
        return None
    mat_det = materias_detalhadas.get(codigo, materias_detalhadas.get(codigo.upper(), materias_detalhadas.get(codigo.lower(), {})))
    dados = {
        'nome': mat_det.get('nome', materia.get('nome', codigo)),
        'codigo': codigo,
        'carga_horaria': ch_to_int(mat_det.get('carga_horaria', mat_det.get('ch', materia.get('ch', materia.get('carga_horaria', 0))))),
        'ementa': mat_det.get('ementa', materia.get('ementa', '')),
    }
    departamento = DEPARTAMENTOS_MATERIAS.get(codigo, '')
    if codigo in CACHE_ID_MATERIA:
        return CACHE_ID_MATERIA[codigo]  # já existe, não atualiza
    result = executar_operacao(supabase.table('materias').select('id_materia', 'ementa', 'departamento', 'carga_horaria').eq('codigo_materia', codigo).execute)
    if result.data:
        row = result.data[0]
        id_m = row['id_materia']
        CACHE_ID_MATERIA[codigo] = id_m
        if dados['ementa'] and dados['ementa'] != (row.get('ementa') or ''):
            executar_operacao(supabase.table('materias').update({'ementa': dados['ementa']}).eq('id_materia', id_m).execute)
        if departamento and (not row.get('departamento') or row.get('departamento') != departamento):
            executar_operacao(supabase.table('materias').update({'departamento': departamento}).eq('id_materia', id_m).execute)
        ch_novo = dados['carga_horaria'] or 0
        ch_atual = row.get('carga_horaria') or 0
        if ch_novo and ch_novo > 0 and (not ch_atual or ch_atual == 0):
            executar_operacao(supabase.table('materias').update({'carga_horaria': ch_novo}).eq('id_materia', id_m).execute)
        return id_m
    insert_data = {
        'nome_materia': dados['nome'],
        'codigo_materia': codigo,
        'carga_horaria': dados['carga_horaria'] or 0,
        'ementa': dados['ementa'],
        'departamento': departamento,
    }
    res = executar_operacao(supabase.table('materias').insert(insert_data).execute)
    id_m = res.data[0]['id_materia']
    CACHE_ID_MATERIA[codigo] = id_m
    print(f"  [CRIADO] Matéria {codigo}")
    return id_m


def insert_materias_por_curso_batch(linhas, id_matriz):
    """
    Como integracao_banco: insere (id_materia, id_matriz, nivel, tipo_natureza).
    Constraint unique_materia_grade_matriz (id_matriz, id_materia): uma matéria por matriz.
    Mantém primeira ocorrência por id_materia. tipo_natureza: 0=obrigatória, 1=optativa.
    """
    if not linhas:
        return
    try:
        res = executar_operacao(supabase.table('materias_por_curso').select('id_materia').eq('id_matriz', id_matriz).execute)
        existentes_ids = {r['id_materia'] for r in (res.data or [])}
    except Exception:
        existentes_ids = set()
    seen = set()
    to_insert = []
    for (id_m, niv, tipo_nat) in linhas:
        if id_m in existentes_ids or id_m in seen:
            continue
        seen.add(id_m)
        row = {'id_materia': id_m, 'id_matriz': id_matriz, 'nivel': niv}
        if tipo_nat is not None:
            row['tipo_natureza'] = tipo_nat
        to_insert.append(row)
    for i in range(0, len(to_insert), CHUNK_SIZE):
        lote = to_insert[i : i + CHUNK_SIZE]
        try:
            executar_operacao(supabase.table('materias_por_curso').insert(lote).execute)
        except Exception as e:
            if '23505' not in str(e) and 'duplicate key' not in str(e).lower():
                for row in lote:
                    try:
                        executar_operacao(supabase.table('materias_por_curso').insert(row).execute)
                    except Exception:
                        pass


def matriz_existe(curriculo_completo):
    """Retorna (existe: bool, id_matriz ou None). curriculo_completo já inclui turno."""
    curriculo_completo = (curriculo_completo or '').strip()
    result = executar_operacao(supabase.table('matrizes').select('id_matriz').eq('curriculo_completo', curriculo_completo).execute)
    if result.data:
        return True, result.data[0]['id_matriz']
    return False, None


def listar_arquivos_turno():
    """Retorna apenas arquivos com - diurno.json ou - noturno.json."""
    if not os.path.isdir(PASTA_ESTRUTURAS):
        return []
    return [
        f for f in os.listdir(PASTA_ESTRUTURAS)
        if f.endswith('.json') and (' - diurno.json' in f or ' - noturno.json' in f)
    ]


def listar_todos_arquivos_estruturas():
    """Retorna todos os arquivos .json da pasta estruturas-curriculares."""
    if not os.path.isdir(PASTA_ESTRUTURAS):
        return []
    return sorted([f for f in os.listdir(PASTA_ESTRUTURAS) if f.endswith('.json')])


def get_turno_do_arquivo(arquivo, matriz=None):
    """
    Retorna turno (DIURNO/NOTURNO) a partir do JSON ou do nome do arquivo.
    matriz: dict do JSON (opcional); se não passado, só usa o nome do arquivo.
    """
    if matriz and isinstance(matriz, dict) and matriz.get('turno'):
        return (matriz.get('turno') or '').strip().upper()
    arquivo_lower = (arquivo or '').lower()
    if ' - noturno.json' in arquivo_lower:
        return 'NOTURNO'
    if ' - diurno.json' in arquivo_lower:
        return 'DIURNO'
    return ''


def processar_um_arquivo(caminho_arquivo):
    """
    Processa um único arquivo de estrutura curricular (cria curso, matriz e materias_por_curso se não existirem).
    caminho_arquivo: path completo para o JSON.
    Retorna (id_matriz, linhas_inseridas) ou (None, 0) em caso de erro/skip.
    """
    if not os.path.isfile(caminho_arquivo):
        return None, 0
    arquivo = os.path.basename(caminho_arquivo)
    try:
        with open(caminho_arquivo, 'r', encoding='utf-8') as f:
            raw = json.load(f)
    except Exception as e:
        print(f"  [ERRO] Leitura: {e}")
        return None, 0
    # Alguns JSON têm raiz como lista; usar primeiro elemento dict
    if isinstance(raw, list):
        matriz = next((x for x in raw if isinstance(x, dict)), None)
    elif isinstance(raw, dict):
        matriz = raw
    else:
        matriz = None
    if not matriz:
        return None, 0
    nome_curso = remover_acentos(matriz.get('curso', '')).replace('Ç', 'C').upper().strip()
    tipo_curso = matriz.get('tipo_curso')
    periodo_letivo = matriz.get('periodo_letivo_vigor')
    curriculo_str = matriz.get('curriculo') or ''
    if isinstance(curriculo_str, (int, float)):
        curriculo_str = str(curriculo_str)
    curriculo_str = (curriculo_str or '').strip()
    if curriculo_str and '/' not in curriculo_str and curriculo_str.isdigit():
        curriculo_str = curriculo_str + '/1'
    turno = get_turno_do_arquivo(arquivo, matriz)
    codigo_base = extrair_codigo_base(curriculo_str)
    if not codigo_base:
        print(f"  [AVISO] curriculo inválido, pulando.")
        return None, 0
    dados_mat = build_dados_matriz(curriculo_str, periodo_letivo, turno)
    existe, _ = matriz_existe(dados_mat['curriculo_completo'])
    if existe:
        return None, 0  # já existe, não insere
    id_curso = get_or_create_curso(codigo_base, nome_curso, tipo_curso, turno)
    if id_curso is None:
        return None, 0
    prazos_cargas = matriz.get('prazos_cargas') or {}
    id_matriz = get_or_create_matriz(
        id_curso,
        dados_mat['curriculo_completo'],
        dados_mat['versao'],
        dados_mat['ano_vigor'],
        prazos_cargas,
    )
    linhas_matriz = []
    for nivel in matriz.get('niveis', []):
        nivel_int = nivel_to_int(nivel.get('nivel', ''))
        for materia in nivel.get('materias', []):
            id_materia = get_or_create_materia(materia)
            if id_materia is None:
                continue
            tipo_natureza = natureza_to_tipo(materia.get('natureza', ''))
            linhas_matriz.append((id_materia, nivel_int, tipo_natureza))
    insert_materias_por_curso_batch(linhas_matriz, id_matriz)
    return id_matriz, len(linhas_matriz)


def processar():
    arquivos = sorted(listar_arquivos_turno())
    if not arquivos:
        print("Nenhum arquivo com turno (diurno/noturno) encontrado.")
        return
    print(f"Processando {len(arquivos)} arquivos de estruturas com turno...\n")
    carregar_cache_materias()
    materias_criadas_antes = len(CACHE_ID_MATERIA)
    total_registros = 0
    pulados = 0
    for i, arquivo in enumerate(arquivos, 1):
        caminho = os.path.join(PASTA_ESTRUTURAS, arquivo)
        try:
            with open(caminho, 'r', encoding='utf-8') as f:
                matriz = json.load(f)
        except Exception as e:
            print(f"[ERRO] {arquivo}: {e}")
            continue
        nome_curso = remover_acentos(matriz.get('curso', '')).replace('Ç', 'C').upper().strip()
        tipo_curso = matriz.get('tipo_curso')
        periodo_letivo = matriz.get('periodo_letivo_vigor')
        curriculo_str = matriz.get('curriculo') or ''
        turno = matriz.get('turno', '') or ('DIURNO' if ' - diurno.json' in arquivo else 'NOTURNO' if ' - noturno.json' in arquivo else '')
        codigo_base = extrair_codigo_base(curriculo_str)
        if not codigo_base:
            print(f"[AVISO] {arquivo}: curriculo inválido, pulando.")
            continue
        print(f"[{i}/{len(arquivos)}] {arquivo}")
        dados_mat = build_dados_matriz(curriculo_str, periodo_letivo, turno)
        existe, _ = matriz_existe(dados_mat['curriculo_completo'])
        if existe:
            print(f"  → Matriz já existe (curriculo + turno), pulando.")
            pulados += 1
            continue
        id_curso = get_or_create_curso(codigo_base, nome_curso, tipo_curso, turno)
        if id_curso is None:
            continue
        prazos_cargas = matriz.get('prazos_cargas') or {}
        id_matriz = get_or_create_matriz(
            id_curso,
            dados_mat['curriculo_completo'],
            dados_mat['versao'],
            dados_mat['ano_vigor'],
            prazos_cargas,
        )
        linhas_matriz = []
        for nivel in matriz.get('niveis', []):
            nivel_int = nivel_to_int(nivel.get('nivel', ''))
            for materia in nivel.get('materias', []):
                id_materia = get_or_create_materia(materia)
                if id_materia is None:
                    continue
                tipo_natureza = natureza_to_tipo(materia.get('natureza', ''))
                linhas_matriz.append((id_materia, nivel_int, tipo_natureza))
        insert_materias_por_curso_batch(linhas_matriz, id_matriz)
        total_registros += len(linhas_matriz)
    materias_criadas_depois = len(CACHE_ID_MATERIA)
    print(f"\nConcluído. Arquivos pulados (matriz já existe): {pulados}")
    print(f"Vínculos materias_por_curso inseridos: {total_registros}")
    print(f"Matérias novas inseridas: {materias_criadas_depois - materias_criadas_antes}")


if __name__ == '__main__':
    processar()

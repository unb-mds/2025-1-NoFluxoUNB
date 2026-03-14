import os
import json
from supabase import create_client, Client
import time
from tenacity import retry, stop_after_attempt, wait_exponential
import re
from datetime import datetime
import unicodedata

print("Iniciando script...")
# Normalização: id_curso = código antes da / (ex: 8150), usado como PK em cursos e nas FKs (matrizes, equivalencias).

SUPABASE_URL = "https://lijmhbstgdinsukovyfl.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxpam1oYnN0Z2RpbnN1a292eWZsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgzOTM3MywiZXhwIjoyMDYzNDE1MzczfQ._o2wq5p0C6YBIrTGJsNl6xdg4l8Ju7CbwvaaeCWbeAc"
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def reconectar_supabase():
    global supabase
    print("Reconectando ao Supabase...")
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("Reconexão bem-sucedida!")
    except Exception as e:
        print(f"Erro na reconexão: {e}")
        raise

@retry(stop=stop_after_attempt(5), wait=wait_exponential(multiplier=1, min=2, max=15))
def executar_operacao(operacao, *args, **kwargs):
    try:
        resultado = operacao(*args, **kwargs)
        return resultado
    except Exception as e:
        error_msg = str(e).lower()
        if 'duplicate key value violates unique constraint' in error_msg:
            raise
        if any(keyword in error_msg for keyword in ['connection', 'timeout', 'network', 'socket']):
            print(f"Erro de conexão detectado: {str(e)}")
            print("Tentando reconectar...")
            reconectar_supabase()
            time.sleep(3)
            raise
        print(f"Erro na operação: {str(e)}")
        print("Tentando reconectar...")
        reconectar_supabase()
        time.sleep(2)
        raise

# Caminhos das pastas
PASTA_MATRIZES = os.path.join(os.path.dirname(__file__), '..', 'dados', 'estruturas-curriculares')
PASTA_MATERIAS = os.path.join(os.path.dirname(__file__), '..', 'dados', 'materias')

# Utilitário para converter periodo_letivo_vigor em data
def periodo_to_date(periodo):
    if not periodo or not re.match(r'\d{4}\.[12]', str(periodo)):
        return None
    ano, semestre = str(periodo).split('.')
    mes = '01' if semestre == '1' else '07'
    return f"{ano}-{mes}-01"

def to_int(val):
    try:
        return int(val)
    except Exception:
        return None


def ch_to_int(val):
    """Converte carga horária para inteiro; remove sufixo 'h' se existir (ex: '60h' -> 60)."""
    if val is None:
        return None
    if isinstance(val, int):
        return val
    s = str(val).strip().rstrip('hH')
    return to_int(s)


def parse_curriculo(curriculo_str):
    """
    Regra de ouro: o que vem ANTES da / é o código do curso (base). O que vem DEPOIS é o identificador da matriz.
    Ex: "8150/-2", "6360/1 - 2017.1" -> codigo_curso_base="8150" ou "6360", matriz_versao="-2" ou "1".
    Retorna: dict com codigo_curso_base, matriz_versao, matriz_ano (ou None).
    """
    if not curriculo_str or not isinstance(curriculo_str, str):
        return {'codigo_curso_base': None, 'matriz_versao': None, 'matriz_ano': None}
    s = curriculo_str.strip()
    # Sempre: código base = antes da primeira /
    if '/' in s:
        codigo_curso_base = s.split('/', 1)[0].strip()
        resto = s.split('/', 1)[1].strip()
        # matriz_versao = sufixo (ex: "-2" ou "1"); resto pode ser " - 2017.2" após a versão
        if ' - ' in resto and re.search(r'\d{4}\.[12]\s*$', resto):
            parts = re.split(r'\s+-\s+', resto, 1)
            matriz_versao = parts[0].strip()
            matriz_ano = parts[1].strip() if len(parts) > 1 and re.match(r'^\d{4}\.[12]$', parts[1].strip()) else None
        else:
            matriz_versao = resto
            matriz_ano = None
        if not codigo_curso_base or not codigo_curso_base.isdigit():
            return {'codigo_curso_base': None, 'matriz_versao': None, 'matriz_ano': None}
        return {'codigo_curso_base': codigo_curso_base, 'matriz_versao': matriz_versao, 'matriz_ano': matriz_ano}
    return {'codigo_curso_base': None, 'matriz_versao': None, 'matriz_ano': None}


def extrair_codigo_base(curriculo_str):
    """Retorna apenas o código base (antes da /). Ex: '8150/-2' -> '8150'. None se inválido."""
    if not curriculo_str or not isinstance(curriculo_str, str):
        return None
    s = curriculo_str.strip()
    if '/' in s:
        base = s.split('/', 1)[0].strip()
        return base if base.isdigit() else None
    return None


def build_dados_matriz(curriculo_str, periodo_letivo_vigor):
    """
    Monta curriculo_completo, versao e ano_vigor para a tabela matrizes.
    curriculo_completo = "8150/-2 - 2017.2"; versao = parte após /; ano_vigor = periodo_letivo_vigor.
    """
    curriculo_str = (curriculo_str or '').strip()
    periodo_letivo_vigor = (periodo_letivo_vigor or '').strip()
    curriculo_completo = f"{curriculo_str} - {periodo_letivo_vigor}".strip(' - ') if curriculo_str or periodo_letivo_vigor else ''
    # versao = identificador da matriz (sufixo após /), ex: "-2" ou "1"
    versao = None
    if curriculo_str and '/' in curriculo_str:
        sufixo = curriculo_str.split('/', 1)[1].strip()
        versao = sufixo.split(' - ')[0].strip() if ' - ' in sufixo else sufixo
    ano_vigor = periodo_letivo_vigor if periodo_letivo_vigor else None
    return {'curriculo_completo': curriculo_completo, 'versao': versao or '', 'ano_vigor': ano_vigor}


def get_or_create_curso(codigo_base, nome_curso, tipo_curso):
    """
    id_curso = código base (ex: 8150), usado como PK em public.cursos e refletido nas FKs (matrizes, equivalencias).
    Se o curso já existir (id_curso = codigo_base): atualiza nome_curso e tipo_curso. Retorna id_curso (integer).
    Tabela cursos: id_curso (PK, integer/bigint, sem IDENTITY) = código do curso.
    """
    if not codigo_base:
        raise ValueError("codigo_base é obrigatório para get_or_create_curso")
    id_curso = to_int(codigo_base)
    if id_curso is None:
        raise ValueError(f"codigo_base deve ser numérico: {codigo_base}")
    result = executar_operacao(supabase.table('cursos').select('id_curso', 'nome_curso', 'tipo_curso').eq('id_curso', id_curso).execute)
    if result.data:
        row = result.data[0]
        updates = {}
        if nome_curso and (row.get('nome_curso') or '') != nome_curso:
            updates['nome_curso'] = nome_curso
        if tipo_curso is not None and row.get('tipo_curso') != tipo_curso:
            updates['tipo_curso'] = tipo_curso
        if updates:
            executar_operacao(supabase.table('cursos').update(updates).eq('id_curso', id_curso).execute)
        return id_curso
    insert_data = {
        'id_curso': id_curso,
        'nome_curso': nome_curso,
        'tipo_curso': tipo_curso
    }
    executar_operacao(supabase.table('cursos').insert(insert_data).execute)
    return id_curso


def prazos_cargas_to_ints(prazos_cargas):
    """Converte valores do dicionário prazos_cargas (ex: '3210h') para inteiros (3210)."""
    if not prazos_cargas or not isinstance(prazos_cargas, dict):
        return {}
    out = {}
    for k, v in prazos_cargas.items():
        out[k] = ch_to_int(v)
    return out


def get_or_create_matriz(id_curso, curriculo_completo, versao, ano_vigor, prazos_cargas):
    """
    Insere ou busca em public.matrizes. Usa prazos_cargas para colunas de carga horária.
    Retorna id_matriz. Busca primeiro por curriculo_completo (UNIQUE) para evitar duplicata.
    """
    curriculo_completo = curriculo_completo or ''
    # Busca primeiro: evita duplicate key e não dispara retry do tenacity
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
        'ch_complementar_exigida': ch.get('ch_complementar_minima')
    }
    insert_data = {k: v for k, v in insert_data.items() if v is not None or k in ('curriculo_completo', 'versao', 'ano_vigor')}
    try:
        res = executar_operacao(supabase.table('matrizes').insert(insert_data).execute)
        return res.data[0]['id_matriz']
    except Exception:
        result = executar_operacao(supabase.table('matrizes').select('id_matriz').eq('curriculo_completo', curriculo_completo).execute)
        if result.data:
            return result.data[0]['id_matriz']
        raise

# Carregar departamentos das matérias a partir dos arquivos turmas_depto_*.json
DEPARTAMENTOS_MATERIAS = {}
PASTA_TURMAS_DEPTO = os.path.join(os.path.dirname(__file__), '..', 'dados', 'materias')
for arquivo in os.listdir(PASTA_TURMAS_DEPTO):
    if arquivo.startswith('turmas_depto_') and arquivo.endswith('.json'):
        with open(os.path.join(PASTA_TURMAS_DEPTO, arquivo), 'r', encoding='utf-8') as f:
            turmas = json.load(f)
            for turma in turmas:
                cod = turma.get('codigo', turma.get('codigo_materia', None))
                depto = turma.get('unidade_responsavel', turma.get('departamento', turma.get('depto', None)))
                if cod and depto:
                    DEPARTAMENTOS_MATERIAS[cod] = depto

# Cache codigo_materia -> id_materia para evitar SELECT por matéria (reduz milhares de chamadas à API)
CACHE_ID_MATERIA = {}
try:
    res = executar_operacao(supabase.table('materias').select('codigo_materia', 'id_materia').execute)
    for r in (res.data or []):
        if r.get('codigo_materia'):
            CACHE_ID_MATERIA[r['codigo_materia']] = r['id_materia']
    print(f"[Cache] {len(CACHE_ID_MATERIA)} matérias carregadas (codigo -> id_materia).")
except Exception:
    pass

def get_or_create_materia(materia):
    codigo = materia['codigo']
    departamento = DEPARTAMENTOS_MATERIAS.get(codigo, '')
    # Usar cache para evitar SELECT em toda matéria
    id_materia = CACHE_ID_MATERIA.get(codigo)
    ch_novo = ch_to_int(materia.get('carga_horaria', materia.get('ch', 0)))
    if id_materia is not None:
        # Preencher carga_horária quando existir e for > 0 (evita matérias com 0 créditos)
        if ch_novo and ch_novo > 0:
            try:
                executar_operacao(supabase.table('materias').update({'carga_horaria': ch_novo}).eq('id_materia', id_materia).execute)
            except Exception:
                pass
        return id_materia
    result = executar_operacao(supabase.table('materias').select('id_materia', 'ementa', 'departamento', 'carga_horaria').eq('codigo_materia', codigo).execute)
    if result.data:
        id_materia = result.data[0]['id_materia']
        CACHE_ID_MATERIA[codigo] = id_materia
        ementa_atual = result.data[0].get('ementa', '')
        departamento_atual = result.data[0].get('departamento', '')
        ch_atual = result.data[0].get('carga_horaria') or 0
        if materia.get('ementa', '') and materia.get('ementa', '') != ementa_atual:
            executar_operacao(supabase.table('materias').update({'ementa': materia.get('ementa', '')}).eq('id_materia', id_materia).execute)
        if departamento and (not departamento_atual or departamento != departamento_atual):
            executar_operacao(supabase.table('materias').update({'departamento': departamento}).eq('id_materia', id_materia).execute)
        if ch_novo and ch_novo > 0 and (not ch_atual or ch_atual == 0):
            executar_operacao(supabase.table('materias').update({'carga_horaria': ch_novo}).eq('id_materia', id_materia).execute)
        return id_materia
    insert_data = {
        'nome_materia': materia['nome'],
        'codigo_materia': codigo,
        'carga_horaria': ch_to_int(materia.get('carga_horaria', materia.get('ch', 0))),
        'ementa': materia.get('ementa', ''),
        'departamento': departamento
    }
    res = executar_operacao(supabase.table('materias').insert(insert_data).execute)
    id_materia = res.data[0]['id_materia']
    CACHE_ID_MATERIA[codigo] = id_materia
    return id_materia

def nivel_to_int(nivel_nome):
    """Converte '1° NIVEL' -> 1, 'OPTATIVAS' -> 0. Sempre retorna inteiro."""
    if nivel_nome is None:
        return 0
    s = (nivel_nome or '').strip().upper()
    if 'OPTATIVA' in s or s == 'OPTATIVAS':
        return 0
    m = re.match(r'(\d+)', s)
    if m:
        return int(m.group(1))
    return 0


def get_or_create_materia_por_curso(id_materia, id_matriz, nivel):
    """Vincula matéria à matriz. nivel: inteiro. (Para uso unitário; em lote use insert_materias_por_curso_batch.)"""
    nivel_int = int(nivel) if isinstance(nivel, int) else nivel_to_int(nivel)
    insert_data = {'id_materia': id_materia, 'id_matriz': id_matriz, 'nivel': nivel_int}
    try:
        res = executar_operacao(supabase.table('materias_por_curso').insert(insert_data).execute)
        return res.data[0].get('id_materia_curso') or res.data[0].get('id') if res.data else None
    except Exception:
        result = executar_operacao(supabase.table('materias_por_curso').select('id_materia_curso').eq('id_materia', id_materia).eq('id_matriz', id_matriz).eq('nivel', nivel_int).execute)
        return result.data[0].get('id_materia_curso') if result.data else None


def insert_materias_por_curso_batch(linhas, id_matriz, tamanho_lote=80):
    """
    Insere em lote (id_materia, id_matriz, nivel). linhas = list of (id_materia, nivel_int).
    A constraint unique_materia_grade_matriz é (id_matriz, id_materia): uma matéria por matriz.
    Mantém a primeira ocorrência de cada id_materia (primeiro nivel visto). Ignora duplicatas.
    """
    if not linhas:
        return
    try:
        res = executar_operacao(supabase.table('materias_por_curso').select('id_materia').eq('id_matriz', id_matriz).execute)
        existentes_ids = {r['id_materia'] for r in (res.data or [])}
    except Exception:
        existentes_ids = set()
    # Uma linha por id_materia (primeiro nivel encontrado); evita violar unique (id_matriz, id_materia)
    seen = set()
    to_insert = []
    for (id_m, niv) in linhas:
        if id_m in existentes_ids or id_m in seen:
            continue
        seen.add(id_m)
        to_insert.append({'id_materia': id_m, 'id_matriz': id_matriz, 'nivel': niv})
    for i in range(0, len(to_insert), tamanho_lote):
        lote = to_insert[i : i + tamanho_lote]
        try:
            executar_operacao(supabase.table('materias_por_curso').insert(lote).execute)
        except Exception as e:
            # Duplicata (ex.: inserção concorrente): ignora; fallback linha a linha só se necessário
            if '23505' not in str(e) and 'duplicate key' not in str(e).lower():
                for row in lote:
                    try:
                        executar_operacao(supabase.table('materias_por_curso').insert(row).execute)
                    except Exception:
                        pass

def _eh_requisito_unico(expr):
    """Retorna True se a expressão for uma única disciplina (sem operadores E, OU ou parênteses)."""
    if not expr or not isinstance(expr, str):
        return False
    e = expr.strip().upper()
    if ' E ' in e or ' OU ' in e or '(' in e or ')' in e:
        return False
    return True


def _id_materia_requisito_unico(expr):
    """Se a expressão tiver exatamente um código de matéria, retorna id_materia; senão None.
    Assim preenchemos id_materia_requisito/id_materia_corequisito mesmo com parênteses, ex: ((BOT0008))."""
    codigos = _codigos_na_expressao(expr)
    if len(codigos) != 1:
        return None
    return _id_materia_from_cache(codigos[0])


def _codigos_na_expressao(expr):
    """Extrai códigos de disciplinas da expressão (ex: ADM001, MAT0025). Padrão: letras + números."""
    if not expr or not isinstance(expr, str):
        return []
    return re.findall(r'[A-Z]{2,}\d{2,}[A-Z0-9]*', expr.upper()) or re.findall(r'[A-Z]+\d+', expr.upper())


def build_expressao_logica(expr):
    """
    Converte a string de expressão (ex: '(CIC0100 OU CIC0101)', '(A E B)', 'ADM0023')
    em um objeto JSONB: {"operador": "OU"|"E"|null, "materias": ["CIC0100", "CIC0101"]}.
    Usado em expressao_logica das tabelas equivalencias, pre_requisitos e co_requisitos.
    """
    if not expr or not isinstance(expr, str):
        return None
    e = expr.strip()
    if not e:
        return None
    materias = _codigos_na_expressao(e)
    e_upper = e.upper()
    if ' OU ' in e_upper:
        operador = 'OU'
    elif ' E ' in e_upper:
        operador = 'E'
    else:
        operador = None
    return {'operador': operador, 'materias': materias}


def _id_materia_from_cache(codigo):
    """Retorna id_materia do cache; tenta codigo, upper e lower para evitar falha por casing."""
    if not codigo:
        return None
    return (
        CACHE_ID_MATERIA.get(codigo)
        or CACHE_ID_MATERIA.get(codigo.upper())
        or CACHE_ID_MATERIA.get(codigo.lower())
    )


def _codigos_em_expressoes_mat_det(mat_det):
    """Retorna set de códigos de matérias que aparecem em pre_requisitos, co_requisitos, equivalências e equivalencias_especificas."""
    codigos = set()
    for campo, key in [
        ('pre_requisitos', None),
        ('co_requisitos', None),
        ('equivalencias', None),
        ('equivalencias_especificas', 'expressao')
    ]:
        val = mat_det.get(campo)
        if not val or val == '-':
            continue
        if isinstance(val, list):
            for item in val:
                expr = item.get(key, item.get('expressao', '')) if isinstance(item, dict) else str(item)
                codigos.update(_codigos_na_expressao(expr))
        else:
            codigos.update(_codigos_na_expressao(str(val)))
    return codigos


def ensure_materias_existem(codigos, materias_detalhadas_dict=None):
    """
    Garante que todas as matérias com os códigos existam no banco (e no CACHE_ID_MATERIA).
    Cria com dados de materias_detalhadas_dict[codigo] ou registro mínimo. Não insere em pre/co/equiv.
    """
    if not codigos:
        return
    detalhes = materias_detalhadas_dict or {}
    for cod in codigos:
        if not cod:
            continue
        if _id_materia_from_cache(cod) is not None:
            continue
        mat = detalhes.get(cod) or detalhes.get(cod.upper()) or detalhes.get(cod.lower())
        if isinstance(mat, dict):
            get_or_create_materia({
                'nome': mat.get('nome', cod),
                'codigo': cod,
                'carga_horaria': ch_to_int(mat.get('carga_horaria', mat.get('ch', 0))),
                'ementa': mat.get('ementa', '')
            })
        else:
            get_or_create_materia({'nome': cod, 'codigo': cod, 'carga_horaria': 0, 'ementa': ''})


def get_or_create_pre_requisito(id_materia, expressao_original, id_materia_requisito=None):
    """Salva expressao_original e expressao_logica (JSONB); id_materia_requisito quando for matéria única."""
    payload = {'id_materia': id_materia, 'expressao_original': expressao_original}
    logica = build_expressao_logica(expressao_original)
    if logica is not None:
        payload['expressao_logica'] = logica
    if id_materia_requisito is not None:
        payload['id_materia_requisito'] = id_materia_requisito
    try:
        res = executar_operacao(supabase.table('pre_requisitos').insert(payload).execute)
        return res.data[0]['id_pre_requisito']
    except Exception:
        result = executar_operacao(supabase.table('pre_requisitos').select('id_pre_requisito').eq('id_materia', id_materia).eq('expressao_original', expressao_original).execute)
        return result.data[0]['id_pre_requisito'] if result.data else None


def get_or_create_co_requisito(id_materia, expressao_original, id_materia_corequisito=None):
    """Salva expressao_original e expressao_logica (JSONB); id_materia_corequisito quando for matéria única."""
    payload = {'id_materia': id_materia, 'expressao_original': expressao_original}
    logica = build_expressao_logica(expressao_original)
    if logica is not None:
        payload['expressao_logica'] = logica
    if id_materia_corequisito is not None:
        payload['id_materia_corequisito'] = id_materia_corequisito
    try:
        res = executar_operacao(supabase.table('co_requisitos').insert(payload).execute)
        return res.data[0]['id_co_requisito']
    except Exception:
        result = executar_operacao(supabase.table('co_requisitos').select('id_co_requisito').eq('id_materia', id_materia).eq('expressao_original', expressao_original).execute)
        return result.data[0]['id_co_requisito'] if result.data else None


def get_or_create_equivalencia(id_materia, id_curso, expressao_original, curriculo=None, data_vigencia=None):
    """Schema equivalencias: id_materia, id_curso, curriculo, data_vigencia, fim_vigencia, expressao_original, expressao_logica."""
    payload = {'id_materia': id_materia, 'id_curso': id_curso, 'expressao_original': expressao_original, 'curriculo': curriculo, 'data_vigencia': data_vigencia}
    logica = build_expressao_logica(expressao_original)
    if logica is not None:
        payload['expressao_logica'] = logica
    try:
        res = executar_operacao(supabase.table('equivalencias').insert(payload).execute)
        return res.data[0]['id_equivalencia']
    except Exception:
        result = executar_operacao(supabase.table('equivalencias').select('id_equivalencia').eq('id_materia', id_materia).eq('id_curso', id_curso or '').eq('expressao_original', expressao_original).execute)
        return result.data[0]['id_equivalencia'] if result.data else None

def remover_acentos(txt):
    return ''.join(c for c in unicodedata.normalize('NFD', txt) if unicodedata.category(c) != 'Mn')

# Carregar todos os dados de matérias detalhadas em cache para busca rápida
materias_detalhadas = {}
for arquivo in os.listdir(PASTA_MATERIAS):
    if not arquivo.endswith('.json'):
        continue
    with open(os.path.join(PASTA_MATERIAS, arquivo), 'r', encoding='utf-8') as f:
        materias = json.load(f)
        for mat in materias:
            materias_detalhadas[mat['codigo']] = mat

# Cache de cursos existentes (id_curso = código base numérico)
cursos_existentes = set()
try:
    res = executar_operacao(supabase.table('cursos').select('id_curso').execute)
    for c in (res.data or []):
        if c.get('id_curso') is not None:
            cursos_existentes.add(c['id_curso'])
except Exception:
    pass

materias_existentes = set()
res = executar_operacao(supabase.table('materias').select('codigo_materia').execute)
for m in res.data:
    materias_existentes.add(m['codigo_materia'])

def processar_matrizes():
    print("Processando matrizes curriculares...")
    # Cache da lista de cursos (evita N chamadas na equivalências específicas)
    try:
        res_cursos = executar_operacao(supabase.table('cursos').select('id_curso', 'nome_curso').execute)
        CACHE_CURSOS_LISTA = list(res_cursos.data or [])
    except Exception:
        CACHE_CURSOS_LISTA = []
    total_arquivos = len([f for f in os.listdir(PASTA_MATRIZES) if f.endswith('.json')])
    for i, arquivo in enumerate(os.listdir(PASTA_MATRIZES), 1):
        if not arquivo.endswith('.json'):
            continue
        print(f"\r[{i}/{total_arquivos}] {arquivo[:50]}...", end='', flush=True)
        with open(os.path.join(PASTA_MATRIZES, arquivo), 'r', encoding='utf-8') as f:
            matriz = json.load(f)
            nome_curso = remover_acentos(matriz['curso']).replace('Ç', 'C').upper().strip()
            tipo_curso = matriz.get('tipo_curso')
            periodo_letivo = matriz.get('periodo_letivo_vigor')
            curriculo_str = matriz.get('curriculo') or ''
            codigo_base = extrair_codigo_base(curriculo_str)
            if not codigo_base:
                continue
            id_curso = get_or_create_curso(codigo_base, nome_curso, tipo_curso)
            if not any(c.get('id_curso') == id_curso for c in CACHE_CURSOS_LISTA):
                CACHE_CURSOS_LISTA.append({'id_curso': id_curso, 'nome_curso': nome_curso})
            cursos_existentes.add(id_curso)
            dados_mat = build_dados_matriz(curriculo_str, periodo_letivo)
            prazos_cargas = matriz.get('prazos_cargas') or {}
            id_matriz = get_or_create_matriz(
                id_curso,
                dados_mat['curriculo_completo'],
                dados_mat['versao'],
                dados_mat['ano_vigor'],
                prazos_cargas
            )
            # Coletar todas as (id_materia, nivel) e garantir que existam no banco
            linhas_matriz = []
            for nivel in matriz['niveis']:
                nivel_int = nivel_to_int(nivel.get('nivel', ''))
                for materia in nivel['materias']:
                    codigo = materia['codigo']
                    mat_det = materias_detalhadas.get(codigo, {})
                    dados_materia = {
                        'nome': mat_det.get('nome', materia['nome']),
                        'codigo': codigo,
                        'carga_horaria': ch_to_int(mat_det.get('carga_horaria', materia.get('carga_horaria', materia.get('ch', 0)))),
                        'ementa': mat_det.get('ementa', materia.get('ementa', ''))
                    }
                    id_materia = get_or_create_materia(dados_materia)
                    linhas_matriz.append((id_materia, nivel_int))
            # Garantir que todas as matérias referenciadas em pre/co/equiv existam (uma vez por matriz)
            codigos_ref_matriz = set()
            for nivel in matriz['niveis']:
                for materia in nivel['materias']:
                    mat_det = materias_detalhadas.get(materia['codigo'], {})
                    codigos_ref_matriz.update(_codigos_em_expressoes_mat_det(mat_det))
            ensure_materias_existem(codigos_ref_matriz, materias_detalhadas)
            insert_materias_por_curso_batch(linhas_matriz, id_matriz)
            # Buscar em 3 chamadas (não N) todos os pre/co/requisitos e equivalências já existentes para as matérias desta matriz
            id_materias_matriz = list({CACHE_ID_MATERIA.get(m['codigo']) for nivel in matriz['niveis'] for m in nivel['materias'] if CACHE_ID_MATERIA.get(m['codigo']) is not None})
            pre_existentes = set()
            co_existentes = set()
            equiv_existentes = set()
            if id_materias_matriz:
                try:
                    r_pre = executar_operacao(supabase.table('pre_requisitos').select('id_materia', 'expressao_original').in_('id_materia', id_materias_matriz).execute)
                    for row in (r_pre.data or []):
                        pre_existentes.add((row['id_materia'], (row.get('expressao_original') or '').strip()))
                except Exception:
                    pass
                try:
                    r_co = executar_operacao(supabase.table('co_requisitos').select('id_materia', 'expressao_original').in_('id_materia', id_materias_matriz).execute)
                    for row in (r_co.data or []):
                        co_existentes.add((row['id_materia'], (row.get('expressao_original') or '').strip()))
                except Exception:
                    pass
                try:
                    r_eq = executar_operacao(supabase.table('equivalencias').select('id_materia', 'expressao_original', 'id_curso', 'curriculo').in_('id_materia', id_materias_matriz).execute)
                    for row in (r_eq.data or []):
                        equiv_existentes.add((row['id_materia'], (row.get('expressao_original') or '').strip(), row.get('id_curso'), row.get('curriculo')))
                except Exception:
                    pass
            # Pré/co-requisitos e equivalências (só após matérias existirem no banco)
            for nivel in matriz['niveis']:
                nivel_int = nivel_to_int(nivel.get('nivel', ''))
                for materia in nivel['materias']:
                    codigo = materia['codigo']
                    id_materia = CACHE_ID_MATERIA.get(codigo)
                    if id_materia is None:
                        continue
                    mat_det = materias_detalhadas.get(codigo, {})
                    # Pré-requisitos: id_materia_requisito preenchido quando há exatamente uma matéria na expressão (ex: ((BOT0008)))
                    pre = mat_det.get('pre_requisitos', None)
                    if pre and pre != '-' and pre is not None:
                        expr = (pre or '').strip()
                        codigos_pre = _codigos_na_expressao(expr)
                        id_pre = _id_materia_requisito_unico(expr)
                        if id_pre is not None or len(codigos_pre) != 1:
                            if (id_materia, expr) not in pre_existentes:
                                get_or_create_pre_requisito(id_materia, expr, id_pre)
                                pre_existentes.add((id_materia, expr))
                    # Co-requisitos: id_materia_corequisito preenchido quando há exatamente uma matéria na expressão
                    co = mat_det.get('co_requisitos', None)
                    if co and co != '-' and co is not None:
                        expr = (co or '').strip()
                        codigos_co = _codigos_na_expressao(expr)
                        id_co = _id_materia_requisito_unico(expr)
                        if id_co is not None or len(codigos_co) != 1:
                            if (id_materia, expr) not in co_existentes:
                                get_or_create_co_requisito(id_materia, expr, id_co)
                                co_existentes.add((id_materia, expr))
                    # Equivalências: expressao + expressao_original
                    eq = mat_det.get('equivalencias', None)
                    if eq and eq != '-' and eq is not None:
                        expr_eq = (eq or '').strip()
                        chave_equiv = (id_materia, expr_eq, None, None)
                        if chave_equiv not in equiv_existentes:
                            executar_operacao(supabase.table('equivalencias').insert({
                                'id_materia': id_materia,
                                'id_curso': None,
                                'expressao_original': expr_eq,
                                'expressao_logica': build_expressao_logica(expr_eq),
                                'curriculo': None,
                                'data_vigencia': None
                            }).execute)
                            equiv_existentes.add(chave_equiv)
                    # Equivalências específicas (com expressao_original)
                    equiv_esp = mat_det.get('equivalencias_especificas', None)
                    if equiv_esp and isinstance(equiv_esp, list):
                        for eqesp in equiv_esp:
                            nome_curso_esp = remover_acentos(eqesp.get('matriz_curricular', '').strip().split(' - ')[0].upper())
                            curriculo_raw = eqesp.get('curriculo', '').strip()
                            match = re.search(r'(\d{4}\.\d)', curriculo_raw)
                            periodo_letivo_esp = match.group(1) if match else ''
                            id_curso_esp = None
                            codigo_base_esp = extrair_codigo_base(curriculo_raw)
                            if codigo_base_esp:
                                id_c = to_int(codigo_base_esp)
                                if id_c is not None and any(c.get('id_curso') == id_c for c in CACHE_CURSOS_LISTA):
                                    id_curso_esp = id_c
                            if id_curso_esp is None and nome_curso_esp:
                                for curso in CACHE_CURSOS_LISTA:
                                    nome_curso_banco = remover_acentos((curso.get('nome_curso') or '').strip().upper())
                                    if nome_curso_banco == nome_curso_esp:
                                        id_curso_esp = curso['id_curso']
                                        break
                            data_vigencia_raw = eqesp.get('data_vigencia', '').strip()
                            fim_vigencia_raw = eqesp.get('fim_vigencia', '').strip()
                            data_vigencia_eq = periodo_letivo_to_date(data_vigencia_raw)
                            fim_vigencia_eq = periodo_letivo_to_date(fim_vigencia_raw) if fim_vigencia_raw else None
                            expr_esp = eqesp.get('expressao', '').strip()
                            if id_curso_esp and curriculo_raw and data_vigencia_eq and expr_esp:
                                chave_esp = (id_materia, expr_esp, id_curso_esp, curriculo_raw)
                                if chave_esp not in equiv_existentes:
                                    executar_operacao(
                                        supabase.table('equivalencias').insert({
                                            'id_materia': id_materia,
                                            'id_curso': id_curso_esp,
                                            'expressao_original': expr_esp,
                                            'expressao_logica': build_expressao_logica(expr_esp),
                                            'curriculo': curriculo_raw,
                                            'data_vigencia': data_vigencia_eq,
                                            'fim_vigencia': fim_vigencia_eq
                                        }).execute
                                    )
                                    equiv_existentes.add(chave_esp)
    print("\nMatrizes curriculares processadas!")

def processar_materias():
    print("Processando matérias (pré/co-requisitos e equivalências)...")
    lista_arquivos = sorted([f for f in os.listdir(PASTA_MATERIAS) if f.endswith('.json')])
    try:
        res_c = executar_operacao(supabase.table('cursos').select('id_curso', 'nome_curso').execute)
        cache_cursos = list(res_c.data or [])
    except Exception:
        cache_cursos = []
    # Fase 1: garantir que todas as matérias (e as referenciadas em expressões) existam no banco
    print("  Fase 1: garantindo que todas as matérias existam no banco...")
    for idx, arquivo in enumerate(lista_arquivos, 1):
        print(f"\r[Matérias {idx}/{len(lista_arquivos)}] {arquivo[:40]}...", end='', flush=True)
        with open(os.path.join(PASTA_MATERIAS, arquivo), 'r', encoding='utf-8') as f:
            materias = json.load(f)
            for materia in materias:
                codigo = materia['codigo']
                get_or_create_materia({
                    'nome': materia['nome'],
                    'codigo': codigo,
                    'carga_horaria': ch_to_int(materia.get('carga_horaria', materia.get('ch', 0))),
                    'ementa': materia.get('ementa', '')
                })
                codigos_ref = _codigos_em_expressoes_mat_det(materia)
                ensure_materias_existem(codigos_ref, materias_detalhadas)
    # Fase 2: inserir pré/co-requisitos e equivalências (matérias já existem)
    print("\n  Fase 2: inserindo pré/co-requisitos e equivalências...")
    for idx, arquivo in enumerate(lista_arquivos, 1):
        print(f"\r[Matérias {idx}/{len(lista_arquivos)}] {arquivo[:40]}...", end='', flush=True)
        with open(os.path.join(PASTA_MATERIAS, arquivo), 'r', encoding='utf-8') as f:
            materias = json.load(f)
            for materia in materias:
                codigo = materia['codigo']
                id_materia = _id_materia_from_cache(codigo)
                if id_materia is None:
                    continue
                # Pré-requisitos: id_materia_requisito preenchido quando há exatamente uma matéria na expressão
                pre = materia.get('pre_requisitos', '')
                if pre and pre != '-':
                    expr = (pre or '').strip()
                    codigos_pre = _codigos_na_expressao(expr)
                    id_pre = _id_materia_requisito_unico(expr)
                    if id_pre is not None or len(codigos_pre) != 1:
                        result = executar_operacao(supabase.table('pre_requisitos').select('id_pre_requisito').eq('id_materia', id_materia).eq('expressao_original', expr).execute)
                        if not result.data:
                            get_or_create_pre_requisito(id_materia, expr, id_pre)
                # Co-requisitos: id_materia_corequisito preenchido quando há exatamente uma matéria na expressão
                co = materia.get('co_requisitos', '')
                if co and co != '-':
                    expr = (co or '').strip()
                    codigos_co = _codigos_na_expressao(expr)
                    id_co = _id_materia_requisito_unico(expr)
                    if id_co is not None or len(codigos_co) != 1:
                        result = executar_operacao(supabase.table('co_requisitos').select('id_co_requisito').eq('id_materia', id_materia).eq('expressao_original', expr).execute)
                        if not result.data:
                            get_or_create_co_requisito(id_materia, expr, id_co)
                # Equivalências: expressao_original + expressao_logica
                eq = materia.get('equivalencias', '')
                if eq and eq != '-':
                    expr_eq = (eq or '').strip()
                    result = executar_operacao(supabase.table('equivalencias').select('id_equivalencia').eq('id_materia', id_materia).eq('expressao_original', expr_eq).is_('id_curso', 'null').execute)
                    if not result.data:
                        executar_operacao(supabase.table('equivalencias').insert({
                            'id_materia': id_materia,
                            'id_curso': None,
                            'expressao_original': expr_eq,
                            'expressao_logica': build_expressao_logica(expr_eq),
                            'curriculo': None,
                            'data_vigencia': None
                        }).execute)
                # Equivalências específicas (usa cache de cursos)
                equiv_esp = materia.get('equivalencias_especificas', None)
                if equiv_esp and isinstance(equiv_esp, list):
                    for eqesp in equiv_esp:
                        nome_curso_esp = remover_acentos(eqesp.get('matriz_curricular', '').strip().split(' - ')[0].upper())
                        curriculo_raw = eqesp.get('curriculo', '').strip()
                        id_curso_esp = None
                        codigo_base_esp = extrair_codigo_base(curriculo_raw)
                        if codigo_base_esp:
                            id_c = to_int(codigo_base_esp)
                            if id_c is not None and any(c.get('id_curso') == id_c for c in cache_cursos):
                                id_curso_esp = id_c
                        if id_curso_esp is None:
                            for curso in cache_cursos:
                                nome_curso_banco = remover_acentos((curso.get('nome_curso') or '').strip().upper())
                                if nome_curso_banco == nome_curso_esp:
                                    id_curso_esp = curso['id_curso']
                                    break
                        data_vigencia_eq = periodo_letivo_to_date(eqesp.get('data_vigencia', '').strip())
                        fim_vigencia_eq = periodo_letivo_to_date(eqesp.get('fim_vigencia', '').strip()) if eqesp.get('fim_vigencia') else None
                        expr_esp = eqesp.get('expressao', '').strip()
                        if id_curso_esp and curriculo_raw and data_vigencia_eq and expr_esp:
                            result = executar_operacao(
                                supabase.table('equivalencias')
                                .select('id_equivalencia')
                                .eq('id_materia', id_materia)
                                .eq('id_curso', id_curso_esp)
                                .eq('expressao_original', expr_esp)
                                .eq('curriculo', curriculo_raw)
                                .execute
                            )
                            if not result.data:
                                executar_operacao(
                                    supabase.table('equivalencias').insert({
                                        'id_materia': id_materia,
                                        'id_curso': id_curso_esp,
                                        'expressao_original': expr_esp,
                                        'expressao_logica': build_expressao_logica(expr_esp),
                                        'curriculo': curriculo_raw,
                                        'data_vigencia': data_vigencia_eq,
                                        'fim_vigencia': fim_vigencia_eq
                                    }).execute
                                )
    print("\nMatérias processadas!")

def periodo_letivo_to_date(periodo):
    if not periodo or not re.match(r'\d{4}\.\d', periodo):
        return None
    ano, semestre = periodo.split('.')
    mes = '01' if semestre == '1' else '07'
    return f"{ano}-{mes}-01"


def processar_uma_matriz(arquivo_path):
    """
    Processa um único arquivo de estrutura curricular (ex.: direito - 2019.2.json).
    arquivo_path: caminho completo ou apenas o nome do arquivo (será buscado em PASTA_MATRIZES).
    """
    if not os.path.isabs(arquivo_path) and not os.path.dirname(arquivo_path):
        arquivo_path = os.path.join(PASTA_MATRIZES, arquivo_path)
    if not os.path.isfile(arquivo_path):
        raise FileNotFoundError(f"Arquivo não encontrado: {arquivo_path}")
    with open(arquivo_path, 'r', encoding='utf-8') as f:
        matriz = json.load(f)
    nome_arquivo = os.path.basename(arquivo_path)
    print(f"Processando: {nome_arquivo}")

    try:
        res_c = executar_operacao(supabase.table('cursos').select('id_curso', 'nome_curso').execute)
        cache_cursos_lista = list(res_c.data or [])
    except Exception:
        cache_cursos_lista = []

    nome_curso = remover_acentos(matriz['curso']).replace('Ç', 'C').upper().strip()
    tipo_curso = matriz.get('tipo_curso')
    periodo_letivo = matriz.get('periodo_letivo_vigor')
    curriculo_str = matriz.get('curriculo') or ''
    codigo_base = extrair_codigo_base(curriculo_str)
    if not codigo_base:
        raise ValueError(f"Currículo inválido no arquivo: {curriculo_str}")
    id_curso = get_or_create_curso(codigo_base, nome_curso, tipo_curso)
    if not any(c.get('id_curso') == id_curso for c in cache_cursos_lista):
        cache_cursos_lista.append({'id_curso': id_curso, 'nome_curso': nome_curso})
    dados_mat = build_dados_matriz(curriculo_str, periodo_letivo)
    prazos_cargas = matriz.get('prazos_cargas') or {}
    id_matriz = get_or_create_matriz(
        id_curso,
        dados_mat['curriculo_completo'],
        dados_mat['versao'],
        dados_mat['ano_vigor'],
        prazos_cargas
    )
    linhas_matriz = []
    for nivel in matriz['niveis']:
        nivel_int = nivel_to_int(nivel.get('nivel', ''))
        for materia in nivel['materias']:
            codigo = materia['codigo']
            mat_det = materias_detalhadas.get(codigo, {})
            dados_materia = {
                'nome': mat_det.get('nome', materia['nome']),
                'codigo': codigo,
                'carga_horaria': ch_to_int(mat_det.get('carga_horaria', materia.get('carga_horaria', materia.get('ch', 0)))),
                'ementa': mat_det.get('ementa', materia.get('ementa', ''))
            }
            id_materia = get_or_create_materia(dados_materia)
            linhas_matriz.append((id_materia, nivel_int))
    codigos_ref_matriz = set()
    for nivel in matriz['niveis']:
        for m in nivel['materias']:
            mat_det = materias_detalhadas.get(m['codigo'], {})
            codigos_ref_matriz.update(_codigos_em_expressoes_mat_det(mat_det))
    ensure_materias_existem(codigos_ref_matriz, materias_detalhadas)
    insert_materias_por_curso_batch(linhas_matriz, id_matriz)

    id_materias_matriz = list({CACHE_ID_MATERIA.get(m['codigo']) for nivel in matriz['niveis'] for m in nivel['materias'] if CACHE_ID_MATERIA.get(m['codigo']) is not None})
    pre_existentes = set()
    co_existentes = set()
    equiv_existentes = set()
    if id_materias_matriz:
        try:
            r_pre = executar_operacao(supabase.table('pre_requisitos').select('id_materia', 'expressao_original').in_('id_materia', id_materias_matriz).execute)
            for row in (r_pre.data or []):
                pre_existentes.add((row['id_materia'], (row.get('expressao_original') or '').strip()))
        except Exception:
            pass
        try:
            r_co = executar_operacao(supabase.table('co_requisitos').select('id_materia', 'expressao_original').in_('id_materia', id_materias_matriz).execute)
            for row in (r_co.data or []):
                co_existentes.add((row['id_materia'], (row.get('expressao_original') or '').strip()))
        except Exception:
            pass
        try:
            r_eq = executar_operacao(supabase.table('equivalencias').select('id_materia', 'expressao_original', 'id_curso', 'curriculo').in_('id_materia', id_materias_matriz).execute)
            for row in (r_eq.data or []):
                equiv_existentes.add((row['id_materia'], (row.get('expressao_original') or '').strip(), row.get('id_curso'), row.get('curriculo')))
        except Exception:
            pass

    for nivel in matriz['niveis']:
        for materia in nivel['materias']:
            codigo = materia['codigo']
            id_materia = CACHE_ID_MATERIA.get(codigo)
            if id_materia is None:
                continue
            mat_det = materias_detalhadas.get(codigo, {})
            pre = mat_det.get('pre_requisitos', None)
            if pre and pre != '-' and pre is not None:
                expr = (pre or '').strip()
                codigos_pre = _codigos_na_expressao(expr)
                id_pre = _id_materia_requisito_unico(expr)
                if id_pre is not None or len(codigos_pre) != 1:
                    if (id_materia, expr) not in pre_existentes:
                        get_or_create_pre_requisito(id_materia, expr, id_pre)
                        pre_existentes.add((id_materia, expr))
            co = mat_det.get('co_requisitos', None)
            if co and co != '-' and co is not None:
                expr = (co or '').strip()
                codigos_co = _codigos_na_expressao(expr)
                id_co = _id_materia_requisito_unico(expr)
                if id_co is not None or len(codigos_co) != 1:
                    if (id_materia, expr) not in co_existentes:
                        get_or_create_co_requisito(id_materia, expr, id_co)
                        co_existentes.add((id_materia, expr))
            eq = mat_det.get('equivalencias', None)
            if eq and eq != '-' and eq is not None:
                expr_eq = (eq or '').strip()
                chave_equiv = (id_materia, expr_eq, None, None)
                if chave_equiv not in equiv_existentes:
                    executar_operacao(supabase.table('equivalencias').insert({
                        'id_materia': id_materia,
                        'id_curso': None,
                        'expressao_original': expr_eq,
                        'expressao_logica': build_expressao_logica(expr_eq),
                        'curriculo': None,
                        'data_vigencia': None
                    }).execute)
                    equiv_existentes.add(chave_equiv)
            equiv_esp = mat_det.get('equivalencias_especificas', None)
            if equiv_esp and isinstance(equiv_esp, list):
                for eqesp in equiv_esp:
                    nome_curso_esp = remover_acentos(eqesp.get('matriz_curricular', '').strip().split(' - ')[0].upper())
                    curriculo_raw = eqesp.get('curriculo', '').strip()
                    match = re.search(r'(\d{4}\.\d)', curriculo_raw)
                    periodo_letivo_esp = match.group(1) if match else ''
                    id_curso_esp = None
                    codigo_base_esp = extrair_codigo_base(curriculo_raw)
                    if codigo_base_esp:
                        id_c = to_int(codigo_base_esp)
                        if id_c is not None and any(c.get('id_curso') == id_c for c in cache_cursos_lista):
                            id_curso_esp = id_c
                    if id_curso_esp is None and nome_curso_esp:
                        for curso in cache_cursos_lista:
                            nome_curso_banco = remover_acentos((curso.get('nome_curso') or '').strip().upper())
                            if nome_curso_banco == nome_curso_esp:
                                id_curso_esp = curso['id_curso']
                                break
                    data_vigencia_raw = eqesp.get('data_vigencia', '').strip()
                    fim_vigencia_raw = eqesp.get('fim_vigencia', '').strip()
                    data_vigencia_eq = periodo_letivo_to_date(data_vigencia_raw)
                    fim_vigencia_eq = periodo_letivo_to_date(fim_vigencia_raw) if fim_vigencia_raw else None
                    expr_esp = eqesp.get('expressao', '').strip()
                    if id_curso_esp and curriculo_raw and data_vigencia_eq and expr_esp:
                        chave_esp = (id_materia, expr_esp, id_curso_esp, curriculo_raw)
                        if chave_esp not in equiv_existentes:
                            executar_operacao(
                                supabase.table('equivalencias').insert({
                                    'id_materia': id_materia,
                                    'id_curso': id_curso_esp,
                                    'expressao_original': expr_esp,
                                    'expressao_logica': build_expressao_logica(expr_esp),
                                    'curriculo': curriculo_raw,
                                    'data_vigencia': data_vigencia_eq,
                                    'fim_vigencia': fim_vigencia_eq
                                }).execute
                            )
                            equiv_existentes.add(chave_esp)

    print(f"  Curso: {nome_curso} | Matriz: {dados_mat['curriculo_completo']} | id_matriz={id_matriz} | {len(linhas_matriz)} matérias.")
    return id_matriz


if __name__ == "__main__":
    processar_matrizes()
    processar_materias()
    print("Processamento concluído!")   
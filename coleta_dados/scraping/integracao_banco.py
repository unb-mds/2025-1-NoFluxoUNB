import os
import json
from supabase import create_client, Client
import time
from tenacity import retry, stop_after_attempt, wait_exponential
import re
from datetime import datetime
import unicodedata

print("Iniciando script...")

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
    Parse do campo curriculo no formato "6360/1 - 2017.1" ou "60810/2".
    Retorna: dict com codigo_curso_base, matriz_versao, matriz_ano (ou None se não houver).
    """
    if not curriculo_str or not isinstance(curriculo_str, str):
        return {'codigo_curso_base': None, 'matriz_versao': None, 'matriz_ano': None}
    s = curriculo_str.strip()
    # Formato "6360/1 - 2017.1"
    m = re.match(r'^(\d+)/(\d+)\s*-\s*(\d{4}\.[12])$', s)
    if m:
        return {
            'codigo_curso_base': m.group(1),
            'matriz_versao': m.group(2),
            'matriz_ano': m.group(3)
        }
    # Formato "60810/2" (sem ano)
    m = re.match(r'^(\d+)/(\d+)$', s)
    if m:
        return {
            'codigo_curso_base': m.group(1),
            'matriz_versao': m.group(2),
            'matriz_ano': None
        }
    return {'codigo_curso_base': None, 'matriz_versao': None, 'matriz_ano': None}


def build_dados_matriz(curriculo_str, periodo_letivo_vigor):
    """
    Monta curriculo_completo, versao e ano_vigor para a tabela matrizes.
    curriculo_completo = "8150/-2 - 2017.2"; versao = parte após /; ano_vigor = periodo_letivo_vigor.
    """
    curriculo_str = (curriculo_str or '').strip()
    periodo_letivo_vigor = (periodo_letivo_vigor or '').strip()
    curriculo_completo = f"{curriculo_str} - {periodo_letivo_vigor}".strip(' - ') if curriculo_str or periodo_letivo_vigor else ''
    versao = None
    if curriculo_str and '/' in curriculo_str:
        versao = curriculo_str.split('/', 1)[1].strip()
    ano_vigor = periodo_letivo_vigor if periodo_letivo_vigor else None
    return {'curriculo_completo': curriculo_completo, 'versao': versao, 'ano_vigor': ano_vigor}


def get_or_create_curso(nome_curso, tipo_curso):
    """Insere ou busca em public.cursos (apenas nome_curso e tipo_curso). Retorna id_curso."""
    insert_data = {
        'nome_curso': nome_curso,
        'tipo_curso': tipo_curso
    }
    try:
        res = executar_operacao(supabase.table('cursos').insert(insert_data).execute)
        return res.data[0]['id_curso']
    except Exception:
        result = executar_operacao(supabase.table('cursos').select('id_curso', 'tipo_curso').eq('nome_curso', nome_curso).execute)
        if not result.data:
            raise
        id_curso = result.data[0]['id_curso']
        tipo_atual = result.data[0].get('tipo_curso')
        if tipo_curso and tipo_atual is None:
            executar_operacao(supabase.table('cursos').update({'tipo_curso': tipo_curso}).eq('id_curso', id_curso).execute)
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
    Retorna id_matriz.
    """
    # Schema: matrizes (curriculo_completo, versao NOT NULL; ch_obrigatoria_exigida, ch_optativa_exigida, ch_complementar_exigida, ch_total_exigida)
    ch = prazos_cargas_to_ints(prazos_cargas or {})
    insert_data = {
        'id_curso': id_curso,
        'curriculo_completo': curriculo_completo or '',
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
        result = executar_operacao(supabase.table('matrizes').select('id_matriz').eq('id_curso', id_curso).eq('curriculo_completo', curriculo_completo or '').execute)
        if not result.data:
            result = executar_operacao(supabase.table('matrizes').select('id_matriz').eq('id_curso', id_curso).eq('ano_vigor', ano_vigor).execute)
        if not result.data:
            raise
        return result.data[0]['id_matriz']

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

print(f"[DEBUG] Total de códigos de matérias com departamento encontrados: {len(DEPARTAMENTOS_MATERIAS)}")
for cod, depto in list(DEPARTAMENTOS_MATERIAS.items())[:10]:
    print(f"[DEBUG] Exemplo: {cod} => {depto}")

# Atualizar get_or_create_materia para preencher departamento

def get_or_create_materia(materia):
    codigo = materia['codigo']
    departamento = DEPARTAMENTOS_MATERIAS.get(codigo, '')
    print(f"[DEBUG] Matéria {codigo} - departamento encontrado: '{departamento}'")
    # Sempre verifica no banco antes de tentar inserir
    result = executar_operacao(supabase.table('materias').select('id_materia', 'ementa', 'departamento').eq('codigo_materia', codigo).execute)
    if result.data:
        id_materia = result.data[0]['id_materia']
        ementa_atual = result.data[0].get('ementa', '')
        departamento_atual = result.data[0].get('departamento', '')
        # Atualiza ementa se diferente
        if materia.get('ementa', '') and materia.get('ementa', '') != ementa_atual:
            executar_operacao(supabase.table('materias').update({'ementa': materia.get('ementa', '')}).eq('id_materia', id_materia).execute)
        # Atualiza departamento se diferente
        if departamento and (not departamento_atual or departamento != departamento_atual):
            executar_operacao(supabase.table('materias').update({'departamento': departamento}).eq('id_materia', id_materia).execute)
            print(f"[DEBUG] Atualizado departamento da matéria {codigo}: {departamento}")
        return id_materia
    insert_data = {
        'nome_materia': materia['nome'],
        'codigo_materia': codigo,
        'carga_horaria': ch_to_int(materia.get('carga_horaria')),
        'ementa': materia.get('ementa', ''),
        'departamento': departamento
    }
    res = executar_operacao(supabase.table('materias').insert(insert_data).execute)
    return res.data[0]['id_materia']

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
    """
    Vincula matéria à matriz (grade). nivel: inteiro (0 = optativas, 1+ = nível).
    Tabela public.materias_por_curso: id_materia (FK), id_matriz (FK), nivel (integer).
    """
    nivel_int = int(nivel) if isinstance(nivel, int) else nivel_to_int(nivel)
    insert_data = {
        'id_materia': id_materia,
        'id_matriz': id_matriz,
        'nivel': nivel_int
    }
    try:
        res = executar_operacao(supabase.table('materias_por_curso').insert(insert_data).execute)
        return res.data[0].get('id_materia_curso') or res.data[0].get('id') if res.data else None
    except Exception:
        result = executar_operacao(supabase.table('materias_por_curso').select('id_materia_curso').eq('id_materia', id_materia).eq('id_matriz', id_matriz).eq('nivel', nivel_int).execute)
        if result.data:
            return result.data[0].get('id_materia_curso') or result.data[0].get('id')
        return None

def _eh_requisito_unico(expr):
    """Retorna True se a expressão for uma única disciplina (sem operadores E, OU ou parênteses)."""
    if not expr or not isinstance(expr, str):
        return False
    e = expr.strip().upper()
    if ' E ' in e or ' OU ' in e or '(' in e or ')' in e:
        return False
    return True


def _codigos_na_expressao(expr):
    """Extrai códigos de disciplinas da expressão (ex: ADM001, MAT0025). Padrão: letras + números."""
    if not expr or not isinstance(expr, str):
        return []
    return re.findall(r'[A-Z]{2,}\d{2,}[A-Z0-9]*', expr.upper()) or re.findall(r'[A-Z]+\d+', expr.upper())


def get_or_create_pre_requisito(id_materia, expressao_original, id_materia_requisito=None):
    """Salva expressao_original; id_materia_requisito só se for matéria única (senão None)."""
    payload = {'id_materia': id_materia, 'expressao_original': expressao_original}
    if id_materia_requisito is not None:
        payload['id_materia_requisito'] = id_materia_requisito
    try:
        res = executar_operacao(supabase.table('pre_requisitos').insert(payload).execute)
        return res.data[0]['id_pre_requisito']
    except Exception:
        result = executar_operacao(supabase.table('pre_requisitos').select('id_pre_requisito').eq('id_materia', id_materia).eq('expressao_original', expressao_original).execute)
        return result.data[0]['id_pre_requisito'] if result.data else None


def get_or_create_co_requisito(id_materia, expressao_original, id_materia_corequisito=None):
    """Salva expressao_original; id_materia_corequisito só se for matéria única (senão None)."""
    payload = {'id_materia': id_materia, 'expressao_original': expressao_original}
    if id_materia_corequisito is not None:
        payload['id_materia_corequisito'] = id_materia_corequisito
    try:
        res = executar_operacao(supabase.table('co_requisitos').insert(payload).execute)
        return res.data[0]['id_co_requisito']
    except Exception:
        result = executar_operacao(supabase.table('co_requisitos').select('id_co_requisito').eq('id_materia', id_materia).eq('expressao_original', expressao_original).execute)
        return result.data[0]['id_co_requisito'] if result.data else None

def get_or_create_equivalencia(id_materia, id_curso, expressao_original, curriculo=None, data_vigencia=None):
    """Schema equivalencias: id_materia, id_curso, curriculo, data_vigencia, fim_vigencia, expressao_original, id_matriz (sem coluna expressao)."""
    payload = {
        'id_materia': id_materia,
        'id_curso': id_curso,
        'expressao_original': expressao_original,
        'curriculo': curriculo,
        'data_vigencia': data_vigencia
    }
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

# Cache de cursos existentes (por nome_curso)
cursos_existentes = set()
try:
    res = executar_operacao(supabase.table('cursos').select('nome_curso').execute)
    for c in (res.data or []):
        cursos_existentes.add(c['nome_curso'])
except Exception:
    pass

materias_existentes = set()
res = executar_operacao(supabase.table('materias').select('codigo_materia').execute)
for m in res.data:
    materias_existentes.add(m['codigo_materia'])

def processar_matrizes():
    print("Processando matrizes curriculares...")
    for i, arquivo in enumerate(os.listdir(PASTA_MATRIZES), 1):
        print(f"\n[{i}/{len(os.listdir(PASTA_MATRIZES))}] Processando: {arquivo}")
        if not arquivo.endswith('.json'):
            continue
        with open(os.path.join(PASTA_MATRIZES, arquivo), 'r', encoding='utf-8') as f:
            matriz = json.load(f)
            nome_curso = remover_acentos(matriz['curso']).replace('Ç', 'C').upper().strip()
            tipo_curso = matriz.get('tipo_curso')
            periodo_letivo = matriz.get('periodo_letivo_vigor')
            curriculo_str = matriz.get('curriculo') or ''
            id_curso = get_or_create_curso(nome_curso, tipo_curso)
            cursos_existentes.add(nome_curso)
            dados_mat = build_dados_matriz(curriculo_str, periodo_letivo)
            prazos_cargas = matriz.get('prazos_cargas') or {}
            id_matriz = get_or_create_matriz(
                id_curso,
                dados_mat['curriculo_completo'],
                dados_mat['versao'],
                dados_mat['ano_vigor'],
                prazos_cargas
            )
            print(f"Curso: {nome_curso} (id: {id_curso}) | Matriz: {dados_mat['curriculo_completo']} (id: {id_matriz})")
            relacoes_curso = 0
            relacoes_criadas_curso = 0
            encontrou_materias = False
            for nivel in matriz['niveis']:
                nivel_nome = nivel.get('nivel', '')
                nivel_int = nivel_to_int(nivel_nome)
                for materia in nivel['materias']:
                    encontrou_materias = True
                    codigo = materia['codigo']
                    mat_det = materias_detalhadas.get(codigo, {})
                    ch_val = mat_det.get('carga_horaria', materia.get('carga_horaria', materia.get('ch', 0)))
                    dados_materia = {
                        'nome': mat_det.get('nome', materia['nome']),
                        'codigo': codigo,
                        'carga_horaria': ch_to_int(ch_val),
                        'ementa': mat_det.get('ementa', materia.get('ementa', ''))
                    }
                    id_materia = get_or_create_materia(dados_materia)
                    get_or_create_materia_por_curso(id_materia, id_matriz, nivel_int)
                    # Pré-requisitos: expressao_original sempre; id_materia_requisito só se for matéria única
                    pre = mat_det.get('pre_requisitos', None)
                    if pre and pre != '-' and pre is not None:
                        expr = (pre or '').strip()
                        id_pre = None
                        if _eh_requisito_unico(expr):
                            codigos_pre = _codigos_na_expressao(expr)
                            if codigos_pre:
                                res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', codigos_pre[0]).execute)
                                if res.data:
                                    id_pre = res.data[0]['id_materia']
                        result = executar_operacao(supabase.table('pre_requisitos').select('id_pre_requisito').eq('id_materia', id_materia).eq('expressao_original', expr).execute)
                        if not result.data:
                            get_or_create_pre_requisito(id_materia, expr, id_pre)
                    # Co-requisitos: expressao_original sempre; id_materia_corequisito só se matéria única
                    co = mat_det.get('co_requisitos', None)
                    if co and co != '-' and co is not None:
                        expr = (co or '').strip()
                        id_co = None
                        if _eh_requisito_unico(expr):
                            codigos_co = _codigos_na_expressao(expr)
                            if codigos_co:
                                res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', codigos_co[0]).execute)
                                if res.data:
                                    id_co = res.data[0]['id_materia']
                        result = executar_operacao(supabase.table('co_requisitos').select('id_co_requisito').eq('id_materia', id_materia).eq('expressao_original', expr).execute)
                        if not result.data:
                            get_or_create_co_requisito(id_materia, expr, id_co)
                    # Equivalências: expressao + expressao_original
                    eq = mat_det.get('equivalencias', None)
                    if eq and eq != '-' and eq is not None:
                        expr_eq = (eq or '').strip()
                        codigos_eq = _codigos_na_expressao(expr_eq)
                        for cod in codigos_eq:
                            res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                            if res.data:
                                result = executar_operacao(supabase.table('equivalencias').select('id_equivalencia').eq('id_materia', id_materia).eq('expressao_original', expr_eq).is_('id_curso', None).execute)
                                if not result.data:
                                    executar_operacao(supabase.table('equivalencias').insert({
                                        'id_materia': id_materia,
                                        'id_curso': None,
                                        'expressao_original': expr_eq,
                                        'curriculo': None,
                                        'data_vigencia': None
                                    }).execute)
                    # Equivalências específicas (com expressao_original)
                    equiv_esp = mat_det.get('equivalencias_especificas', None)
                    if equiv_esp and isinstance(equiv_esp, list):
                        for eqesp in equiv_esp:
                            nome_curso_esp = remover_acentos(eqesp.get('matriz_curricular', '').strip().split(' - ')[0].upper())
                            curriculo_raw = eqesp.get('curriculo', '').strip()
                            match = re.search(r'(\d{4}\.\d)', curriculo_raw)
                            periodo_letivo_esp = match.group(1) if match else ''
                            id_curso_esp = None
                            if nome_curso_esp:
                                res_cursos = executar_operacao(supabase.table('cursos').select('id_curso', 'nome_curso').execute)
                                for curso in (res_cursos.data or []):
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
                                            'curriculo': curriculo_raw,
                                            'data_vigencia': data_vigencia_eq,
                                            'fim_vigencia': fim_vigencia_eq
                                        }).execute
                                    )
                    relacoes_curso += 1
    print("Matrizes curriculares processadas!")

def processar_materias():
    print("Processando matérias...")
    # Carregar todos os códigos de matérias já existentes no banco
    materias_existentes = set()
    res = executar_operacao(supabase.table('materias').select('codigo_materia').execute)
    for m in res.data:
        materias_existentes.add(m['codigo_materia'])
    for arquivo in sorted(os.listdir(PASTA_MATERIAS)):
        if not arquivo.endswith('.json'):
            continue
        print(f"Processando arquivo: {arquivo}")
        with open(os.path.join(PASTA_MATERIAS, arquivo), 'r', encoding='utf-8') as f:
            materias = json.load(f)
            for materia in materias:
                codigo = materia['codigo']
                if codigo in materias_existentes:
                    print(f"[DEBUG] Matéria já existe no banco: {codigo}")
                    # Buscar id_materia do banco
                    res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', codigo).execute)
                    if res.data:
                        id_materia = res.data[0]['id_materia']
                    else:
                        continue
                else:
                    print(f"[DEBUG MAT] Processando matéria: {codigo} - {materia.get('nome')}")
                    id_materia = get_or_create_materia({
                        'nome': materia['nome'],
                        'codigo': codigo,
                        'carga_horaria': ch_to_int(materia.get('carga_horaria', materia.get('ch', 0))),
                        'ementa': materia.get('ementa', '')
                    })
                    materias_existentes.add(codigo)
                # Pré-requisitos: expressao_original sempre; id_materia_requisito só se matéria única
                pre = materia.get('pre_requisitos', '')
                if pre and pre != '-':
                    expr = (pre or '').strip()
                    id_pre = None
                    if _eh_requisito_unico(expr):
                        codigos_pre = _codigos_na_expressao(expr)
                        if codigos_pre:
                            res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', codigos_pre[0]).execute)
                            if res.data:
                                id_pre = res.data[0]['id_materia']
                    result = executar_operacao(supabase.table('pre_requisitos').select('id_pre_requisito').eq('id_materia', id_materia).eq('expressao_original', expr).execute)
                    if not result.data:
                        get_or_create_pre_requisito(id_materia, expr, id_pre)
                # Co-requisitos: expressao_original sempre; id_materia_corequisito só se matéria única
                co = materia.get('co_requisitos', '')
                if co and co != '-':
                    expr = (co or '').strip()
                    id_co = None
                    if _eh_requisito_unico(expr):
                        codigos_co = _codigos_na_expressao(expr)
                        if codigos_co:
                            res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', codigos_co[0]).execute)
                            if res.data:
                                id_co = res.data[0]['id_materia']
                    result = executar_operacao(supabase.table('co_requisitos').select('id_co_requisito').eq('id_materia', id_materia).eq('expressao_original', expr).execute)
                    if not result.data:
                        get_or_create_co_requisito(id_materia, expr, id_co)
                # Equivalências: expressao + expressao_original
                eq = materia.get('equivalencias', '')
                if eq and eq != '-':
                    expr_eq = (eq or '').strip()
                    codigos = _codigos_na_expressao(expr_eq)
                    for cod in codigos:
                        res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                        if res.data:
                            result = executar_operacao(supabase.table('equivalencias').select('id_equivalencia').eq('id_materia', id_materia).eq('expressao_original', expr_eq).is_('id_curso', None).execute)
                            if not result.data:
                                executar_operacao(supabase.table('equivalencias').insert({
                                    'id_materia': id_materia,
                                    'id_curso': None,
                                    'expressao_original': expr_eq,
                                    'curriculo': None,
                                    'data_vigencia': None
                                }).execute)
                # Equivalências específicas (expressao_original)
                equiv_esp = materia.get('equivalencias_especificas', None)
                if equiv_esp and isinstance(equiv_esp, list):
                    for eqesp in equiv_esp:
                        nome_curso_esp = remover_acentos(eqesp.get('matriz_curricular', '').strip().split(' - ')[0].upper())
                        curriculo_raw = eqesp.get('curriculo', '').strip()
                        match = re.search(r'(\d{4}\.\d)', curriculo_raw)
                        periodo_letivo_esp = match.group(1) if match else ''
                        id_curso_esp = None
                        res_cursos = executar_operacao(supabase.table('cursos').select('id_curso', 'nome_curso').execute)
                        for curso in (res_cursos.data or []):
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
                                        'curriculo': curriculo_raw,
                                        'data_vigencia': data_vigencia_eq,
                                        'fim_vigencia': fim_vigencia_eq
                                    }).execute
                                )
    print("Matérias processadas!")

def periodo_letivo_to_date(periodo):
    if not periodo or not re.match(r'\d{4}\.\d', periodo):
        return None
    ano, semestre = periodo.split('.')
    mes = '01' if semestre == '1' else '07'
    return f"{ano}-{mes}-01"

if __name__ == "__main__":
    processar_matrizes()
    processar_materias()
    print("Processamento concluído!")   
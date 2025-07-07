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
    if not periodo or not re.match(r'\d{4}\.[12]', periodo):
        return None
    ano, semestre = periodo.split('.')
    mes = '01' if semestre == '1' else '07'
    return f"{ano}-{mes}-01"

def get_or_create_curso(nome_curso, matriz_json, periodo_letivo):
    data_inicio = periodo_to_date(periodo_letivo)
    insert_data = {
        'nome_curso': nome_curso,
        'matriz_curricular': periodo_letivo,
        'data_inicio_matriz': data_inicio
    }
    try:
        res = executar_operacao(supabase.table('cursos').insert(insert_data).execute)
        return res.data[0]['id_curso']
    except Exception as e:
        # Se duplicado, pega o id existente
        result = executar_operacao(supabase.table('cursos').select('id_curso').eq('nome_curso', nome_curso).eq('data_inicio_matriz', data_inicio).execute)
        return result.data[0]['id_curso']

def get_or_create_materia(materia):
    codigo = materia['codigo']
    # Verifica se já existe matéria com esse código
    result = executar_operacao(supabase.table('materias').select('id_materia', 'ementa').eq('codigo_materia', codigo).execute)
    if result.data:
        id_materia = result.data[0]['id_materia']
        ementa_atual = result.data[0].get('ementa', '')
        # Atualiza ementa se diferente
        if materia.get('ementa', '') and materia.get('ementa', '') != ementa_atual:
            executar_operacao(supabase.table('materias').update({'ementa': materia.get('ementa', '')}).eq('id_materia', id_materia).execute)
        return id_materia
    insert_data = {
        'nome_materia': materia['nome'],
        'codigo_materia': codigo,
        'carga_horaria': materia.get('carga_horaria', ''),
        'ementa': materia.get('ementa', '')
    }
    res = executar_operacao(supabase.table('materias').insert(insert_data).execute)
    return res.data[0]['id_materia']

def get_or_create_materia_por_curso(id_materia, id_curso, nivel):
    insert_data = {
        'id_materia': id_materia,
        'id_curso': id_curso,
        'nivel': nivel
    }
    try:
        res = executar_operacao(supabase.table('materias_por_curso').insert(insert_data).execute)
        return res.data[0]['id_materia_curso']
    except Exception as e:
        result = executar_operacao(supabase.table('materias_por_curso').select('id_materia_curso').eq('id_materia', id_materia).eq('id_curso', id_curso).eq('nivel', nivel).execute)
        return result.data[0]['id_materia_curso']

def get_or_create_pre_requisito(id_materia, id_pre):
    try:
        res = executar_operacao(supabase.table('pre_requisitos').insert({'id_materia': id_materia, 'id_materia_requisito': id_pre}).execute)
        return res.data[0]['id_pre_requisito']
    except Exception as e:
        result = executar_operacao(supabase.table('pre_requisitos').select('id_pre_requisito').eq('id_materia', id_materia).eq('id_materia_requisito', id_pre).execute)
        return result.data[0]['id_pre_requisito']

def get_or_create_co_requisito(id_materia, id_co):
    try:
        res = executar_operacao(supabase.table('co_requisitos').insert({'id_materia': id_materia, 'id_materia_corequisito': id_co}).execute)
        return res.data[0]['id_co_requisito']
    except Exception as e:
        result = executar_operacao(supabase.table('co_requisitos').select('id_co_requisito').eq('id_materia', id_materia).eq('id_materia_corequisito', id_co).execute)
        return result.data[0]['id_co_requisito']

def get_or_create_equivalencia(id_materia, id_eq, id_curso, matriz_curricular, expressao):
    try:
        res = executar_operacao(supabase.table('equivalencias').insert({
            'id_materia': id_materia,
            'id_curso': id_curso,
            'expressao': expressao,
            'matriz_curricular': matriz_curricular,
            'curriculo': matriz_curricular,
            'data_vigencia': None
        }).execute)
        return res.data[0]['id_equivalencia']
    except Exception as e:
        result = executar_operacao(supabase.table('equivalencias').select('id_equivalencia').eq('id_materia', id_materia).eq('id_curso', id_curso).eq('matriz_curricular', matriz_curricular).eq('curriculo', matriz_curricular).eq('expressao', expressao).execute)
        return result.data[0]['id_equivalencia']

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

# Carregar cache de cursos e matérias existentes
cursos_existentes = set()
res = executar_operacao(supabase.table('cursos').select('nome_curso', 'matriz_curricular').execute)
for c in res.data:
    cursos_existentes.add((c['nome_curso'], c['matriz_curricular']))

materias_existentes = set()
res = executar_operacao(supabase.table('materias').select('codigo_materia').execute)
for m in res.data:
    materias_existentes.add(m['codigo_materia'])

def processar_matrizes():
    print("Processando matrizes curriculares...")
    for arquivo in os.listdir(PASTA_MATRIZES):
        if not arquivo.endswith('.json'):
            continue
        with open(os.path.join(PASTA_MATRIZES, arquivo), 'r', encoding='utf-8') as f:
            matriz = json.load(f)
            nome_curso = remover_acentos(matriz['curso']).replace('Ç', 'C').upper().strip()
            periodo_letivo = matriz.get('periodo_letivo_vigor', None)
            if (nome_curso, periodo_letivo) in cursos_existentes:
                print(f"[PULAR] Curso já existe: {nome_curso} - {periodo_letivo}")
                continue
            id_curso = get_or_create_curso(nome_curso, matriz, periodo_letivo)
            print(f"Curso inserido/atualizado: {nome_curso} - {periodo_letivo} (id: {id_curso})")
            matriz_curricular = periodo_letivo
            for nivel in matriz['niveis']:
                nivel_nome = nivel.get('nivel', '')
                nivel_num = 0
                match = re.match(r'(\d+)', nivel_nome)
                if match:
                    nivel_num = int(match.group(1))
                for materia in nivel['materias']:
                    codigo = materia['codigo']
                    if codigo in materias_existentes:
                        # Pular matéria já existente
                        continue
                    # Buscar dados detalhados
                    mat_det = materias_detalhadas.get(codigo, {})
                    dados_materia = {
                        'nome': mat_det.get('nome', materia['nome']),
                        'codigo': codigo,
                        'carga_horaria': mat_det.get('carga_horaria', materia.get('carga_horaria', '')),
                        'ementa': mat_det.get('ementa', materia.get('ementa', ''))
                    }
                    id_materia = get_or_create_materia(dados_materia)
                    get_or_create_materia_por_curso(id_materia, id_curso, nivel_num)
                    # Pré-requisitos
                    pre = mat_det.get('pre_requisitos', None)
                    if pre and pre != '-' and pre is not None:
                        codigos = re.findall(r'[A-Z]{3,}[0-9]{3,}', pre)
                        for cod in codigos:
                            res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                            if res.data:
                                id_pre = res.data[0]['id_materia']
                                result = executar_operacao(supabase.table('pre_requisitos').select('id_pre_requisito').eq('id_materia', id_materia).eq('id_materia_requisito', id_pre).execute)
                                if not result.data:
                                    get_or_create_pre_requisito(id_materia, id_pre)
                    # Co-requisitos
                    co = mat_det.get('co_requisitos', None)
                    if co and co != '-' and co is not None:
                        codigos = re.findall(r'[A-Z]{3,}[0-9]{3,}', co)
                        for cod in codigos:
                            res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                            if res.data:
                                id_co = res.data[0]['id_materia']
                                result = executar_operacao(supabase.table('co_requisitos').select('id_co_requisito').eq('id_materia', id_materia).eq('id_materia_corequisito', id_co).execute)
                                if not result.data:
                                    get_or_create_co_requisito(id_materia, id_co)
                    # Equivalências
                    eq = mat_det.get('equivalencias', None)
                    if eq and eq != '-' and eq is not None:
                        codigos = re.findall(r'[A-Z]{3,}[0-9]{3,}', eq)
                        for cod in codigos:
                            res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                            if res.data:
                                id_eq = res.data[0]['id_materia']
                                result = executar_operacao(supabase.table('equivalencias').select('id_equivalencia').eq('id_materia', id_materia).eq('expressao', cod).eq('id_curso', id_curso).eq('matriz_curricular', matriz_curricular).eq('curriculo', matriz_curricular).execute)
                                if not result.data:
                                    get_or_create_equivalencia(id_materia, id_eq, id_curso, matriz_curricular, cod)
                    # Equivalências específicas
                    equiv_esp = mat_det.get('equivalencias_especificas', None)
                    if equiv_esp and isinstance(equiv_esp, list):
                        for eqesp in equiv_esp:
                            nome_curso_esp = remover_acentos(eqesp.get('matriz_curricular', '').strip().split(' - ')[0].upper())
                            curriculo_raw = eqesp.get('curriculo', '').strip()
                            # Extrai o período letivo do curriculo (ex: "8150/-3 - 2015.1" -> "2015.1")
                            match = re.search(r'(\d{4}\.\d)', curriculo_raw)
                            periodo_letivo_esp = match.group(1) if match else ''
                            print(f"[DEBUG EQ ESP] Matéria: {materia['codigo']} | Nome curso: '{nome_curso_esp}' | Curriculo raw: '{curriculo_raw}' | Período letivo extraído: '{periodo_letivo_esp}'")
                            # Busca o id_curso correspondente
                            id_curso_esp = None
                            if nome_curso_esp and periodo_letivo_esp:
                                res_cursos = executar_operacao(
                                    supabase.table('cursos')
                                    .select('id_curso', 'nome_curso', 'matriz_curricular')
                                    .eq('matriz_curricular', periodo_letivo_esp)
                                    .execute
                                )
                                print(f"[DEBUG EQ ESP] Cursos encontrados: {res_cursos.data}")
                                for curso in res_cursos.data:
                                    nome_curso_banco = remover_acentos(curso['nome_curso'].strip().upper())
                                    if nome_curso_banco == nome_curso_esp:
                                        id_curso_esp = curso['id_curso']
                                        break
                            data_vigencia_eq = eqesp.get('data_vigencia', '').strip()
                            fim_vigencia_eq = eqesp.get('fim_vigencia', None)
                            print(f"[DEBUG EQ ESP] id_curso_esp: {id_curso_esp} | data_vigencia: '{data_vigencia_eq}' | fim_vigencia: '{fim_vigencia_eq}' | expressao: '{eqesp.get('expressao', '')}'")
                            if id_curso_esp and nome_curso_esp and curriculo_raw and data_vigencia_eq:
                                # Verifica se já existe equivalência igual no banco
                                result = executar_operacao(
                                    supabase.table('equivalencias')
                                    .select('id_equivalencia')
                                    .eq('id_materia', id_materia)
                                    .eq('expressao', eqesp.get('expressao', ''))
                                    .eq('matriz_curricular', periodo_letivo_esp)
                                    .eq('curriculo', curriculo_raw)
                                    .eq('data_vigencia', data_vigencia_eq)
                                    .execute
                                )
                                print(f"[DEBUG EQ ESP] Já existe? {result.data}")
                                if not result.data:
                                    print(f"[DEBUG EQ ESP] Inserindo equivalência específica!")
                                    executar_operacao(
                                        supabase.table('equivalencias').insert({
                                            'id_materia': id_materia,
                                            'id_curso': id_curso_esp,
                                            'expressao': eqesp.get('expressao', ''),
                                            'matriz_curricular': periodo_letivo_esp,
                                            'curriculo': curriculo_raw,
                                            'data_vigencia': data_vigencia_eq,
                                            'fim_vigencia': fim_vigencia_eq if fim_vigencia_eq else None
                                        }).execute
                                    )
    print("Matrizes curriculares processadas!")

def processar_relacoes_materias_por_curso_individual():
    print("Processando relações matérias por curso (verificação individual)...")
    
    # Cache de matérias (padronizado)
    cache_materias = {}
    res_materias = executar_operacao(supabase.table('materias').select('id_materia,codigo_materia,nome_materia').execute)
    for mat in res_materias.data:
        codigo_pad = mat['codigo_materia'].strip().upper()
        cache_materias[codigo_pad] = {
            'id_materia': mat['id_materia'],
            'nome_materia': mat['nome_materia']
        }
    print(f"Cache de matérias carregado: {len(cache_materias)} matérias")
    
    # Cache de cursos - CORRIGIDO: usar matriz_curricular e padronizar nome
    cache_cursos = {}
    res_cursos = executar_operacao(supabase.table('cursos').select('id_curso,nome_curso,matriz_curricular').execute)
    for curso in res_cursos.data:
        nome_curso_pad = remover_acentos(curso['nome_curso']).replace('Ç', 'C').upper().strip()
        key = (nome_curso_pad, curso['matriz_curricular'])
        cache_cursos[key] = {
            'id_curso': curso['id_curso'],
            'nome_curso': curso['nome_curso']
        }
    print(f"Cache de cursos carregado: {len(cache_cursos)} cursos")
    
    # Cache de relações existentes
    cache_relacoes = set()
    res_relacoes = executar_operacao(supabase.table('materias_por_curso').select('id_materia,id_curso').execute)
    for rel in res_relacoes.data:
        cache_relacoes.add((rel['id_materia'], rel['id_curso']))
    print(f"Relações existentes: {len(cache_relacoes)}")
    
    # Processar cada arquivo de matriz
    total_relacoes_criadas = 0
    total_relacoes_existentes = 0
    materias_nao_encontradas = []
    cursos_nao_encontrados = []
    
    arquivos_matrizes = [f for f in os.listdir(PASTA_MATRIZES) if f.endswith('.json')]
    print(f"Processando {len(arquivos_matrizes)} arquivos de matrizes...")
    
    for i, arquivo in enumerate(arquivos_matrizes, 1):
        print(f"\n[{i}/{len(arquivos_matrizes)}] Processando: {arquivo}")
        
        with open(os.path.join(PASTA_MATRIZES, arquivo), 'r', encoding='utf-8') as f:
            matriz = json.load(f)
            nome_curso = remover_acentos(matriz['curso']).replace('Ç', 'C').upper().strip()
            periodo_letivo = matriz.get('periodo_letivo_vigor', None)
            
            # CORRIGIDO: usar matriz_curricular para fazer o match
            key_curso = (nome_curso, periodo_letivo)
            if key_curso not in cache_cursos:
                cursos_nao_encontrados.append(f"{nome_curso} - {periodo_letivo}")
                print(f"  ❌ Curso não encontrado: {nome_curso} - {periodo_letivo}")
                continue
            
            curso_info = cache_cursos[key_curso]
            print(f"  ✓ Curso: {curso_info['nome_curso']} (ID: {curso_info['id_curso']})")
            
            relacoes_curso = 0
            relacoes_criadas_curso = 0
            
            for nivel in matriz['niveis']:
                nivel_nome = nivel.get('nivel', '')
                nivel_num = 0
                
                # CORRIGIDO: Extração melhorada do nível
                if 'semestre' in nivel_nome.lower():
                    # Para semestres: "1º Semestre" -> 1
                    match = re.search(r'(\d+)', nivel_nome)
                    if match:
                        nivel_num = int(match.group(1))
                elif 'optativa' in nivel_nome.lower():
                    # Para optativas: usar nível 0
                    nivel_num = 0
                else:
                    # Para outros casos, tentar extrair número
                    match = re.search(r'(\d+)', nivel_nome)
                    if match:
                        nivel_num = int(match.group(1))
                
                for materia in nivel['materias']:
                    codigo = materia['codigo']
                    relacoes_curso += 1
                    
                    codigo_pad = codigo.strip().upper()
                    if codigo_pad not in cache_materias:
                        print(f"DEBUG: Código do JSON '{codigo}' (padronizado: '{codigo_pad}') não encontrado no banco.")
                        print(f"DEBUG: Exemplos de códigos do banco próximos:")
                        for k in cache_materias.keys():
                            if codigo_pad[:5] in k or k[:5] in codigo_pad:
                                print(f'  Banco: {k}')
                        continue
                    materia_info = cache_materias[codigo_pad]
                    key_relacao = (materia_info['id_materia'], curso_info['id_curso'])
                    
                    if key_relacao in cache_relacoes:
                        total_relacoes_existentes += 1
                        print(f"    ✓ Relação já existe: {codigo} - {materia_info['nome_materia']} (nível {nivel_num})")
                    else:
                        # Criar relação individual
                        try:
                            executar_operacao(supabase.table('materias_por_curso').insert({
                                'id_materia': materia_info['id_materia'],
                                'id_curso': curso_info['id_curso'],
                                'nivel': nivel_num
                            }).execute)
                            
                            # Adicionar ao cache para não duplicar
                            cache_relacoes.add(key_relacao)
                            total_relacoes_criadas += 1
                            relacoes_criadas_curso += 1
                            print(f"    ➕ Relação criada: {codigo} - {materia_info['nome_materia']} (nível {nivel_num})")
                            
                        except Exception as e:
                            print(f"    ❌ Erro ao criar relação {codigo}: {str(e)}")
            
            print(f"  📊 Curso: {relacoes_criadas_curso} relações criadas, {relacoes_curso - relacoes_criadas_curso} já existiam")
    
    print(f"\n=== RESUMO FINAL ===")
    print(f"Total de relações criadas: {total_relacoes_criadas}")
    print(f"Total de relações já existentes: {total_relacoes_existentes}")
    print(f"Matérias não encontradas: {len(materias_nao_encontradas)}")
    print(f"Cursos não encontrados: {len(cursos_nao_encontrados)}")
    
    if materias_nao_encontradas:
        print(f"Primeiras 10 matérias não encontradas: {materias_nao_encontradas[:10]}")
    
    if cursos_nao_encontrados:
        print(f"Primeiros 5 cursos não encontrados: {cursos_nao_encontrados[:5]}")
    
    print(f"✓ Processamento concluído!")

if __name__ == "__main__":
    print("=== APENAS RELAÇÕES MATÉRIAS POR CURSO ===")
    print("Criando relações entre matérias e cursos...")
    processar_relacoes_materias_por_curso_individual()
    print("\n=== CONCLUÍDO ===")
import os
import json
from supabase import create_client, Client
import time
from tenacity import retry, stop_after_attempt, wait_exponential
import re
from datetime import datetime

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
    result = executar_operacao(supabase.table('cursos').select('id_curso').eq('nome_curso', nome_curso).eq('data_inicio_matriz', data_inicio).execute)
    if result.data:
        return result.data[0]['id_curso']
    insert_data = {
        'nome_curso': nome_curso,
        'matriz_curricular': periodo_letivo,
        'data_inicio_matriz': data_inicio
    }
    res = executar_operacao(supabase.table('cursos').insert(insert_data).execute)
    return res.data[0]['id_curso']

def get_or_create_materia(materia):
    codigo = materia['codigo']
    result = executar_operacao(supabase.table('materias').select('id_materia', 'ementa').eq('codigo_materia', codigo).execute)
    if result.data:
        # Atualiza ementa se estiver diferente
        id_materia = result.data[0]['id_materia']
        ementa_atual = result.data[0].get('ementa', '')
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
    result = executar_operacao(supabase.table('materias_por_curso').select('id_materia_curso').eq('id_materia', id_materia).eq('id_curso', id_curso).eq('nivel', nivel).execute)
    if result.data:
        return result.data[0]['id_materia_curso']
    insert_data = {
        'id_materia': id_materia,
        'id_curso': id_curso,
        'nivel': nivel
    }
    res = executar_operacao(supabase.table('materias_por_curso').insert(insert_data).execute)
    return res.data[0]['id_materia_curso']

def get_or_create_pre_requisito(id_materia, id_pre):
    result = executar_operacao(supabase.table('pre_requisitos').select('id_pre_requisito').eq('id_materia', id_materia).eq('id_materia_requisito', id_pre).execute)
    if result.data:
        return result.data[0]['id_pre_requisito']
    res = executar_operacao(supabase.table('pre_requisitos').insert({'id_materia': id_materia, 'id_materia_requisito': id_pre}).execute)
    return res.data[0]['id_pre_requisito']

def get_or_create_co_requisito(id_materia, id_co):
    result = executar_operacao(supabase.table('co_requisitos').select('id_co_requisito').eq('id_materia', id_materia).eq('id_materia_corequisito', id_co).execute)
    if result.data:
        return result.data[0]['id_co_requisito']
    res = executar_operacao(supabase.table('co_requisitos').insert({'id_materia': id_materia, 'id_materia_corequisito': id_co}).execute)
    return res.data[0]['id_co_requisito']

def get_or_create_equivalencia(id_materia, id_eq, id_curso, matriz_curricular):
    result = executar_operacao(supabase.table('equivalencias').select('id_equivalencia').eq('id_materia', id_materia).eq('id_curso', id_curso).eq('matriz_curricular', matriz_curricular).eq('curriculo', matriz_curricular).execute)
    if result.data:
        return result.data[0]['id_equivalencia']
    res = executar_operacao(supabase.table('equivalencias').insert({
        'id_materia': id_materia,
        'id_curso': id_curso,
        'expressao': '',
        'matriz_curricular': matriz_curricular,
        'curriculo': matriz_curricular,
        'data_vigencia': None
    }).execute)
    return res.data[0]['id_equivalencia']

def processar_matrizes():
    print("Processando matrizes curriculares...")
    # 1. Carregar dados existentes em cache
    print('Carregando dados existentes do banco...')
    cursos_existentes = {}
    res = executar_operacao(supabase.table('cursos').select('id_curso', 'nome_curso', 'matriz_curricular').execute)
    for c in res.data:
        key = (c['nome_curso'], c['matriz_curricular'])
        cursos_existentes[key] = c['id_curso']

    materias_existentes = {}
    res = executar_operacao(supabase.table('materias').select('id_materia', 'codigo_materia', 'ementa').execute)
    for m in res.data:
        materias_existentes[m['codigo_materia']] = {'id': m['id_materia'], 'ementa': m.get('ementa', '')}

    materias_por_curso_existentes = set()
    res = executar_operacao(supabase.table('materias_por_curso').select('id_materia', 'id_curso', 'nivel').execute)
    for rel in res.data:
        materias_por_curso_existentes.add((rel['id_materia'], rel['id_curso'], rel['nivel']))

    pre_requisitos_existentes = set()
    res = executar_operacao(supabase.table('pre_requisitos').select('id_materia', 'id_materia_prerequisito').execute)
    for rel in res.data:
        pre_requisitos_existentes.add((rel['id_materia'], rel['id_materia_prerequisito']))

    co_requisitos_existentes = set()
    res = executar_operacao(supabase.table('co_requisitos').select('id_materia', 'id_materia_corequisito').execute)
    for rel in res.data:
        co_requisitos_existentes.add((rel['id_materia'], rel['id_materia_corequisito']))

    equivalencias_existentes = set()
    res = executar_operacao(supabase.table('equivalencias').select('id_materia', 'id_curso', 'matriz_curricular').execute)
    for rel in res.data:
        equivalencias_existentes.add((rel['id_materia'], rel['id_curso'], rel['matriz_curricular']))

    # 2. Durante o processamento, consultar o cache e acumular para batch
    novos_cursos = []
    novas_materias = []
    novas_relacoes = []
    novos_pre_requisitos = []
    novos_co_requisitos = []
    novas_equivalencias = []

    for arquivo in os.listdir(PASTA_MATRIZES):
        if not arquivo.endswith('.json'):
            continue
        with open(os.path.join(PASTA_MATRIZES, arquivo), 'r', encoding='utf-8') as f:
            matriz = json.load(f)
            nome_curso = matriz['curso']
            periodo_letivo = matriz.get('periodo_letivo_vigor', None)
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
                    id_materia = get_or_create_materia(materia)
                    get_or_create_materia_por_curso(id_materia, id_curso, nivel_num)
                    # Pré-requisitos
                    pre = materia.get('pre_requisitos', '')
                    if pre and pre != '-':
                        codigos = re.findall(r'[A-Z]{3,}[0-9]{3,}', pre)
                        for cod in codigos:
                            res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                            if res.data:
                                id_pre = res.data[0]['id_materia']
                                get_or_create_pre_requisito(id_materia, id_pre)
                    # Co-requisitos
                    co = materia.get('co_requisitos', '')
                    if co and co != '-':
                        codigos = re.findall(r'[A-Z]{3,}[0-9]{3,}', co)
                        for cod in codigos:
                            res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                            if res.data:
                                id_co = res.data[0]['id_materia']
                                get_or_create_co_requisito(id_materia, id_co)
                    # Equivalências
                    eq = materia.get('equivalencias', '')
                    if eq and eq != '-':
                        codigos = re.findall(r'[A-Z]{3,}[0-9]{3,}', eq)
                        for cod in codigos:
                            res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                            if res.data:
                                id_eq = res.data[0]['id_materia']
                                get_or_create_equivalencia(id_materia, id_eq, id_curso, matriz_curricular)

    # Exemplo para curso:
    if (nome_curso, periodo_letivo) not in cursos_existentes:
        novos_cursos.append({
            'nome_curso': nome_curso,
            'matriz_curricular': periodo_letivo,
            'data_inicio_matriz': periodo_to_date(periodo_letivo)
        })

    # Repita lógica similar para matérias, relações, pré/co-requisitos e equivalências
    # Só atualize ementa se realmente mudou:
    if materia.get('ementa', '') and materia.get('ementa', '') != materias_existentes[codigo]['ementa']:
        executar_operacao(supabase.table('materias').update({'ementa': materia.get('ementa', '')}).eq('id_materia', materias_existentes[codigo]['id']).execute)
        materias_existentes[codigo]['ementa'] = materia.get('ementa', '')

    if novos_cursos:
        res = executar_operacao(supabase.table('cursos').insert(novos_cursos).execute)
        # Atualiza o cache com os novos ids
        for c, r in zip(novos_cursos, res.data):
            cursos_existentes[(c['nome_curso'], c['matriz_curricular'])] = r['id_curso']

    print("Matrizes curriculares processadas!")

def processar_materias():
    print("Processando matérias...")
    for arquivo in os.listdir(PASTA_MATERIAS):
        if not arquivo.endswith('.json'):
            continue
        with open(os.path.join(PASTA_MATERIAS, arquivo), 'r', encoding='utf-8') as f:
            materias = json.load(f)
            for materia in materias:
                id_materia = get_or_create_materia({
                    'nome': materia['nome'],
                    'codigo': materia['codigo'],
                    'carga_horaria': materia.get('carga_horaria', ''),
                    'ementa': materia.get('ementa', '')
                })
                # Pré-requisitos
                pre = materia.get('pre_requisitos', '')
                if pre and pre != '-':
                    codigos = re.findall(r'[A-Z]{3,}[0-9]{3,}', pre)
                    for cod in codigos:
                        res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                        if res.data:
                            id_pre = res.data[0]['id_materia']
                            get_or_create_pre_requisito(id_materia, id_pre)
                # Co-requisitos
                co = materia.get('co_requisitos', '')
                if co and co != '-':
                    codigos = re.findall(r'[A-Z]{3,}[0-9]{3,}', co)
                    for cod in codigos:
                        res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                        if res.data:
                            id_co = res.data[0]['id_materia']
                            get_or_create_co_requisito(id_materia, id_co)
                # Equivalências
                eq = materia.get('equivalencias', '')
                if eq and eq != '-':
                    codigos = re.findall(r'[A-Z]{3,}[0-9]{3,}', eq)
                    for cod in codigos:
                        res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                        if res.data:
                            id_eq = res.data[0]['id_materia']
                            # Aqui você pode ajustar para inserir na tabela de equivalências conforme o modelo do seu banco
                            # Exemplo:
                            # get_or_create_equivalencia(id_materia, id_eq, id_curso, matriz_curricular)
    print("Matérias processadas!")

if __name__ == "__main__":
    processar_matrizes()
    processar_materias()
    print("Processamento concluído!")

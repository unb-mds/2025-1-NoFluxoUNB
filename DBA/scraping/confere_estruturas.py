import os
import json
from supabase import create_client, Client
import time
from tenacity import retry, stop_after_attempt, wait_exponential
import re
from datetime import datetime

print("Iniciando verificação de estruturas curriculares...")

# Configuração do Supabase
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

def periodo_to_date(periodo):
    if not periodo or not re.match(r'\d{4}\.[12]', periodo):
        return None
    ano, semestre = periodo.split('.')
    mes = '01' if semestre == '1' else '07'
    return f"{ano}-{mes}-01"

def get_or_create_curso(nome_curso, matriz_json, periodo_letivo):
    """Verifica se o curso existe, se não existir, insere"""
    data_inicio = periodo_to_date(periodo_letivo)
    tipo_curso = matriz_json.get('tipo_curso', None)
    
    # Verifica se o curso já existe
    result = executar_operacao(supabase.table('cursos').select('id_curso, nome_curso, matriz_curricular').eq('nome_curso', nome_curso).eq('matriz_curricular', periodo_letivo).execute)
    
    if result.data:
        id_curso = result.data[0]['id_curso']
        print(f"✓ Curso já existe: {nome_curso} - {periodo_letivo} (ID: {id_curso})")
        return id_curso
    else:
        # Insere o curso se não existir
        insert_data = {
            'nome_curso': nome_curso,
            'matriz_curricular': periodo_letivo,
            'data_inicio_matriz': data_inicio,
            'tipo_curso': tipo_curso
        }
        res = executar_operacao(supabase.table('cursos').insert(insert_data).execute)
        id_curso = res.data[0]['id_curso']
        print(f"✓ Curso inserido: {nome_curso} - {periodo_letivo} (ID: {id_curso})")
        return id_curso

def get_or_create_materia(materia):
    """Verifica se a matéria existe, se não existir, insere"""
    codigo = materia['codigo']
    
    # Verifica se a matéria já existe
    result = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', codigo).execute)
    
    if result.data:
        id_materia = result.data[0]['id_materia']
        return id_materia
    else:
        # Insere nova matéria
        insert_data = {
            'nome_materia': materia['nome'],
            'codigo_materia': codigo,
            'carga_horaria': int(materia['ch']) if materia['ch'].isdigit() else None,
            'ementa': '',
            'departamento': ''
        }
        res = executar_operacao(supabase.table('materias').insert(insert_data).execute)
        return res.data[0]['id_materia']

def get_or_create_materia_por_curso(id_materia, id_curso, nivel):
    """Verifica se a matéria está associada ao curso, se não estiver, associa"""
    try:
        # Verifica se já existe a associação
        result = executar_operacao(supabase.table('materias_por_curso').select('id_materia_curso').eq('id_materia', id_materia).eq('id_curso', id_curso).eq('nivel', nivel).execute)
        
        if result.data:
            return result.data[0]['id_materia_curso']
        else:
            # Cria a associação
            insert_data = {
                'id_materia': id_materia,
                'id_curso': id_curso,
                'nivel': nivel
            }
            res = executar_operacao(supabase.table('materias_por_curso').insert(insert_data).execute)
            return res.data[0]['id_materia_curso']
    except Exception as e:
        print(f"Erro ao associar matéria ao curso: {e}")
        return None

def determinar_nivel(nivel_nome):
    """Determina o número do nível baseado no nome"""
    if nivel_nome == "OPTATIVAS":
        return 0  # Nível 0 para optativas
    else:
        # Extrai o número do nível (1° NIVEL -> 1)
        try:
            return int(nivel_nome.split('°')[0])
        except:
            return 0

def verificar_estrutura_curricular(arquivo_json):
    """Verifica e corrige a estrutura curricular de um arquivo JSON"""
    try:
        with open(arquivo_json, 'r', encoding='utf-8') as f:
            dados_curso = json.load(f)
    except Exception as e:
        print(f"❌ Erro ao ler arquivo {arquivo_json}: {e}")
        return
    
    nome_curso = dados_curso['curso']
    periodo_letivo = dados_curso['periodo_letivo_vigor']
    
    print(f"\n{'='*80}")
    print(f"Verificando: {nome_curso} - {periodo_letivo}")
    print(f"{'='*80}")
    
    # 1. Verifica/cria o curso
    id_curso = get_or_create_curso(nome_curso, dados_curso, periodo_letivo)
    
    # 2. Verifica as matérias existentes no banco para este curso
    result_materias_banco = executar_operacao(supabase.table('materias_por_curso').select('id_materia_curso, id_materia, nivel').eq('id_curso', id_curso).execute)
    
    materias_banco = {}
    for item in result_materias_banco.data:
        materias_banco[item['id_materia']] = item['nivel']
    
    print(f"Matérias já no banco para este curso: {len(materias_banco)}")
    
    # 3. Processa cada nível do JSON
    materias_processadas = 0
    materias_inseridas = 0
    materias_ignoradas = 0
    
    for nivel_data in dados_curso['niveis']:
        nivel_nome = nivel_data['nivel']
        materias = nivel_data['materias']
        nivel_num = determinar_nivel(nivel_nome)
        
        print(f"\n  Nível: {nivel_nome} (número: {nivel_num})")
        
        for materia in materias:
            codigo = materia['codigo']
            
            # Pula matérias com código "O" (optativas genéricas)
            if codigo == "O":
                continue
            
            materias_processadas += 1
            
            # Verifica/cria a matéria
            id_materia = get_or_create_materia(materia)
            
            # Verifica se a matéria já está associada ao curso
            if id_materia in materias_banco and materias_banco[id_materia] == nivel_num:
                print(f"    ✓ {codigo}: {materia['nome']} - Já existe no nível {nivel_num}")
                materias_ignoradas += 1
            else:
                # Associa a matéria ao curso
                resultado = get_or_create_materia_por_curso(id_materia, id_curso, nivel_num)
                if resultado:
                    print(f"    ➕ {codigo}: {materia['nome']} - Inserida no nível {nivel_num}")
                    materias_inseridas += 1
                else:
                    print(f"    ❌ {codigo}: {materia['nome']} - Erro ao inserir")
    
    print(f"\n  RESUMO:")
    print(f"    Matérias processadas: {materias_processadas}")
    print(f"    Matérias inseridas: {materias_inseridas}")
    print(f"    Matérias ignoradas (já existiam): {materias_ignoradas}")
    
    return materias_processadas, materias_inseridas, materias_ignoradas

def main():
    """Função principal que processa todos os arquivos JSON"""
    pasta_estruturas = os.path.join(os.path.dirname(__file__), '..', 'dados', 'estruturas-curriculares')
    
    if not os.path.exists(pasta_estruturas):
        print(f"❌ Pasta não encontrada: {pasta_estruturas}")
        return
    
    arquivos_json = [f for f in os.listdir(pasta_estruturas) if f.endswith('.json')]
    arquivos_json.sort()
    
    print(f"Encontrados {len(arquivos_json)} arquivos JSON para verificar")
    
    total_processadas = 0
    total_inseridas = 0
    total_ignoradas = 0
    
    for arquivo in arquivos_json:
        caminho_completo = os.path.join(pasta_estruturas, arquivo)
        try:
            processadas, inseridas, ignoradas = verificar_estrutura_curricular(caminho_completo)
            total_processadas += processadas
            total_inseridas += inseridas
            total_ignoradas += ignoradas
        except Exception as e:
            print(f"❌ Erro ao processar {arquivo}: {e}")
            continue
    
    print(f"\n{'='*80}")
    print(f"VERIFICAÇÃO CONCLUÍDA")
    print(f"{'='*80}")
    print(f"Total de arquivos processados: {len(arquivos_json)}")
    print(f"Total de matérias processadas: {total_processadas}")
    print(f"Total de matérias inseridas: {total_inseridas}")
    print(f"Total de matérias ignoradas (já existiam): {total_ignoradas}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Erro durante o processamento: {e}")
        raise

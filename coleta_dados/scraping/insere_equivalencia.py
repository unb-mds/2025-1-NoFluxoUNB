import os
import json
import re
import time
from supabase import create_client, Client
from integracao_banco import SUPABASE_URL, SUPABASE_KEY, remover_acentos, periodo_letivo_to_date
from tenacity import retry, stop_after_attempt, wait_exponential

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
        if any(keyword in error_msg for keyword in ['connection', 'timeout', 'network', 'socket', 'protocol']):
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

# Caminho da pasta de matérias
PASTA_MATERIAS = os.path.join(os.path.dirname(__file__), '..', 'dados', 'materias')

def insere_equivalencias():
    arquivos = [arq for arq in os.listdir(PASTA_MATERIAS) if arq.endswith('.json')]
    print(f"Total de arquivos de matérias encontrados: {len(arquivos)}")
    
    total_equivalencias_gerais = 0
    total_equivalencias_especificas = 0
    total_inseridas_gerais = 0
    total_inseridas_especificas = 0
    
    for arquivo in arquivos:
        print(f"\nProcessando arquivo: {arquivo}")
        try:
            with open(os.path.join(PASTA_MATERIAS, arquivo), 'r', encoding='utf-8') as f:
                materias = json.load(f)
                print(f"  Matérias no arquivo: {len(materias)}")
                
                for materia in materias:
                    codigo = materia['codigo']
                    
                    try:
                        # Buscar id_materia no banco
                        res = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', codigo).execute)
                        if not res.data:
                            print(f"  [WARN] Matéria {codigo} não encontrada no banco, pulando...")
                            continue
                        
                        id_materia = res.data[0]['id_materia']
                        
                        # Equivalências gerais
                        eq = materia.get('equivalencias', '')
                        if eq and eq != '-':
                            total_equivalencias_gerais += 1
                            codigos = re.findall(r'[A-Z]{3,}[0-9]{3,}', eq)
                            for cod in codigos:
                                try:
                                    # Verificar se a matéria equivalente existe
                                    res_eq = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', cod).execute)
                                    if res_eq.data:
                                        # Verificar se equivalência geral já existe
                                        query = supabase.table('equivalencias').select('id_equivalencia').eq('id_materia', id_materia).eq('expressao', cod)
                                        query = query.is_('id_curso', None).is_('matriz_curricular', None).is_('curriculo', None)
                                        result = executar_operacao(query.execute)
                                        
                                        if not result.data:
                                            executar_operacao(supabase.table('equivalencias').insert({
                                                'id_materia': id_materia,
                                                'id_curso': None,
                                                'expressao': cod,
                                                'matriz_curricular': None,
                                                'curriculo': None,
                                                'data_vigencia': None
                                            }).execute)
                                            print(f"  [OK] Inserida equivalência geral: {codigo} -> {cod}")
                                            total_inseridas_gerais += 1
                                        else:
                                            print(f"  [SKIP] Equivalência geral já existe: {codigo} -> {cod}")
                                except Exception as e:
                                    print(f"  [ERROR] Erro ao processar equivalência geral {codigo} -> {cod}: {e}")
                                    continue
                        
                        # Equivalências específicas
                        equiv_esp = materia.get('equivalencias_especificas', None)
                        if equiv_esp and isinstance(equiv_esp, list):
                            for eqesp in equiv_esp:
                                try:
                                    total_equivalencias_especificas += 1
                                    nome_curso_esp = remover_acentos(eqesp.get('matriz_curricular', '').strip().split(' - ')[0].upper())
                                    curriculo_raw = eqesp.get('curriculo', '').strip()
                                    match = re.search(r'(\d{4}\.\d)', curriculo_raw)
                                    periodo_letivo_esp = match.group(1) if match else ''
                                    
                                    # Buscar o id_curso correspondente
                                    id_curso_esp = None
                                    if nome_curso_esp and periodo_letivo_esp:
                                        res_cursos = executar_operacao(supabase.table('cursos').select('id_curso', 'nome_curso', 'matriz_curricular').eq('matriz_curricular', periodo_letivo_esp).execute)
                                        for curso in res_cursos.data:
                                            nome_curso_banco = remover_acentos(curso['nome_curso'].strip().upper())
                                            if nome_curso_banco == nome_curso_esp:
                                                id_curso_esp = curso['id_curso']
                                                break
                                    
                                    data_vigencia_raw = eqesp.get('data_vigencia', '').strip()
                                    fim_vigencia_raw = eqesp.get('fim_vigencia', '').strip()
                                    data_vigencia_eq = periodo_letivo_to_date(data_vigencia_raw)
                                    fim_vigencia_eq = periodo_letivo_to_date(fim_vigencia_raw) if fim_vigencia_raw else None
                                    
                                    if id_curso_esp and nome_curso_esp and curriculo_raw and data_vigencia_eq:
                                        # Verificar se equivalência específica já existe
                                        result = executar_operacao(supabase.table('equivalencias').select('id_equivalencia').eq('id_materia', id_materia).eq('expressao', eqesp.get('expressao', '')).eq('matriz_curricular', periodo_letivo_esp).eq('curriculo', curriculo_raw).eq('data_vigencia', data_vigencia_eq).execute)
                                        
                                        if not result.data:
                                            executar_operacao(supabase.table('equivalencias').insert({
                                                'id_materia': id_materia,
                                                'id_curso': id_curso_esp,
                                                'expressao': eqesp.get('expressao', ''),
                                                'matriz_curricular': periodo_letivo_esp,
                                                'curriculo': curriculo_raw,
                                                'data_vigencia': data_vigencia_eq,
                                                'fim_vigencia': fim_vigencia_eq if fim_vigencia_eq else None
                                            }).execute)
                                            print(f"  [OK] Inserida equivalência específica: {codigo} -> {eqesp.get('expressao', '')}")
                                            total_inseridas_especificas += 1
                                        else:
                                            print(f"  [SKIP] Equivalência específica já existe: {codigo} -> {eqesp.get('expressao', '')}")
                                except Exception as e:
                                    print(f"  [ERROR] Erro ao processar equivalência específica {codigo}: {e}")
                                    continue
                    except Exception as e:
                        print(f"  [ERROR] Erro ao processar matéria {codigo}: {e}")
                        continue
        except Exception as e:
            print(f"  [ERROR] Erro ao processar arquivo {arquivo}: {e}")
            continue
    
    print(f"\n=== RESUMO ===")
    print(f"Total de equivalências gerais processadas: {total_equivalencias_gerais}")
    print(f"Total de equivalências gerais inseridas: {total_inseridas_gerais}")
    print(f"Total de equivalências específicas processadas: {total_equivalencias_especificas}")
    print(f"Total de equivalências específicas inseridas: {total_inseridas_especificas}")

if __name__ == "__main__":
    insere_equivalencias()
    print("Inserção de equivalências concluída!")

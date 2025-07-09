import os
import json
import time
from supabase import create_client, Client
from integracao_banco import SUPABASE_URL, SUPABASE_KEY
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

# Caminho da pasta de turmas dos departamentos
PASTA_TURMAS_DEPTO = os.path.join(os.path.dirname(__file__), '..', 'dados', 'materias')

def atualiza_departamento():
    # Percorrer todos os arquivos turmas_depto_*.json
    arquivos = [arq for arq in os.listdir(PASTA_TURMAS_DEPTO) if arq.startswith('turmas_depto_') and arq.endswith('.json')]
    print(f"Total de arquivos de departamentos encontrados: {len(arquivos)}")
    
    total_materias = 0
    total_atualizadas = 0
    total_puladas = 0
    total_nao_encontradas = 0
    
    for arquivo in arquivos:
        print(f"\nProcessando arquivo: {arquivo}")
        try:
            with open(os.path.join(PASTA_TURMAS_DEPTO, arquivo), 'r', encoding='utf-8') as f:
                turmas = json.load(f)
                print(f"  Matérias no arquivo: {len(turmas)}")
                
                for turma in turmas:
                    total_materias += 1
                    codigo = turma.get('codigo')
                    departamento = turma.get('unidade_responsavel', '').strip()
                    
                    if not codigo or not departamento:
                        print(f"  [SKIP] Matéria sem código ou departamento: {turma}")
                        continue
                    
                    try:
                        # Atualiza o campo departamento na tabela materias
                        res = executar_operacao(supabase.table('materias').select('id_materia', 'departamento').eq('codigo_materia', codigo).execute)
                        if res.data:
                            id_materia = res.data[0]['id_materia']
                            departamento_atual = res.data[0].get('departamento', '')
                            
                            if departamento_atual != departamento:
                                executar_operacao(supabase.table('materias').update({'departamento': departamento}).eq('id_materia', id_materia).execute)
                                print(f"  [OK] Atualizado departamento da matéria {codigo}: {departamento}")
                                total_atualizadas += 1
                            else:
                                print(f"  [SKIP] Matéria {codigo} já está com departamento correto.")
                                total_puladas += 1
                        else:
                            print(f"  [WARN] Matéria {codigo} não encontrada no banco.")
                            total_nao_encontradas += 1
                    except Exception as e:
                        print(f"  [ERROR] Erro ao processar matéria {codigo}: {e}")
                        continue
        except Exception as e:
            print(f"  [ERROR] Erro ao processar arquivo {arquivo}: {e}")
            continue
    
    print(f"\n=== RESUMO ===")
    print(f"Total de matérias processadas: {total_materias}")
    print(f"Total de departamentos atualizados: {total_atualizadas}")
    print(f"Total de matérias já corretas: {total_puladas}")
    print(f"Total de matérias não encontradas: {total_nao_encontradas}")

if __name__ == "__main__":
    atualiza_departamento()
    print("Atualização de departamentos concluída!")


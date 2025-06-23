import os
import json
from supabase import create_client, Client
import time
from tenacity import retry, stop_after_attempt, wait_exponential
import re

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
        print(f"[DEBUG] Executando operação...")
        resultado = operacao(*args, **kwargs)
        print(f"[DEBUG] Operação executada com sucesso")
        return resultado
    except Exception as e:
        error_msg = str(e).lower()
        
        # Se for erro de duplicidade, não tenta reconectar
        if 'duplicate key value violates unique constraint' in error_msg:
            print(f"[DEBUG] Erro de duplicidade detectado: {str(e)}")
            raise  # Re-lança a exceção sem tentar reconectar
        
        # Se for erro de conexão ou timeout
        if any(keyword in error_msg for keyword in ['connection', 'timeout', 'network', 'socket']):
            print(f"Erro de conexão detectado: {str(e)}")
            print("Tentando reconectar...")
            reconectar_supabase()
            time.sleep(3)  # Espera 3 segundos antes de tentar novamente
            raise  # Re-lança a exceção para o retry
        
        # Para outros erros, também tenta reconectar
        print(f"Erro na operação: {str(e)}")
        print("Tentando reconectar...")
        reconectar_supabase()
        time.sleep(2)
        raise

print("Testando conexão com o Supabase...")
# Teste de conexão com o Supabase
try:
    resposta = executar_operacao(supabase.table('cursos').select('id_curso, nome_curso').limit(1).execute)
    print('Conexão com Supabase bem-sucedida! Exemplo de curso:', resposta.data)
except Exception as e:
    print('Erro ao conectar com o Supabase. Verifique sua SUPABASE_URL e SUPABASE_KEY.')
    print('Detalhes do erro:', e)
    exit(1)

print("Definindo caminho da pasta de dados...")
pasta = os.path.join(os.path.dirname(__file__), '..', 'dados', 'estruturas-curriculares')
print(f"Caminho da pasta: {pasta}")

# Função para recarregar caches do banco
def recarregar_caches():
    print("Iniciando recarga de caches...")
    cursos_existentes = {}
    print("Buscando cursos existentes...")
    try:
        result = executar_operacao(supabase.table('cursos').select('id_curso, nome_curso').execute)
        if result.data:
            for c in result.data:
                cursos_existentes[c['nome_curso']] = c['id_curso']
        print(f"Encontrados {len(cursos_existentes)} cursos")
    except Exception as e:
        print(f"Erro ao buscar cursos: {e}")
        return {}, {}, {}

    materias_existentes = {}
    print("Buscando matérias existentes...")
    try:
        result = executar_operacao(supabase.table('materias').select('id_materia, codigo_materia').execute)
        if result.data:
            for m in result.data:
                materias_existentes[m['codigo_materia']] = m['id_materia']
        print(f"Encontradas {len(materias_existentes)} matérias")
    except Exception as e:
        print(f"Erro ao buscar matérias: {e}")
        return cursos_existentes, {}, {}

    # Carregar relações materia-curso existentes
    materias_por_curso_existentes = set()
    print("Buscando relações materia-curso existentes...")
    try:
        result = executar_operacao(supabase.table('materias_por_curso').select('id_materia, id_curso, nivel').execute)
        if result.data:
            for mpc in result.data:
                materias_por_curso_existentes.add((mpc['id_materia'], mpc['id_curso'], mpc['nivel']))
        print(f"Encontradas {len(materias_por_curso_existentes)} relações materia-curso")
    except Exception as e:
        print(f"Erro ao buscar relações materia-curso: {e}")
        return cursos_existentes, materias_existentes, set()
    
    return cursos_existentes, materias_existentes, materias_por_curso_existentes

print("Recarregando caches do banco...")
# Recarregar caches do banco antes de processar
cursos_existentes, materias_existentes, materias_por_curso_existentes = recarregar_caches()

print("Iniciando processamento dos arquivos JSON...")
arquivos_processados = 0
erros_arquivos = 0

for arquivo in os.listdir(pasta):
    if arquivo.endswith('.json'):
        print(f"\n{'='*50}")
        print(f"Processando arquivo: {arquivo}")
        print(f"{'='*50}")
        
        try:
            with open(os.path.join(pasta, arquivo), 'r', encoding='utf-8') as f:
                dados = json.load(f)
                curso_nome = dados['curso']
                niveis = dados['niveis']
                print(f"Curso: {curso_nome} - {len(niveis)} níveis encontrados")

                # Curso
                try:
                    if curso_nome in cursos_existentes:
                        curso_id = cursos_existentes[curso_nome]
                        print(f"[DEBUG] Curso já existe: {curso_nome} (id: {curso_id})")
                    else:
                        curso_id = executar_operacao(supabase.table('cursos').insert({'nome_curso': curso_nome}).execute).data[0]['id_curso']
                        cursos_existentes[curso_nome] = curso_id
                        print(f"[DEBUG] Inserindo novo curso: {curso_nome} (id: {curso_id})")
                except Exception as e:
                    print(f"Erro ao processar curso {curso_nome}: {e}")
                    continue

                materias_processadas = 0
                for ordem, nivel in enumerate(niveis, start=1):
                    try:
                        # Usar o nível do JSON, não a ordem
                        nivel_raw = nivel.get('nivel', ordem)
                        
                        # Extrair apenas o número do nível (remover "º Semestre", etc.)
                        if isinstance(nivel_raw, str):
                            # Extrair apenas dígitos da string
                            numeros = re.findall(r'\d+', nivel_raw)
                            if numeros:
                                nivel_numero = int(numeros[0])
                            else:
                                nivel_numero = ordem
                        else:
                            nivel_numero = int(nivel_raw)
                            
                        print(f"[DEBUG] Processando nível {nivel_numero} (original: {nivel_raw}) para curso {curso_nome}")

                        for materia in nivel['materias']:
                            try:
                                # Determinar o nível final da matéria
                                nivel_final = nivel_numero
                                
                                # Se a matéria é optativa, definir nível como 0
                                if materia.get('natureza') == 'Optativa':
                                    nivel_final = 0
                                    print(f"[DEBUG] Matéria optativa detectada: {materia['nome']} - definindo nível como 0")
                                
                                # Preparar dados da matéria
                                materia_dict = {
                                    'nome_materia': materia['nome'],
                                    'codigo_materia': materia['codigo'],
                                    'carga_horaria': materia['carga_horaria']
                                }
                                
                                codigo = materia['codigo']
                                if codigo in materias_existentes:
                                    materia_id = materias_existentes[codigo]
                                    print(f"[DEBUG] Matéria já existe: {codigo} - {materia['nome']} (id: {materia_id})")
                                else:
                                    try:
                                        materia_id = executar_operacao(supabase.table('materias').insert(materia_dict).execute).data[0]['id_materia']
                                        materias_existentes[codigo] = materia_id
                                        print(f"[DEBUG] Inserindo nova matéria: {codigo} - {materia['nome']} (id: {materia_id})")
                                    except Exception as e:
                                        # Se for erro de duplicidade, busca o id no banco
                                        if 'duplicate key value violates unique constraint' in str(e):
                                            result = executar_operacao(supabase.table('materias').select('id_materia').eq('codigo_materia', codigo).execute)
                                            if result.data:
                                                materia_id = result.data[0]['id_materia']
                                                materias_existentes[codigo] = materia_id
                                                print(f"[DEBUG] Matéria encontrada após erro de duplicidade: {codigo} - {materia['nome']} (id: {materia_id})")
                                            else:
                                                raise
                                        else:
                                            raise

                                # Criar relação materia-curso
                                if (materia_id, curso_id, nivel_final) not in materias_por_curso_existentes:
                                    try:
                                        rel_id = executar_operacao(supabase.table('materias_por_curso')
                                            .insert({
                                                'id_materia': materia_id, 
                                                'id_curso': curso_id, 
                                                'nivel': nivel_final
                                            })
                                            .execute).data[0]['id_materia_curso']
                                        materias_por_curso_existentes.add((materia_id, curso_id, nivel_final))
                                        print(f"[DEBUG] Relacionando materia_id: {materia_id} com curso_id: {curso_id} no nível {nivel_final} (materias_por_curso.id: {rel_id})")
                                        materias_processadas += 1
                                    except Exception as e:
                                        if 'duplicate key value violates unique constraint' in str(e):
                                            print(f"[DEBUG] Relação já existe: materia_id: {materia_id} com curso_id: {curso_id} no nível {nivel_final}")
                                            # Adiciona ao cache para evitar tentativas futuras
                                            materias_por_curso_existentes.add((materia_id, curso_id, nivel_final))
                                        else:
                                            raise
                                else:
                                    print(f"[DEBUG] Relação já existe: materia_id: {materia_id} com curso_id: {curso_id} no nível {nivel_final}")
                                    
                            except Exception as e:
                                print(f"Erro ao processar matéria {materia.get('nome', 'N/A')}: {e}")
                                continue
                                
                    except Exception as e:
                        print(f"Erro ao processar nível {ordem}: {e}")
                        continue
                
                print(f"Arquivo {arquivo} processado com sucesso! {materias_processadas} matérias processadas.")
                arquivos_processados += 1
                
        except Exception as e:
            print(f"Erro ao processar arquivo {arquivo}: {str(e)}")
            erros_arquivos += 1
            continue

print(f"\n{'='*50}")
print("PROCESSAMENTO CONCLUÍDO!")
print(f"{'='*50}")
print(f"Arquivos processados com sucesso: {arquivos_processados}")
print(f"Arquivos com erro: {erros_arquivos}")
print(f"Total de arquivos: {arquivos_processados + erros_arquivos}")

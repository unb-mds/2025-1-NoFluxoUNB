import os
import json
from supabase import create_client, Client
from integracao_banco import SUPABASE_URL, SUPABASE_KEY, periodo_to_date

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Caminho das matrizes curriculares
PASTA_MATRIZES = os.path.join(os.path.dirname(__file__), '..', 'dados', 'estruturas-curriculares')

def atualiza_tipo_curso():
    arquivos = [arq for arq in os.listdir(PASTA_MATRIZES) if arq.endswith('.json')]
    print(f"Total de matrizes encontradas: {len(arquivos)}")
    for arquivo in arquivos:
        with open(os.path.join(PASTA_MATRIZES, arquivo), 'r', encoding='utf-8') as f:
            matriz = json.load(f)
            nome_curso = matriz.get('curso')
            periodo_letivo = matriz.get('periodo_letivo_vigor')
            tipo_curso = matriz.get('tipo_curso')
            if not (nome_curso and periodo_letivo and tipo_curso):
                print(f"[SKIP] {arquivo}: dados insuficientes.")
                continue
            data_inicio = periodo_to_date(periodo_letivo)
            # Busca o curso no banco
            res = supabase.table('cursos').select('id_curso', 'tipo_curso').eq('nome_curso', nome_curso).eq('data_inicio_matriz', data_inicio).execute()
            if not res.data:
                print(f"[NOT FOUND] {nome_curso} - {periodo_letivo}")
                continue
            id_curso = res.data[0]['id_curso']
            tipo_curso_atual = res.data[0].get('tipo_curso')
            if tipo_curso_atual is None:
                supabase.table('cursos').update({'tipo_curso': tipo_curso}).eq('id_curso', id_curso).execute()
                print(f"[OK] Atualizado tipo_curso para {nome_curso} - {periodo_letivo}: {tipo_curso}")
            else:
                print(f"[SKIP] {nome_curso} - {periodo_letivo}: tipo_curso já preenchido ({tipo_curso_atual})")

if __name__ == "__main__":
    atualiza_tipo_curso()

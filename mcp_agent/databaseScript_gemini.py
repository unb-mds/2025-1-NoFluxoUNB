import os
from supabase import create_client, Client
from tqdm import tqdm
import google.generativeai as genai
from dotenv import load_dotenv

# Carrega as variáveis do .env do mcp_agent
load_dotenv()

SUPABASE_URL = os.environ.get("SUPABASE_URL")
# Tenta pegar a SERVICE_ROLE_KEY primeiro, senao pega a comum (para poder fazer upsert)
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY")
GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY")

NOME_TABELA = "materias_vetorizadas"

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
genai.configure(api_key=GOOGLE_API_KEY)

tamanho_do_lote = 100

print("==================================================")
print(" Atualizando banco de dados com Embeddings GEMINI ")
print("==================================================")

# Busca todas as matérias
all_materias = []
start = 0
step = 1000
while True:
    res = supabase.table(NOME_TABELA).select("*").range(start, start + step - 1).execute()
    if not res.data:
        break
    all_materias.extend(res.data)
    start += step

print(f"\nTotal de {len(all_materias)} matérias encontradas no banco.")

lote_para_atualizar = []

print("\nGerando embeddings (isso pode levar alguns minutos)...")
for materia in tqdm(all_materias, desc="Calculando Embeddings (Gemini)"):
    nome = str(materia.get("nome_materia", "")).strip()
    ementa = str(materia.get("ementa", "")).strip()
    
    texto_busca = f"Disciplina: {nome}. Ementa: {ementa}"
    
    try:
        # Usa o mesmo modelo da API (api_producao.py)
        result = genai.embed_content(
            model="models/gemini-embedding-001",
            content=texto_busca,
            task_type="retrieval_document",
            output_dimensionality=256
        )
        
        vetor = result.get("embedding")
        if vetor:
            materia_atualizada = materia.copy()
            materia_atualizada["embedding"] = vetor
            lote_para_atualizar.append(materia_atualizada)
    except Exception as e:
        print(f"\nErro ao gerar embedding para {nome}: {e}")

print(f"\nEnviando {len(lote_para_atualizar)} matérias atualizadas para o Supabase em lotes de {tamanho_do_lote}...")
for i in range(0, len(lote_para_atualizar), tamanho_do_lote):
    pacote = lote_para_atualizar[i:i+tamanho_do_lote]
    supabase.table(NOME_TABELA).upsert(pacote).execute()

print("\n✅ BANCO DE DADOS ATUALIZADO COM SUCESSO!")

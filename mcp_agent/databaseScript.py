from sentence_transformers import SentenceTransformer
from supabase import create_client, Client
from tqdm import tqdm
import warnings
import os

warnings.filterwarnings("ignore")

# Configurações

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
NOME_TABELA = "materias_vetorizadas" # Apontando para a tabela

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Carregar o modelo
print("Carregando o modelo")
modelo = SentenceTransformer("all-MiniLM-L6-v2")

# Puxar as matérias da tabela nova que ainda não têm vetor
print("Buscando materias para vetorizar")
resposta = supabase.table(NOME_TABELA).select("id_materia, nome_materia, ementa").is_("embedding", "null").limit(5000).execute()
materias = resposta.data

if not materias:
    print("Todas as mateerias ja estão vetorizadas")
    exit()

print(f"Vetorizando {len(materias)} matérias e atualizando o banco")

for materia in tqdm(materias):
    id_mat = materia['id_materia']
    nome = str(materia.get('nome_materia', '')).strip()
    ementa = str(materia.get('ementa', '')).strip()
    
    texto_busca = f"Disciplina: {nome}. Ementa: {ementa}"
    vetor = modelo.encode(texto_busca).tolist()
    
    supabase.table(NOME_TABELA).update({"embedding": vetor}).eq("id_materia", id_mat).execute()

print("\nA tabela copiada está vetorizada")
from mcp.server.fastmcp import FastMCP
import json
import sys
import warnings
import os

# Silencia avisos desnecessários no terminal
warnings.filterwarnings("ignore")
os.environ["TOKENIZERS_PARALLELISM"] = "false"

print("Iniciando o servidor MCP para o Recomendador UnB...", file=sys.stderr)

mcp = FastMCP("Recomendador_UnB_Supabase")

# Variáveis globais para persistência em memória
supabase_client = None
modelo_embedding = None

def inicializar_sistemas():
    global supabase_client, modelo_embedding
    
    # Inicializa o cliente Supabase
    if supabase_client is None:
        print("Conectando ao Supabase...", file=sys.stderr)

        SUPABASE_URL = ""
        SUPABASE_KEY = ""
        
        from supabase import create_client
        supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
    # Carrega o modelo de IA apenas se não estiver na RAM
    if modelo_embedding is None:
        print("Carregando modelo SentenceTransformer na RAM...", file=sys.stderr)
        from sentence_transformers import SentenceTransformer
        modelo_embedding = SentenceTransformer("all-MiniLM-L6-v2")

@mcp.tool()
def buscar_materias_unb(interesse: str) -> str:
    """
    Busca matérias na base de dados da UnB com base no interesse do aluno.
    """
    inicializar_sistemas()
    
    # Gera o vetor para a busca
    vetor_pergunta = modelo_embedding.encode(interesse).tolist()
    
    try:
        # Chama a função RPC no (Supabase)
        resposta = supabase_client.rpc(
            "match_materias", 
            {
                "query_embedding": vetor_pergunta,
                "match_threshold": 0.35, # Filtro de similaridade
                "match_count": 5        # Top 5 resultados por termo
            }
        ).execute()
        
        dados = resposta.data
        if not dados:
            return "[]"

        lista_final = []
        for item in dados:
            lista_final.append({
                "Codigo": item.get("codigo_materia"),
                "Materia": item.get("nome_materia"),
                "Departamento": item.get("departamento") or "Não informado",
                "Ementa_Resumida": str(item.get("ementa", ""))[:250] + "...",
                "Score_DB": round(item.get("similaridade", 0), 2)
            })
                    
        return json.dumps(lista_final, ensure_ascii=False, indent=2)
    
    except Exception as e:
        print(f"Erro na busca RPC: {e}", file=sys.stderr)
        return "[]"

if __name__ == "__main__":
    mcp.run(transport='stdio')
from mcp.server.fastmcp import FastMCP
import json
import sys
import warnings
import os

# Desativa logs
warnings.filterwarnings("ignore")
os.environ["TOKENIZERS_PARALLELISM"] = "false"

print(" Iniciando Servidor MCP Offline para MaritacaAI...", file=sys.stderr)

mcp = FastMCP("Recomendador_UnB_Supabase")

supabase_client = None
modelo_embedding = None

def inicializar_sistemas():
    global supabase_client, modelo_embedding
    
    if supabase_client is None:
        print("Conectando ao Supabase...", file=sys.stderr)
        SUPABASE_URL = os.environ.get("SUPABASE_URL")
        SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
        
        from supabase import create_client
        supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
    if modelo_embedding is None:
        print("Carregando modelo local na RAM", file=sys.stderr)
        from sentence_transformers import SentenceTransformer
        # Apontamos para a pasta local onde o modelo está armazenado, garantindo que a geração de vetores seja feita offline
        modelo_embedding = SentenceTransformer("./modelo_local", device="cpu")

@mcp.tool()
def buscar_materias_unb(interesse: str) -> str:
    """Busca matérias na base de dados da UnB via busca vetorial."""
    inicializar_sistemas()
    
    # Gera o vetor localmente
    vetor_pergunta = modelo_embedding.encode(interesse).tolist()
    
    try:
        resposta = supabase_client.rpc(
            "match_materias", 
            {
                "query_embedding": vetor_pergunta,
                "match_threshold": 0.4, 
                "match_count": 8        
            }
        ).execute()
        
        dados = resposta.data or []
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
        print(f"Erro na busca: {e}", file=sys.stderr)
        return "[]"

if __name__ == "__main__":
    mcp.run(transport='stdio')
from mcp.server.fastmcp import FastMCP
import json
import sys
import warnings
import os


print("Iniciando o servidor MCP", file=sys.stderr)

warnings.filterwarnings("ignore")
os.environ["TOKENIZERS_PARALLELISM"] = "false"

mcp = FastMCP("Recomendador_UnB_Supabase")

supabase_client = None
modelo_embedding = None

def inicializar_sistemas():
    global supabase_client, modelo_embedding
    if supabase_client is None:
        print("Conectando ao Supabase e carregando modelo", file=sys.stderr)
        
        # 2. credenciais reais 
        SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
        SUPABASE_URL = os.environ.get("SUPABASE_URL")
        from supabase import create_client, Client
        supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        from sentence_transformers import SentenceTransformer
        modelo_embedding = SentenceTransformer("all-MiniLM-L6-v2")

@mcp.tool()
def buscar_materias_unb(interesse: str) -> str:
    """
    Busca matérias universitárias na base de dados da UnB com base no interesse do aluno.
    Use esta ferramenta para recomendar disciplinas informando a palavra-chave.
    """
    inicializar_sistemas()
    
    vetor_pergunta = modelo_embedding.encode(interesse).tolist()
    
    resposta = supabase_client.rpc(
        "match_materias", 
        {
            "query_embedding": vetor_pergunta,
            "match_threshold": 0.4, 
            "match_count": 8        
        }
    ).execute()
    
    dados = resposta.data
    lista_final = []
    
    if not dados:
        return "Nenhuma matéria encontrada para este tema."

    for item in dados:
        lista_final.append({
            "Codigo": item.get("codigo_materia"),
            "Materia": item.get("nome_materia"),
            "Departamento": item.get("departamento") or "Não informado",
            "Ementa_Resumida": str(item.get("ementa", ""))[:250] + "..."
            #"Score_Similaridade": round(item.get("similaridade", 0), 2)
        })
                
    return json.dumps(lista_final, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    mcp.run(transport='stdio')
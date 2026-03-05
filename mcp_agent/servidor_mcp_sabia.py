from mcp.server.fastmcp import FastMCP
import json
import sys
import warnings
import os
from dotenv import load_dotenv
from pathlib import Path

# Carrega variáveis de ambiente do .env na pasta do script
script_dir = Path(__file__).parent
dotenv_path = script_dir / ".env"
load_dotenv(dotenv_path)

# Desativa logs
warnings.filterwarnings("ignore")
os.environ["TOKENIZERS_PARALLELISM"] = "false"

print("[MCP] Iniciando Servidor MCP Offline para MaritacaAI...", file=sys.stderr)

mcp = FastMCP("Recomendador_UnB_Supabase")

supabase_client = None
modelo_embedding = None

# Inicializa sistemas no carregamento do módulo (uma vez só)
print("[MCP] Pré-inicializando sistemas...", file=sys.stderr)

try:
    print("[MCP] 1/2 Conectando Supabase...", file=sys.stderr)
    SUPABASE_URL = os.environ.get("SUPABASE_URL")
    SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    
    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        raise ValueError("SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY não encontrados no .env")
    
    from supabase import create_client
    supabase_client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    print("[MCP] ✅ Supabase conectado!", file=sys.stderr)
    
    print("[MCP] 2/2 Carregando modelo de embedding...", file=sys.stderr)
    from sentence_transformers import SentenceTransformer
    
    # Usa o modelo multilingual L12-v2 (mesmo usado no banco)
    modelo_local = Path(__file__).parent / "modelo_local_v2"
    print(f"[MCP] Verificando modelo em: {modelo_local}", file=sys.stderr)
    print(f"[MCP] Existe? {modelo_local.exists()}", file=sys.stderr)
    print(f"[MCP] Working directory: {os.getcwd()}", file=sys.stderr)
    
    if modelo_local.exists():
        print(f"[MCP] Carregando de: {modelo_local}", file=sys.stderr)
        modelo_embedding = SentenceTransformer(str(modelo_local), device="cpu")
    else:
        print("[MCP] Baixando modelo multilingual (primeira vez)...", file=sys.stderr)
        modelo_embedding = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2", device="cpu")
        modelo_embedding.save(str(modelo_local))
    
    print(f"[MCP] ✅ Modelo carregado: {modelo_embedding}", file=sys.stderr)
    print("[MCP] ✅ Sistemas prontos!", file=sys.stderr)
    
except Exception as e:
    print(f"[MCP] ❌ ERRO na inicialização: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc(file=sys.stderr)

def inicializar_sistemas():
    """Função mantida para compatibilidade, mas inicialização já foi feita."""
    global supabase_client, modelo_embedding
    
    if supabase_client is None or modelo_embedding is None:
        raise RuntimeError("Sistemas não foram inicializados corretamente no startup")

@mcp.tool()
def buscar_materias_unb(interesse: str) -> str:
    """Busca matérias na base de dados da UnB via busca vetorial."""
    print(f"[MCP] ========================================", file=sys.stderr)
    print(f"[MCP] BUSCA INICIADA", file=sys.stderr)
    print(f"[MCP] Interesse recebido: '{interesse}'", file=sys.stderr)
    print(f"[MCP] Tipo: {type(interesse)}, Repr: {repr(interesse)}", file=sys.stderr)
    print(f"[MCP] Encoding: {interesse.encode('utf-8')}", file=sys.stderr)
    print(f"[MCP] ========================================", file=sys.stderr)
    
    try:
        inicializar_sistemas()
        print(f"[MCP] Sistemas inicializados", file=sys.stderr)
    except Exception as e:
        print(f"[MCP] ERRO ao inicializar: {e}", file=sys.stderr)
        return json.dumps([])
    
    # Gera o vetor localmente
    try:
        print(f"[MCP] Gerando embedding para: '{interesse}'", file=sys.stderr)
        print(f"[MCP] Modelo sendo usado: {type(modelo_embedding).__name__}", file=sys.stderr)
        print(f"[MCP] Device: {modelo_embedding.device}", file=sys.stderr)
        
        vetor_pergunta = modelo_embedding.encode(interesse).tolist()
        print(f"[MCP] Embedding gerado: {len(vetor_pergunta)} dimensões", file=sys.stderr)
        print(f"[MCP] Primeiros 5 valores do embedding: {vetor_pergunta[:5]}", file=sys.stderr)
    except Exception as e:
        print(f"[MCP] ERRO ao gerar embedding: {e}", file=sys.stderr)
        return json.dumps([])
    
    try:
        print(f"[MCP] Consultando Supabase...", file=sys.stderr)
        resposta = supabase_client.rpc(
            "match_materias", 
            {
                "query_embedding": vetor_pergunta,
                "match_threshold": 0.3,  # Reduzido de 0.4 para 0.3 para testar
                "match_count": 10         # Aumentado para ver mais resultados
            }
        ).execute()
        
        print(f"[MCP] Supabase respondeu", file=sys.stderr)
        dados = resposta.data or []
        print(f"[MCP] Encontradas {len(dados)} matérias", file=sys.stderr)
        
        if len(dados) > 0:
            print(f"[MCP] Primeira matéria: {dados[0].get('nome_materia')} - Score: {dados[0].get('similaridade', 0):.3f}", file=sys.stderr)
        else:
            print(f"[MCP] Nenhuma matéria acima do threshold de 0.4", file=sys.stderr)
        
        lista_final = []
        for item in dados:
            lista_final.append({
                "Codigo": item.get("codigo_materia"),
                "Materia": item.get("nome_materia"),
                "Departamento": item.get("departamento") or "Não informado",
                "Ementa_Resumida": str(item.get("ementa", ""))[:250] + "...",
                "Score_DB": round(item.get("similaridade", 0), 2)
            })
        
        resultado = json.dumps(lista_final, ensure_ascii=False, indent=2)
        print(f"[MCP] Retornando resultado", file=sys.stderr)
        return resultado
    except Exception as e:
        print(f"[MCP] ERRO na busca Supabase: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        return json.dumps([])

if __name__ == "__main__":
    mcp.run(transport='stdio')
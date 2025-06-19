# check_connection.py
print("--- Iniciando teste de conexão com a API de Agentes RAGflowww ---")

try:
    from config import RAGFLOW_API_KEY, RAGFLOW_BASE_URL, RAGFLOW_AGENT_ID

    if not RAGFLOW_API_KEY or not RAGFLOW_BASE_URL or not RAGFLOW_AGENT_ID:
        print("\nERRO: Variáveis não carregadas. Verifique seu arquivo .env")
    else:
        print("OK: Variáveis de ambiente carregadas.")
        print(f"-> URL Base: {RAGFLOW_BASE_URL}")
        print(f"-> ID do Agente: {RAGFLOW_AGENT_ID}")

    from ragflow_agent_client import RagflowClient
    print("OK: Cliente de Agente Ragflow importado.")

    client = RagflowClient()
    print(f"-> Enviando requisição para o endpoint:")
    
    #response = client.get_completion("Este é um teste de conexão.")

    print("\n--- RESPOSTA RECEBIDA DO SERVIDOR ---")
    #print(response)
    print("-------------------------------------")

except Exception as e:
    print(f"\nERRO INESPERADO: Ocorreu uma exceção durante o teste: {e}")
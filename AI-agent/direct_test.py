# direct_test.py
import requests
import json

print("--- INICIANDO TESTE DIRETO SEM ARQUIVO .ENV ---")

# --- SUAS CREDENCIAIS CORRETAS ESTÃO FIXAS AQUI ---
# Pegue a chave da interface do RAGFlow (⚙️ -> API Setting)
API_KEY      = "ragflow-MyMDYxOTNjNDhhNjExZjBhYWEzZmE3Nj"
# Pegue o ID do seu agente na lista de agentes
AGENT_ID     = "10b20f0248a611f089a9fa761c0fa70c"
BASE_URL     = "http://localhost"
# --------------------------------------------------

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}
endpoint_url = f"{BASE_URL}/api/v1/agents_openai/{AGENT_ID}/chat/completions"

payload = {
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Isto é um teste direto."}],
    "stream": False
}

print(f"Enviando requisição para: {endpoint_url}")
print(f"Usando Agent ID: {AGENT_ID}")

try:
    response = requests.post(endpoint_url, headers=headers, json=payload, timeout=180)
    response.raise_for_status()
    json_data = response.json()
    final_answer = json_data.get("choices", [{}])[0].get("message", {}).get("content", "")

    if final_answer:
        print("\n--- SUCESSO! RESPOSTA RECEBIDA ---")
        print(final_answer.strip())
    else:
        print("\n--- CONEXÃO BEM-SUCEDIDA, MAS SEM CONTEÚDO ---")
        print(f"Resposta completa: {json.dumps(json_data)}")

except requests.exceptions.HTTPError as http_err:
    print(f"\n--- ERRO DE HTTP ---")
    print(f"Status: {http_err.response.status_code}")
    print(f"Resposta do Servidor: {http_err.response.text}")
except Exception as e:
    print(f"\n--- ERRO INESPERADO ---")
    print(e)
# app.py (Versão com Flask)
import unicodedata
from flask import Flask, request, jsonify
from ragflow_agent_client import RagflowClient
from visualizaJsonMateriasAssociadas import gerar_texto_ranking

# --- Funções e Lógica de Negócio (movidas ou importadas) ---

def remover_acentos_nativo(texto: str) -> str:
    """
    Normaliza o texto para o formato NFD, que separa o caractere do acento,
    e depois remove os caracteres de combinação (acentos).
    """
    if not isinstance(texto, str):
        return ""
    texto_normalizado = unicodedata.normalize('NFD', texto)
    texto_sem_acento = "".join(c for c in texto_normalizado if not unicodedata.combining(c))
    return texto_sem_acento

# --- Configuração do Servidor Flask ---

app = Flask(__name__)

# --- Definição do Endpoint da API ---

@app.route('/assistente', methods=['POST'])
def analisar_materia_endpoint():
    """
    Endpoint da API que recebe um JSON com a matéria, a processa
    e retorna o ranking das disciplinas relacionadas.
    """
    # 1. Extrair os dados da requisição
    dados_requisicao = request.get_json()

    if not dados_requisicao or 'materia' not in dados_requisicao:
        return jsonify({"erro": "O campo 'materia' é obrigatório no corpo da requisição JSON."}), 400

    materia_original = dados_requisicao['materia']

    if not materia_original or not materia_original.strip():
        return jsonify({"erro": "O campo 'materia' não pode estar vazio."}), 400

    # 2. Pré-processamento do input (mesma lógica do Streamlit)
    materia_processada = remover_acentos_nativo(materia_original).upper()
    print(f"Matéria Recebida: '{materia_original}' -> Processada como: '{materia_processada}'")

    # 3. Executar a lógica de análise (mesma lógica do Streamlit)
    try:
        client = RagflowClient()
        session_id = client.start_session(materia_processada)
        print(f"Sessão iniciada com ID: {session_id}")
        
        resultado_agente = client.analyze_materia(materia_processada, session_id)
        print(f"Resultado bruto do agente: {resultado_agente}")

        if resultado_agente.get("code") != 0:
            # Se a API do RAGFlow retornar um erro, repassa a mensagem.
            mensagem_erro = resultado_agente.get('message', 'Erro desconhecido na API do agente.')
            print(f"Erro da API RAGFlow: {mensagem_erro}")
            return jsonify({"erro": f"Erro na API do agente: {mensagem_erro}"}), 500

        # 4. Formatar a resposta final
        resposta_formatada = gerar_texto_ranking(resultado_agente)
        print("Resposta formatada gerada com sucesso.")
        
        # 5. Retornar a resposta formatada como JSON
        return jsonify({"resultado": resposta_formatada})

    except Exception as e:
        # Captura qualquer outro erro durante o processo
        print(f"ERRO INESPERADO: {e}")
        return jsonify({"erro": f"Ocorreu um erro interno no servidor: {str(e)}"}), 500

# --- Execução do Servidor ---

if __name__ == '__main__':
    # O host '0.0.0.0' torna o servidor acessível na sua rede local.
    # Para produção, use um servidor WSGI como Gunicorn ou Waitress.
    app.run(host='0.0.0.0', port=5000, debug=True)
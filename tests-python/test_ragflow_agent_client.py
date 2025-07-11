# tests/test_ragflow_agent_client.py
import pytest
import requests
from unittest.mock import MagicMock

# Define as variáveis de configuração antes de importar o cliente
import os
import sys
os.environ['RAGFLOW_API_KEY'] = 'test_key'
os.environ['RAGFLOW_BASE_URL'] = 'http://fake-url.com'
os.environ['RAGFLOW_AGENT_ID'] = 'test_agent'

project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, project_root)

from no_fluxo_backend.ai_agent.ragflow_agent_client import RagflowClient


@pytest.fixture
def client():
    """Fixture que cria uma instância do RagflowClient para os testes."""
    return RagflowClient()


def test_client_initialization(client):
    """Verifica se o cliente é inicializado com os valores corretos."""
    assert client.agent_id == 'test_agent'
    assert client.url == 'http://fake-url.com/api/v1/agents/test_agent/completions'
    assert client.headers["Authorization"] == "Bearer test_key"


def test_analyze_materia_sucesso(client, mocker):
    """
    Testa o método analyze_materia com uma resposta de sucesso simulada da API.
    """
    # Prepara um mock para requests.post
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"code": 0, "data": "sucesso"}
    mocker.patch('requests.post', return_value=mock_response)

    # Executa o método
    resultado = client.analyze_materia("historia", "sessao_123")

    # Verifica se a chamada à API foi feita com os parâmetros corretos
    requests.post.assert_called_once_with(
        client.url,
        headers=client.headers,
        json={"question": "historia", "session_id": "sessao_123", "stream": False},
        timeout=60
    )
    # Verifica o resultado
    assert resultado == {"code": 0, "data": "sucesso"}


def test_analyze_materia_erro_api(client, mocker):
    """
    Testa o método analyze_materia quando a API RAGFlow retorna um erro
    (código diferente de 0).
    """
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"code": 1, "message": "Erro interno do agente"}
    mocker.patch('requests.post', return_value=mock_response)

    resultado = client.analyze_materia("historia", "sessao_123")

    assert resultado["code"] == 1
    assert resultado["message"] == "Erro interno do agente"


def test_analyze_materia_erro_http(client, mocker):
    """
    Testa o tratamento de erros HTTP (ex: 500 Internal Server Error).
    """
    mock_response = MagicMock()
    mock_response.status_code = 500
    mock_response.raise_for_status.side_effect = requests.exceptions.HTTPError("Erro no servidor")
    mocker.patch('requests.post', return_value=mock_response)

    with pytest.raises(requests.exceptions.HTTPError):
        client.analyze_materia("historia", "sessao_123")


def test_analyze_materia_timeout(client, mocker):
    """
    Testa o tratamento de um erro de timeout na requisição.
    """
    mocker.patch('requests.post', side_effect=requests.exceptions.Timeout("A requisição expirou"))

    with pytest.raises(requests.exceptions.Timeout):
        client.analyze_materia("historia", "sessao_123")
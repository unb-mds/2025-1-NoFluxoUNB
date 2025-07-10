# tests/test_ragflow_agent_client.py
"""
Testes unitários para a classe RagflowClient.
"""
import pytest
import requests
from unittest.mock import patch, Mock

from ai_agent.ragflow_agent_client import RagflowClient
from ai_agent.config import RAGFLOW_API_KEY, RAGFLOW_BASE_URL, RAGFLOW_AGENT_ID

@pytest.fixture
def client():
    """Cria uma instância do RagflowClient para os testes."""
    return RagflowClient(agent_id=RAGFLOW_AGENT_ID)

@patch('requests.post')
def test_start_session_success(mock_post, client):
    """
    Testa o método start_session em um cenário de sucesso.
    """
    mock_response = Mock()
    mock_response.status_code = 200
    expected_session_id = "test_session_12345"
    mock_response.json.return_value = {"data": {"session_id": expected_session_id}}
    mock_post.return_value = mock_response

    session_id = client.start_session(materia="Teste de materia")

    expected_url = f"{RAGFLOW_BASE_URL}/api/v1/agents/{RAGFLOW_AGENT_ID}/completions"
    expected_headers = {"Authorization": f"Bearer {RAGFLOW_API_KEY}", "Content-Type": "application/json"}
    expected_json = {"materia": "Teste de materia", "stream": False}

    mock_post.assert_called_once_with(expected_url, headers=expected_headers, json=expected_json)
    assert session_id == expected_session_id

@patch('requests.post')
def test_analyze_materia_success(mock_post, client):
    """
    Testa o método analyze_materia em um cenário de sucesso.
    """
    mock_response = Mock()
    expected_result = {"data": "resultado da analise"}
    mock_response.json.return_value = expected_result
    mock_post.return_value = mock_response

    result = client.analyze_materia(materia="Detalhes", session_id="test_session_12345")

    expected_payload = {"question": "Detalhes", "session_id": "test_session_12345", "stream": False}
    mock_post.assert_called_once_with(client.url, headers=client.headers, json=expected_payload)
    assert result == expected_result

@patch('requests.post')
def test_api_http_error(mock_post, client):
    """
    Testa o tratamento de erros HTTP, verificando se a exceção é propagada.
    """
    mock_response = Mock()
    mock_response.raise_for_status.side_effect = requests.exceptions.HTTPError("404 Not Found")
    mock_post.return_value = mock_response

    with pytest.raises(requests.exceptions.HTTPError):
        client.start_session(materia="qualquer_materia")
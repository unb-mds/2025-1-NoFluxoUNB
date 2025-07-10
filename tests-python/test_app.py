# tests-python/test_app.py
"""
Testes unitários para a aplicação Flask em app.py.
"""
import json
import pytest
from unittest.mock import patch

from ai_agent.app import app, remover_acentos_nativo

# O path para o mock deve ser o caminho absoluto a partir da raiz do projeto
RAGFLOW_CLIENT_PATH = 'ai_agent.app.RagflowClient'

MOCK_AGENT_RESULT = {
    'code': 0,
    'data': {
        'answer': "{'content': {'0': '--- INÍCIO DO RANKING ---\\n1. **Disciplina:** TESTE DE SOFTWARE; Codigo: TSW001; Unidade responsavel: DEPTO TESTE\\n**Pontuação:** 100\\n**Justificativa:** Teste.'}}"
    }
}

@pytest.fixture
def client():
    """Cria e configura um cliente de teste para a aplicação Flask."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_remover_acentos_nativo():
    """Testa a função utilitária de remoção de acentos."""
    assert remover_acentos_nativo("OLÁ MUNDO, Ç, Ã") == "OLA MUNDO, C, A"

@patch(RAGFLOW_CLIENT_PATH)
def test_analisar_materia_endpoint_sucesso(MockRagflowClient, client):
    """
    Testa o endpoint /assistente em um cenário de sucesso com a resposta 200.
    """
    mock_instance = MockRagflowClient.return_value
    mock_instance.start_session.return_value = "fake_session_id"
    mock_instance.analyze_materia.return_value = MOCK_AGENT_RESULT

    response = client.post(
        '/assistente',
        data=json.dumps({'materia': 'Teste de Software'}),
        content_type='application/json'
    )

    assert response.status_code == 200
    data = response.get_json()
    assert 'resultado' in data
    assert 'TESTE DE SOFTWARE' in data['resultado']
    mock_instance.start_session.assert_called_once_with('TESTE DE SOFTWARE')

def test_analisar_materia_endpoint_bad_request(client):
    """
    Testa o endpoint /assistente com requisições inválidas (400).
    """
    response_no_json = client.post('/assistente', content_type='application/json')
    assert response_no_json.status_code == 400

    response_empty_materia = client.post(
        '/assistente',
        data=json.dumps({'materia': ''}),
        content_type='application/json'
    )
    assert response_empty_materia.status_code == 400

@patch(RAGFLOW_CLIENT_PATH)
def test_analisar_materia_endpoint_agent_api_error(MockRagflowClient, client):
    """
    Testa o cenário onde a API do agente retorna um erro (500).
    """
    mock_instance = MockRagflowClient.return_value
    mock_instance.start_session.return_value = "fake_session_id"
    mock_instance.analyze_materia.return_value = {"code": -1, "message": "Erro no agente"}

    response = client.post(
        '/assistente',
        data=json.dumps({'materia': 'teste'}),
        content_type='application/json'
    )

    assert response.status_code == 500
    assert 'Erro na API do agente: Erro no agente' in response.get_json()['erro']

@patch(RAGFLOW_CLIENT_PATH)
def test_analisar_materia_endpoint_internal_server_error(MockRagflowClient, client):
    """
    Testa uma exceção inesperada no servidor (500).
    """
    mock_instance = MockRagflowClient.return_value
    mock_instance.start_session.side_effect = Exception("Falha geral")

    response = client.post(
        '/assistente',
        data=json.dumps({'materia': 'teste'}),
        content_type='application/json'
    )
    assert response.status_code == 500
    assert 'Ocorreu um erro interno no servidor: Falha geral' in response.get_json()['erro']
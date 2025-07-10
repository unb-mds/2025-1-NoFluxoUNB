# tests_python/test_app.py

import sys
import os
import pytest
import json

# 1. Adicionar o diretório raiz do projeto ao sys.path.
#    Subimos um nível ('..') a partir da pasta 'tests_python' para chegar à raiz.
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, project_root)

# 2. Usar importações absolutas a partir da raiz do projeto.
#    Note o novo caminho: 'no_fluxo_backend.ai_agent.app'
from no_fluxo_backend.ai_agent.app import app as flask_app
from no_fluxo_backend.ai_agent.app import remover_acentos_nativo


# --- O restante do seu código de teste permanece o mesmo ---

@pytest.fixture
def app():
    """Cria e configura uma nova instância do app para cada teste."""
    yield flask_app


@pytest.fixture
def client(app):
    """Um cliente de teste para o app."""
    return app.test_client()

# --- Testes de funções auxiliares ---
@pytest.mark.parametrize("entrada, esperado", [
    ("História da África", "Historia da Africa"),
    ("educação", "educacao"),
    ("texto sem acento", "texto sem acento"),
    ("", ""),
])
def test_remover_acentos_nativo(entrada, esperado):
    """Testa a função de remoção de acentos com vários casos."""
    assert remover_acentos_nativo(entrada) == esperado


# --- Testes de Endpoints ---
def test_health_check_endpoints(client):
    """Testa os endpoints de health check ('/' e '/health')."""
    for endpoint in ['/', '/health']:
        response = client.get(endpoint)
        assert response.status_code == 200
        data = response.get_json()
        assert data['status'] == 'healthy'
        assert data['service'] == 'AI Agent'


def test_analisar_materia_endpoint_sucesso(client, mocker):
    """
    Testa o endpoint /assistente em um cenário de sucesso, mockando as
    dependências externas.
    """
    # Mock do RagflowClient
    mock_ragflow_client = mocker.patch('app.RagflowClient').return_value
    mock_ragflow_client.start_session.return_value = "sessao_mock_123"
    mock_ragflow_client.analyze_materia.return_value = {"code": 0, "data": "dados_mock"}

    # Mock da função de formatação
    mocker.patch('app.gerar_texto_ranking', return_value="Ranking formatado com sucesso.")

    # Faz a requisição
    response = client.post(
        '/assistente',
        data=json.dumps({'materia': 'História da África'}),
        content_type='application/json'
    )

    # Verifica a resposta
    assert response.status_code == 200
    data = response.get_json()
    assert data['resultado'] == "Ranking formatado com sucesso."

    # Verifica se os mocks foram chamados
    mock_ragflow_client.start_session.assert_called_once_with('HISTORIA DA AFRICA')
    mock_ragflow_client.analyze_materia.assert_called_once_with(
        'HISTORIA DA AFRICA', 'sessao_mock_123'
    )


@pytest.mark.parametrize("payload, erro_esperado", [
    ({}, "O campo 'materia' é obrigatório"),
    ({'materia': None}, "O campo 'materia' não pode estar vazio."),
    ({'materia': '  '}, "O campo 'materia' não pode estar vazio."),
    ({'disciplina': 'invalido'}, "O campo 'materia' é obrigatório"),
])
def test_analisar_materia_endpoint_bad_request(client, payload, erro_esperado):
    """
    Testa o endpoint /assistente com vários tipos de requisições inválidas (400).
    """
    response = client.post(
        '/assistente',
        data=json.dumps(payload),
        content_type='application/json'
    )
    assert response.status_code == 400
    data = response.get_json()
    assert erro_esperado in data['erro']


def test_analisar_materia_endpoint_erro_api_ragflow(client, mocker):
    """
    Testa o endpoint /assistente quando a API do RAGFlow retorna um erro.
    """
    mock_ragflow_client = mocker.patch('app.RagflowClient').return_value
    mock_ragflow_client.start_session.return_value = "sessao_mock_123"
    mock_ragflow_client.analyze_materia.return_value = {
        "code": 1, "message": "Falha na análise"
    }

    response = client.post(
        '/assistente',
        data=json.dumps({'materia': 'Qualquer Coisa'}),
        content_type='application/json'
    )

    assert response.status_code == 500
    data = response.get_json()
    assert "Erro na API do agente: Falha na análise" in data['erro']


def test_analisar_materia_endpoint_erro_inesperado(client, mocker):
    """
    Testa o endpoint /assistente quando uma exceção inesperada ocorre.
    """
    mocker.patch('app.remover_acentos_nativo', side_effect=Exception("Erro inesperado"))

    response = client.post(
        '/assistente',
        data=json.dumps({'materia': 'Qualquer Coisa'}),
        content_type='application/json'
    )

    assert response.status_code == 500
    data = response.get_json()
    assert "Ocorreu um erro interno no servidor: Erro inesperado" in data['erro']
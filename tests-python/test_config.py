# tests/test_config.py
"""
Testes unitários para o arquivo de configuração config.py.
"""
import pytest
from ai_agent.config import RAGFLOW_API_KEY, RAGFLOW_BASE_URL, RAGFLOW_AGENT_ID

def test_config_variables_are_loaded():
    """
    Testa se as variáveis de configuração do RAGFlow são importadas
    corretamente e não são nulas ou vazias.
    """
    assert RAGFLOW_API_KEY is not None and RAGFLOW_API_KEY != ""
    assert RAGFLOW_BASE_URL is not None and RAGFLOW_BASE_URL != ""
    assert RAGFLOW_AGENT_ID is not None and RAGFLOW_AGENT_ID != ""
    assert isinstance(RAGFLOW_API_KEY, str)
    assert isinstance(RAGFLOW_BASE_URL, str)
    assert isinstance(RAGFLOW_AGENT_ID, str)
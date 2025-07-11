# tests/test_config.py
import os
import importlib
import pytest
import sys

# Importar o módulo config para que possamos recarregá-lo
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, project_root)


from no_fluxo_backend.ai_agent import config


@pytest.fixture
def clean_env(monkeypatch):
    """
    Fixture que limpa as variáveis de ambiente do RAGFlow antes de cada teste.
    """
    monkeypatch.delenv("RAGFLOW_API_KEY", raising=False)
    monkeypatch.delenv("RAGFLOW_BASE_URL", raising=False)
    monkeypatch.delenv("RAGFLOW_AGENT_ID", raising=False)


def test_config_carregamento_sucesso(monkeypatch):
    """
    Testa se as variáveis de configuração são carregadas corretamente quando
    todas as variáveis de ambiente estão definidas.
    """
    monkeypatch.setenv("RAGFLOW_API_KEY", "key_teste")
    monkeypatch.setenv("RAGFLOW_BASE_URL", "url_teste")
    monkeypatch.setenv("RAGFLOW_AGENT_ID", "id_teste")

    # Recarrega o módulo config para aplicar as variáveis de ambiente do patch
    importlib.reload(config)

    assert config.RAGFLOW_API_KEY == "key_teste"
    assert config.RAGFLOW_BASE_URL == "url_teste"
    assert config.RAGFLOW_AGENT_ID == "id_teste"


def test_config_variaveis_ausentes(clean_env, mocker):
    """
    Testa se um ValueError é levantado quando as variáveis de ambiente
    necessárias não estão definidas.
    """
    # Esta linha impede que a função load_dotenv seja executada,
    # garantindo que o .env não seja lido do disco neste teste.
    mocker.patch('dotenv.load_dotenv')


    with pytest.raises(ValueError) as excinfo:
        importlib.reload(config)


    error_msg = str(excinfo.value)
    assert "Missing required configuration variables" in error_msg
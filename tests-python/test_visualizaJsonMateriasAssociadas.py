# tests/test_visualizaJsonMateriasAssociadas.py
import sys
import os

# Adiciona o diretório raiz do projeto ao sys.path
# Sobe um nível ('..') a partir da pasta 'tests-python'.
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, project_root)

import pytest
from no_fluxo_backend.ai_agent.visualizaJsonMateriasAssociadas import (
    gerar_texto_ranking,
)


# Exemplo de JSON válido, extraído do arquivo original.
JSON_VALIDO_COMPLETO = {
    "code": 0,
    "data": {
        "answer": "{'content': {'0': '--- INÍCIO DO RANKING ---\\n\\n1. **Disciplina:** HISTORIA DA AFRICA; "
        "Codigo: HIS0252; Unidade responsavel: DEPTO HISTORIA; "
        "Ementa: Processo historico das sociedades africanas.\\n\\n"
        "**Pontuação:** 100 \\n\\n**Justificativa:** Aborda diretamente o conteúdo.\\n\\n"
        "2. **Disciplina:** LITERATURAS AFRICANAS; Codigo: ILD0206; "
        "Unidade responsavel: INSTITUTO DE LETRAS\\n\\n"
        "**Pontuação:** 80 \\n\\n**Justificativa:** Relevante para o tema.\\n\\n--- FIM DO RANKING ---'}, "
        "'component_id': {'0': 'Generate:TenTreesMix'}}",
        "id": "12345",
        "param": [],
        "reference": {},
        "session_id": "67890",
    },
}

# Exemplo de JSON com o bloco de ranking ausente.
JSON_SEM_RANKING = {
    "data": {"answer": "{'content': {'0': 'Nenhum ranking encontrado.'}}"}
}

# Exemplo de JSON com estrutura inválida.
JSON_MAL_FORMADO = {"data": {"answer": "não é um dicionário"}}


def test_gerar_texto_ranking_sucesso():
    """
    Testa a função com um JSON válido e verifica se a saída Markdown
    contém os elementos esperados.
    """
    resultado = gerar_texto_ranking(JSON_VALIDO_COMPLETO)

    assert "# 🏆 Ranking de Disciplinas" in resultado
    assert "## 🥇 **1º Lugar** - Pontuação: **100/100**" in resultado
    assert "### 📖 **HISTORIA DA AFRICA**" in resultado
    assert "| **Código** | `HIS0252` |" in resultado
    assert "### 📝 **Ementa**" in resultado
    assert "> Processo historico das sociedades africanas." in resultado
    assert "### 💡 **Por que esta disciplina?**" in resultado
    assert "> Aborda diretamente o conteúdo." in resultado
    assert "## 🥈 **2º Lugar** - Pontuação: **80/100**" in resultado
    assert "LITERATURAS AFRICANAS" in resultado
    assert "## 📊 **Resumo da Análise**" in resultado
    assert "| **Total de disciplinas** | 2 |" in resultado
    assert "| **Melhor pontuação** | 100/100 |" in resultado


def test_gerar_texto_ranking_sem_bloco_ranking_retorna_template_vazio():
    """
    Testa se a função, com um JSON sem ranking, retorna o template
    de Markdown formatado, mas sem nenhuma matéria, que é o comportamento atual.
    """
    # Define o JSON de teste que não contém um ranking válido
    JSON_SEM_RANKING = {
        "data": {
            "answer": "{'content': {'0': 'Nenhum ranking foi encontrado para sua busca.'}}"
        }
    }

    resultado = gerar_texto_ranking(JSON_SEM_RANKING)

    # 1. Verifica se o resultado NÃO contém a antiga mensagem de erro.
    assert (
        "Erro: Não foi possível extrair um bloco de ranking válido do JSON."
        not in resultado
    )

    # 2. Verifica se o resultado contém partes chave do template de sucesso.
    assert "# 🏆 Ranking de Disciplinas" in resultado
    assert "## 📊 **Resumo da Análise**" in resultado

    # 3. Verifica especificamente se o total de disciplinas na tabela de resumo é 0.
    #    (Nota: o código atual pode mostrar 1, dependendo da lógica. Ajuste se necessário)
    assert "| **Total de disciplinas** | 0 |" in resultado


def test_gerar_texto_ranking_erro_de_chave():
    """
    Testa a robustez da função contra um KeyError se 'data' ou 'answer'
    estiverem faltando.
    """
    resultado = gerar_texto_ranking({"dados_invalidos": {}})
    assert "Erro ao processar o JSON: 'data'" in resultado


def test_gerar_texto_ranking_erro_de_sintaxe():
    """
    Testa a robustez da função contra um SyntaxError se o 'answer'
    não for um dicionário stringificado válido.
    """
    resultado = gerar_texto_ranking(JSON_MAL_FORMADO)
    assert "Erro ao processar o JSON" in resultado


def test_gerar_texto_ranking_disciplina_sem_ementa():
    """
    Verifica se a disciplina sem ementa no JSON é processada corretamente,
    não exibindo a seção de ementa no Markdown final.
    """
    json_sem_ementa = {
        "data": {
            "answer": "{'content': {'0': 'INÍCIO DO RANKING\\n1. **Disciplina:** GEOGRAFIA; "
            "Codigo: GEA0003; Unidade responsavel: DEPTO GEOGRAFIA\\n"
            "**Pontuação:** 50\\n**Justificativa:** Teste.'}}"
        }
    }
    resultado = gerar_texto_ranking(json_sem_ementa)

    assert "### 📖 **GEOGRAFIA**" in resultado
    assert "| **Código** | `GEA0003` |" in resultado
    assert "### 📝 **Ementa**" not in resultado  # A seção não deve existir
    assert "### 💡 **Por que esta disciplina?**" in resultado
    assert "> Teste." in resultado

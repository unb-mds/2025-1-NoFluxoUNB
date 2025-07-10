# tests/test_visualizaJsonMateriasAssociadas.py
import pytest
from no_fluxo_backend.ai_agent.visualizaJsonMateriasAssociadas import gerar_texto_ranking

# Exemplo de JSON válido, extraído do arquivo original.
JSON_VALIDO_COMPLETO = {
    'code': 0,
    'data': {
        'answer': "{'content': {'0': '--- INÍCIO DO RANKING ---\\n\\n1. **Disciplina:** HISTORIA DA AFRICA; "
                  "Codigo: HIS0252; Unidade responsavel: DEPTO HISTORIA; "
                  "Ementa: Processo historico das sociedades africanas.\\n\\n"
                  "**Pontuação:** 100 \\n\\n**Justificativa:** Aborda diretamente o conteúdo.\\n\\n"
                  "2. **Disciplina:** LITERATURAS AFRICANAS; Codigo: ILD0206; "
                  "Unidade responsavel: INSTITUTO DE LETRAS\\n\\n"
                  "**Pontuação:** 80 \\n\\n**Justificativa:** Relevante para o tema.\\n\\n--- FIM DO RANKING ---'}, "
                  "'component_id': {'0': 'Generate:TenTreesMix'}}",
        'id': '12345',
        'param': [],
        'reference': {},
        'session_id': '67890'
    }
}

# Exemplo de JSON com o bloco de ranking ausente.
JSON_SEM_RANKING = {
    'data': {
        'answer': "{'content': {'0': 'Nenhum ranking encontrado.'}}"
    }
}

# Exemplo de JSON com estrutura inválida.
JSON_MAL_FORMADO = {
    'data': {
        'answer': "não é um dicionário"
    }
}


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


def test_gerar_texto_ranking_sem_bloco_ranking():
    """
    Testa a função com um JSON onde o bloco de ranking não é encontrado.
    """
    resultado = gerar_texto_ranking(JSON_SEM_RANKING)
    assert "Erro: Não foi possível extrair um bloco de ranking válido do JSON." in resultado


def test_gerar_texto_ranking_erro_de_chave():
    """
    Testa a robustez da função contra um KeyError se 'data' ou 'answer'
    estiverem faltando.
    """
    resultado = gerar_texto_ranking({'dados_invalidos': {}})
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
        'data': {
            'answer': "{'content': {'0': 'INÍCIO DO RANKING\\n1. **Disciplina:** GEOGRAFIA; "
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
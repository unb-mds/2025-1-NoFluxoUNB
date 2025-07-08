# tests/test_visualizaJsonMateriasAssociadas.py
"""
Testes unitários para a função de parsing e formatação.
"""
import pytest
from ai_agent.visualizaJsonMateriasAssociadas import gerar_texto_ranking

JSON_SUCESSO = {
    'data': {
        'answer': "{'content': {'0': '--- INÍCIO DO RANKING ---\\n1. **Disciplina:** HISTORIA DA AFRICA; Codigo: HIS0252; Unidade responsavel: DEPTO HISTORIA; Ementa: Ementa de teste.\\n**Pontuação:** 100\\n**Justificativa:** Justificativa de teste.'}}"
    }
}
JSON_FALHA_CHAVE = {'data': {}}
JSON_FALHA_FORMATO = {'data': {'answer': "{'content': {'0': 'Apenas um texto qualquer sem o formato esperado.'}}"}}

def test_gerar_texto_ranking_sucesso():
    """
    Testa a função com um JSON válido e verifica a saída em Markdown.
    """
    resultado = gerar_texto_ranking(JSON_SUCESSO)
    assert "# 🏆 Ranking de Disciplinas" in resultado
    assert "🥇 **1º Lugar** - Pontuação: **100/100**" in resultado
    assert "📖 **HISTORIA DA AFRICA**" in resultado
    assert "| **Código** | `HIS0252` |" in resultado

def test_gerar_texto_ranking_falha_keyerror():
    """
    Testa a função com um JSON onde faltam chaves essenciais.
    """
    resultado = gerar_texto_ranking(JSON_FALHA_CHAVE)
    assert "Erro ao processar o JSON" in resultado

def test_gerar_texto_ranking_falha_formato_interno():
    """
    Testa a função com um JSON onde o conteúdo não contém o bloco de ranking.
    """
    resultado = gerar_texto_ranking(JSON_FALHA_FORMATO)
    assert "Erro: Não foi possível encontrar nenhuma disciplina formatada no ranking." in resultado
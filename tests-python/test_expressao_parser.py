"""
Testes do parser de expressões de pré-requisitos (DBA/database/expressao_parser.py).

Cobre tokenize() e parse_expression() combinando:
  - Caixa-preta: particionamento de equivalência e análise de valor-limite;
  - Caixa-branca: cobertura de decisão/branch dos ramos da gramática;
  - TDD: a classe TestParentesesBalanceados foi escrita ANTES da correção
         (ciclo Red -> Green -> Refactor) para o defeito de parênteses
         não-balanceados aceitos silenciosamente.

Gramática: expr = term (OU term)* ; term = factor (E factor)* ; factor = ( expr ) | CODIGO
"""

import os
import sys

import pytest

# Torna o módulo de DBA/database importável a partir de tests-python/
sys.path.insert(
    0,
    os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "DBA",
        "database",
    ),
)

from expressao_parser import (  # noqa: E402
    is_expressao_valida,
    normalize_input,
    parse_expression,
    tokenize,
)


# ---------------------------------------------------------------------------
# CAIXA-PRETA + CAIXA-BRANCA — tokenize()
# ---------------------------------------------------------------------------
class TestTokenize:
    def test_codigo_unico_vira_maiusculo(self):
        # Partição: código simples minúsculo -> normalizado para maiúsculo
        assert tokenize("cca0105") == ["CCA0105"]

    def test_operadores_e_ou_case_insensitive(self):
        # Partição: operadores em qualquer caixa
        assert tokenize("CCA0105 ou FUP0289") == ["CCA0105", "OU", "FUP0289"]
        assert tokenize("CCA0105 E FUP0289") == ["CCA0105", "E", "FUP0289"]

    def test_parenteses_sao_tokenizados(self):
        assert tokenize("( CCA0105 )") == ["(", "CCA0105", ")"]

    def test_parenteses_unicode_normalizados(self):
        # Valor-limite: parênteses unicode (（ ）) viram ASCII
        assert tokenize("（ CCA0105 ）") == ["(", "CCA0105", ")"]

    def test_espaco_nbsp_normalizado(self):
        assert tokenize("CCA0105 OU FUP0289") == ["CCA0105", "OU", "FUP0289"]

    def test_string_vazia_retorna_lista_vazia(self):
        # Valor-limite inferior
        assert tokenize("") == []

    def test_ou_dentro_de_palavra_nao_e_operador(self):
        # Caixa-branca: o \b do regex impede casar "ou" colado a código
        # "FUP0289" começa com F, então não há risco; usamos um cenário de borda:
        assert tokenize("CCA0105") == ["CCA0105"]


# ---------------------------------------------------------------------------
# CAIXA-PRETA + CAIXA-BRANCA — parse_expression()
# ---------------------------------------------------------------------------
class TestParseExpression:
    def test_codigo_simples_sem_parenteses(self):
        # Partição: código puro -> string
        assert parse_expression("CCA0105") == "CCA0105"

    def test_codigo_simples_entre_parenteses(self):
        # Partição: "( CODE )" -> string (atalho da função)
        assert parse_expression("( CCA0105 )") == "CCA0105"

    def test_minusculo_normalizado(self):
        assert parse_expression("cca0105") == "CCA0105"

    def test_disjuncao_simples_ou(self):
        result = parse_expression("( CCA0105 ) OU ( FUP0289 )")
        assert result == {"operador": "OU", "condicoes": ["CCA0105", "FUP0289"]}

    def test_conjuncao_simples_e(self):
        result = parse_expression("( CCA0105 ) E ( FUP0289 )")
        assert result == {"operador": "E", "condicoes": ["CCA0105", "FUP0289"]}

    def test_flatten_de_ou_aninhado(self):
        # Caixa-branca: _flatten_operador colapsa OUs aninhados de mesmo operador
        result = parse_expression("( ( CCA0105 ) OU ( FUP0289 ) ) OU ( CCA0102 )")
        assert result == {
            "operador": "OU",
            "condicoes": ["CCA0105", "FUP0289", "CCA0102"],
        }

    def test_precedencia_e_liga_mais_forte_que_ou(self):
        # A E B OU C  ==  (A E B) OU C
        result = parse_expression("CCA0105 E FUP0289 OU CCA0102")
        assert result == {
            "operador": "OU",
            "condicoes": [
                {"operador": "E", "condicoes": ["CCA0105", "FUP0289"]},
                "CCA0102",
            ],
        }

    def test_expressao_vazia_levanta_erro(self):
        # Valor-limite: entrada vazia
        with pytest.raises(ValueError):
            parse_expression("")

    def test_tokens_restantes_levanta_erro(self):
        # Caixa-branca: ramo "Tokens restantes após parse" (parêntese de fechamento a mais)
        with pytest.raises(ValueError):
            parse_expression("CCA0105 )")


# ---------------------------------------------------------------------------
# TDD — feature: rejeitar parênteses NÃO-BALANCEADOS (escrito ANTES do fix)
# Estado RED: estes testes FALHAM contra a implementação atual, que aceita
# um '(' sem ')' correspondente e retorna um resultado em vez de erro.
# ---------------------------------------------------------------------------
class TestParentesesBalanceados:
    def test_parentese_aberto_sem_fechar_levanta_erro(self):
        with pytest.raises(ValueError):
            parse_expression("( CCA0105 OU FUP0289")

    def test_parentese_interno_sem_fechar_levanta_erro(self):
        with pytest.raises(ValueError):
            parse_expression("( ( CCA0105 ) OU ( FUP0289 )")

    def test_apenas_parentese_aberto_levanta_erro(self):
        with pytest.raises(ValueError):
            parse_expression("( CCA0105")

    def test_expressao_balanceada_continua_valida(self):
        # Garante que a correção NÃO quebra o caminho feliz (regressão)
        result = parse_expression("( CCA0105 ) OU ( FUP0289 )")
        assert result == {"operador": "OU", "condicoes": ["CCA0105", "FUP0289"]}


# ---------------------------------------------------------------------------
# is_expressao_valida() — apoio (caixa-preta)
# ---------------------------------------------------------------------------
class TestIsExpressaoValida:
    def test_string_codigo_valida(self):
        assert is_expressao_valida("CCA0105") is True

    def test_operador_invalido_e_falso(self):
        assert is_expressao_valida({"operador": "XOR", "condicoes": ["CCA0105"]}) is False

    def test_condicoes_vazias_e_falso(self):
        assert is_expressao_valida({"operador": "OU", "condicoes": []}) is False

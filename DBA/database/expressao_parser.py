"""
Parser de expressão original → expressao_logica (estrutura JSON para JSONB).
Port do DBA/dados/expressao_logica/parse-expressao.ts.

Formato: string (código único) ou {"operador": "OU"|"E", "condicoes": [ExpressaoLogica, ...]}
Ex: "( ( CCA0105 ) OU ( FUP0289 ) OU ( CCA0102 ) )" -> {"operador": "OU", "condicoes": ["CCA0105", "FUP0289", "CCA0102"]}
"""
import re
from typing import Any, List, Union

# Códigos de matérias (ex: MAT0001, EST0023)
CODIGO_MATERIA_REGEX = re.compile(r"[A-Za-z]{2,}\d{3,}")


def normalize_input(expr: str) -> str:
    """Remove espaços especiais, parênteses unicode, normaliza espaços."""
    if not expr:
        return ""
    s = expr.replace("\u00A0", " ")
    s = s.replace("\uFF08", "(").replace("\uFF09", ")")
    s = re.sub(r"\s+", " ", s)
    return s.strip()


def tokenize(expr: str) -> List[str]:
    tokens: List[str] = []
    s = normalize_input(expr)
    i = 0
    while i < len(s):
        if re.match(r"\s", s[i]):
            i += 1
            continue
        if s[i] in "()":
            tokens.append(s[i])
            i += 1
            continue
        rest = s[i:]
        m_ou = re.match(r"^(ou)\b", rest, re.I)
        if m_ou:
            tokens.append("OU")
            i += len(m_ou.group(1))
            continue
        m_e = re.match(r"^(e)\b", rest, re.I)
        if m_e:
            tokens.append("E")
            i += len(m_e.group(1))
            continue
        m_code = CODIGO_MATERIA_REGEX.match(rest)
        if m_code:
            tokens.append(m_code.group(0).upper())
            i += m_code.end()
            continue
        i += 1
    return tokens


def _flatten_operador(node: Any, op: str) -> List[Any]:
    if isinstance(node, str):
        return [node]
    if isinstance(node, dict) and node.get("operador") == op:
        out: List[Any] = []
        for c in node.get("condicoes", []):
            out.extend(_flatten_operador(c, op))
        return out
    return [node]


def _merge_ou(left: Any, right: Any) -> Any:
    left_arr = _flatten_operador(left, "OU")
    right_arr = _flatten_operador(right, "OU")
    condicoes = left_arr + right_arr
    if len(condicoes) == 1:
        return condicoes[0]
    return {"operador": "OU", "condicoes": condicoes}


def _merge_e(left: Any, right: Any) -> Any:
    left_arr = _flatten_operador(left, "E")
    right_arr = _flatten_operador(right, "E")
    condicoes = left_arr + right_arr
    if len(condicoes) == 1:
        return condicoes[0]
    return {"operador": "E", "condicoes": condicoes}


def parse_expression(input_expr: str) -> Union[str, dict]:
    """
    Converte expressao_original em estrutura para expressao_logica (JSONB).
    expr = term (OU term)*; term = factor (E factor)*; factor = ( expr ) | CODIGO
    """
    normalized = normalize_input(input_expr)
    if not normalized:
        raise ValueError("Expressão vazia")

    # Um único código: "( CODE )" ou "CODE"
    single = re.match(r"^\s*\(\s*([A-Za-z]{2,}\d{3,})\s*\)\s*$", normalized)
    if single:
        return single.group(1).upper()
    bare = re.match(r"^\s*([A-Za-z]{2,}\d{3,})\s*$", normalized)
    if bare:
        return bare.group(1).upper()

    tokens = tokenize(normalized)
    if not tokens:
        raise ValueError("Expressão vazia")

    idx = [0]

    def factor() -> Any:
        if idx[0] >= len(tokens):
            raise ValueError(f"Token inesperado na posição {idx[0]}: EOF")
        if tokens[idx[0]] == "(":
            idx[0] += 1
            result = expr()
            if idx[0] < len(tokens) and tokens[idx[0]] == ")":
                idx[0] += 1
            return result
        if CODIGO_MATERIA_REGEX.match(tokens[idx[0]]):
            t = tokens[idx[0]].upper()
            idx[0] += 1
            return t
        raise ValueError(f"Token inesperado na posição {idx[0]}: {tokens[idx[0]]}")

    def term() -> Any:
        left = factor()
        while idx[0] < len(tokens) and tokens[idx[0]] == "E":
            idx[0] += 1
            right = factor()
            left = _merge_e(left, right)
        return left

    def expr() -> Any:
        left = term()
        while idx[0] < len(tokens) and tokens[idx[0]] == "OU":
            idx[0] += 1
            right = term()
            left = _merge_ou(left, right)
        return left

    result = expr()
    if idx[0] < len(tokens):
        raise ValueError(f"Tokens restantes após parse: {' '.join(tokens[idx[0]:])}")
    return result


def is_expressao_valida(obj: Any) -> bool:
    """Verifica se a estrutura já é uma expressão lógica válida (para pular atualização)."""
    if isinstance(obj, str):
        return bool(CODIGO_MATERIA_REGEX.match(obj))
    if isinstance(obj, dict) and "operador" in obj and "condicoes" in obj:
        if obj["operador"] not in ("OU", "E"):
            return False
        cond = obj.get("condicoes")
        if not isinstance(cond, list) or len(cond) == 0:
            return False
        return all(is_expressao_valida(c) for c in cond)
    return False

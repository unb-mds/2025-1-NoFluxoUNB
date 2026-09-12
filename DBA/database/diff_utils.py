"""Diff campo-a-campo para o sync de cursos/matrizes/materias/materias_por_curso.

Regra geral (definida com o time): o JSON local PREENCHE e CORRIGE o banco,
mas NUNCA apaga. Um valor vazio, nulo ou ausente no JSON jamais sobrescreve
um dado ja presente no banco.

Tipos de regra por campo:
  DIFF_STR       texto: troca se o novo (apos strip) nao for vazio e diferir do banco.
  DIFF_STR_FILL  texto, mas so quando o banco esta vazio/nulo (nao "corrige").
  DIFF_CH        carga horaria (int): 0 e None NAO contam como valor; troca se novo > 0 e diferir.
  DIFF_INT       inteiro onde 0 e valido (nivel, tipo_natureza): troca sempre que o novo (nao-nulo) diferir.
  DIFF_JSON      dict/list (jsonb): troca se o novo nao for vazio e diferir do banco.
"""

DIFF_STR = "str"
DIFF_STR_FILL = "str_fill"
DIFF_CH = "ch"
DIFF_INT = "int"
DIFF_JSON = "json"


def _norm_str(v):
    if isinstance(v, str):
        return v.strip()
    if v is None:
        return ""
    return str(v)


def _to_int(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def diff_campos(atual, desejado, regras):
    """Compara `desejado` (derivado do JSON) contra `atual` (linha do banco).

    `regras`: dict {campo: DIFF_*}. Retorna apenas os campos que devem ser
    atualizados como {campo: novo_valor}. Dict vazio significa "nada a fazer".
    """
    mudancas = {}
    for campo, tipo in regras.items():
        novo = desejado.get(campo)
        cur = atual.get(campo)

        if tipo in (DIFF_STR, DIFF_STR_FILL):
            novo_n = _norm_str(novo)
            if novo_n == "":
                continue
            cur_n = _norm_str(cur)
            if tipo == DIFF_STR_FILL and cur_n != "":
                continue
            if cur_n != novo_n:
                mudancas[campo] = novo_n

        elif tipo == DIFF_CH:
            n = _to_int(novo)
            if n is None or n <= 0:
                continue
            if _to_int(cur) != n:
                mudancas[campo] = n

        elif tipo == DIFF_INT:
            if novo is None:
                continue
            if cur != novo:
                mudancas[campo] = novo

        elif tipo == DIFF_JSON:
            if not novo:
                continue
            if cur != novo:
                mudancas[campo] = novo

        else:
            raise ValueError(f"regra de diff desconhecida: {tipo!r}")

    return mudancas

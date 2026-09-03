#!/usr/bin/env python3
"""Testes do diff campo-a-campo (diff_utils.diff_campos).

Rodar sem dependencias:
  cd DBA/database
  python test_diff_campos.py
"""

from diff_utils import (
    DIFF_CH,
    DIFF_INT,
    DIFF_JSON,
    DIFF_STR,
    DIFF_STR_FILL,
    diff_campos,
)

falhas = []


def check(nome, cond):
    if cond:
        print(f"  ok  {nome}")
    else:
        print(f"  FALHA  {nome}")
        falhas.append(nome)


# ---------------------------------------------------------------------------
# DIFF_STR: preenche e corrige, mas nunca apaga
# ---------------------------------------------------------------------------
r = {"nome_materia": DIFF_STR}

check(
    "str: banco nulo, json com valor -> preenche",
    diff_campos({"nome_materia": None}, {"nome_materia": "CALCULO 1"}, r)
    == {"nome_materia": "CALCULO 1"},
)
check(
    "str: valores diferentes -> corrige",
    diff_campos({"nome_materia": "CALC 1"}, {"nome_materia": "CALCULO 1"}, r)
    == {"nome_materia": "CALCULO 1"},
)
check(
    "str: json vazio nao apaga banco",
    diff_campos({"nome_materia": "CALCULO 1"}, {"nome_materia": ""}, r) == {},
)
check(
    "str: json ausente nao apaga banco",
    diff_campos({"nome_materia": "CALCULO 1"}, {}, r) == {},
)
check(
    "str: iguais a menos de espacos -> nada",
    diff_campos({"nome_materia": "CALCULO 1"}, {"nome_materia": "  CALCULO 1 "}, r)
    == {},
)

# ---------------------------------------------------------------------------
# DIFF_STR_FILL: so quando o banco esta vazio
# ---------------------------------------------------------------------------
rf = {"nome_materia": DIFF_STR_FILL}

check(
    "str_fill: banco vazio -> preenche",
    diff_campos({"nome_materia": ""}, {"nome_materia": "NOME NOVO"}, rf)
    == {"nome_materia": "NOME NOVO"},
)
check(
    "str_fill: banco ja tem valor -> nao mexe mesmo diferente",
    diff_campos({"nome_materia": "Nome Antigo"}, {"nome_materia": "NOME NOVO"}, rf)
    == {},
)

# ---------------------------------------------------------------------------
# DIFF_CH: carga horaria; 0/None nao contam como valor
# ---------------------------------------------------------------------------
rc = {"ch_maxima_componentes_eletivos": DIFF_CH}

check(
    "ch: banco nulo, json 600 -> preenche (coluna nova)",
    diff_campos(
        {"ch_maxima_componentes_eletivos": None},
        {"ch_maxima_componentes_eletivos": 600},
        rc,
    )
    == {"ch_maxima_componentes_eletivos": 600},
)
check(
    "ch: json 0 nao apaga banco",
    diff_campos(
        {"ch_maxima_componentes_eletivos": 600},
        {"ch_maxima_componentes_eletivos": 0},
        rc,
    )
    == {},
)
check(
    "ch: json None nao apaga banco",
    diff_campos(
        {"ch_maxima_componentes_eletivos": 600},
        {"ch_maxima_componentes_eletivos": None},
        rc,
    )
    == {},
)
check(
    "ch: string '1680' vira int e compara",
    diff_campos({"ch_total_exigida": 1680}, {"ch_total_exigida": "1680"}, {"ch_total_exigida": DIFF_CH})
    == {},
)
check(
    "ch: valor diferente -> corrige",
    diff_campos({"ch_total_exigida": 1500}, {"ch_total_exigida": 1680}, {"ch_total_exigida": DIFF_CH})
    == {"ch_total_exigida": 1680},
)

# ---------------------------------------------------------------------------
# DIFF_INT: nivel / tipo_natureza -> 0 e valido, sobrescreve sempre que diferir
# ---------------------------------------------------------------------------
ri = {"nivel": DIFF_INT, "tipo_natureza": DIFF_INT}

check(
    "int: nivel diferente -> sobrescreve",
    diff_campos({"nivel": 3, "tipo_natureza": 0}, {"nivel": 4, "tipo_natureza": 0}, ri)
    == {"nivel": 4},
)
check(
    "int: nivel 0 sobrescreve nivel existente (regra do usuario)",
    diff_campos({"nivel": 5, "tipo_natureza": 1}, {"nivel": 0, "tipo_natureza": 1}, ri)
    == {"nivel": 0},
)
check(
    "int: tipo_natureza 1->0 sobrescreve",
    diff_campos({"nivel": 2, "tipo_natureza": 1}, {"nivel": 2, "tipo_natureza": 0}, ri)
    == {"tipo_natureza": 0},
)
check(
    "int: iguais -> nada",
    diff_campos({"nivel": 2, "tipo_natureza": 0}, {"nivel": 2, "tipo_natureza": 0}, ri)
    == {},
)
check(
    "int: json None nao apaga",
    diff_campos({"nivel": 2}, {"nivel": None}, {"nivel": DIFF_INT}) == {},
)

# ---------------------------------------------------------------------------
# DIFF_JSON: formatura (dict {minimo, medio, maximo})
# ---------------------------------------------------------------------------
rj = {"formatura": DIFF_JSON}

check(
    "json: banco nulo, json com dict -> preenche (coluna nova)",
    diff_campos(
        {"formatura": None}, {"formatura": {"minimo": 8, "medio": 8, "maximo": 16}}, rj
    )
    == {"formatura": {"minimo": 8, "medio": 8, "maximo": 16}},
)
check(
    "json: dict igual (ordem diferente) -> nada",
    diff_campos(
        {"formatura": {"maximo": 16, "minimo": 8, "medio": 8}},
        {"formatura": {"minimo": 8, "medio": 8, "maximo": 16}},
        rj,
    )
    == {},
)
check(
    "json: dict diferente -> corrige",
    diff_campos(
        {"formatura": {"minimo": 8, "medio": 8, "maximo": 16}},
        {"formatura": {"minimo": 8, "medio": 10, "maximo": 18}},
        rj,
    )
    == {"formatura": {"minimo": 8, "medio": 10, "maximo": 18}},
)
check(
    "json: json vazio nao apaga banco",
    diff_campos(
        {"formatura": {"minimo": 8, "medio": 8, "maximo": 16}}, {"formatura": {}}, rj
    )
    == {},
)
check(
    "json: json ausente nao apaga banco",
    diff_campos({"formatura": {"minimo": 8}}, {}, rj) == {},
)

# ---------------------------------------------------------------------------
# Varios campos de uma vez: so volta o que mudou
# ---------------------------------------------------------------------------
regras_matriz = {
    "ch_obrigatoria_exigida": DIFF_CH,
    "ch_optativa_exigida": DIFF_CH,
    "ch_total_exigida": DIFF_CH,
    "ch_complementar_exigida": DIFF_CH,
    "ch_maxima_componentes_eletivos": DIFF_CH,
    "formatura": DIFF_JSON,
}
atual = {
    "ch_obrigatoria_exigida": 1680,
    "ch_optativa_exigida": 1320,
    "ch_total_exigida": 3000,
    "ch_complementar_exigida": None,
    "ch_maxima_componentes_eletivos": None,
    "formatura": None,
}
desejado = {
    "ch_obrigatoria_exigida": 1680,
    "ch_optativa_exigida": 1320,
    "ch_total_exigida": 3000,
    "ch_complementar_exigida": 0,
    "ch_maxima_componentes_eletivos": 600,
    "formatura": {"minimo": 8, "medio": 8, "maximo": 16},
}
check(
    "matriz: backfill so das colunas novas (complementar 0 fica de fora)",
    diff_campos(atual, desejado, regras_matriz)
    == {
        "ch_maxima_componentes_eletivos": 600,
        "formatura": {"minimo": 8, "medio": 8, "maximo": 16},
    },
)

print()
if falhas:
    print(f"{len(falhas)} teste(s) falharam.")
    raise SystemExit(1)
print("Todos os testes passaram.")

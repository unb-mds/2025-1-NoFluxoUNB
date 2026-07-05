"""Testes das funções puras de parsing de tool call (sem dependências externas).

Executar: python test_tool_call_utils.py
"""

from tool_call_utils import extrair_tool_call_texto, termo_materia


def test_extrai_tool_call_wrapper():
    # O caso real do bug reportado: a tool call vazou como texto.
    content = (
        '<tool_call>\n'
        '{"name": "buscar_materias_unb", "arguments": {"termos_busca": ["ENE0274"]}}\n'
        '</tool_call>'
    )
    nome, args = extrair_tool_call_texto(content)
    assert nome == "buscar_materias_unb", nome
    assert args == {"termos_busca": ["ENE0274"]}, args


def test_extrai_explicar_materia():
    content = '<tool_call>{"name": "explicar_materia", "arguments": {"materia": "Fundamentos de Redes"}}</tool_call>'
    nome, args = extrair_tool_call_texto(content)
    assert nome == "explicar_materia"
    assert args == {"materia": "Fundamentos de Redes"}


def test_extrai_json_puro_sem_wrapper():
    content = 'Claro! {"name": "explicar_materia", "arguments": {"materia": "Calculo 1"}}'
    nome, args = extrair_tool_call_texto(content)
    assert nome == "explicar_materia"
    assert args == {"materia": "Calculo 1"}


def test_arguments_como_string():
    content = '<tool_call>{"name": "buscar_materias_unb", "arguments": "{\\"termos_busca\\": [\\"IA\\"]}"}</tool_call>'
    nome, args = extrair_tool_call_texto(content)
    assert nome == "buscar_materias_unb"
    assert args == {"termos_busca": ["IA"]}


def test_texto_normal_nao_e_tool_call():
    assert extrair_tool_call_texto("Aqui estão suas disciplinas recomendadas.") is None
    assert extrair_tool_call_texto("") is None
    assert extrair_tool_call_texto(None) is None


def test_json_invalido_retorna_none():
    assert extrair_tool_call_texto('<tool_call>{name: quebrado}</tool_call>') is None


def test_termo_materia_variacoes():
    assert termo_materia({"materia": "Redes"}) == "Redes"
    assert termo_materia({"termo": " Cálculo 1 "}) == "Cálculo 1"
    assert termo_materia({"termos_busca": ["Física 1", "outro"]}) == "Física 1"
    assert termo_materia({"termos_busca": []}) == ""
    assert termo_materia({}) == ""


if __name__ == "__main__":
    testes = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    falhas = 0
    for t in testes:
        try:
            t()
            print(f"PASS  {t.__name__}")
        except AssertionError as e:
            falhas += 1
            print(f"FAIL  {t.__name__}: {e}")
        except Exception as e:  # noqa: BLE001
            falhas += 1
            print(f"ERROR {t.__name__}: {type(e).__name__}: {e}")
    print(f"\n{len(testes) - falhas}/{len(testes)} testes passaram")
    raise SystemExit(1 if falhas else 0)

"""
Utilitários puros (sem efeitos colaterais) para lidar com tool calls do Darcy.

Alguns modelos da Maritaca às vezes emitem a chamada de ferramenta como TEXTO
no conteúdo da mensagem (ex: "<tool_call>{...}</tool_call>") em vez de preencher
o campo estruturado `tool_calls`. Sem tratamento, esse texto cru vaza direto para
o usuário. As funções abaixo detectam e normalizam esse caso.
"""

import json
import re


def extrair_tool_call_texto(content: str):
    """Extrai uma tool call embutida no texto da resposta do modelo.

    Trata o caso em que o modelo devolve algo como
    ``<tool_call>{"name": "buscar_materias_unb", "arguments": {...}}</tool_call>``
    (ou apenas o JSON) no lugar do campo estruturado ``tool_calls``.

    Retorna ``(nome, args)`` quando encontra uma chamada válida, ou ``None``.
    """
    if not content:
        return None

    # 1. Formato mais comum observado: <tool_call>{...}</tool_call>
    match = re.search(r"<tool_call>\s*(\{.*?\})\s*</tool_call>", content, re.DOTALL)
    raw = match.group(1) if match else None

    # 2. Fallback: pega o primeiro objeto JSON que contenha "name"
    if raw is None and '"name"' in content:
        start = content.find("{")
        end = content.rfind("}")
        if start != -1 and end > start:
            raw = content[start : end + 1]

    if not raw:
        return None

    try:
        parsed = json.loads(raw)
    except (ValueError, TypeError):
        return None

    if not isinstance(parsed, dict):
        return None

    nome = parsed.get("name")
    if not nome:
        return None

    args = parsed.get("arguments", {})
    if isinstance(args, str):
        try:
            args = json.loads(args)
        except (ValueError, TypeError):
            args = {}
    if not isinstance(args, dict):
        args = {}

    return nome, args


def termo_materia(args: dict) -> str:
    """Normaliza o termo da disciplina a partir dos argumentos da tool call.

    Aceita ``materia``/``termo`` (string) ou ``termos_busca`` (lista), pois o
    modelo pode variar o nome do campo.
    """
    termo = args.get("materia") or args.get("termo") or args.get("termos_busca") or ""
    if isinstance(termo, list):
        termo = termo[0] if termo else ""
    return str(termo).strip()

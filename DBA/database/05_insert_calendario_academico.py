#!/usr/bin/env python3
"""
Fase 5: Inserir/atualizar os períodos letivos na tabela
public.calendario_academico a partir de:
DBA/dados/calendario-academico-graduacao.json

Esse JSON é produzido por DBA/scraping/scraping_calendario_academico.py, que
extrai os períodos regulares (.1 e .2) do calendário da SAA.

Regras:
- Chave: periodo (ex.: "2026.1"). UPSERT com on_conflict="periodo".
- As datas do JSON vêm em DD/MM/YYYY (formato BR) e são convertidas para
  YYYY-MM-DD (a coluna é date).
- limite_matricula_25pct NÃO é enviada: é coluna GENERATED ALWAYS, o Postgres
  rejeita escrita explícita. O banco a recalcula sozinho a cada UPDATE.
- Linha inválida (período fora do padrão, data_fim <= data_inicio) é reportada
  e pulada -- não derruba a rodada inteira.
- Mudança de data em período já existente é impressa no log: o CEPE revisa
  calendário, e isso desloca o limite de matrícula de todo mundo.

Uso:
  cd DBA/database
  python -m pip install -r requirements.txt   # instalar dependências
  python 05_insert_calendario_academico.py [--dry-run] [--json CAMINHO]
"""

import argparse
import json
import sys
import time
from datetime import datetime
from pathlib import Path

from supabase import create_client
from tenacity import retry, stop_after_attempt, wait_exponential

from config import DBA_ROOT, SUPABASE_URL, SUPABASE_KEY

JSON_PADRAO = DBA_ROOT / "dados" / "calendario-academico-graduacao.json"

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


def reconectar():
    global supabase
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


@retry(stop=stop_after_attempt(5), wait=wait_exponential(multiplier=1, min=2, max=15))
def db(op, *args, **kwargs):
    try:
        return op(*args, **kwargs)
    except Exception as e:
        err = str(e).lower()
        if any(k in err for k in ["connection", "timeout", "network", "socket"]):
            reconectar()
            time.sleep(3)
            raise
        reconectar()
        time.sleep(2)
        raise


def data_br_para_iso(texto):
    """'18/07/2026' -> '2026-07-18'. Levanta ValueError se não casar."""
    return datetime.strptime(texto.strip(), "%d/%m/%Y").date().isoformat()


def validar(item):
    """
    Valida um item do JSON e devolve a linha pronta para o upsert.
    Levanta ValueError com a razão quando a linha não presta.
    """
    periodo = str(item.get("periodo", "")).strip()
    if len(periodo) != 6 or periodo[4] != "." or periodo[5] not in "12":
        raise ValueError(f"periodo fora do padrão AAAA.[12]: {periodo!r}")
    if not periodo[:4].isdigit():
        raise ValueError(f"ano não numérico em periodo: {periodo!r}")

    ano = item.get("ano")
    if not isinstance(ano, int):
        raise ValueError(f"ano ausente ou não inteiro: {ano!r}")
    if str(ano) != periodo[:4]:
        raise ValueError(f"ano {ano} não bate com o periodo {periodo!r}")

    data_inicio = data_br_para_iso(item["data_inicio"])
    data_fim = data_br_para_iso(item["data_fim"])
    if data_fim <= data_inicio:
        raise ValueError(f"data_fim {data_fim} não é posterior a data_inicio {data_inicio}")

    return {
        "periodo": periodo,
        "ano": ano,
        "data_inicio": data_inicio,
        "data_fim": data_fim,
        "texto_bruto": (item.get("texto_bruto") or "").strip() or None,
        # limite_matricula_25pct é GENERATED -- nunca enviar.
    }


def carregar_json(caminho):
    if not caminho.is_file():
        print(
            f"[ERRO] JSON não encontrado: {caminho}\n"
            "       Rode antes: cd DBA/scraping && python scraping_calendario_academico.py",
            file=sys.stderr,
        )
        sys.exit(1)

    with open(caminho, encoding="utf-8") as f:
        dados = json.load(f)

    if not isinstance(dados, list):
        print(f"[ERRO] Esperava uma lista no JSON, veio {type(dados).__name__}.", file=sys.stderr)
        sys.exit(1)
    return dados


def buscar_existentes():
    """periodo -> linha do que já está no banco, ordenado por período."""
    res = db(
        supabase.table("calendario_academico")
        .select("periodo, data_inicio, data_fim, limite_matricula_25pct")
        .order("periodo")
        .execute
    )
    return {row["periodo"]: row for row in (res.data or [])}


def main():
    parser = argparse.ArgumentParser(
        description="Carrega os períodos letivos da UnB em public.calendario_academico."
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--json",
        default=None,
        help=f"Caminho do JSON do calendário. Default: {JSON_PADRAO}",
    )
    args = parser.parse_args()

    caminho = Path(args.json).resolve() if args.json else JSON_PADRAO

    print("Fase 5: Calendário acadêmico")
    print(f"  origem: {caminho}")
    if args.dry_run:
        print("  [DRY-RUN] Nenhuma alteração será persistida.")
    print(flush=True)

    dados = carregar_json(caminho)

    linhas = []
    invalidas = 0
    for item in dados:
        try:
            linhas.append(validar(item))
        except (ValueError, KeyError, TypeError) as e:
            invalidas += 1
            print(f"  [PULADO] {item!r}: {e}")

    if not linhas:
        print("[ERRO] Nenhum período válido no JSON — nada a fazer.", file=sys.stderr)
        sys.exit(1)

    existentes = buscar_existentes()

    novos, alterados, iguais = [], [], 0
    for linha in linhas:
        atual = existentes.get(linha["periodo"])
        if atual is None:
            novos.append(linha)
        elif (
            atual["data_inicio"] != linha["data_inicio"]
            or atual["data_fim"] != linha["data_fim"]
        ):
            alterados.append((atual, linha))
        else:
            iguais += 1

    print(f"  Períodos no JSON: {len(linhas)} (inválidos ignorados: {invalidas})")
    print(f"  Já no banco e sem mudança: {iguais}")

    for linha in novos:
        print(f"  [NOVO] {linha['periodo']}: {linha['data_inicio']} a {linha['data_fim']}")

    # Mudança de data desloca o limite de matrícula -- precisa ser visível.
    for atual, linha in alterados:
        print(
            f"  [MUDOU] {linha['periodo']}: "
            f"{atual['data_inicio']} a {atual['data_fim']}  ->  "
            f"{linha['data_inicio']} a {linha['data_fim']}"
        )

    if not novos and not alterados:
        print("\n  Nada a gravar — calendário já está em dia.")
        return

    if args.dry_run:
        print(f"\n  [DRY-RUN] {len(novos) + len(alterados)} período(s) seriam gravados.")
        return

    # Volume é de meia dúzia de linhas: um único lote, sem chunking.
    db(
        supabase.table("calendario_academico")
        .upsert(linhas, on_conflict="periodo")
        .execute
    )
    print(f"\n  {len(novos)} novo(s), {len(alterados)} atualizado(s).")

    print("\n  Calendário no banco (limite de matrícula = 25% do período, calculado pelo Postgres):")
    for row in buscar_existentes().values():
        print(
            f"    {row['periodo']}: {row['data_inicio']} a {row['data_fim']}"
            f"  | matrícula até {row['limite_matricula_25pct']}"
        )


if __name__ == "__main__":
    main()

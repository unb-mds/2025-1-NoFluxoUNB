#!/usr/bin/env python3
"""
Fase 2: Inserir pré-requisitos, co-requisitos e equivalências a partir de
DBA/dados/materias (turmas_depto_*.json). Só insere se ainda não existir.

- expressao_original: texto da fonte (ex: "( ( CCA0105 ) OU ( FUP0289 ) )").
- expressao_logica: JSONB gerado pelo parser (ex: {"operador": "OU", "condicoes": ["CCA0105", "FUP0289"]}).
- Equivalências genéricas: id_curso e curriculo nulos.
- Equivalências específicas: id_curso = código do currículo (ex: 8150); curriculo = "8150/-4 - 2014.1"; data_vigencia.

Uso:
  cd DBA/database
  python 02_insert_pre_requisitos_equivalencias.py [--dry-run]
"""

import json
import re
import sys
import time
from datetime import date
from pathlib import Path

from supabase import create_client
from tenacity import retry, stop_after_attempt, wait_exponential

from config import PASTA_MATERIAS, SUPABASE_URL, SUPABASE_KEY
from expressao_parser import parse_expression

DRY_RUN = "--dry-run" in sys.argv
CHUNK_SIZE = 200  # tamanho do lote para batch insert
FETCH_PAGE = 2000  # quantos registros buscar por vez ao carregar caches

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# Chaves já existentes no banco (evita SELECT por registro)
SET_PRE = set()   # (id_materia, expressao_original)
SET_CO = set()    # (id_materia, expressao_original)
SET_EQUI = set()  # (id_materia, expressao_original, id_curso ou None, curriculo ou "")


def reconectar():
    global supabase
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


@retry(stop=stop_after_attempt(5), wait=wait_exponential(multiplier=1, min=2, max=15))
def db(op, *args, **kwargs):
    try:
        return op(*args, **kwargs)
    except Exception as e:
        err = str(e).lower()
        if "duplicate key" in err or "23505" in err:
            raise
        if any(k in err for k in ["connection", "timeout", "network", "socket"]):
            reconectar()
            time.sleep(3)
            raise
        reconectar()
        time.sleep(2)
        raise


def expr_vazia(val):
    """Considera vazia: None, "", "-" (traço sozinho)."""
    if val is None:
        return True
    s = (val or "").strip()
    return s == "" or s == "-"


def extrair_codigo_base(curriculo_str):
    """'8150/-4 - 2014.1' -> 8150."""
    if not curriculo_str or not isinstance(curriculo_str, str):
        return None
    s = curriculo_str.strip().split(" - ")[0].strip()
    if "/" in s:
        base = s.split("/", 1)[0].strip()
        return int(base) if base.isdigit() else None
    return int(s) if s.isdigit() else None


def periodo_to_date(periodo):
    """'2006.1' -> 2006-01-01; '2006.2' -> 2006-07-01."""
    if not periodo or not re.match(r"^\d{4}\.[12]$", str(periodo).strip()):
        return None
    ano, sem = str(periodo).strip().split(".")
    return date(int(ano), 1 if sem == "1" else 7, 1)


# ---------------------------------------------------------------------------
# Cache: codigo_materia -> id_materia; curriculo_completo -> id_curso; id_curso válidos (FK)
# ---------------------------------------------------------------------------
CACHE_ID_MATERIA = {}
CACHE_CURRICULO_ID_CURSO = {}
SET_ID_CURSOS_VALIDOS = set()  # id_curso que existem em cursos (evita FK ao inserir equivalências)


def load_cache_materias():
    res = db(supabase.table("materias").select("codigo_materia, id_materia").execute)
    for r in res.data or []:
        if r.get("codigo_materia"):
            CACHE_ID_MATERIA[r["codigo_materia"]] = r["id_materia"]


def load_cache_curriculo_id_curso():
    """Matrizes: curriculo_completo -> id_curso (para equivalências específicas)."""
    res = db(supabase.table("matrizes").select("curriculo_completo, id_curso").execute)
    for r in res.data or []:
        cc = (r.get("curriculo_completo") or "").strip()
        if cc:
            CACHE_CURRICULO_ID_CURSO[cc] = r.get("id_curso")


def load_cache_id_cursos_validos():
    """Carrega id_curso existentes em cursos (para não violar FK em equivalencias)."""
    offset = 0
    while True:
        r = db(supabase.table("cursos").select("id_curso").range(offset, offset + FETCH_PAGE - 1).execute)
        for row in r.data or []:
            i = row.get("id_curso")
            if i is not None:
                SET_ID_CURSOS_VALIDOS.add(i)
        if len(r.data or []) < FETCH_PAGE:
            break
        offset += FETCH_PAGE


def id_curso_from_curriculo(curriculo_str):
    """De '8150/-4 - 2014.1' retorna id_curso (8150) se existir em cursos; senão None."""
    if not curriculo_str:
        return None
    cc = (curriculo_str or "").strip()
    if cc in CACHE_CURRICULO_ID_CURSO:
        return CACHE_CURRICULO_ID_CURSO[cc]
    id_c = extrair_codigo_base(cc)
    if id_c is not None and id_c in SET_ID_CURSOS_VALIDOS:
        return id_c
    return None


def _chave_equi(id_materia, expressao_original, id_curso, curriculo):
    """Chave única para equivalência (hashable)."""
    return (id_materia, expressao_original, id_curso, (curriculo or "")[:500])


# ---------------------------------------------------------------------------
# Carregar existentes no banco (uma vez no início)
# ---------------------------------------------------------------------------
def load_cache_pre_requisitos():
    offset = 0
    while True:
        r = db(
            supabase.table("pre_requisitos")
            .select("id_materia, expressao_original")
            .range(offset, offset + FETCH_PAGE - 1)
            .execute
        )
        for row in r.data or []:
            SET_PRE.add((row["id_materia"], (row.get("expressao_original") or "")))
        if len(r.data or []) < FETCH_PAGE:
            break
        offset += FETCH_PAGE


def load_cache_co_requisitos():
    offset = 0
    while True:
        r = db(
            supabase.table("co_requisitos")
            .select("id_materia, expressao_original")
            .range(offset, offset + FETCH_PAGE - 1)
            .execute
        )
        for row in r.data or []:
            SET_CO.add((row["id_materia"], (row.get("expressao_original") or "")))
        if len(r.data or []) < FETCH_PAGE:
            break
        offset += FETCH_PAGE


def load_cache_equivalencias():
    offset = 0
    while True:
        r = db(
            supabase.table("equivalencias")
            .select("id_materia, expressao_original, id_curso, curriculo")
            .range(offset, offset + FETCH_PAGE - 1)
            .execute
        )
        for row in r.data or []:
            SET_EQUI.add(
                _chave_equi(
                    row["id_materia"],
                    row.get("expressao_original") or "",
                    row.get("id_curso"),
                    row.get("curriculo"),
                )
            )
        if len(r.data or []) < FETCH_PAGE:
            break
        offset += FETCH_PAGE


# ---------------------------------------------------------------------------
# Inserção em lote: acumula em listas e grava a cada CHUNK_SIZE
# ---------------------------------------------------------------------------
def _flush_pre(lote):
    if not lote or DRY_RUN:
        return len(lote)
    try:
        db(supabase.table("pre_requisitos").insert(lote).execute)
        return len(lote)
    except Exception:
        n = 0
        for row in lote:
            try:
                supabase.table("pre_requisitos").insert(row).execute()
                n += 1
            except Exception:
                pass
        if n < len(lote):
            print(f"    [pre] lote parcial: {n}/{len(lote)} inseridos.", flush=True)
        return n


def _flush_co(lote):
    if not lote or DRY_RUN:
        return len(lote)
    try:
        db(supabase.table("co_requisitos").insert(lote).execute)
        return len(lote)
    except Exception:
        n = 0
        for row in lote:
            try:
                supabase.table("co_requisitos").insert(row).execute()
                n += 1
            except Exception:
                pass
        if n < len(lote):
            print(f"    [co] lote parcial: {n}/{len(lote)} inseridos.", flush=True)
        return n


def _flush_equi(lote):
    if not lote or DRY_RUN:
        return len(lote)
    try:
        db(supabase.table("equivalencias").insert(lote).execute)
        return len(lote)
    except Exception:
        # Fallback: insere linha a linha, uma tentativa por linha (sem retry) para não travar
        n = 0
        for row in lote:
            try:
                supabase.table("equivalencias").insert(row).execute()
                n += 1
            except Exception:
                pass
        if n < len(lote):
            print(f"    [equi] lote parcial: {n}/{len(lote)} inseridos.", flush=True)
        return n


# ---------------------------------------------------------------------------
# Listar turmas (turmas_depto_*.json)
# ---------------------------------------------------------------------------
def listar_arquivos_turmas():
    if not PASTA_MATERIAS.is_dir():
        return []
    return sorted(PASTA_MATERIAS.glob("turmas_depto_*.json"))


def main():
    print("Fase 2: Pré-requisitos, Co-requisitos e Equivalências")
    print(f"Fonte: {PASTA_MATERIAS} (turmas_depto_*.json)")
    print("Expressão lógica: parser em expressao_parser.py (port de parse-expressao.ts)")
    if DRY_RUN:
        print(" [DRY-RUN] Nenhuma alteração será persistida.")
    print()

    load_cache_materias()
    load_cache_curriculo_id_curso()
    load_cache_id_cursos_validos()
    print(f"[Cache] {len(CACHE_ID_MATERIA)} matérias; {len(CACHE_CURRICULO_ID_CURSO)} matrizes; {len(SET_ID_CURSOS_VALIDOS)} cursos (id_curso válidos para FK).")

    print("Carregando pré-requisitos, co-requisitos e equivalências já existentes no banco...", flush=True)
    load_cache_pre_requisitos()
    load_cache_co_requisitos()
    load_cache_equivalencias()
    print(f"[Cache] existentes: pre={len(SET_PRE)}, co={len(SET_CO)}, equi={len(SET_EQUI)}.", flush=True)

    arquivos = listar_arquivos_turmas()
    print(f"Arquivos: {len(arquivos)} (inserção em lotes de {CHUNK_SIZE})")
    if not arquivos:
        print("Nenhum turmas_depto_*.json encontrado.")
        return

    list_pre = []
    list_co = []
    list_equi = []
    total_pre = 0
    total_co = 0
    total_equi = 0
    total_equi_esp = 0
    erros_parse = 0
    total_arquivos = len(arquivos)

    PROGRESSO_TURMAS = 400  # a cada N turmas imprime um ponto para não parecer travado
    for idx_arq, arq in enumerate(arquivos):
        n = idx_arq + 1
        print(f"  [{n}/{total_arquivos}] {arq.name}...", flush=True)
        try:
            turmas = json.loads(arq.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"  [ERRO] {arq.name}: {e}")
            continue
        if not isinstance(turmas, list):
            continue
        for idx_turma, turma in enumerate(turmas):
            if (idx_turma + 1) % PROGRESSO_TURMAS == 0:
                print(f"    ({idx_turma + 1} turmas)", flush=True)
            if not isinstance(turma, dict):
                continue
            codigo = turma.get("codigo")
            if not codigo:
                continue
            id_materia = CACHE_ID_MATERIA.get(codigo)
            if id_materia is None:
                continue

            # Pré-requisitos
            expr_pr = turma.get("pre_requisitos")
            if not expr_vazia(expr_pr):
                expr_pr = expr_pr.strip()
                key_pre = (id_materia, expr_pr)
                if key_pre not in SET_PRE:
                    try:
                        expr_logica = parse_expression(expr_pr)
                        SET_PRE.add(key_pre)
                        list_pre.append({
                            "id_materia": id_materia,
                            "expressao_original": expr_pr,
                            "expressao_logica": expr_logica,
                        })
                        if len(list_pre) >= CHUNK_SIZE:
                            total_pre += _flush_pre(list_pre)
                            list_pre = []
                    except Exception:
                        erros_parse += 1

            # Co-requisitos
            expr_cr = turma.get("co_requisitos")
            if not expr_vazia(expr_cr):
                expr_cr = expr_cr.strip()
                key_co = (id_materia, expr_cr)
                if key_co not in SET_CO:
                    try:
                        expr_logica = parse_expression(expr_cr)
                        SET_CO.add(key_co)
                        list_co.append({
                            "id_materia": id_materia,
                            "expressao_original": expr_cr,
                            "expressao_logica": expr_logica,
                        })
                        if len(list_co) >= CHUNK_SIZE:
                            total_co += _flush_co(list_co)
                            list_co = []
                    except Exception:
                        erros_parse += 1

            # Equivalências genéricas
            expr_eq = turma.get("equivalencias")
            if not expr_vazia(expr_eq):
                expr_eq = expr_eq.strip()
                key_equi = _chave_equi(id_materia, expr_eq, None, None)
                if key_equi not in SET_EQUI:
                    try:
                        expr_logica = parse_expression(expr_eq)
                        SET_EQUI.add(key_equi)
                        list_equi.append({
                            "id_materia": id_materia,
                            "expressao_original": expr_eq,
                            "expressao_logica": expr_logica,
                        })
                        if len(list_equi) >= CHUNK_SIZE:
                            total_equi += _flush_equi(list_equi)
                            list_equi = []
                    except Exception:
                        erros_parse += 1

            # Equivalências específicas
            for esp in turma.get("equivalencias_especificas") or []:
                if not isinstance(esp, dict):
                    continue
                expr_esp = esp.get("expressao")
                if expr_vazia(expr_esp):
                    continue
                expr_esp = expr_esp.strip()
                curriculo = (esp.get("curriculo") or "").strip()
                id_curso = id_curso_from_curriculo(curriculo) if curriculo else None
                dv = esp.get("data_vigencia")
                data_vigencia = periodo_to_date(dv) if dv else None
                key_equi = _chave_equi(id_materia, expr_esp, id_curso, curriculo or None)
                if key_equi not in SET_EQUI:
                    try:
                        expr_logica = parse_expression(expr_esp)
                        SET_EQUI.add(key_equi)
                        row = {
                            "id_materia": id_materia,
                            "expressao_original": expr_esp,
                            "expressao_logica": expr_logica,
                        }
                        if id_curso is not None:
                            row["id_curso"] = id_curso
                        if curriculo:
                            row["curriculo"] = curriculo
                        if data_vigencia is not None:
                            row["data_vigencia"] = data_vigencia.isoformat()
                        list_equi.append(row)
                        total_equi_esp += 1
                        if len(list_equi) >= CHUNK_SIZE:
                            total_equi += _flush_equi(list_equi)
                            list_equi = []
                    except Exception:
                        erros_parse += 1

    total_pre += _flush_pre(list_pre)
    total_co += _flush_co(list_co)
    total_equi += _flush_equi(list_equi)

    print(
        f"\nConcluído. Inseridos: pre_requisitos={total_pre}, co_requisitos={total_co}, "
        f"equivalencias={total_equi} (dentre elas {total_equi_esp} específicas por curso/currículo)."
    )
    if erros_parse:
        print(f" Erros de parse: {erros_parse}.")
    if DRY_RUN:
        print(" [DRY-RUN] Nenhuma alteração foi persistida.")


if __name__ == "__main__":
    main()

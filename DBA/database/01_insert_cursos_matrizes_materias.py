#!/usr/bin/env python3
"""
Fase 1: Inserir cursos, matrizes, matérias e materias_por_curso a partir dos JSONs
em DBA/dados/estruturas-curriculares.

Regras:
- id_curso (tabela cursos) = código do currículo da matriz (primeira parte antes da /).
  Ex: "6360/1" -> id_curso 6360; "8150/-4" -> id_curso 8150.
- curriculo_completo na tabela matrizes: apenas "codigo/versao - periodo" (ex: "8150/-4 - 2014.1").
  NÃO incluir turno (DIURNO/NOTURNO) no curriculo_completo.
- Se já existir matriz com mesmo id_curso, versao e ano_vigor mas curriculo_completo no formato
  antigo (com turno), faz UPDATE na coluna curriculo_completo para o padrão sem turno.
- tipo_natureza em materias_por_curso: 0 = Obrigatória, 1 = Optativa (a partir do campo natureza do JSON).
- Só insere curso/matriz/matéria/materias_por_curso se ainda não existir; as únicas atualizações
  explícitas são: matrizes.curriculo_completo (quando fora do padrão) e normalização de cursos
  (id_curso legado codigo_base+100000 -> codigo_base).

Uso:
  cd DBA/database
  python 01_insert_cursos_matrizes_materias.py [--dry-run]
"""

import json
import os
import re
import sys
import time
import unicodedata
from pathlib import Path

from supabase import create_client
from tenacity import retry, stop_after_attempt, wait_exponential

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
from config import (
    DBA_ROOT,
    PASTA_ESTRUTURAS,
    PASTA_MATERIAS,
    SUPABASE_URL,
    SUPABASE_KEY,
)

DRY_RUN = "--dry-run" in sys.argv
CHUNK_SIZE = 80
FETCH_PAGE = 2000  # paginação ao carregar caches do banco
# Padrão legado noturno: id_curso = codigo_base + OFFSET_LEGADO; normalizar para id_curso = codigo_base.
OFFSET_LEGADO_CURSO = 100000
SLOW_OP_THRESHOLD_S = 5.0
LOG_MATERIAS_EVERY = 25

# Caches carregados no início (evitam SELECT por arquivo)
CACHE_CURSOS_BY_ID = {}  # id_curso -> {id_curso, nome_curso, tipo_curso, turno}
CACHE_CURSOS_BY_NOME = {}  # (nome_curso, turno, tipo_curso) -> id_curso
CACHE_MATRIZ_BY_CURRICULO = {}  # curriculo_completo -> {id_matriz, curriculo_completo, id_curso, versao, ano_vigor}
CACHE_MATRIZ_BY_CURSO_VERSAO_ANO = {}  # (id_curso, versao, ano_vigor) -> row
SET_MPC = set()  # (id_matriz, id_materia) já existentes
# Contadores para log (não alteram o processamento)
CONTAGEM_NOVOS_CURSOS = 0
CONTAGEM_NOVAS_MATRIZES = 0
CONTAGEM_NOVOS_MPC = 0

# ---------------------------------------------------------------------------
# Supabase
# ---------------------------------------------------------------------------
supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


def reconectar():
    global supabase
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


@retry(stop=stop_after_attempt(5), wait=wait_exponential(multiplier=1, min=2, max=15))
def db(op, *args, **kwargs):
    op_name = kwargs.pop("op_name", "db-op")
    t0 = time.time()
    try:
        result = op(*args, **kwargs)
        elapsed = time.time() - t0
        if elapsed >= SLOW_OP_THRESHOLD_S:
            print(f"[SLOW-DB] {op_name} levou {elapsed:.1f}s", flush=True)
        return result
    except Exception as e:
        err = str(e).lower()
        elapsed = time.time() - t0
        print(f"[ERRO-DB] {op_name} falhou após {elapsed:.1f}s: {e}", flush=True)
        if "duplicate key" in err or "23505" in err:
            raise
        if any(k in err for k in ["connection", "timeout", "network", "socket"]):
            reconectar()
            time.sleep(3)
            raise
        reconectar()
        time.sleep(2)
        raise


# ---------------------------------------------------------------------------
# Utilitários
# ---------------------------------------------------------------------------
def to_int(val):
    try:
        return int(val)
    except (TypeError, ValueError):
        return None


def ch_to_int(val):
    if val is None:
        return None
    if isinstance(val, int):
        return val
    s = str(val).strip().rstrip("hH")
    return to_int(s)


def remover_acentos(txt):
    return "".join(c for c in unicodedata.normalize("NFD", txt) if unicodedata.category(c) != "Mn")


def extrair_codigo_base(curriculo_str):
    if not curriculo_str or not isinstance(curriculo_str, str):
        return None
    s = curriculo_str.strip()
    if "/" in s:
        base = s.split("/", 1)[0].strip()
        return base if base.isdigit() else None
    return s if s.isdigit() else None


def build_curriculo_completo_sem_turno(curriculo_str, periodo_letivo_vigor):
    """
    curriculo_completo = apenas "codigo/versao - periodo" (ex: "8150/-4 - 2014.1").
    NÃO inclui turno (DIURNO/NOTURNO).
    """
    curriculo_str = (curriculo_str or "").strip()
    periodo = (periodo_letivo_vigor or "").strip()
    if not curriculo_str and not periodo:
        return ""
    return f"{curriculo_str} - {periodo}".strip(" - ")


def build_versao_ano(curriculo_str, periodo_letivo_vigor):
    versao = ""
    if curriculo_str and "/" in curriculo_str:
        sufixo = curriculo_str.split("/", 1)[1].strip()
        versao = sufixo.split(" - ")[0].strip() if " - " in sufixo else sufixo
    return versao or "", periodo_letivo_vigor or None


def nivel_to_int(nivel_nome):
    if nivel_nome is None:
        return 0
    s = (nivel_nome or "").strip().upper()
    if "OPTATIVA" in s or s == "OPTATIVAS":
        return 0
    m = re.match(r"(\d+)", s)
    return int(m.group(1)) if m else 0


def natureza_to_tipo(natureza):
    """0 = Obrigatória, 1 = Optativa (materias_por_curso.tipo_natureza)."""
    s = (natureza or "").strip().lower()
    return 1 if "optativa" in s else 0


def prazos_to_ints(prazos):
    if not prazos or not isinstance(prazos, dict):
        return {}
    return {k: ch_to_int(v) for k, v in prazos.items()}


# ---------------------------------------------------------------------------
# Turno a partir do arquivo ou do JSON (para curso.turno)
# ---------------------------------------------------------------------------
def get_turno_do_arquivo(nome_arquivo, data=None):
    if data and isinstance(data, dict) and data.get("turno"):
        return (data.get("turno") or "").strip().upper()
    n = (nome_arquivo or "").lower()
    if " - noturno" in n:
        return "NOTURNO"
    if " - diurno" in n:
        return "DIURNO"
    return ""


# ---------------------------------------------------------------------------
# Cursos (usa cache carregado no início)
# id_curso = código do currículo da matriz (primeira parte antes da /).
# ---------------------------------------------------------------------------
def load_cache_cursos():
    offset = 0
    while True:
        r = db(
            supabase.table("cursos")
            .select("id_curso, nome_curso, tipo_curso, turno")
            .range(offset, offset + FETCH_PAGE - 1)
            .execute
        )
        for row in r.data or []:
            i = row.get("id_curso")
            if i is not None:
                CACHE_CURSOS_BY_ID[i] = row
                nome = (row.get("nome_curso") or "").strip()
                turno = row.get("turno")
                tipo = row.get("tipo_curso")
                CACHE_CURSOS_BY_NOME[(nome, turno, tipo)] = i
        if len(r.data or []) < FETCH_PAGE:
            break
        offset += FETCH_PAGE


def get_or_create_curso(codigo_base, nome_curso, tipo_curso, turno=None):
    turno = (turno or "").strip().upper() or None
    id_curso = to_int(codigo_base)
    if id_curso is None:
        return None
    # 1) Cache por id_curso
    if id_curso in CACHE_CURSOS_BY_ID:
        row = CACHE_CURSOS_BY_ID[id_curso]
        updates = {}
        if nome_curso and (row.get("nome_curso") or "") != nome_curso:
            updates["nome_curso"] = nome_curso
        if tipo_curso is not None and row.get("tipo_curso") != tipo_curso:
            updates["tipo_curso"] = tipo_curso
        if turno is not None and row.get("turno") != turno:
            updates["turno"] = turno
        if updates and not DRY_RUN:
            db(supabase.table("cursos").update(updates).eq("id_curso", id_curso).execute)
        return id_curso
    # 2) Cache por (nome_curso, turno, tipo_curso)
    key_nome = (nome_curso or "", turno, tipo_curso)
    if key_nome in CACHE_CURSOS_BY_NOME:
        return CACHE_CURSOS_BY_NOME[key_nome]
    # 3) Inserir e adicionar ao cache
    if DRY_RUN:
        return -1
    global CONTAGEM_NOVOS_CURSOS
    try:
        insert_data = {"id_curso": id_curso, "nome_curso": nome_curso, "tipo_curso": tipo_curso or ""}
        if turno:
            insert_data["turno"] = turno
        res = db(supabase.table("cursos").insert(insert_data).execute)
        new_id = res.data[0]["id_curso"]
        row = {"id_curso": new_id, "nome_curso": nome_curso, "tipo_curso": tipo_curso, "turno": turno}
        CACHE_CURSOS_BY_ID[new_id] = row
        CACHE_CURSOS_BY_NOME[key_nome] = new_id
        CONTAGEM_NOVOS_CURSOS += 1
        return new_id
    except Exception as e:
        if "identity" in str(e).lower() or "23505" in str(e):
            insert_data = {"nome_curso": nome_curso, "tipo_curso": tipo_curso or ""}
            if turno:
                insert_data["turno"] = turno
            res = db(supabase.table("cursos").insert(insert_data).execute)
            new_id = res.data[0]["id_curso"]
            row = {"id_curso": new_id, "nome_curso": nome_curso, "tipo_curso": tipo_curso, "turno": turno}
            CACHE_CURSOS_BY_ID[new_id] = row
            CACHE_CURSOS_BY_NOME[key_nome] = new_id
            CONTAGEM_NOVOS_CURSOS += 1
            return new_id
        raise


# ---------------------------------------------------------------------------
# Normalização: cursos com id_curso no padrão legado (codigo_base + 100000)
# passam a ter id_curso = codigo_base; atualiza FKs em matrizes e equivalencias.
# Mesma ideia do curriculo_completo: padronizar dados já existentes no banco.
# ---------------------------------------------------------------------------
def normalizar_cursos_id_legado():
    """Cursos com id_curso >= OFFSET_LEGADO_CURSO são tratados como legado (ex: 108150 = 8150+100000).
    Atualiza matrizes e equivalencias para id_curso = codigo_base; depois atualiza ou remove o curso."""
    if DRY_RUN:
        return
    try:
        res = db(supabase.table("cursos").select("id_curso").gte("id_curso", OFFSET_LEGADO_CURSO).execute)
    except Exception:
        return
    if not res.data:
        return
    for row in res.data:
        id_legado = row.get("id_curso")
        if id_legado is None or id_legado < OFFSET_LEGADO_CURSO:
            continue
        codigo_base = id_legado - OFFSET_LEGADO_CURSO
        # FK em matrizes/equivalencias exige que codigo_base exista em cursos antes do UPDATE.
        # Se codigo_base não existir, criar curso a partir do legado; depois atualizar FKs e apagar legado.
        existe_base = db(supabase.table("cursos").select("id_curso").eq("id_curso", codigo_base).execute)
        if not existe_base.data:
            row_legado = db(supabase.table("cursos").select("nome_curso, tipo_curso, turno, campus").eq("id_curso", id_legado).limit(1).execute)
            if row_legado.data:
                rl = row_legado.data[0]
                try:
                    db(supabase.table("cursos").insert({
                        "id_curso": codigo_base,
                        "nome_curso": rl.get("nome_curso"),
                        "tipo_curso": rl.get("tipo_curso"),
                        "turno": rl.get("turno"),
                        "campus": rl.get("campus"),
                    }).execute)
                except Exception as ins:
                    if "23505" in str(ins) or "duplicate" in str(ins).lower():
                        pass
                    else:
                        raise
        try:
            db(supabase.table("matrizes").update({"id_curso": codigo_base}).eq("id_curso", id_legado).execute)
        except Exception:
            pass
        try:
            db(supabase.table("equivalencias").update({"id_curso": codigo_base}).eq("id_curso", id_legado).execute)
        except Exception:
            pass
        try:
            db(supabase.table("cursos").delete().eq("id_curso", id_legado).execute)
        except Exception as e:
            if "23503" in str(e) or "foreign key" in str(e).lower():
                pass
            else:
                raise


# ---------------------------------------------------------------------------
# Matrizes (usa cache carregado no início); curriculo_completo SEM turno.
# ---------------------------------------------------------------------------
def load_cache_matrizes():
    offset = 0
    while True:
        r = db(
            supabase.table("matrizes")
            .select("id_matriz, curriculo_completo, id_curso, versao, ano_vigor")
            .range(offset, offset + FETCH_PAGE - 1)
            .execute
        )
        for row in r.data or []:
            cc = (row.get("curriculo_completo") or "").strip()
            if cc:
                CACHE_MATRIZ_BY_CURRICULO[cc] = row
            id_c = row.get("id_curso")
            ver = row.get("versao") or ""
            ano = row.get("ano_vigor") or ""
            CACHE_MATRIZ_BY_CURSO_VERSAO_ANO[(id_c, ver, ano)] = row
        if len(r.data or []) < FETCH_PAGE:
            break
        offset += FETCH_PAGE


def get_or_create_matriz(id_curso, curriculo_completo, versao, ano_vigor, prazos_cargas):
    curriculo_completo = (curriculo_completo or "").strip()
    # 1) Cache por curriculo_completo
    if curriculo_completo in CACHE_MATRIZ_BY_CURRICULO:
        return CACHE_MATRIZ_BY_CURRICULO[curriculo_completo]["id_matriz"]

    # 2) Cache por (id_curso, versao, ano_vigor) — pode ser formato antigo com turno
    key = (id_curso, versao or "", ano_vigor or "")
    if key in CACHE_MATRIZ_BY_CURSO_VERSAO_ANO:
        row = CACHE_MATRIZ_BY_CURSO_VERSAO_ANO[key]
        atual = (row.get("curriculo_completo") or "").strip()
        if atual != curriculo_completo and (atual.endswith(" - DIURNO") or atual.endswith(" - NOTURNO")):
            if not DRY_RUN:
                db(supabase.table("matrizes").update({"curriculo_completo": curriculo_completo}).eq("id_matriz", row["id_matriz"]).execute)
                row["curriculo_completo"] = curriculo_completo
                CACHE_MATRIZ_BY_CURRICULO[curriculo_completo] = row
            return row["id_matriz"]
        return row["id_matriz"]

    # 3) Inserir e adicionar ao cache
    ch = prazos_to_ints(prazos_cargas or {})
    insert_data = {
        "id_curso": id_curso,
        "curriculo_completo": curriculo_completo,
        "versao": versao or "",
        "ano_vigor": ano_vigor,
        "ch_obrigatoria_exigida": ch.get("ch_obrigatoria_total"),
        "ch_total_exigida": ch.get("total_minima"),
        "ch_optativa_exigida": ch.get("ch_optativa_minima"),
        "ch_complementar_exigida": ch.get("ch_complementar_minima"),
    }
    insert_data = {k: v for k, v in insert_data.items() if v is not None or k in ("curriculo_completo", "versao", "ano_vigor")}
    if DRY_RUN:
        return None
    global CONTAGEM_NOVAS_MATRIZES
    res = db(supabase.table("matrizes").insert(insert_data).execute)
    new_id = res.data[0]["id_matriz"]
    row = {"id_matriz": new_id, "curriculo_completo": curriculo_completo, "id_curso": id_curso, "versao": versao or "", "ano_vigor": ano_vigor or ""}
    CACHE_MATRIZ_BY_CURRICULO[curriculo_completo] = row
    CACHE_MATRIZ_BY_CURSO_VERSAO_ANO[key] = row
    CONTAGEM_NOVAS_MATRIZES += 1
    return new_id


# ---------------------------------------------------------------------------
# Matérias e cache
# ---------------------------------------------------------------------------
DEPARTAMENTOS_MATERIAS = {}
CACHE_ID_MATERIA = {}


def load_departamentos():
    if not PASTA_MATERIAS.is_dir():
        return
    for arq in PASTA_MATERIAS.iterdir():
        if not arq.name.startswith("turmas_depto_") or not arq.suffix == ".json":
            continue
        try:
            for turma in json.loads(arq.read_text(encoding="utf-8")):
                cod = turma.get("codigo", turma.get("codigo_materia"))
                depto = turma.get("unidade_responsavel", turma.get("departamento", turma.get("depto")))
                if cod and depto:
                    DEPARTAMENTOS_MATERIAS[cod] = depto
        except Exception:
            pass


def load_materias_detalhadas():
    out = {}
    if not PASTA_MATERIAS.is_dir():
        return out
    for arq in PASTA_MATERIAS.iterdir():
        if not arq.suffix == ".json":
            continue
        try:
            for mat in json.loads(arq.read_text(encoding="utf-8")):
                if isinstance(mat, dict) and mat.get("codigo"):
                    out[mat["codigo"]] = mat
        except Exception:
            pass
    return out


def load_cache_materias():
    res = db(supabase.table("materias").select("codigo_materia, id_materia").execute)
    for r in res.data or []:
        if r.get("codigo_materia"):
            CACHE_ID_MATERIA[r["codigo_materia"]] = r["id_materia"]


def get_or_create_materia(materia, materias_detalhadas):
    codigo = materia.get("codigo")
    if not codigo:
        return None
    det = materias_detalhadas.get(codigo) or materias_detalhadas.get(codigo.upper()) or materias_detalhadas.get(codigo.lower()) or {}
    nome = det.get("nome", materia.get("nome", codigo))
    ch = ch_to_int(det.get("carga_horaria", det.get("ch", materia.get("ch", materia.get("carga_horaria", 0)))))
    ementa = det.get("ementa", materia.get("ementa", ""))
    departamento = DEPARTAMENTOS_MATERIAS.get(codigo, "")

    if codigo in CACHE_ID_MATERIA:
        return CACHE_ID_MATERIA[codigo]

    result = db(supabase.table("materias").select("id_materia, ementa, departamento, carga_horaria").eq("codigo_materia", codigo).execute)
    if result.data:
        row = result.data[0]
        id_m = row["id_materia"]
        CACHE_ID_MATERIA[codigo] = id_m
        if ementa and (row.get("ementa") or "") != ementa and not DRY_RUN:
            db(supabase.table("materias").update({"ementa": ementa}).eq("id_materia", id_m).execute)
        if departamento and (not row.get("departamento") or row.get("departamento") != departamento) and not DRY_RUN:
            db(supabase.table("materias").update({"departamento": departamento}).eq("id_materia", id_m).execute)
        ch_atual = row.get("carga_horaria") or 0
        if ch and ch > 0 and (not ch_atual or ch_atual == 0) and not DRY_RUN:
            db(supabase.table("materias").update({"carga_horaria": ch}).eq("id_materia", id_m).execute)
        return id_m

    if DRY_RUN:
        CACHE_ID_MATERIA[codigo] = -1  # fictício
        return -1
    insert_data = {
        "nome_materia": nome,
        "codigo_materia": codigo,
        "carga_horaria": ch or 0,
        "ementa": ementa or "",
        "departamento": departamento or "",
    }
    res = db(supabase.table("materias").insert(insert_data).execute)
    id_m = res.data[0]["id_materia"]
    CACHE_ID_MATERIA[codigo] = id_m
    return id_m


# ---------------------------------------------------------------------------
# Materias_por_curso (usa SET_MPC em memória; inserção em lote)
# ---------------------------------------------------------------------------
def load_cache_materias_por_curso():
    offset = 0
    while True:
        r = db(
            supabase.table("materias_por_curso")
            .select("id_matriz, id_materia")
            .range(offset, offset + FETCH_PAGE - 1)
            .execute
        )
        for row in r.data or []:
            if row.get("id_matriz") is not None and row.get("id_materia") is not None:
                SET_MPC.add((row["id_matriz"], row["id_materia"]))
        if len(r.data or []) < FETCH_PAGE:
            break
        offset += FETCH_PAGE


def insert_materias_por_curso_batch(linhas, id_matriz):
    if not linhas or id_matriz is None or (isinstance(id_matriz, int) and id_matriz <= 0):
        return
    seen = set()
    to_insert = []
    for (id_m, niv, tipo_nat) in linhas:
        if id_m is None or id_m <= 0:
            continue
        if (id_matriz, id_m) in SET_MPC or id_m in seen:
            continue
        seen.add(id_m)
        SET_MPC.add((id_matriz, id_m))
        row = {"id_materia": id_m, "id_matriz": id_matriz, "nivel": niv, "tipo_natureza": tipo_nat if tipo_nat is not None else 0}
        to_insert.append(row)
    if DRY_RUN:
        return
    global CONTAGEM_NOVOS_MPC
    CONTAGEM_NOVOS_MPC += len(to_insert)
    for i in range(0, len(to_insert), CHUNK_SIZE):
        lote = to_insert[i : i + CHUNK_SIZE]
        try:
            db(supabase.table("materias_por_curso").insert(lote).execute)
        except Exception as e:
            if "23505" not in str(e) and "duplicate" not in str(e).lower():
                for row in lote:
                    try:
                        db(supabase.table("materias_por_curso").insert(row).execute)
                    except Exception:
                        pass


# ---------------------------------------------------------------------------
# Listar arquivos de estrutura (todos os .json; nome pode terminar em " - 94.json")
# ---------------------------------------------------------------------------
def listar_arquivos_estruturas():
    if not PASTA_ESTRUTURAS.is_dir():
        return []
    return sorted(PASTA_ESTRUTURAS.glob("*.json"))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    t0 = time.time()
    print("Fase 1: Cursos, Matrizes, Matérias e Materias_por_curso")
    print(f"Fonte: {PASTA_ESTRUTURAS}")
    print(f"curriculo_completo: padrão SEM turno (ex: 8150/-4 - 2014.1)")
    print(f"id_curso: código do currículo (ex: 8150); normalizando legado (id >= {OFFSET_LEGADO_CURSO}).")
    if DRY_RUN:
        print(" [DRY-RUN] Nenhuma alteração será persistida.")
    print(flush=True)

    print("[1/5] Normalização de cursos legados (id_curso >= 100000)...", flush=True)
    normalizar_cursos_id_legado()
    print("      Normalização concluída.", flush=True)

    print("[2/5] Carregando departamentos e detalhes de matérias...", flush=True)
    load_departamentos()
    materias_detalhadas = load_materias_detalhadas()
    load_cache_materias()
    print(f"      [Cache] {len(CACHE_ID_MATERIA)} matérias; {len(materias_detalhadas)} detalhes em JSON.", flush=True)

    print("[3/5] Carregando cursos, matrizes e materias_por_curso já existentes...", flush=True)
    load_cache_cursos()
    load_cache_matrizes()
    load_cache_materias_por_curso()
    print(f"      [Cache] cursos={len(CACHE_CURSOS_BY_ID)}, matrizes={len(CACHE_MATRIZ_BY_CURRICULO)}, mpc={len(SET_MPC)}.", flush=True)

    arquivos = listar_arquivos_estruturas()
    print(f"[4/5] Processando {len(arquivos)} arquivos de estrutura...", flush=True)
    if not arquivos:
        print("Nenhum arquivo .json encontrado.", flush=True)
        return

    total_matrizes = 0
    total_mpc = 0
    total_arquivos = len(arquivos)
    for idx, arq in enumerate(arquivos):
        file_t0 = time.time()
        if (idx + 1) % 50 == 0 or idx == 0:
            print(f"      {idx + 1}/{total_arquivos} arquivos...", flush=True)
        print(f"      [ARQ {idx + 1}/{total_arquivos}] Início: {arq.name}", flush=True)

        try:
            data = json.loads(arq.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"  [ERRO] {arq.name}: {e}")
            continue
        if not isinstance(data, dict):
            continue

        nome_curso = remover_acentos(data.get("curso", "")).replace("Ç", "C").upper().strip()
        tipo_curso = data.get("tipo_curso")
        periodo_letivo = (data.get("periodo_letivo_vigor") or "").strip()
        curriculo_str = data.get("curriculo") or ""
        if isinstance(curriculo_str, (int, float)):
            curriculo_str = str(curriculo_str)
        curriculo_str = (curriculo_str or "").strip()
        if curriculo_str and "/" not in curriculo_str and curriculo_str.isdigit():
            curriculo_str = curriculo_str + "/1"

        turno = get_turno_do_arquivo(arq.name, data)
        codigo_base = extrair_codigo_base(curriculo_str)
        if not codigo_base:
            continue

        curriculo_completo = build_curriculo_completo_sem_turno(curriculo_str, periodo_letivo)
        versao, ano_vigor = build_versao_ano(curriculo_str, periodo_letivo)
        prazos = data.get("prazos_cargas") or {}

        t_curso = time.time()
        id_curso = get_or_create_curso(codigo_base, nome_curso, tipo_curso, turno)
        if id_curso is None:
            print(f"      [ARQ {idx + 1}] Ignorado: id_curso inválido.", flush=True)
            continue
        print(f"      [ARQ {idx + 1}] Curso resolvido em {time.time() - t_curso:.1f}s (id_curso={id_curso})", flush=True)

        t_matriz = time.time()
        id_matriz = get_or_create_matriz(id_curso, curriculo_completo, versao, ano_vigor, prazos)
        if id_matriz is None and not DRY_RUN:
            print(f"      [ARQ {idx + 1}] Ignorado: matriz não resolvida.", flush=True)
            continue
        if id_matriz is not None:
            total_matrizes += 1
        print(f"      [ARQ {idx + 1}] Matriz resolvida em {time.time() - t_matriz:.1f}s (id_matriz={id_matriz})", flush=True)

        linhas = []
        materias_total_arquivo = sum(len((bloco or {}).get("materias") or []) for bloco in (data.get("niveis") or []))
        materias_processadas = 0
        print(f"      [ARQ {idx + 1}] Matérias previstas: {materias_total_arquivo}", flush=True)

        for bloco in data.get("niveis") or []:
            nivel_int = nivel_to_int(bloco.get("nivel", ""))
            for mat in bloco.get("materias") or []:
                codigo = mat.get("codigo")
                if not codigo:
                    continue
                t_materia = time.time()
                id_m = get_or_create_materia(mat, materias_detalhadas)
                materia_elapsed = time.time() - t_materia
                materias_processadas += 1
                if materia_elapsed >= SLOW_OP_THRESHOLD_S:
                    print(
                        f"      [ARQ {idx + 1}] Matéria lenta ({materia_elapsed:.1f}s): {codigo}",
                        flush=True,
                    )
                if materias_processadas % LOG_MATERIAS_EVERY == 0:
                    print(
                        f"      [ARQ {idx + 1}] Progresso matérias: {materias_processadas}/{materias_total_arquivo}",
                        flush=True,
                    )
                tipo_nat = natureza_to_tipo(mat.get("natureza", ""))
                linhas.append((id_m, nivel_int, tipo_nat))
        if linhas and id_matriz:
            t_insert = time.time()
            insert_materias_por_curso_batch(linhas, id_matriz)
            print(
                f"      [ARQ {idx + 1}] Batch materias_por_curso concluído em {time.time() - t_insert:.1f}s "
                f"({len(linhas)} linhas)",
                flush=True,
            )
            total_mpc += len(linhas)
        print(
            f"      [ARQ {idx + 1}/{total_arquivos}] Fim {arq.name} em {time.time() - file_t0:.1f}s",
            flush=True,
        )

    elapsed = round(time.time() - t0, 1)
    print(flush=True)
    print("[5/5] Concluído.", flush=True)
    print(f"      Matrizes processadas: {total_matrizes} | Vínculos mpc (total): {total_mpc}", flush=True)
    if not DRY_RUN and (CONTAGEM_NOVOS_CURSOS or CONTAGEM_NOVAS_MATRIZES or CONTAGEM_NOVOS_MPC):
        print(f"      Inseridos neste run: {CONTAGEM_NOVOS_CURSOS} cursos, {CONTAGEM_NOVAS_MATRIZES} matrizes, {CONTAGEM_NOVOS_MPC} materias_por_curso.", flush=True)
    print(f"      Tempo: {elapsed}s", flush=True)
    if DRY_RUN:
        print(" [DRY-RUN] Nenhuma alteração foi persistida.", flush=True)


if __name__ == "__main__":
    main()

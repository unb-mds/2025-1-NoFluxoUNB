#!/usr/bin/env python3
"""
Identifica e corrige cursos com id_curso incorreto.
id_curso deve ser = cod_curso do curriculo (ex: 8117 de "8117/-2 - 2018.2").
Alguns foram inseridos com ID aleatório (IDENTITY) em vez do cod_curso.

Uso:
  cd coleta_dados/scraping
  python corrigir_id_curso_cursos.py          # só reporta
  python corrigir_id_curso_cursos.py --fix    # aplica correções
"""

import os
import re
import argparse
from supabase import create_client

try:
    from dotenv import load_dotenv
    for p in [
        os.path.join(os.path.dirname(__file__), '..', '..', 'no_fluxo_backend', '.env'),
        os.path.join(os.path.dirname(__file__), '..', '..', '.env'),
    ]:
        if os.path.isfile(p):
            load_dotenv(p)
            break
except ImportError:
    pass

SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://lijmhbstgdinsukovyfl.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_KEY') or ''
if not SUPABASE_KEY or len(SUPABASE_KEY) < 50:
    SUPABASE_KEY = '.s._o2wq5p0C6YBIrTGJsNl6xdg4l8Ju7CbwvaaeCWbeAc'

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


def extrair_cod_curso(curriculo_completo):
    """Extrai cod_curso do curriculo (parte antes da /). Ex: '8117/-2 - 2018.2' -> 8117."""
    if not curriculo_completo or not isinstance(curriculo_completo, str):
        return None
    s = curriculo_completo.strip()
    if '/' in s:
        base = s.split('/', 1)[0].strip()
    else:
        m = re.match(r'^(\d+)', s)
        base = m.group(1) if m else None
    return int(base) if base and base.isdigit() else None


def id_curso_esperado(cod_curso, turno):
    """id_curso correto: DIURNO=cod_curso, NOTURNO=cod_curso+100000."""
    if not cod_curso:
        return None
    turno = (turno or '').strip().upper()
    if turno == 'NOTURNO':
        return cod_curso + 100000
    return cod_curso


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--fix', action='store_true', help='Aplicar correções (padrão: só reportar)')
    args = parser.parse_args()

    # Buscar matrizes (turno pode não existir ainda; inferimos do curriculo_completo)
    res = supabase.table('matrizes').select('id_matriz', 'id_curso', 'curriculo_completo').execute()
    matrizes = res.data or []

    # Buscar cursos
    res_c = supabase.table('cursos').select('id_curso', 'nome_curso', 'turno').execute()
    cursos_map = {c['id_curso']: c for c in (res_c.data or [])}

    incorretos = []  # (id_curso_atual, id_curso_correto, cod_curso, nome_curso, curriculo)

    for m in matrizes:
        curriculo = m.get('curriculo_completo') or ''
        id_atual = m.get('id_curso')
        # turno: da coluna ou inferido do curriculo (ex: "... - NOTURNO")
        turno = m.get('turno') or ('NOTURNO' if curriculo.strip().upper().endswith(' - NOTURNO') else 'DIURNO')
        cod = extrair_cod_curso(curriculo)
        if cod is None or id_atual is None:
            continue
        id_esperado = id_curso_esperado(cod, turno)
        if id_esperado is None:
            continue
        if id_atual != id_esperado:
            curso = cursos_map.get(id_atual, {})
            incorretos.append({
                'id_curso_atual': id_atual,
                'id_curso_correto': id_esperado,
                'cod_curso': cod,
                'nome_curso': curso.get('nome_curso', '?'),
                'curriculo': curriculo[:60],
                'turno': turno or 'DIURNO',
            })

    # Deduplicar por id_curso_atual (um curso pode ter várias matrizes)
    vistos = set()
    unicos = []
    for i in incorretos:
        k = i['id_curso_atual']
        if k not in vistos:
            vistos.add(k)
            unicos.append(i)

    if not unicos:
        print("Nenhum curso com id_curso incorreto encontrado.")
        return

    print(f"Encontrados {len(unicos)} curso(s) com id_curso incorreto:\n")
    for u in unicos:
        print(f"  id_curso atual: {u['id_curso_atual']} (deveria ser {u['id_curso_correto']})")
        print(f"  cod_curso: {u['cod_curso']} | {u['nome_curso']}")
        print(f"  curriculo: {u['curriculo']}...")
        print()

    if not args.fix:
        print("Execute com --fix para aplicar correções.")
        return

    print("Aplicando correções...")
    for u in unicos:
        id_atual = u['id_curso_atual']
        id_correto = u['id_curso_correto']
        cod = u['cod_curso']
        nome = u['nome_curso']
        turno = u['turno']

        # Verificar se curso correto já existe
        res_ex = supabase.table('cursos').select('id_curso').eq('id_curso', id_correto).execute()
        curso_correto_existe = bool(res_ex.data)

        if curso_correto_existe:
            # Atualizar matrizes e equivalencias para apontar ao curso correto
            supabase.table('matrizes').update({'id_curso': id_correto}).eq('id_curso', id_atual).execute()
            try:
                supabase.table('equivalencias').update({'id_curso': id_correto}).eq('id_curso', id_atual).execute()
            except Exception:
                pass
            # Remover curso incorreto
            supabase.table('cursos').delete().eq('id_curso', id_atual).execute()
            print(f"  [OK] id_curso {id_atual} -> {id_correto} (curso correto já existia)")
        else:
            # Criar curso com id correto, copiar dados, atualizar FKs, remover antigo
            res_antigo = supabase.table('cursos').select('*').eq('id_curso', id_atual).execute()
            if not res_antigo.data:
                print(f"  [ERRO] Curso {id_atual} não encontrado")
                continue
            antigo = res_antigo.data[0]
            novo = {
                'id_curso': id_correto,
                'nome_curso': antigo.get('nome_curso', nome),
                'tipo_curso': antigo.get('tipo_curso'),
                'turno': turno or antigo.get('turno'),
            }
            supabase.table('cursos').insert(novo).execute()
            supabase.table('matrizes').update({'id_curso': id_correto}).eq('id_curso', id_atual).execute()
            try:
                supabase.table('equivalencias').update({'id_curso': id_correto}).eq('id_curso', id_atual).execute()
            except Exception:
                pass
            supabase.table('cursos').delete().eq('id_curso', id_atual).execute()
            print(f"  [OK] id_curso {id_atual} -> {id_correto} (criado novo curso)")

    print("\nCorreções aplicadas.")


if __name__ == '__main__':
    main()

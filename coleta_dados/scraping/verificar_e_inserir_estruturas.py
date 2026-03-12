#!/usr/bin/env python3
"""
Conferir todas as estruturas curriculares (JSON) e inserir no banco as que não existem.

- Mostra resumo do banco: total de cursos, matrizes, materias_por_curso; cursos sem matriz; matrizes sem matérias.
- Percorre todos os .json em dados/estruturas-curriculares.
- Para cada um, monta curriculo_completo igual a integracao_estruturas_turno (com turno quando houver).
- Verifica se existe matriz no banco com esse curriculo_completo.
- Sem --execute: só lista o que falta.
- Com --execute: carrega cache de matérias e insere curso + matriz + materias_por_curso para cada faltante
  (reutiliza integracao_estruturas_turno.processar_um_arquivo).

Uso:
  cd coleta_dados/scraping
  python verificar_e_inserir_estruturas.py              # só conferir e listar faltantes
  python verificar_e_inserir_estruturas.py --execute   # inserir as que não existem
"""

import os
import sys
import json
import unicodedata

# Garantir que o script rode a partir de coleta_dados/scraping para imports
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from integracao_estruturas_turno import (
    PASTA_ESTRUTURAS,
    build_dados_matriz,
    extrair_codigo_base,
    get_turno_do_arquivo,
    listar_todos_arquivos_estruturas,
    processar_um_arquivo,
    carregar_cache_materias,
    executar_operacao,
    supabase,
)


def resolver_caminho(pasta, nome_arquivo):
    """
    Retorna o caminho real do arquivo na pasta (evita falha por encoding/unicode no Windows).
    Se nome_arquivo não existir como está, tenta encontrar por comparação normalizada (NFC, case).
    """
    caminho_direto = os.path.join(pasta, nome_arquivo)
    if os.path.isfile(caminho_direto):
        return caminho_direto
    nome_nfc = unicodedata.normalize('NFC', nome_arquivo)
    try:
        for f in os.listdir(pasta):
            if not f.endswith('.json'):
                continue
            if f == nome_arquivo or os.path.normcase(f) == os.path.normcase(nome_arquivo):
                return os.path.join(pasta, f)
            if unicodedata.normalize('NFC', f) == nome_nfc or os.path.normcase(unicodedata.normalize('NFC', f)) == os.path.normcase(nome_nfc):
                return os.path.join(pasta, f)
    except Exception:
        pass
    return caminho_direto  # devolve mesmo assim para tentar abrir


def curriculo_completo_do_arquivo(caminho_arquivo):
    """
    Lê o JSON e retorna o curriculo_completo que essa estrutura teria no banco
    (igual à lógica de integracao_estruturas_turno).
    Retorna None se o arquivo for inválido ou não tiver curriculo.
    """
    if not os.path.isfile(caminho_arquivo):
        return None
    try:
        with open(caminho_arquivo, 'r', encoding='utf-8') as f:
            raw = json.load(f)
    except Exception:
        return None
    # Alguns JSON têm raiz como lista; usar primeiro elemento dict
    if isinstance(raw, list):
        matriz = next((x for x in raw if isinstance(x, dict)), None)
    elif isinstance(raw, dict):
        matriz = raw
    else:
        return None
    if not matriz:
        return None
    curriculo_str = matriz.get('curriculo') or ''
    if isinstance(curriculo_str, (int, float)):
        curriculo_str = str(curriculo_str)
    # Curriculo só com número (ex: "5584") → tratar como "5584/1"
    curriculo_str = (curriculo_str or '').strip()
    if curriculo_str and '/' not in curriculo_str and curriculo_str.isdigit():
        curriculo_str = curriculo_str + '/1'
    periodo_letivo = matriz.get('periodo_letivo_vigor') or ''
    if not extrair_codigo_base(curriculo_str):
        return None
    arquivo = os.path.basename(caminho_arquivo)
    turno = get_turno_do_arquivo(arquivo, matriz)
    dados = build_dados_matriz(curriculo_str, periodo_letivo, turno)
    return (dados.get('curriculo_completo') or '').strip()


def obter_curriculos_completos_banco():
    """Retorna set de curriculo_completo presentes na tabela matrizes."""
    try:
        result = executar_operacao(
            supabase.table('matrizes').select('curriculo_completo').execute
        )
        return { (r.get('curriculo_completo') or '').strip() for r in (result.data or []) if r.get('curriculo_completo') }
    except Exception as e:
        print(f"Erro ao buscar matrizes no banco: {e}")
        return set()


def resumo_banco():
    """
    Retorna dict com totais e listas de órfãos: cursos sem matriz, matrizes sem materias_por_curso.
    """
    out = {
        'total_cursos': 0,
        'total_matrizes': 0,
        'total_materias_por_curso': 0,
        'cursos_sem_matriz': [],
        'matrizes_sem_materias': [],
    }
    todos_cursos = []
    todos_id_matriz = []
    ids_curso_com_matriz = set()
    try:
        r = executar_operacao(supabase.table('cursos').select('id_curso').execute)
        todos_cursos = [x['id_curso'] for x in (r.data or []) if x.get('id_curso') is not None]
        out['total_cursos'] = len(todos_cursos)
    except Exception:
        pass
    try:
        r = executar_operacao(supabase.table('matrizes').select('id_matriz', 'id_curso').execute)
        todos_id_matriz = [x['id_matriz'] for x in (r.data or []) if x.get('id_matriz') is not None]
        ids_curso_com_matriz = {x['id_curso'] for x in (r.data or []) if x.get('id_curso') is not None}
        out['total_matrizes'] = len(todos_id_matriz)
    except Exception:
        pass
    try:
        r = executar_operacao(supabase.table('materias_por_curso').select('id_materia_curso').execute)
        out['total_materias_por_curso'] = len(r.data or [])
    except Exception:
        pass
    out['cursos_sem_matriz'] = sorted([c for c in todos_cursos if c not in ids_curso_com_matriz])
    try:
        ids_matriz_com_materias = set()
        page = 0
        while True:
            r = executar_operacao(supabase.table('materias_por_curso').select('id_matriz').range(page * 1000, (page + 1) * 1000 - 1).execute)
            for row in (r.data or []):
                if row.get('id_matriz') is not None:
                    ids_matriz_com_materias.add(row['id_matriz'])
            if not r.data or len(r.data) < 1000:
                break
            page += 1
        out['matrizes_sem_materias'] = sorted([m for m in todos_id_matriz if m not in ids_matriz_com_materias])
    except Exception:
        pass
    return out


def main():
    execute = '--execute' in sys.argv

    if not os.path.isdir(PASTA_ESTRUTURAS):
        print(f"Pasta não encontrada: {PASTA_ESTRUTURAS}")
        return 1

    arquivos = listar_todos_arquivos_estruturas()
    if not arquivos:
        print("Nenhum arquivo .json em estruturas-curriculares.")
        return 0

    print("Conferindo estruturas curriculares...")
    print(f"Arquivos na pasta: {len(arquivos)}\n")

    # Resumo do banco: cursos, matrizes, materias_por_curso e órfãos
    try:
        resumo = resumo_banco()
        print("=== Resumo do banco ===")
        print(f"  Cursos (cursos):           {resumo['total_cursos']}")
        print(f"  Matrizes (matrizes):       {resumo['total_matrizes']}")
        print(f"  Vínculos (materias_por_curso): {resumo['total_materias_por_curso']}")
        if resumo['cursos_sem_matriz']:
            print(f"  Cursos SEM nenhuma matriz (id_curso): {len(resumo['cursos_sem_matriz'])} — {resumo['cursos_sem_matriz'][:15]}{'...' if len(resumo['cursos_sem_matriz']) > 15 else ''}")
        if resumo['matrizes_sem_materias']:
            print(f"  Matrizes SEM matérias (id_matriz): {len(resumo['matrizes_sem_materias'])} — {resumo['matrizes_sem_materias'][:15]}{'...' if len(resumo['matrizes_sem_materias']) > 15 else ''}")
        print()
    except Exception as e:
        print(f"(Não foi possível obter resumo do banco: {e})\n")

    # Montar curriculo_completo de cada arquivo (usar caminho resolvido por encoding)
    arquivo_para_curriculo = {}
    for arq in arquivos:
        caminho = resolver_caminho(PASTA_ESTRUTURAS, arq)
        cc = curriculo_completo_do_arquivo(caminho)
        if cc:
            arquivo_para_curriculo[arq] = cc

    ignorados = [arq for arq in arquivos if arq not in arquivo_para_curriculo]
    if ignorados:
        print(f"Arquivos ignorados (curriculo inválido ou JSON incompatível): {len(ignorados)}")
        for arq in ignorados:
            print(f"  - {arq}")
        print()

    # Curriculos que existem no banco
    no_banco = obter_curriculos_completos_banco()
    print(f"Matrizes no banco (curriculo_completo): {len(no_banco)}")
    print(f"Estruturas válidas nos arquivos: {len(arquivo_para_curriculo)}\n")

    # Faltantes: arquivos cujo curriculo_completo não está no banco
    faltantes = []
    for arq, cc in arquivo_para_curriculo.items():
        if cc not in no_banco:
            faltantes.append((arq, cc))

    if not faltantes:
        print("Todas as estruturas (com curriculo válido) existem no banco. Nada a inserir.")
        if ignorados:
            print(f"({len(ignorados)} arquivo(s) ignorado(s) por curriculo inválido ou JSON incompatível.)")
        return 0

    print(f"Estruturas que NÃO existem no banco: {len(faltantes)}\n")
    for arq, cc in faltantes[:30]:
        print(f"  - {arq}")
        print(f"    curriculo_completo: {cc}")
    if len(faltantes) > 30:
        print(f"  ... e mais {len(faltantes) - 30} arquivo(s).")

    if not execute:
        print("\nPara inserir as faltantes no banco, rode com --execute")
        return 0

    print("\n--- Inserindo estruturas faltantes ---\n")
    carregar_cache_materias()
    inseridos = 0
    erros = 0
    for i, (arq, cc) in enumerate(faltantes, 1):
        caminho = resolver_caminho(PASTA_ESTRUTURAS, arq)
        print(f"[{i}/{len(faltantes)}] {arq}")
        try:
            id_matriz, linhas = processar_um_arquivo(caminho)
            if id_matriz is not None:
                print(f"  → Matriz criada id_matriz={id_matriz} | {linhas} matérias em materias_por_curso")
                inseridos += 1
            else:
                print("  → (já existia ou curriculo inválido)")
        except Exception as e:
            print(f"  [ERRO] {e}")
            erros += 1

    print(f"\nConcluído. Inseridas: {inseridos} | Erros: {erros}")
    return 0 if erros == 0 else 1


if __name__ == '__main__':
    sys.exit(main())

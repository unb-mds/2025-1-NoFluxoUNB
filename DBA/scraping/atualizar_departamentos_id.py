import argparse
import csv
from pathlib import Path

import requests
from bs4 import BeautifulSoup

"""
Atualiza a lista de IDs de departamento usada por scraping_turmas.py.

Os IDs vêm do <select id="formTurma:inputDepto"> da página pública de
busca de turmas do SIGAA (o mesmo dropdown de "Unidade" -- seleção
única, sem opção "todas"). Essa lista é estática hoje: se a UnB criar
um novo departamento no SIGAA, ele só passa a ser scrapeado depois que
esse script for rodado de novo manualmente.

Uso:
  cd DBA/scraping
  python atualizar_departamentos_id.py                # gera departamentos_ID_unb_novo.csv e mostra o diff
  python atualizar_departamentos_id.py --apply         # sobrescreve departamentos_ID_unb.csv direto
"""

URL = "https://sigaa.unb.br/sigaa/public/turmas/listar.jsf"
SCRIPT_DIR = Path(__file__).resolve().parent
ARQUIVO_ATUAL = SCRIPT_DIR / "departamentos_ID_unb.csv"
ARQUIVO_NOVO = SCRIPT_DIR / "departamentos_ID_unb_novo.csv"


def coletar_ids_departamento():
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
        }
    )

    response = session.get(URL, timeout=30)
    response.raise_for_status()

    soup = BeautifulSoup(response.text, "html.parser")
    select = soup.find("select", {"id": "formTurma:inputDepto"})
    if not select:
        raise RuntimeError(
            "Não encontrei o <select id='formTurma:inputDepto'> na página. "
            "O SIGAA pode ter mudado a estrutura do formulário."
        )

    ids = []
    for option in select.find_all("option"):
        valor = option.get("value")
        if valor is None or not valor.isdigit() or valor == "0":
            continue
        ids.append(int(valor))

    return sorted(set(ids))


def carregar_ids_existentes(caminho):
    if not caminho.is_file():
        return set()
    ids = set()
    with open(caminho, "r", encoding="utf-8") as f:
        for row in csv.reader(f):
            if row and row[0].isdigit():
                ids.add(int(row[0]))
    return ids


def salvar_csv(caminho, ids):
    with open(caminho, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["id"])
        for id_depto in ids:
            writer.writerow([id_depto])


def main():
    parser = argparse.ArgumentParser(
        description="Atualiza departamentos_ID_unb.csv a partir do dropdown de Unidade do SIGAA."
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Sobrescreve departamentos_ID_unb.csv diretamente (default: só gera departamentos_ID_unb_novo.csv pra revisão).",
    )
    args = parser.parse_args()

    print(f"Buscando IDs de departamento em {URL} ...")
    ids_novos = coletar_ids_departamento()
    ids_atuais = carregar_ids_existentes(ARQUIVO_ATUAL)

    adicionados = sorted(set(ids_novos) - ids_atuais)
    removidos = sorted(ids_atuais - set(ids_novos))

    print(f"\nTotal coletado agora: {len(ids_novos)}")
    print(f"Total no arquivo atual ({ARQUIVO_ATUAL.name}): {len(ids_atuais)}")
    print(
        f"Novos (não estavam antes): {len(adicionados)} {adicionados if adicionados else ''}"
    )
    print(
        f"Sumiram (estavam antes, não vieram agora): {len(removidos)} {removidos if removidos else ''}"
    )

    if args.apply:
        salvar_csv(ARQUIVO_ATUAL, ids_novos)
        print(f"\n✓ {ARQUIVO_ATUAL.name} atualizado com {len(ids_novos)} IDs.")
    else:
        salvar_csv(ARQUIVO_NOVO, ids_novos)
        print(
            f"\n✓ Gravado em {ARQUIVO_NOVO.name} pra revisão. "
            f"Confira o diff acima e rode com --apply se estiver ok."
        )


if __name__ == "__main__":
    main()

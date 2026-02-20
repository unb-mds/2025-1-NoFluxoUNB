#!/usr/bin/env python3
"""
Script para subir apenas a estrutura curricular "Direito - 2019.2" no banco.
Uso (a partir da raiz do repo ou de coleta_dados):
  python -m coleta_dados.scraping.upload_direito_2019
  ou, na pasta scraping:
  python upload_direito_2019.py
"""
import os
import sys

# Garante que o diretório do script está no path para importar integracao_banco
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

# Nome do arquivo em dados/estruturas-curriculares
ARQUIVO = "direito - 2019.2.json"


def main():
    import integracao_banco as ib

    # Caminho: mesmo padrão do integracao_banco (PASTA_MATRIZES)
    pasta_matrizes = os.path.join(SCRIPT_DIR, "..", "dados", "estruturas-curriculares")
    path = os.path.join(pasta_matrizes, ARQUIVO)

    if not os.path.isfile(path):
        print(f"Erro: arquivo não encontrado: {path}")
        sys.exit(1)

    print(f"Subindo estrutura: {ARQUIVO}")
    try:
        id_matriz = ib.processar_uma_matriz(path)
        print(f"Concluído. id_matriz = {id_matriz}")
    except Exception as e:
        print(f"Erro: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

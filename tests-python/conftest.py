"""Configuração compartilhada do pytest para a suíte Python.

Adiciona a raiz do repositório ao ``sys.path`` para que os testes consigam
importar os módulos do projeto (``DBA.scraping``, ``DBA.parse_pdf`` etc.)
independentemente do diretório de execução ou da ordem de coleta.
"""

import os
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

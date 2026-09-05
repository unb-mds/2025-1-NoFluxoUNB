"""
Configuração centralizada para scripts de integração com o banco (Supabase).
Use os scripts nesta pasta para inserir/atualizar cursos, matrizes, matérias, etc.
"""

import os
from pathlib import Path

# Raiz do projeto DBA
DBA_ROOT = Path(__file__).resolve().parent.parent
# Dados
PASTA_ESTRUTURAS = DBA_ROOT / "dados" / "estruturas-curriculares"
PASTA_MATERIAS = DBA_ROOT / "dados" / "materias"

# .env: backend, raiz do repo, diretório atual
try:
    from dotenv import load_dotenv

    for p in [
        DBA_ROOT.parent / "no_fluxo_backend" / ".env",
        DBA_ROOT.parent / ".env",
        Path.cwd() / ".env",
        DBA_ROOT / ".env",
    ]:
        if p.is_file():
            load_dotenv(p)
            break
except ImportError:
    pass

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://lijmhbstgdinsukovyfl.supabase.co")
SUPABASE_KEY = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_SERVICE_KEY")
    or os.getenv("SUPABASE_KEY")
    or ""
)

<<<<<<< Updated upstream
=======
if not SUPABASE_KEY or len(SUPABASE_KEY) < 50:
    raise RuntimeError(
        "SUPABASE_SERVICE_ROLE_KEY não configurada. Defina a variável de ambiente "
        "ou um arquivo .env (nunca commitar a chave no repositório)."
    )
>>>>>>> Stashed changes

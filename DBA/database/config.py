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

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_SERVICE_KEY")
    or os.getenv("SUPABASE_KEY")
)

if not SUPABASE_URL or not SUPABASE_KEY:
    raise RuntimeError(
        "SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY devem estar definidos no .env "
        "(ver no_fluxo_backend/.env.example)."
    )

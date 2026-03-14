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

# Fallback para chave de serviço se env vazia (evitar quebrar em dev)
if not SUPABASE_KEY or len(SUPABASE_KEY) < 50:
    _FALLBACK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxpam1oYnN0Z2RpbnN1a292eWZsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgzOTM3MywiZXhwIjoyMDYzNDE1MzczfQ._o2wq5p0C6YBIrTGJsNl6xdg4l8Ju7CbwvaaeCWbeAc"
    SUPABASE_KEY = _FALLBACK

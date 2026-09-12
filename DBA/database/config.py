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

# Valida o FORMATO da chave, não o tamanho.
#
# O guard original exigia len >= 50, número herdado de quando as chaves do
# Supabase eram JWT (200+ caracteres). Desde a migração de setembro/2026 a
# service key é `sb_secret_…` com 41 caracteres — ou seja, a heurística de
# tamanho passou a rejeitar justamente a chave certa. Foi o que derrubou o
# workflow Sync Calendario Academico.
if not SUPABASE_KEY:
    raise RuntimeError(
        "SUPABASE_SERVICE_ROLE_KEY não configurada. Defina a variável de ambiente "
        "ou um arquivo .env (nunca commitar a chave no repositório)."
    )

if SUPABASE_KEY.startswith("sb_publishable_"):
    raise RuntimeError(
        "SUPABASE_SERVICE_ROLE_KEY recebeu a chave PUBLICÁVEL (sb_publishable_…). "
        "Os scripts de carga escrevem com RLS desligado e precisam da secret "
        "(sb_secret_…) — com a publicável as escritas falhariam em silêncio."
    )

# sb_secret_… = formato atual; eyJ… = JWT legado (desativado em 04/09/2026,
# ainda aceito aqui para não quebrar quem rodar com um .env antigo).
if not SUPABASE_KEY.startswith(("sb_secret_", "eyJ")):
    raise RuntimeError(
        f"SUPABASE_SERVICE_ROLE_KEY com formato não reconhecido "
        f"(prefixo {SUPABASE_KEY[:12]!r}). Esperado 'sb_secret_…'."
    )

#!/usr/bin/env python3
"""
Reconferir cursos adicionados antes da coluna turno.
Define turno='DIURNO' para cursos com turno NULL.
Turno fica apenas em CURSOS (matrizes não tem turno).

Uso:
  cd coleta_dados/scraping
  python reconferir_cursos_turno.py
"""

import os
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
    SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxpam1oYnN0Z2RpbnN1a292eWZsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgzOTM3MywiZXhwIjoyMDYzNDE1MzczfQ._o2wq5p0C6YBIrTGJsNl6xdg4l8Ju7CbwvaaeCWbeAc'

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


def main():
    """Turno só em CURSOS. Atualiza cursos com turno NULL."""
    res = supabase.table('cursos').select('id_curso', 'nome_curso', 'turno').is_('turno', 'null').execute()
    cursos_sem_turno = res.data or []

    if not cursos_sem_turno:
        print("Nenhum curso com turno NULL.")
        return

    print(f"CURSOS: {len(cursos_sem_turno)} com turno NULL -> DIURNO")
    for c in cursos_sem_turno:
        supabase.table('cursos').update({'turno': 'DIURNO'}).eq('id_curso', c['id_curso']).execute()
        print(f"  id_curso={c['id_curso']} | {c.get('nome_curso', '')}")
    print(f"\nReconferência concluída: {len(cursos_sem_turno)} curso(s) atualizado(s).")


if __name__ == '__main__':
    main()

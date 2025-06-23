
from supabase import Client,create_client


SUPABASE_URL = "https://lijmhbstgdinsukovyfl.supabase.co/"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxpam1oYnN0Z2RpbnN1a292eWZsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NzgzOTM3MywiZXhwIjoyMDYzNDE1MzczfQ._o2wq5p0C6YBIrTGJsNl6xdg4l8Ju7CbwvaaeCWbeAc"
client: Client = create_client(SUPABASE_URL, SUPABASE_KEY)


dados = client.from_("cursos").select("*,materias_por_curso(materias(*))").execute().data

print(dados[0]["nome_curso"])
print(dados[0]["materias_por_curso"][0])



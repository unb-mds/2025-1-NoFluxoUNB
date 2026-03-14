-- Remove IDENTITY da coluna id_curso em cursos para permitir:
-- - Inserção com id_curso = código do currículo (ex: 8150, 6360)
-- - Normalização: UPDATE id_curso de legado (codigo_base+100000) para codigo_base
-- Executar uma vez no Supabase (SQL Editor ou migration).

ALTER TABLE public.cursos
  ALTER COLUMN id_curso DROP IDENTITY;

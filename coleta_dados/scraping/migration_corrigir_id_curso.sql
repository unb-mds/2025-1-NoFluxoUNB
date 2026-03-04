-- Migration: corrigir id_curso em cursos
-- id_curso deve ser = cod_curso do curriculo (ex: 8117 de "8117/-2 - 2018.2")
-- Alguns cursos foram inseridos com ID aleatório (IDENTITY) em vez do cod_curso
--
-- ATENÇÃO: Execute o script Python corrigir_id_curso_cursos.py primeiro para
-- identificar os cursos incorretos. Este SQL é um exemplo para um caso específico.
--
-- Exemplo manual (substitua os valores):
-- 1. Curso com id_curso=12345 deveria ser id_curso=8117 (cod_curso do curriculo)
-- 2. Se curso 8117 já existe: atualizar matrizes e equivalencias, deletar 12345
-- 3. Se não existe: criar curso 8117, atualizar FKs, deletar 12345

-- Exemplo para id_curso errado 12345 -> correto 8117:
/*
BEGIN;
  -- Atualizar matrizes (FK id_curso)
  UPDATE public.matrizes SET id_curso = 8117 WHERE id_curso = 12345;
  -- Atualizar equivalencias (FK id_curso)
  UPDATE public.equivalencias SET id_curso = 8117 WHERE id_curso = 12345;
  -- Remover curso incorreto
  DELETE FROM public.cursos WHERE id_curso = 12345;
  -- Se curso 8117 não existir, inserir antes:
  -- INSERT INTO public.cursos (id_curso, nome_curso, tipo_curso, turno)
  -- SELECT 8117, nome_curso, tipo_curso, 'DIURNO' FROM public.cursos WHERE id_curso = 12345;
COMMIT;
*/

-- Para listar cursos cujo id_curso não bate com cod_curso do curriculo:
SELECT
  c.id_curso,
  c.nome_curso,
  c.turno,
  m.curriculo_completo,
  (regexp_match(m.curriculo_completo, '^(\d+)/'))[1]::bigint AS cod_curso_extraido,
  CASE
    WHEN c.turno = 'NOTURNO' THEN (regexp_match(m.curriculo_completo, '^(\d+)/'))[1]::bigint + 100000
    ELSE (regexp_match(m.curriculo_completo, '^(\d+)/'))[1]::bigint
  END AS id_curso_esperado
FROM public.cursos c
JOIN public.matrizes m ON m.id_curso = c.id_curso
WHERE (regexp_match(m.curriculo_completo, '^(\d+)/'))[1]::bigint IS NOT NULL
  AND c.id_curso != CASE
    WHEN c.turno = 'NOTURNO' THEN (regexp_match(m.curriculo_completo, '^(\d+)/'))[1]::bigint + 100000
    ELSE (regexp_match(m.curriculo_completo, '^(\d+)/'))[1]::bigint
  END;

-- Migration: coluna turno em CURSOS (não em matrizes)
-- id_curso: PK em cursos, FK em matrizes (matrizes.id_curso -> cursos.id_curso)

ALTER TABLE public.cursos
ADD COLUMN IF NOT EXISTS turno text;

COMMENT ON COLUMN public.cursos.turno IS 'DIURNO ou NOTURNO';

CREATE INDEX IF NOT EXISTS idx_cursos_turno ON public.cursos(turno);

-- Reconferir cursos adicionados antes
UPDATE public.cursos SET turno = 'DIURNO' WHERE turno IS NULL;

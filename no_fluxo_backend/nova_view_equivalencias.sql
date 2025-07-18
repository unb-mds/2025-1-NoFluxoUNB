CREATE OR REPLACE VIEW public.vw_equivalencias_com_materias AS
WITH codigos_explodidos AS (
  SELECT
    e.id_equivalencia,
    e.id_curso,
    e.matriz_curricular,
    e.curriculo,
    e.data_vigencia,
    e.fim_vigencia,
    e.expressao,
    m_origem.codigo_materia AS codigo_materia_origem,
    m_origem.nome_materia AS nome_materia_origem,
    c.nome_curso,
    regexp_split_to_table(
      regexp_replace(e.expressao, '[\(\)]'::text, ''::text, 'g'::text),
      '\s+(OU|ou|E|e)\s+'::text
    ) AS codigo_equivalente
  FROM
    equivalencias e
    LEFT JOIN materias m_origem ON e.id_materia = m_origem.id_materia
    LEFT JOIN cursos c ON e.id_curso = c.id_curso
),
materias_equivalentes AS (
  SELECT
    ce.id_equivalencia,
    ce.codigo_materia_origem,
    ce.nome_materia_origem,
    ce.expressao,
    ce.codigo_equivalente,
    m.nome_materia AS nome_materia_equivalente,
    ce.id_curso,
    ce.nome_curso,
    ce.matriz_curricular,
    ce.curriculo,
    ce.data_vigencia,
    ce.fim_vigencia
  FROM
    codigos_explodidos ce
    LEFT JOIN materias m ON m.codigo_materia = ce.codigo_equivalente
)
SELECT
  materias_equivalentes.id_equivalencia,
  materias_equivalentes.codigo_materia_origem,
  materias_equivalentes.nome_materia_origem,
  materias_equivalentes.codigo_equivalente AS codigo_materia_equivalente,
  materias_equivalentes.nome_materia_equivalente,
  materias_equivalentes.expressao,
  materias_equivalentes.id_curso,
  materias_equivalentes.nome_curso,
  materias_equivalentes.matriz_curricular,
  materias_equivalentes.curriculo,
  materias_equivalentes.data_vigencia,
  materias_equivalentes.fim_vigencia
FROM
  materias_equivalentes;

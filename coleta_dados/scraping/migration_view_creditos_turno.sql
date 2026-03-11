-- Migration: adicionar id_curso, tipo_curso e turno à view vw_creditos_por_matriz
-- Necessário para exibição de diurno/noturno no frontend e deduplicação por id_curso

CREATE OR REPLACE VIEW public."vw_creditos_por_matriz" AS
SELECT m.id_matriz,
    m.id_curso,
    m.curriculo_completo,
    c.nome_curso,
    c.tipo_curso,
    c.turno,
    floor(((m.ch_obrigatoria_exigida)::numeric / 15.0)) AS cred_obrigatorio_exigido,
    floor(((m.ch_optativa_exigida)::numeric / 15.0)) AS cred_optativo_exigido,
    floor(((m.ch_complementar_exigida)::numeric / 15.0)) AS cred_complementar_exigido,
    floor(((m.ch_total_exigida)::numeric / 15.0)) AS cred_total_exigido,
    floor(((COALESCE(sum(mat.carga_horaria) FILTER (WHERE (mpc.nivel > 0)), (0)::bigint))::numeric / 15.0)) AS cred_obrigatorio_grade,
    floor(((COALESCE(sum(mat.carga_horaria) FILTER (WHERE (mpc.nivel = 0)), (0)::bigint))::numeric / 15.0)) AS cred_optativo_grade
FROM (((matrizes m
    JOIN cursos c ON ((c.id_curso = m.id_curso)))
    LEFT JOIN materias_por_curso mpc ON ((mpc.id_matriz = m.id_matriz)))
    LEFT JOIN materias mat ON ((mat.id_materia = mpc.id_materia)))
GROUP BY m.id_matriz, m.id_curso, m.curriculo_completo, c.nome_curso, c.tipo_curso, c.turno;

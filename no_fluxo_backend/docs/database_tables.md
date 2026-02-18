# Database Schema

> **Exported at:** 2026-02-16T06:18:23.09767+00:00
> **Export method:** rpc
> **Supabase:** lijmhbstgdinsukovyfl.supabase.co

---

## Tables

### ✅ `co_requisitos`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_co_requisito` | bigint | PK |  |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `id_materia_corequisito` | bigint |  | → `materias.id_materia` |

### ✅ `co_requisitos_backup`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_co_requisito` | bigint |  |  |
| `id_materia` | bigint |  |  |
| `id_materia_corequisito` | bigint |  |  |

### ✅ `cursos`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_curso` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `nome_curso` | text |  |  |
| `matriz_curricular` | text |  |  |
| `data_inicio_matriz` | date |  |  |
| `creditos` | numeric |  |  |
| `classificacao` | text |  |  |
| `tipo_curso` | text |  |  |

### ✅ `dados_users`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_dado_user` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `fluxograma_atual` | text |  |  |
| `id_user` | bigint |  | → `users.id_user` |
| `semestre_atual` | bigint |  |  |

### ✅ `dados_users_backup`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_dado_user` | bigint |  |  |
| `created_at` | timestamp with time zone |  |  |
| `fluxograma_atual` | text |  |  |
| `id_user` | bigint |  |  |
| `semestre_atual` | bigint |  |  |

### ✅ `equivalencia_backup1`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_equivalencia` | bigint |  |  |
| `id_materia` | bigint |  |  |
| `id_curso` | bigint |  |  |
| `expressao` | text |  |  |
| `matriz_curricular` | text |  |  |
| `curriculo` | text |  |  |
| `data_vigencia` | date |  |  |
| `fim_vigencia` | date |  |  |

### ✅ `equivalencias`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_equivalencia` | bigint | PK |  |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `id_curso` | bigint |  | → `cursos.id_curso` |
| `expressao` | text |  |  |
| `matriz_curricular` | text |  |  |
| `curriculo` | text |  |  |
| `data_vigencia` | date |  |  |
| `fim_vigencia` | date |  |  |

### ✅ `materias`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_materia` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `nome_materia` | text |  |  |
| `codigo_materia` | text |  |  |
| `carga_horaria` | bigint |  |  |
| `ementa` | text |  |  |
| `departamento` | text |  |  |

### ✅ `materias_por_curso`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_materia_curso` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `id_curso` | bigint |  | → `cursos.id_curso` |
| `nivel` | bigint |  |  |

### ✅ `pre_requisitos`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_pre_requisito` | bigint | PK |  |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `id_materia_requisito` | bigint |  | → `materias.id_materia` |

### ✅ `users`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_user` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `email` | text |  |  |
| `nome_completo` | text |  |  |
| `auth_id` | uuid |  |  |

### ✅ `users_backup`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_user` | bigint |  |  |
| `created_at` | timestamp with time zone |  |  |
| `email` | text |  |  |
| `nome_completo` | text |  |  |

---

## Views

### ✅ `creditos_por_curso`

```sql
 SELECT c.id_curso,
    c.nome_curso,
    floor((sum(
        CASE
            WHEN (mpc.nivel > 0) THEN m.carga_horaria
            ELSE (0)::bigint
        END) / 15.0)) AS creditos_obrigatorios,
    floor((sum(
        CASE
            WHEN (mpc.nivel = 0) THEN m.carga_horaria
            ELSE (0)::bigint
        END) / 15.0)) AS creditos_optativos,
    floor((sum(m.carga_horaria) / 15.0)) AS creditos_totais
   FROM ((cursos c
     LEFT JOIN materias_por_curso mpc ON ((mpc.id_curso = c.id_curso)))
     LEFT JOIN materias m ON ((m.id_materia = mpc.id_materia)))
  GROUP BY c.id_curso, c.nome_curso
  ORDER BY c.id_curso;
```

### ✅ `vw_equivalencias_com_materias`

```sql
 WITH codigos_explodidos AS (
         SELECT e.id_equivalencia,
            e.id_curso,
            e.matriz_curricular,
            e.curriculo,
            e.data_vigencia,
            e.fim_vigencia,
            e.expressao,
            m_origem.codigo_materia AS codigo_materia_origem,
            m_origem.nome_materia AS nome_materia_origem,
            c.nome_curso,
            regexp_split_to_table(regexp_replace(e.expressao, '[\(\)]'::text, ''::text, 'g'::text), '\s+(OU|ou|E|e)\s+'::text) AS codigo_equivalente
           FROM ((equivalencias e
             LEFT JOIN materias m_origem ON ((e.id_materia = m_origem.id_materia)))
             LEFT JOIN cursos c ON ((e.id_curso = c.id_curso)))
        ), materias_equivalentes AS (
         SELECT ce.id_equivalencia,
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
           FROM (codigos_explodidos ce
             LEFT JOIN materias m ON ((m.codigo_materia = ce.codigo_equivalente)))
        )
 SELECT materias_equivalentes.id_equivalencia,
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
   FROM materias_equivalentes;
```

### ✅ `vw_pre_requisitos_detalhado`

```sql
 SELECT pr.id_pre_requisito,
    pr.id_materia,
    m1.codigo_materia,
    m1.nome_materia,
    pr.id_materia_requisito,
    m2.codigo_materia AS codigo_requisito,
    m2.nome_materia AS nome_requisito,
    mpc.id_curso,
    c.nome_curso,
    c.matriz_curricular
   FROM ((((pre_requisitos pr
     JOIN materias m1 ON ((pr.id_materia = m1.id_materia)))
     JOIN materias m2 ON ((pr.id_materia_requisito = m2.id_materia)))
     JOIN materias_por_curso mpc ON ((mpc.id_materia = pr.id_materia)))
     JOIN cursos c ON ((mpc.id_curso = c.id_curso)));
```

---

## Functions

| Function | Return Type | Arguments |
|----------|-------------|-----------|
| `atualizar_creditos_cursos` | void | - |
| `calcular_creditos_por_curso` | integer | id_curso_input bigint |
| `export_schema` | jsonb | - |
| `gin_extract_query_trgm` | internal | text, internal, smallint, internal, internal, internal, internal |
| `gin_extract_value_trgm` | internal | text, internal |
| `gin_trgm_consistent` | boolean | internal, smallint, text, integer, internal, internal, internal, internal |
| `gin_trgm_triconsistent` | "char" | internal, smallint, text, integer, internal, internal, internal |
| `gtrgm_compress` | internal | internal |
| `gtrgm_consistent` | boolean | internal, text, smallint, oid, internal |
| `gtrgm_decompress` | internal | internal |
| `gtrgm_distance` | double precision | internal, text, smallint, oid, internal |
| `gtrgm_in` | gtrgm | cstring |
| `gtrgm_options` | void | internal |
| `gtrgm_out` | cstring | gtrgm |
| `gtrgm_penalty` | internal | internal, internal, internal |
| `gtrgm_picksplit` | internal | internal, internal |
| `gtrgm_same` | internal | gtrgm, gtrgm, internal |
| `gtrgm_union` | gtrgm | internal, internal |
| `set_limit` | real | real |
| `show_limit` | real | - |
| `show_trgm` | text[] | text |
| `similarity` | real | text, text |
| `similarity_dist` | real | text, text |
| `similarity_op` | boolean | text, text |
| `strict_word_similarity` | real | text, text |
| `strict_word_similarity_commutator_op` | boolean | text, text |
| `strict_word_similarity_dist_commutator_op` | real | text, text |
| `strict_word_similarity_dist_op` | real | text, text |
| `strict_word_similarity_op` | boolean | text, text |
| `update_updated_at` | trigger | - |
| `word_similarity` | real | text, text |
| `word_similarity_commutator_op` | boolean | text, text |
| `word_similarity_dist_commutator_op` | real | text, text |
| `word_similarity_dist_op` | real | text, text |
| `word_similarity_op` | boolean | text, text |

---

## RLS Policies

| Table | Policy | Command |
|-------|--------|---------|
| `co_requisitos` | co_requisitos_select_public | SELECT |
| `cursos` | cursos_select_public | SELECT |
| `dados_users` | dados_users_delete_own | DELETE |
| `dados_users` | dados_users_insert_own | INSERT |
| `dados_users` | dados_users_select_own | SELECT |
| `dados_users` | dados_users_update_own | UPDATE |
| `equivalencias` | equivalencias_select_public | SELECT |
| `materias` | materias_select_public | SELECT |
| `materias_por_curso` | materias_por_curso_select_public | SELECT |
| `pre_requisitos` | pre_requisitos_select_public | SELECT |
| `users` | users_insert_own | INSERT |
| `users` | users_select_own | SELECT |
| `users` | users_update_own | UPDATE |

---

## Indexes

| Index | Table |
|-------|-------|
| `co_requisitos_pkey` | `co_requisitos` |
| `cursos_pkey` | `cursos` |
| `dados_users_id_user_unique` | `dados_users` |
| `dados_users_pkey` | `dados_users` |
| `equivalencias_pkey` | `equivalencias` |
| `materias_codigo_materia_key` | `materias` |
| `materias_pkey` | `materias` |
| `materias_por_curso_pkey` | `materias_por_curso` |
| `pre_requisitos_pkey` | `pre_requisitos` |
| `idx_users_auth_id` | `users` |
| `users_auth_id_key` | `users` |
| `users_pkey` | `users` |

---

## Table Statistics

| Table | Estimated Rows | Size |
|-------|----------------|------|
| `co_requisitos` | 203 | 56 KB |
| `co_requisitos_backup` | 270 | 16 KB |
| `cursos` | 270 | 144 KB |
| `dados_users` | 99 | 472 KB |
| `dados_users_backup` | -1 | 8 KB |
| `equivalencia_backup1` | 37132 | 2.9 MB |
| `equivalencias` | 8090 | 1.1 MB |
| `materias` | 21127 | 8.9 MB |
| `materias_por_curso` | 75465 | 8.1 MB |
| `pre_requisitos` | 20889 | 1.6 MB |
| `users` | 162 | 128 KB |
| `users_backup` | -1 | 16 KB |

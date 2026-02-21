# Database Schema

> **Exported at:** 2026-02-21T02:45:34.066172+00:00
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
| `expressao_original` | text |  |  |
| `expressao_logica` | jsonb |  |  |

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
| `tipo_curso` | text |  |  |

### ✅ `dados_users`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_dado_user` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `fluxograma_atual` | text |  |  |
| `id_user` | bigint |  | → `users.id_user` |
| `semestre_atual` | bigint |  |  |

### ✅ `equivalencias`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_equivalencia` | bigint | PK |  |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `id_curso` | bigint |  | → `cursos.id_curso` |
| `curriculo` | text |  |  |
| `data_vigencia` | date |  |  |
| `fim_vigencia` | date |  |  |
| `expressao_logica` | jsonb |  |  |
| `expressao_original` | text |  |  |
| `id_matriz` | bigint |  | → `matrizes.id_matriz` |

### ✅ `equivalencias_backup_temp`

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

### ✅ `materias`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_materia` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `nome_materia` | text |  |  |
| `codigo_materia` | text |  |  |
| `carga_horaria` | integer |  |  |
| `ementa` | text |  |  |
| `departamento` | text |  |  |

### ✅ `materias_backup_temp`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_materia` | bigint |  |  |
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
| `nivel` | integer |  |  |
| `id_matriz` | bigint |  | → `matrizes.id_matriz` |

### ✅ `materias_por_curso_backup_temp`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_materia_curso` | bigint |  |  |
| `created_at` | timestamp with time zone |  |  |
| `id_materia` | bigint |  |  |
| `id_curso` | bigint |  |  |
| `nivel` | bigint |  |  |

### ✅ `matrizes`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_matriz` | bigint | PK |  |
| `id_curso` | bigint |  | → `cursos.id_curso` |
| `versao` | text |  |  |
| `ano_vigor` | text |  |  |
| `curriculo_completo` | text |  |  |
| `ch_obrigatoria_exigida` | integer |  |  |
| `ch_optativa_exigida` | integer |  |  |
| `ch_complementar_exigida` | integer |  |  |
| `ch_total_exigida` | integer |  |  |

### ✅ `pre_requisitos`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_pre_requisito` | bigint | PK |  |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `id_materia_requisito` | bigint |  | → `materias.id_materia` |
| `expressao_original` | text |  |  |
| `expressao_logica` | jsonb |  |  |

### ✅ `users`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_user` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `email` | text |  |  |
| `nome_completo` | text |  |  |
| `auth_id` | uuid |  |  |

---

## Views

### ✅ `vw_creditos_por_matriz`

```sql
 SELECT m.id_matriz,
    m.curriculo_completo,
    c.nome_curso,
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
  GROUP BY m.id_matriz, m.curriculo_completo, c.nome_curso;
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
| `unique_materia_grade_matriz` | `materias_por_curso` |
| `unique_materia_na_matriz` | `materias_por_curso` |
| `matrizes_curriculo_completo_key` | `matrizes` |
| `matrizes_pkey` | `matrizes` |
| `pre_requisitos_pkey` | `pre_requisitos` |
| `idx_users_auth_id` | `users` |
| `users_auth_id_key` | `users` |
| `users_pkey` | `users` |

---

## Table Statistics

| Table | Estimated Rows | Size |
|-------|----------------|------|
| `co_requisitos` | 185 | 80 KB |
| `co_requisitos_backup` | 270 | 16 KB |
| `cursos` | 102 | 64 KB |
| `dados_users` | 99 | 600 KB |
| `equivalencias` | 19445 | 4 MB |
| `equivalencias_backup_temp` | 8919 | 856 KB |
| `materias` | 25624 | 8.4 MB |
| `materias_backup_temp` | 21134 | 6.9 MB |
| `materias_por_curso` | 65955 | 13.1 MB |
| `materias_por_curso_backup_temp` | 75465 | 4.9 MB |
| `matrizes` | 235 | 96 KB |
| `pre_requisitos` | 14573 | 2.3 MB |
| `users` | 162 | 136 KB |

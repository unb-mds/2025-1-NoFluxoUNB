# Database Schema

> **Exported at:** 2026-02-27T17:44:42.150435+00:00
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

### ✅ `materias_vetorizadas`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_materia` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `nome_materia` | text |  |  |
| `codigo_materia` | text |  |  |
| `carga_horaria` | integer |  |  |
| `ementa` | text |  |  |
| `departamento` | text |  |  |
| `embedding` | USER-DEFINED |  |  |

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
    m.id_curso,
    m.curriculo_completo,
    c.nome_curso,
    c.tipo_curso,
    c.turno,
    floor(((m.ch_obrigatoria_exigida)::numeric / 15.0)) AS cred_obrigatorio_exigido,
    ...
  GROUP BY m.id_matriz, m.id_curso, m.curriculo_completo, c.nome_curso, c.tipo_curso, c.turno;
```

---

## Functions

| Function | Return Type | Arguments |
|----------|-------------|-----------|
| `array_to_halfvec` | halfvec | integer[], integer, boolean |
| `array_to_halfvec` | halfvec | real[], integer, boolean |
| `array_to_halfvec` | halfvec | numeric[], integer, boolean |
| `array_to_halfvec` | halfvec | double precision[], integer, boolean |
| `array_to_sparsevec` | sparsevec | real[], integer, boolean |
| `array_to_sparsevec` | sparsevec | integer[], integer, boolean |
| `array_to_sparsevec` | sparsevec | numeric[], integer, boolean |
| `array_to_sparsevec` | sparsevec | double precision[], integer, boolean |
| `array_to_vector` | vector | numeric[], integer, boolean |
| `array_to_vector` | vector | integer[], integer, boolean |
| `array_to_vector` | vector | real[], integer, boolean |
| `array_to_vector` | vector | double precision[], integer, boolean |
| `atualizar_creditos_cursos` | void | - |
| `binary_quantize` | bit | vector |
| `binary_quantize` | bit | halfvec |
| `calcular_creditos_por_curso` | integer | id_curso_input bigint |
| `cosine_distance` | double precision | halfvec, halfvec |
| `cosine_distance` | double precision | vector, vector |
| `cosine_distance` | double precision | sparsevec, sparsevec |
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
| `halfvec` | halfvec | halfvec, integer, boolean |
| `halfvec_accum` | double precision[] | double precision[], halfvec |
| `halfvec_add` | halfvec | halfvec, halfvec |
| `halfvec_avg` | halfvec | double precision[] |
| `halfvec_cmp` | integer | halfvec, halfvec |
| `halfvec_combine` | double precision[] | double precision[], double precision[] |
| `halfvec_concat` | halfvec | halfvec, halfvec |
| `halfvec_eq` | boolean | halfvec, halfvec |
| `halfvec_ge` | boolean | halfvec, halfvec |
| `halfvec_gt` | boolean | halfvec, halfvec |
| `halfvec_in` | halfvec | cstring, oid, integer |
| `halfvec_l2_squared_distance` | double precision | halfvec, halfvec |
| `halfvec_le` | boolean | halfvec, halfvec |
| `halfvec_lt` | boolean | halfvec, halfvec |
| `halfvec_mul` | halfvec | halfvec, halfvec |
| `halfvec_ne` | boolean | halfvec, halfvec |
| `halfvec_negative_inner_product` | double precision | halfvec, halfvec |
| `halfvec_out` | cstring | halfvec |
| `halfvec_recv` | halfvec | internal, oid, integer |
| `halfvec_send` | bytea | halfvec |
| `halfvec_spherical_distance` | double precision | halfvec, halfvec |
| `halfvec_sub` | halfvec | halfvec, halfvec |
| `halfvec_to_float4` | real[] | halfvec, integer, boolean |
| `halfvec_to_sparsevec` | sparsevec | halfvec, integer, boolean |
| `halfvec_to_vector` | vector | halfvec, integer, boolean |
| `halfvec_typmod_in` | integer | cstring[] |
| `hamming_distance` | double precision | bit, bit |
| `hnsw_bit_support` | internal | internal |
| `hnsw_halfvec_support` | internal | internal |
| `hnsw_sparsevec_support` | internal | internal |
| `hnswhandler` | index_am_handler | internal |
| `inner_product` | double precision | sparsevec, sparsevec |
| `inner_product` | double precision | vector, vector |
| `inner_product` | double precision | halfvec, halfvec |
| `ivfflat_bit_support` | internal | internal |
| `ivfflat_halfvec_support` | internal | internal |
| `ivfflathandler` | index_am_handler | internal |
| `jaccard_distance` | double precision | bit, bit |
| `l1_distance` | double precision | halfvec, halfvec |
| `l1_distance` | double precision | sparsevec, sparsevec |
| `l1_distance` | double precision | vector, vector |
| `l2_distance` | double precision | vector, vector |
| `l2_distance` | double precision | sparsevec, sparsevec |
| `l2_distance` | double precision | halfvec, halfvec |
| `l2_norm` | double precision | halfvec |
| `l2_norm` | double precision | sparsevec |
| `l2_normalize` | vector | vector |
| `l2_normalize` | halfvec | halfvec |
| `l2_normalize` | sparsevec | sparsevec |
| `match_materias` | TABLE(codigo_materia text, nome_materia text, departamento text, ementa text, similaridade double precision) | query_embedding vector, match_threshold double precision, match_count integer |
| `set_limit` | real | real |
| `show_limit` | real | - |
| `show_trgm` | text[] | text |
| `similarity` | real | text, text |
| `similarity_dist` | real | text, text |
| `similarity_op` | boolean | text, text |
| `sparsevec` | sparsevec | sparsevec, integer, boolean |
| `sparsevec_cmp` | integer | sparsevec, sparsevec |
| `sparsevec_eq` | boolean | sparsevec, sparsevec |
| `sparsevec_ge` | boolean | sparsevec, sparsevec |
| `sparsevec_gt` | boolean | sparsevec, sparsevec |
| `sparsevec_in` | sparsevec | cstring, oid, integer |
| `sparsevec_l2_squared_distance` | double precision | sparsevec, sparsevec |
| `sparsevec_le` | boolean | sparsevec, sparsevec |
| `sparsevec_lt` | boolean | sparsevec, sparsevec |
| `sparsevec_ne` | boolean | sparsevec, sparsevec |
| `sparsevec_negative_inner_product` | double precision | sparsevec, sparsevec |
| `sparsevec_out` | cstring | sparsevec |
| `sparsevec_recv` | sparsevec | internal, oid, integer |
| `sparsevec_send` | bytea | sparsevec |
| `sparsevec_to_halfvec` | halfvec | sparsevec, integer, boolean |
| `sparsevec_to_vector` | vector | sparsevec, integer, boolean |
| `sparsevec_typmod_in` | integer | cstring[] |
| `strict_word_similarity` | real | text, text |
| `strict_word_similarity_commutator_op` | boolean | text, text |
| `strict_word_similarity_dist_commutator_op` | real | text, text |
| `strict_word_similarity_dist_op` | real | text, text |
| `strict_word_similarity_op` | boolean | text, text |
| `subvector` | halfvec | halfvec, integer, integer |
| `subvector` | vector | vector, integer, integer |
| `update_updated_at` | trigger | - |
| `vector` | vector | vector, integer, boolean |
| `vector_accum` | double precision[] | double precision[], vector |
| `vector_add` | vector | vector, vector |
| `vector_avg` | vector | double precision[] |
| `vector_cmp` | integer | vector, vector |
| `vector_combine` | double precision[] | double precision[], double precision[] |
| `vector_concat` | vector | vector, vector |
| `vector_dims` | integer | halfvec |
| `vector_dims` | integer | vector |
| `vector_eq` | boolean | vector, vector |
| `vector_ge` | boolean | vector, vector |
| `vector_gt` | boolean | vector, vector |
| `vector_in` | vector | cstring, oid, integer |
| `vector_l2_squared_distance` | double precision | vector, vector |
| `vector_le` | boolean | vector, vector |
| `vector_lt` | boolean | vector, vector |
| `vector_mul` | vector | vector, vector |
| `vector_ne` | boolean | vector, vector |
| `vector_negative_inner_product` | double precision | vector, vector |
| `vector_norm` | double precision | vector |
| `vector_out` | cstring | vector |
| `vector_recv` | vector | internal, oid, integer |
| `vector_send` | bytea | vector |
| `vector_spherical_distance` | double precision | vector, vector |
| `vector_sub` | vector | vector, vector |
| `vector_to_float4` | real[] | vector, integer, boolean |
| `vector_to_halfvec` | halfvec | vector, integer, boolean |
| `vector_to_sparsevec` | sparsevec | vector, integer, boolean |
| `vector_typmod_in` | integer | cstring[] |
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
| `materias_vetorizadas_pkey` | `materias_vetorizadas` |
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
| `dados_users` | 99 | 544 KB |
| `equivalencias` | 19445 | 4 MB |
| `equivalencias_backup_temp` | 8919 | 856 KB |
| `materias` | 25624 | 8.4 MB |
| `materias_backup_temp` | 21134 | 6.9 MB |
| `materias_por_curso` | 65955 | 13.1 MB |
| `materias_por_curso_backup_temp` | 75465 | 4.9 MB |
| `materias_vetorizadas` | 27267 | 53.1 MB |
| `matrizes` | 235 | 96 KB |
| `pre_requisitos` | 14573 | 2.3 MB |
| `users` | 162 | 136 KB |

# Database Schema

> **Exported at:** 2026-03-20T13:54:57.594847+00:00
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

### ✅ `cursos`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_curso` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `nome_curso` | text |  |  |
| `tipo_curso` | text |  |  |
| `turno` | text |  |  |
| `campus` | text |  |  |

### ✅ `dados_users`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_dado_user` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `fluxograma_atual` | text |  |  |
| `id_user` | bigint |  | → `users.id_user` |
| `semestre_atual` | bigint |  |  |
| `carga_horaria_integralizada` | jsonb |  |  |

### ✅ `equivalencias`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_equivalencia` | bigint | PK |  |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `id_curso` | bigint |  | → `cursos.id_curso` |
| `curriculo` | text |  |  |
| `data_vigencia` | date |  |  |
| `expressao_logica` | jsonb |  |  |
| `expressao_original` | text |  |  |

### ✅ `historicos_usuarios`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_historico` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `id_user` | bigint |  | → `users.id_user` |
| `id_dado_user` | bigint |  | → `dados_users.id_dado_user` |
| `curso_extraido` | text |  |  |
| `matriz_curricular` | text |  |  |
| `matricula` | text |  |  |
| `semestre_atual` | bigint |  |  |
| `numero_semestre` | bigint |  |  |
| `ira` | numeric |  |  |
| `media_ponderada` | numeric |  |  |
| `carga_horaria_integralizada` | jsonb |  |  |
| `suspensoes` | jsonb |  |  |
| `fluxograma_atual` | jsonb |  |  |
| `total_disciplinas` | integer |  |  |
| `total_obrigatorias` | integer |  |  |
| `total_obrigatorias_concluidas` | integer |  |  |
| `total_obrigatorias_pendentes` | integer |  |  |
| `percentual_conclusao` | numeric |  |  |

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

### ✅ `materias_por_curso`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_materia_curso` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `nivel` | integer |  |  |
| `id_matriz` | bigint |  | → `matrizes.id_matriz` |
| `tipo_natureza` | integer |  |  |

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
| `array_to_halfvec` | halfvec | numeric[], integer, boolean |
| `array_to_halfvec` | halfvec | real[], integer, boolean |
| `array_to_halfvec` | halfvec | integer[], integer, boolean |
| `array_to_halfvec` | halfvec | double precision[], integer, boolean |
| `array_to_sparsevec` | sparsevec | integer[], integer, boolean |
| `array_to_sparsevec` | sparsevec | real[], integer, boolean |
| `array_to_sparsevec` | sparsevec | numeric[], integer, boolean |
| `array_to_sparsevec` | sparsevec | double precision[], integer, boolean |
| `array_to_vector` | vector | real[], integer, boolean |
| `array_to_vector` | vector | numeric[], integer, boolean |
| `array_to_vector` | vector | integer[], integer, boolean |
| `array_to_vector` | vector | double precision[], integer, boolean |
| `atualizar_creditos_cursos` | void | - |
| `binary_quantize` | bit | vector |
| `binary_quantize` | bit | halfvec |
| `calcular_creditos_por_curso` | integer | id_curso_input bigint |
| `casar_disciplinas` | jsonb | p_dados jsonb |
| `cosine_distance` | double precision | halfvec, halfvec |
| `cosine_distance` | double precision | vector, vector |
| `cosine_distance` | double precision | sparsevec, sparsevec |
| `export_schema` | jsonb | - |
| `get_equivalencias_materia` | TABLE(id_equivalencia integer, id_materia integer, codigo_materia_origem text, nome_materia_origem text, curriculo text, expressao_original text, expressao_logica jsonb) | p_codigo text DEFAULT NULL::text, p_nome text DEFAULT NULL::text |
| `get_pre_requisitos_materia` | TABLE(id_pre_requisito integer, id_materia integer, codigo_materia text, nome_materia text, expressao_original text, expressao_logica jsonb, codigo_requisito text, nome_requisito text) | p_codigo text DEFAULT NULL::text, p_nome text DEFAULT NULL::text |
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
| `inner_product` | double precision | halfvec, halfvec |
| `inner_product` | double precision | sparsevec, sparsevec |
| `inner_product` | double precision | vector, vector |
| `ivfflat_bit_support` | internal | internal |
| `ivfflat_halfvec_support` | internal | internal |
| `ivfflathandler` | index_am_handler | internal |
| `jaccard_distance` | double precision | bit, bit |
| `l1_distance` | double precision | sparsevec, sparsevec |
| `l1_distance` | double precision | vector, vector |
| `l1_distance` | double precision | halfvec, halfvec |
| `l2_distance` | double precision | sparsevec, sparsevec |
| `l2_distance` | double precision | halfvec, halfvec |
| `l2_distance` | double precision | vector, vector |
| `l2_norm` | double precision | sparsevec |
| `l2_norm` | double precision | halfvec |
| `l2_normalize` | sparsevec | sparsevec |
| `l2_normalize` | vector | vector |
| `l2_normalize` | halfvec | halfvec |
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
| `subvector` | vector | vector, integer, integer |
| `subvector` | halfvec | halfvec, integer, integer |
| `update_updated_at` | trigger | - |
| `vector` | vector | vector, integer, boolean |
| `vector_accum` | double precision[] | double precision[], vector |
| `vector_add` | vector | vector, vector |
| `vector_avg` | vector | double precision[] |
| `vector_cmp` | integer | vector, vector |
| `vector_combine` | double precision[] | double precision[], double precision[] |
| `vector_concat` | vector | vector, vector |
| `vector_dims` | integer | vector |
| `vector_dims` | integer | halfvec |
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
| `historicos_usuarios` | historicos_usuarios_insert_own | INSERT |
| `historicos_usuarios` | historicos_usuarios_select_own | SELECT |
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
| `idx_cursos_turno` | `cursos` |
| `dados_users_id_user_unique` | `dados_users` |
| `dados_users_pkey` | `dados_users` |
| `equivalencias_pkey` | `equivalencias` |
| `historicos_usuarios_pkey` | `historicos_usuarios` |
| `idx_historicos_usuarios_created_at` | `historicos_usuarios` |
| `idx_historicos_usuarios_id_dado_user` | `historicos_usuarios` |
| `idx_historicos_usuarios_id_user` | `historicos_usuarios` |
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
| `cursos` | 154 | 96 KB |
| `dados_users` | 236 | 656 KB |
| `equivalencias` | 23687 | 5.8 MB |
| `historicos_usuarios` | 163 | 776 KB |
| `materias` | 26223 | 8.7 MB |
| `materias_por_curso` | 149336 | 39.5 MB |
| `materias_vetorizadas` | 26145 | 57.5 MB |
| `matrizes` | 518 | 200 KB |
| `pre_requisitos` | 15507 | 2.5 MB |
| `users` | 373 | 184 KB |

# Database Schema

> **Exported at:** 2026-07-16T23:00:16.419383+00:00
> **Export method:** rpc
> **Supabase:** lijmhbstgdinsukovyfl.supabase.co

---

## Tables

### ✅ `admins`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `auth_id` | uuid | PK |  |
| `role` | text |  |  |
| `scopes` | ARRAY |  |  |
| `note` | text |  |  |
| `created_at` | timestamp with time zone |  |  |
| `created_by` | uuid |  |  |

### ✅ `ai_pricing`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `model` | text | PK |  |
| `input_per_1k` | numeric |  |  |
| `output_per_1k` | numeric |  |  |
| `currency` | text |  |  |
| `updated_at` | timestamp with time zone |  |  |
| `updated_by` | uuid |  |  |

### ✅ `ai_usage_log`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `endpoint` | text |  |  |
| `model` | text |  |  |
| `prompt_tokens` | integer |  |  |
| `completion_tokens` | integer |  |  |
| `total_tokens` | integer |  |  |
| `duration_ms` | integer |  |  |
| `success` | boolean |  |  |
| `request_excerpt` | text |  |  |

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
| `optativas_manuais` | jsonb |  |  |
| `preferencias_plano` | jsonb |  |  |

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
| `dificuldade_estimada` | smallint |  |  |
| `motivo_dificuldade` | text |  |  |
| `dificuldade_calculada_em` | timestamp with time zone |  |  |

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

### ✅ `notificacoes`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_notificacao` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `id_user` | bigint |  | → `users.id_user` |
| `tipo` | text |  |  |
| `titulo` | text |  |  |
| `mensagem` | text |  |  |
| `metadata` | jsonb |  |  |
| `lida` | boolean |  |  |
| `lida_em` | timestamp with time zone |  |  |

### ✅ `pre_requisitos`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_pre_requisito` | bigint | PK |  |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `id_materia_requisito` | bigint |  | → `materias.id_materia` |
| `expressao_original` | text |  |  |
| `expressao_logica` | jsonb |  |  |

### ✅ `system_settings`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `key` | text | PK |  |
| `value` | jsonb |  |  |
| `description` | text |  |  |
| `updated_at` | timestamp with time zone |  |  |
| `updated_by` | uuid |  |  |

### ✅ `ticket_audit_log`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id` | bigint | PK |  |
| `ticket_id` | bigint |  | → `tickets.id` |
| `actor_id` | uuid |  |  |
| `action` | text |  |  |
| `from_value` | text |  |  |
| `to_value` | text |  |  |
| `notes` | text |  |  |
| `created_at` | timestamp with time zone |  |  |

### ✅ `tickets`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id` | bigint | PK |  |
| `created_by` | uuid |  |  |
| `assigned_to` | uuid |  |  |
| `title` | text |  |  |
| `description` | text |  |  |
| `category` | text |  |  |
| `status` | text |  |  |
| `priority` | text |  |  |
| `metadata` | jsonb |  |  |
| `attachments` | jsonb |  |  |
| `admin_notes` | text |  |  |
| `created_at` | timestamp with time zone |  |  |
| `updated_at` | timestamp with time zone |  |  |
| `resolved_at` | timestamp with time zone |  |  |

### ✅ `turmas`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_turmas` | bigint | PK |  |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `created_at` | timestamp with time zone |  |  |
| `last_updated_at` | timestamp with time zone |  |  |
| `turma` | text |  |  |
| `docente` | text |  |  |
| `horario` | text |  |  |
| `local` | text |  |  |
| `ano_periodo` | text |  |  |
| `vagas_ofertadas` | integer |  |  |
| `vagas_ocupadas` | integer |  |  |
| `vagas_sobrando` | integer |  |  |

### ✅ `turmas_historico`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_historico` | bigint | PK |  |
| `id_turmas` | bigint |  | → `turmas.id_turmas` |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `turma` | text |  |  |
| `ano_periodo` | text |  |  |
| `observed_at` | timestamp with time zone |  |  |
| `vagas_ofertadas` | integer |  |  |
| `vagas_ocupadas` | integer |  |  |
| `vagas_sobrando` | integer |  |  |
| `docente` | text |  |  |
| `horario` | text |  |  |
| `local` | text |  |  |

### ✅ `users`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_user` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `email` | text |  |  |
| `nome_completo` | text |  |  |
| `auth_id` | uuid |  |  |

### ✅ `vaga_assinaturas`

| Column | Type | PK | Foreign Key |
|--------|------|----|-------------|
| `id_assinatura` | bigint | PK |  |
| `created_at` | timestamp with time zone |  |  |
| `id_user` | bigint |  | → `users.id_user` |
| `id_materia` | bigint |  | → `materias.id_materia` |
| `turma` | text |  |  |
| `ano_periodo` | text |  |  |
| `ativa` | boolean |  |  |

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
| `array_to_halfvec` | halfvec | integer[], integer, boolean |
| `array_to_halfvec` | halfvec | double precision[], integer, boolean |
| `array_to_halfvec` | halfvec | real[], integer, boolean |
| `array_to_halfvec` | halfvec | numeric[], integer, boolean |
| `array_to_sparsevec` | sparsevec | integer[], integer, boolean |
| `array_to_sparsevec` | sparsevec | numeric[], integer, boolean |
| `array_to_sparsevec` | sparsevec | double precision[], integer, boolean |
| `array_to_sparsevec` | sparsevec | real[], integer, boolean |
| `array_to_vector` | vector | double precision[], integer, boolean |
| `array_to_vector` | vector | numeric[], integer, boolean |
| `array_to_vector` | vector | real[], integer, boolean |
| `array_to_vector` | vector | integer[], integer, boolean |
| `atualizar_creditos_cursos` | void | - |
| `binary_quantize` | bit | vector |
| `binary_quantize` | bit | halfvec |
| `calcular_creditos_por_curso` | integer | id_curso_input bigint |
| `casar_disciplinas` | jsonb | p_dados jsonb |
| `cosine_distance` | double precision | halfvec, halfvec |
| `cosine_distance` | double precision | vector, vector |
| `cosine_distance` | double precision | sparsevec, sparsevec |
| `deixar_de_seguir_materia` | void | p_id_assinatura bigint |
| `export_schema` | jsonb | - |
| `get_ai_cost_metrics` | jsonb | p_days integer DEFAULT 30 |
| `get_dashboard_overview` | jsonb | - |
| `get_equivalencias_materia` | TABLE(id_equivalencia integer, id_materia integer, codigo_materia_origem text, nome_materia_origem text, curriculo text, expressao_original text, expressao_logica jsonb) | p_codigo text DEFAULT NULL::text, p_nome text DEFAULT NULL::text |
| `get_my_admin` | jsonb | - |
| `get_pre_requisitos_materia` | TABLE(id_pre_requisito integer, id_materia integer, codigo_materia text, nome_materia text, expressao_original text, expressao_logica jsonb, codigo_requisito text, nome_requisito text) | p_codigo text DEFAULT NULL::text, p_nome text DEFAULT NULL::text |
| `get_scraping_health` | jsonb | - |
| `get_system_setting` | jsonb | p_key text |
| `get_ticket_by_id` | jsonb | p_id bigint |
| `get_ticket_metrics` | jsonb | - |
| `get_tickets_paginated` | TABLE(id bigint, title text, description text, status text, category text, priority text, created_by uuid, creator_name text, creator_email text, assigned_to uuid, created_at timestamp with time zone, updated_at timestamp with time zone, resolved_at timestamp with time zone, total_count bigint) | p_limit integer DEFAULT 50, p_offset integer DEFAULT 0, p_status text DEFAULT NULL::text, p_category text DEFAULT NULL::text, p_search text DEFAULT NULL::text |
| `get_top_cursos` | TABLE(curso text, usuarios bigint) | p_limit integer DEFAULT 10 |
| `get_turmas_demanda` | jsonb | p_periodo text DEFAULT NULL::text |
| `get_user_growth` | TABLE(bucket date, novos bigint, acumulado bigint) | p_days integer DEFAULT 30, p_bucket text DEFAULT 'day'::text |
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
| `has_admin_scope` | boolean | p_scope text |
| `hnsw_bit_support` | internal | internal |
| `hnsw_halfvec_support` | internal | internal |
| `hnsw_sparsevec_support` | internal | internal |
| `hnswhandler` | index_am_handler | internal |
| `inner_product` | double precision | halfvec, halfvec |
| `inner_product` | double precision | sparsevec, sparsevec |
| `inner_product` | double precision | vector, vector |
| `is_admin` | boolean | - |
| `is_superadmin` | boolean | - |
| `is_ticket_admin` | boolean | - |
| `ivfflat_bit_support` | internal | internal |
| `ivfflat_halfvec_support` | internal | internal |
| `ivfflathandler` | index_am_handler | internal |
| `jaccard_distance` | double precision | bit, bit |
| `l1_distance` | double precision | vector, vector |
| `l1_distance` | double precision | sparsevec, sparsevec |
| `l1_distance` | double precision | halfvec, halfvec |
| `l2_distance` | double precision | vector, vector |
| `l2_distance` | double precision | sparsevec, sparsevec |
| `l2_distance` | double precision | halfvec, halfvec |
| `l2_norm` | double precision | halfvec |
| `l2_norm` | double precision | sparsevec |
| `l2_normalize` | vector | vector |
| `l2_normalize` | halfvec | halfvec |
| `l2_normalize` | sparsevec | sparsevec |
| `listar_minhas_assinaturas` | SETOF vaga_assinaturas | - |
| `listar_notificacoes` | jsonb | p_limit integer DEFAULT 30, p_somente_nao_lidas boolean DEFAULT false |
| `marcar_notificacao_lida` | void | p_id_notificacao bigint DEFAULT NULL::bigint |
| `match_materias` | TABLE(codigo_materia text, nome_materia text, departamento text, ementa text, similaridade double precision) | query_embedding vector, match_threshold double precision, match_count integer |
| `notificar_vaga_disponivel` | trigger | - |
| `periodo_letivo_atual` | text | - |
| `registrar_turma_historico` | trigger | - |
| `seguir_materia` | vaga_assinaturas | p_id_materia bigint, p_turma text, p_ano_periodo text |
| `set_last_updated_at` | trigger | - |
| `set_limit` | real | real |
| `set_system_setting` | system_settings | p_key text, p_value jsonb |
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
| `tickets_on_insert` | trigger | - |
| `tickets_on_update` | trigger | - |
| `update_ticket_status` | tickets | p_id bigint, p_status text, p_note text DEFAULT NULL::text |
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
| `admins` | admins_delete_superadmin | DELETE |
| `admins` | admins_insert_superadmin | INSERT |
| `admins` | admins_select_self_or_superadmin | SELECT |
| `admins` | admins_update_superadmin | UPDATE |
| `ai_pricing` | ai_pricing_select_dashboard | SELECT |
| `ai_pricing` | ai_pricing_write_superadmin | ALL |
| `ai_usage_log` | ai_usage_select_dashboard | SELECT |
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
| `notificacoes` | notificacoes_select_own | SELECT |
| `notificacoes` | notificacoes_update_own | UPDATE |
| `pre_requisitos` | pre_requisitos_select_public | SELECT |
| `system_settings` | system_settings_select_authenticated | SELECT |
| `ticket_audit_log` | audit_select_own_or_admin | SELECT |
| `tickets` | tickets_delete_admin | DELETE |
| `tickets` | tickets_insert_own | INSERT |
| `tickets` | tickets_select_own_or_admin | SELECT |
| `tickets` | tickets_update_admin | UPDATE |
| `turmas` | turmas_select_public | SELECT |
| `users` | users_insert_own | INSERT |
| `users` | users_select_own | SELECT |
| `users` | users_update_own | UPDATE |
| `vaga_assinaturas` | vaga_assinaturas_delete_own | DELETE |
| `vaga_assinaturas` | vaga_assinaturas_insert_own | INSERT |
| `vaga_assinaturas` | vaga_assinaturas_select_own | SELECT |
| `vaga_assinaturas` | vaga_assinaturas_update_own | UPDATE |

---

## Indexes

| Index | Table |
|-------|-------|
| `admins_pkey` | `admins` |
| `idx_admins_role` | `admins` |
| `ai_pricing_pkey` | `ai_pricing` |
| `ai_usage_log_pkey` | `ai_usage_log` |
| `idx_ai_usage_created_at` | `ai_usage_log` |
| `idx_ai_usage_model` | `ai_usage_log` |
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
| `idx_notificacoes_id_user_nao_lida` | `notificacoes` |
| `notificacoes_pkey` | `notificacoes` |
| `pre_requisitos_pkey` | `pre_requisitos` |
| `system_settings_pkey` | `system_settings` |
| `idx_ticket_audit_ticket` | `ticket_audit_log` |
| `ticket_audit_log_pkey` | `ticket_audit_log` |
| `idx_tickets_category` | `tickets` |
| `idx_tickets_created_at` | `tickets` |
| `idx_tickets_created_by` | `tickets` |
| `idx_tickets_metadata` | `tickets` |
| `idx_tickets_status` | `tickets` |
| `tickets_pkey` | `tickets` |
| `turmas_pkey` | `turmas` |
| `uq_turmas_oferta` | `turmas` |
| `idx_turmas_historico_materia_periodo` | `turmas_historico` |
| `idx_turmas_historico_observed_at` | `turmas_historico` |
| `turmas_historico_pkey` | `turmas_historico` |
| `idx_users_auth_id` | `users` |
| `users_auth_id_key` | `users` |
| `users_pkey` | `users` |
| `idx_vaga_assinaturas_id_user` | `vaga_assinaturas` |
| `idx_vaga_assinaturas_materia_ativa` | `vaga_assinaturas` |
| `uq_vaga_assinatura` | `vaga_assinaturas` |
| `vaga_assinaturas_pkey` | `vaga_assinaturas` |

---

## Table Statistics

| Table | Estimated Rows | Size |
|-------|----------------|------|
| `admins` | -1 | 48 KB |
| `ai_pricing` | -1 | 32 KB |
| `ai_usage_log` | 395 | 176 KB |
| `co_requisitos` | 185 | 80 KB |
| `cursos` | 154 | 96 KB |
| `dados_users` | 1334 | 2.7 MB |
| `equivalencias` | 23687 | 5.8 MB |
| `historicos_usuarios` | 2121 | 5.1 MB |
| `materias` | 26223 | 9 MB |
| `materias_por_curso` | 141184 | 40.3 MB |
| `materias_vetorizadas` | 26145 | 57.5 MB |
| `matrizes` | 518 | 200 KB |
| `notificacoes` | -1 | 24 KB |
| `pre_requisitos` | 15507 | 2.5 MB |
| `system_settings` | -1 | 32 KB |
| `ticket_audit_log` | -1 | 48 KB |
| `tickets` | -1 | 128 KB |
| `turmas` | 12807 | 3.8 MB |
| `turmas_historico` | 12807 | 3 MB |
| `users` | 1778 | 488 KB |
| `vaga_assinaturas` | -1 | 40 KB |

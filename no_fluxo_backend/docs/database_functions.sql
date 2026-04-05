-- Database Functions Export
-- Exported at: 2026-03-20T13:54:57.594847+00:00
-- Source: lijmhbstgdinsukovyfl.supabase.co
-- Total functions: 153

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Other Functions
-- -----------------------------------------------------------------------------

-- Function: array_to_halfvec
-- Return type: halfvec
-- Arguments: numeric[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_halfvec(numeric[], integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_halfvec$function$;

-- Function: array_to_halfvec
-- Return type: halfvec
-- Arguments: real[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_halfvec(real[], integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_halfvec$function$;

-- Function: array_to_halfvec
-- Return type: halfvec
-- Arguments: integer[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_halfvec(integer[], integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_halfvec$function$;

-- Function: array_to_halfvec
-- Return type: halfvec
-- Arguments: double precision[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_halfvec(double precision[], integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_halfvec$function$;

-- Function: array_to_sparsevec
-- Return type: sparsevec
-- Arguments: integer[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_sparsevec(integer[], integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_sparsevec$function$;

-- Function: array_to_sparsevec
-- Return type: sparsevec
-- Arguments: real[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_sparsevec(real[], integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_sparsevec$function$;

-- Function: array_to_sparsevec
-- Return type: sparsevec
-- Arguments: numeric[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_sparsevec(numeric[], integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_sparsevec$function$;

-- Function: array_to_sparsevec
-- Return type: sparsevec
-- Arguments: double precision[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_sparsevec(double precision[], integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_sparsevec$function$;

-- Function: array_to_vector
-- Return type: vector
-- Arguments: real[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_vector(real[], integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_vector$function$;

-- Function: array_to_vector
-- Return type: vector
-- Arguments: numeric[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_vector(numeric[], integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_vector$function$;

-- Function: array_to_vector
-- Return type: vector
-- Arguments: integer[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_vector(integer[], integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_vector$function$;

-- Function: array_to_vector
-- Return type: vector
-- Arguments: double precision[], integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.array_to_vector(double precision[], integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_vector$function$;

-- Function: atualizar_creditos_cursos
-- Return type: void
-- Arguments: (none)
-- Volatility: VOLATILE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.atualizar_creditos_cursos()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    curso_row RECORD;
    total_carga_horaria INTEGER;
    total_creditos INTEGER;
BEGIN
    FOR curso_row IN SELECT id_curso FROM cursos LOOP
        -- Soma a carga horária total das matérias do curso atual
        SELECT SUM(m.carga_horaria)
        INTO total_carga_horaria
        FROM materias_por_curso mpc
        JOIN materias m ON m.id_materia = mpc.id_materia
        WHERE mpc.id_curso = curso_row.id_curso;

        -- Se o curso não tiver matérias, pula
        IF total_carga_horaria IS NULL THEN
            CONTINUE;
        END IF;

        -- Calcula os créditos inteiros (1 crédito = 15 horas)
        total_creditos := FLOOR(total_carga_horaria / 15.0);

        -- Atualiza a coluna creditos como número inteiro
        UPDATE cursos
        SET creditos = total_creditos
        WHERE id_curso = curso_row.id_curso;
    END LOOP;
END;
$function$;

-- Function: binary_quantize
-- Return type: bit
-- Arguments: vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.binary_quantize(vector)
 RETURNS bit
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$binary_quantize$function$;

-- Function: binary_quantize
-- Return type: bit
-- Arguments: halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.binary_quantize(halfvec)
 RETURNS bit
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_binary_quantize$function$;

-- Function: calcular_creditos_por_curso
-- Return type: integer
-- Arguments: id_curso_input bigint
-- Volatility: VOLATILE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.calcular_creditos_por_curso(id_curso_input bigint)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    total_horas INTEGER;
BEGIN
    SELECT SUM(horas)
    INTO total_horas
    FROM (
        SELECT DISTINCT
            LOWER(TRIM(m.nome_materia)) AS nome_normalizado,
            CAST(NULLIF(REGEXP_REPLACE(m.carga_horaria, '[^0-9]', '', 'g'), '') AS INTEGER) AS horas
        FROM materias m
        JOIN materias_por_curso mpc ON m.id_materia = mpc.id_materia
        WHERE mpc.id_curso = id_curso_input
          AND mpc.nivel > 0
          AND m.carga_horaria IS NOT NULL
          AND REGEXP_REPLACE(m.carga_horaria, '[^0-9]', '', 'g') <> ''
    ) AS materias_unicas;

    IF total_horas IS NULL THEN
        RETURN 0;
    END IF;

    RETURN FLOOR(total_horas / 15);
END;
$function$;

-- Function: casar_disciplinas
-- Return type: jsonb
-- Arguments: p_dados jsonb
-- Volatility: VOLATILE
-- Security definer: YES

CREATE OR REPLACE FUNCTION public.casar_disciplinas(p_dados jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  -- Input
  v_extracted_data    jsonb;
  v_curso_extraido    text;
  v_matriz_curricular text;
  v_media_ponderada   numeric;
  v_frequencia_geral  numeric;
  v_id_curso_sel      bigint;
  v_curso_sel         text;

  -- Course resolution
  v_id_curso          bigint;
  v_nome_curso        text;
  v_id_matriz         bigint;
  v_curriculo         text;
  v_count             int;
  v_search_name       text;

  -- Discipline loop
  v_i                 int;
  v_len               int;
  v_item              jsonb;
  v_disc_codigo       text;
  v_disc_nome         text;
  v_disc_status       text;
  v_match_id          bigint;
  v_match_codigo      text;
  v_match_nome        text;
  v_match_nivel       int;
  v_match_tipo_natureza int;  -- 0=obrigatória, 1=optativa (prioridade sobre nivel)
  v_old_status        text;

  -- Aggregation
  v_ira               numeric;
  v_pendencias        jsonb := '[]'::jsonb;
  v_horas             int := 0;

  -- Result builders
  v_cursos_disp       jsonb;
  v_disc_casadas      jsonb;
  v_mat_concluidas    jsonb;
  v_mat_pendentes     jsonb;
  v_mat_optativas     jsonb;
  v_resumo            jsonb;
  v_total_concl       int;
  v_total_pend        int;
  v_total_obrig       int;
  v_total_opt         int;
  v_percentual        numeric;
BEGIN
  -- ═══════════════════════════════════════════════════════════════
  -- 1. PARSE INPUT
  -- ═══════════════════════════════════════════════════════════════
  v_extracted_data    := p_dados->'extracted_data';
  v_curso_extraido    := p_dados->>'curso_extraido';
  v_matriz_curricular := trim(coalesce(p_dados->>'matriz_curricular', ''));
  v_media_ponderada   := (p_dados->>'media_ponderada')::numeric;
  v_frequencia_geral  := (p_dados->>'frequencia_geral')::numeric;
  v_id_curso_sel      := (p_dados->>'id_curso_selecionado')::bigint;
  v_curso_sel         := p_dados->>'curso_selecionado';

  IF v_extracted_data IS NULL
     OR jsonb_array_length(coalesce(v_extracted_data, '[]'::jsonb)) = 0
  THEN
    RETURN jsonb_build_object('error', 'Dados extraídos são obrigatórios');
  END IF;

  -- ═══════════════════════════════════════════════════════════════
  -- 2. RESOLVE COURSE AND MATRIX
  --    (cursos_disponiveis is built lazily only when needed)
  -- ═══════════════════════════════════════════════════════════════
  IF v_curso_extraido IS NULL OR v_curso_extraido = '' THEN
    -- Build cursos_disponiveis only for this error path
    SELECT coalesce(jsonb_agg(
      jsonb_build_object(
        'id_curso', m.id_curso,
        'nome_curso', coalesce(c.nome_curso, ''),
        'matriz_curricular', coalesce(m.curriculo_completo, '')
      ) ORDER BY m.curriculo_completo
    ), '[]'::jsonb)
    INTO v_cursos_disp
    FROM matrizes m
    LEFT JOIN cursos c ON c.id_curso = m.id_curso;

    RETURN jsonb_build_object(
      'error', 'Curso não foi extraído do PDF automaticamente',
      'message', 'Por favor, selecione o curso manualmente',
      'cursos_disponiveis', v_cursos_disp
    );
  END IF;

  CREATE TEMP TABLE _cand (
    id_curso bigint, nome_curso text, id_matriz bigint, curriculo text
  ) ON COMMIT DROP;

  -- 2a. Keyword search (PALAVRAS_CHAVE:word1,word2,...)
  IF v_curso_extraido LIKE 'PALAVRAS_CHAVE:%' THEN
    INSERT INTO _cand
    SELECT DISTINCT c.id_curso, c.nome_curso, m.id_matriz, m.curriculo_completo
    FROM cursos c
    JOIN matrizes m ON m.id_curso = c.id_curso
    WHERE EXISTS (
      SELECT 1
      FROM unnest(string_to_array(substring(v_curso_extraido FROM 16), ',')) kw
      WHERE upper(c.nome_curso) LIKE '%' || upper(trim(kw)) || '%'
    );

    SELECT count(DISTINCT id_curso) INTO v_count FROM _cand;
    IF v_count = 0 THEN
      SELECT coalesce(jsonb_agg(
        jsonb_build_object('id_curso', m.id_curso, 'nome_curso', coalesce(c.nome_curso, ''),
          'matriz_curricular', coalesce(m.curriculo_completo, ''))
        ORDER BY m.curriculo_completo
      ), '[]'::jsonb)
      INTO v_cursos_disp FROM matrizes m LEFT JOIN cursos c ON c.id_curso = m.id_curso;
      RETURN jsonb_build_object(
        'error', 'Nenhum curso encontrado com as palavras-chave',
        'cursos_disponiveis', v_cursos_disp
      );
    ELSIF v_count > 1 THEN
      SELECT jsonb_agg(DISTINCT jsonb_build_object(
        'id_curso', id_curso, 'nome_curso', nome_curso,
        'matriz_curricular', curriculo
      ))
      INTO v_cursos_disp FROM _cand;
      RETURN jsonb_build_object(
        'error', 'Múltiplos cursos encontrados',
        'message', 'Por favor, selecione o curso correto',
        'cursos_disponiveis', v_cursos_disp
      );
    END IF;

  -- 2b. Standard: by selected id, then by name
  ELSE
    IF v_id_curso_sel IS NOT NULL THEN
      INSERT INTO _cand
      SELECT c.id_curso, c.nome_curso, m.id_matriz, m.curriculo_completo
      FROM cursos c
      JOIN matrizes m ON m.id_curso = c.id_curso
      WHERE c.id_curso = v_id_curso_sel;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM _cand) THEN
      v_search_name := coalesce(v_curso_sel, v_curso_extraido);
      INSERT INTO _cand
      SELECT c.id_curso, c.nome_curso, m.id_matriz, m.curriculo_completo
      FROM cursos c
      JOIN matrizes m ON m.id_curso = c.id_curso
      WHERE upper(c.nome_curso) LIKE '%' || upper(v_search_name) || '%';
    END IF;

    -- Fallback: parse matrix as "codigo/versao"
    -- id_curso = código do currículo (ex: 8150, 8117); cada curso (diurno/noturno) tem código próprio.
    IF NOT EXISTS (SELECT 1 FROM _cand)
       AND v_matriz_curricular != ''
       AND position('/' IN v_matriz_curricular) > 0
    THEN
      <<parse_matrix>>
      DECLARE
        v_parts text[];
        v_cod   text;
        v_ver   text;
      BEGIN
        v_parts := string_to_array(v_matriz_curricular, '/');
        v_cod   := trim(v_parts[1]);
        v_ver   := trim(v_parts[2]);
        IF position(' - ' IN v_ver) > 0 THEN
          v_ver := trim(substring(v_ver FROM 1 FOR position(' - ' IN v_ver) - 1));
        END IF;
        IF v_cod ~ '^\d+$' AND v_ver != '' THEN
          INSERT INTO _cand
          SELECT c.id_curso, c.nome_curso, m.id_matriz, m.curriculo_completo
          FROM matrizes m
          JOIN cursos c ON c.id_curso = m.id_curso
          WHERE m.id_curso = v_cod::bigint
            AND m.versao = v_ver;
        END IF;
      END parse_matrix;
    END IF;
  END IF;

  -- 2c. Narrow by matrix: exact match on curriculo_completo, then versao-based
  IF v_matriz_curricular != '' THEN
    IF EXISTS (
      SELECT 1 FROM _cand
      WHERE lower(trim(curriculo)) = lower(trim(v_matriz_curricular))
    ) THEN
      DELETE FROM _cand
      WHERE lower(trim(curriculo)) != lower(trim(v_matriz_curricular));
    ELSIF position('/' IN v_matriz_curricular) > 0 THEN
      -- Parse "codigo/versao" (e.g. "6360/1") and match by versao column
      <<narrow_by_versao>>
      DECLARE
        v_nparts text[];
        v_nver   text;
      BEGIN
        v_nparts := string_to_array(v_matriz_curricular, '/');
        v_nver   := trim(v_nparts[2]);
        -- Strip trailing " - YYYY.S" if present
        IF position(' - ' IN v_nver) > 0 THEN
          v_nver := trim(substring(v_nver FROM 1 FOR position(' - ' IN v_nver) - 1));
        END IF;
        IF v_nver != '' AND EXISTS (
          SELECT 1 FROM _cand ca
          JOIN matrizes m ON m.id_matriz = ca.id_matriz
          WHERE m.versao = v_nver
        ) THEN
          DELETE FROM _cand
          WHERE id_matriz NOT IN (
            SELECT ca2.id_matriz FROM _cand ca2
            JOIN matrizes m2 ON m2.id_matriz = ca2.id_matriz
            WHERE m2.versao = v_nver
          );
        END IF;
      END narrow_by_versao;
    END IF;
  END IF;

  -- 2d. Evaluate candidates
  SELECT count(*) INTO v_count FROM _cand;

  IF v_count = 0 THEN
    SELECT coalesce(jsonb_agg(
      jsonb_build_object('id_curso', m.id_curso, 'nome_curso', coalesce(c.nome_curso, ''),
        'matriz_curricular', coalesce(m.curriculo_completo, ''))
      ORDER BY m.curriculo_completo
    ), '[]'::jsonb)
    INTO v_cursos_disp FROM matrizes m LEFT JOIN cursos c ON c.id_curso = m.id_curso;
    RETURN jsonb_build_object(
      'error', 'Curso não encontrado',
      'curso_buscado', v_curso_extraido,
      'matriz_curricular_buscada', v_matriz_curricular,
      'cursos_disponiveis', v_cursos_disp
    );
  END IF;

  IF v_count > 1 THEN
    -- Try exact matrix match
    IF v_matriz_curricular != '' THEN
      -- First try exact curriculo_completo match
      SELECT id_curso, nome_curso, id_matriz, curriculo
      INTO v_id_curso, v_nome_curso, v_id_matriz, v_curriculo
      FROM _cand
      WHERE lower(trim(curriculo)) = lower(trim(v_matriz_curricular))
      LIMIT 1;

      -- Then try versao-based match
      IF v_id_matriz IS NULL AND position('/' IN v_matriz_curricular) > 0 THEN
        <<resolve_versao>>
        DECLARE
          v_rparts text[];
          v_rver   text;
        BEGIN
          v_rparts := string_to_array(v_matriz_curricular, '/');
          v_rver   := trim(v_rparts[2]);
          IF position(' - ' IN v_rver) > 0 THEN
            v_rver := trim(substring(v_rver FROM 1 FOR position(' - ' IN v_rver) - 1));
          END IF;
          IF v_rver != '' THEN
            SELECT ca.id_curso, ca.nome_curso, ca.id_matriz, ca.curriculo
            INTO v_id_curso, v_nome_curso, v_id_matriz, v_curriculo
            FROM _cand ca
            JOIN matrizes m ON m.id_matriz = ca.id_matriz
            WHERE m.versao = v_rver
            LIMIT 1;
          END IF;
        END resolve_versao;
      END IF;
    END IF;

    IF v_id_matriz IS NULL THEN
      SELECT jsonb_agg(jsonb_build_object(
        'id_curso', id_curso, 'nome_curso', nome_curso,
        'matriz_curricular', curriculo
      ))
      INTO v_cursos_disp FROM _cand;
      RETURN jsonb_build_object(
        'type', 'COURSE_SELECTION',
        'error', 'Mais de uma matriz curricular encontrada para este curso',
        'message', 'Selecione a matriz curricular do seu histórico',
        'cursos_disponiveis', v_cursos_disp,
        'matriz_extraida_pdf', nullif(v_matriz_curricular, '')
      );
    END IF;
  ELSE
    SELECT id_curso, nome_curso, id_matriz, curriculo
    INTO v_id_curso, v_nome_curso, v_id_matriz, v_curriculo
    FROM _cand LIMIT 1;
  END IF;

  RAISE NOTICE 'casar_disciplinas: course resolved to % (id_matriz=%)', v_nome_curso, v_id_matriz;

  -- ═══════════════════════════════════════════════════════════════
  -- 3. LOAD SUBJECTS FOR THE MATRIX
  -- ═══════════════════════════════════════════════════════════════
  CREATE TEMP TABLE _mat (
    id_materia bigint, codigo text, nome text, nivel int, tipo_natureza int, ch int
  ) ON COMMIT DROP;

  INSERT INTO _mat
  SELECT m.id_materia, m.codigo_materia, m.nome_materia, mpc.nivel,
         coalesce(mpc.tipo_natureza, 0), m.carga_horaria
  FROM materias_por_curso mpc
  JOIN materias m ON m.id_materia = mpc.id_materia
  WHERE mpc.id_matriz = v_id_matriz;

  -- Cross-matrix subjects (same course, other matrices)
  CREATE TEMP TABLE _mat_x (
    id_materia bigint, codigo text, nome text, nivel int, tipo_natureza int
  ) ON COMMIT DROP;

  INSERT INTO _mat_x
  SELECT m.id_materia, m.codigo_materia, m.nome_materia, mpc.nivel,
         coalesce(mpc.tipo_natureza, 0)
  FROM materias_por_curso mpc
  JOIN materias m ON m.id_materia = mpc.id_materia
  JOIN matrizes mt ON mt.id_matriz = mpc.id_matriz
  WHERE mt.id_curso = v_id_curso AND mpc.id_matriz != v_id_matriz;

  RAISE NOTICE 'casar_disciplinas: loaded % subjects for matrix, % cross-matrix',
    (SELECT count(*) FROM _mat), (SELECT count(*) FROM _mat_x);

  -- ═══════════════════════════════════════════════════════════════
  -- 4. EQUIVALENCIES + PRE-COMPUTE CODE MAP
  -- ═══════════════════════════════════════════════════════════════
  CREATE TEMP TABLE _eq (
    id_eq bigint, id_materia bigint, codigo_origem text, expressao text
  ) ON COMMIT DROP;

  INSERT INTO _eq
  SELECT e.id_equivalencia, e.id_materia, m.codigo_materia, e.expressao_original
  FROM equivalencias e
  JOIN materias m ON m.id_materia = e.id_materia
  WHERE e.id_materia IN (SELECT id_materia FROM _mat);

  -- Map: equivalent_code → target subject in our matrix
  CREATE TEMP TABLE _eq_map (
    codigo_eq text, id_materia_alvo bigint,
    codigo_alvo text, nome_alvo text, nivel_alvo int, tipo_natureza_alvo int
  ) ON COMMIT DROP;

  INSERT INTO _eq_map
  SELECT DISTINCT upper(codes.code),
         eq.id_materia, mb.codigo, mb.nome, mb.nivel, coalesce(mb.tipo_natureza, 0)
  FROM _eq eq
  CROSS JOIN LATERAL (
    SELECT m[1] AS code
    FROM regexp_matches(eq.expressao, '([A-Za-z]{2,}\d{3,})', 'g') m
  ) codes
  JOIN _mat mb ON mb.codigo = eq.codigo_origem
  WHERE eq.expressao IS NOT NULL AND eq.expressao != '';

  RAISE NOTICE 'casar_disciplinas: built eq_map with % entries', (SELECT count(*) FROM _eq_map);

  -- ═══════════════════════════════════════════════════════════════
  -- 5. MATCH DISCIPLINES
  -- ═══════════════════════════════════════════════════════════════
  CREATE TEMP TABLE _casadas (
    idx int,
    tipo_dado text, nome text, codigo text, status text, mencao text,
    creditos numeric, carga_horaria int, ano_periodo text,
    prefixo text, professor text,
    id_materia bigint, codigo_materia text, nome_materia text,
    nome_historico text, codigo_historico text,
    encontrada boolean DEFAULT false, nivel int,
    tipo text DEFAULT 'nao_encontrada'
  ) ON COMMIT DROP;

  -- Pre-scan: IRA and pendencias
  v_len := jsonb_array_length(v_extracted_data);
  FOR v_i IN 0..v_len - 1 LOOP
    v_item := v_extracted_data->v_i;
    IF (v_item->>'IRA') IS NOT NULL THEN
      v_ira := (v_item->>'valor')::numeric;
    END IF;
    IF v_item->>'tipo_dado' = 'Pendencias' THEN
      v_pendencias := coalesce(v_item->'valores', '[]'::jsonb);
    END IF;
  END LOOP;

  -- Main matching loop
  FOR v_i IN 0..v_len - 1 LOOP
    v_item := v_extracted_data->v_i;
    IF v_item->>'tipo_dado' NOT IN ('Disciplina Regular', 'Disciplina CUMP') THEN
      CONTINUE;
    END IF;

    v_disc_codigo := upper(trim(coalesce(v_item->>'codigo', '')));
    v_disc_nome   := trim(coalesce(v_item->>'nome', ''));
    v_disc_status := trim(coalesce(v_item->>'status', ''));
    v_match_id := NULL;

    -- Try 1: code match in main matrix (obrigatoria first, then optativa)
    SELECT id_materia, codigo, nome, nivel, tipo_natureza
    INTO v_match_id, v_match_codigo, v_match_nome, v_match_nivel, v_match_tipo_natureza
    FROM _mat WHERE upper(trim(codigo)) = v_disc_codigo AND (tipo_natureza IS NULL OR tipo_natureza != 1) AND nivel > 0 LIMIT 1;

    IF v_match_id IS NULL THEN
      SELECT id_materia, codigo, nome, nivel, tipo_natureza
      INTO v_match_id, v_match_codigo, v_match_nome, v_match_nivel, v_match_tipo_natureza
      FROM _mat WHERE upper(trim(codigo)) = v_disc_codigo AND tipo_natureza = 1 LIMIT 1;
    END IF;
    IF v_match_id IS NULL THEN
      SELECT id_materia, codigo, nome, nivel, tipo_natureza
      INTO v_match_id, v_match_codigo, v_match_nome, v_match_nivel, v_match_tipo_natureza
      FROM _mat WHERE upper(trim(codigo)) = v_disc_codigo AND nivel = 0 LIMIT 1;
    END IF;

    -- Try 2: name match in main matrix
    IF v_match_id IS NULL THEN
      SELECT id_materia, codigo, nome, nivel, tipo_natureza
      INTO v_match_id, v_match_codigo, v_match_nome, v_match_nivel, v_match_tipo_natureza
      FROM _mat WHERE lower(trim(nome)) = lower(v_disc_nome) AND (tipo_natureza IS NULL OR tipo_natureza != 1) AND nivel > 0 LIMIT 1;
    END IF;
    IF v_match_id IS NULL THEN
      SELECT id_materia, codigo, nome, nivel, tipo_natureza
      INTO v_match_id, v_match_codigo, v_match_nome, v_match_nivel, v_match_tipo_natureza
      FROM _mat WHERE lower(trim(nome)) = lower(v_disc_nome) AND (tipo_natureza = 1 OR nivel = 0) LIMIT 1;
    END IF;

    -- Try 3: cross-matrix match
    IF v_match_id IS NULL THEN
      SELECT id_materia, codigo, nome, nivel, tipo_natureza
      INTO v_match_id, v_match_codigo, v_match_nome, v_match_nivel, v_match_tipo_natureza
      FROM _mat_x WHERE upper(trim(codigo)) = v_disc_codigo LIMIT 1;
    END IF;
    IF v_match_id IS NULL THEN
      SELECT id_materia, codigo, nome, nivel, tipo_natureza
      INTO v_match_id, v_match_codigo, v_match_nome, v_match_nivel, v_match_tipo_natureza
      FROM _mat_x WHERE lower(trim(nome)) = lower(v_disc_nome) LIMIT 1;
    END IF;

    -- Try 4: equivalency code map
    IF v_match_id IS NULL THEN
      SELECT id_materia_alvo, codigo_alvo, nome_alvo, nivel_alvo, tipo_natureza_alvo
      INTO v_match_id, v_match_codigo, v_match_nome, v_match_nivel, v_match_tipo_natureza
      FROM _eq_map WHERE codigo_eq = v_disc_codigo LIMIT 1;
    END IF;

    -- Handle match
    IF v_match_id IS NOT NULL THEN
      -- Check for duplicate id_materia (keep higher priority status)
      SELECT status INTO v_old_status
      FROM _casadas WHERE id_materia = v_match_id;

      IF FOUND THEN
        IF (CASE WHEN upper(v_disc_status) IN ('APR','CUMP','DISP') THEN 3
                 WHEN upper(v_disc_status) = 'MATR' THEN 2 ELSE 1 END)
         > (CASE WHEN upper(v_old_status) IN ('APR','CUMP','DISP') THEN 3
                 WHEN upper(v_old_status) = 'MATR' THEN 2 ELSE 1 END)
        THEN
          UPDATE _casadas SET
            status = v_disc_status,
            mencao = v_item->>'mencao',
            carga_horaria = (v_item->>'carga_horaria')::int,
            ano_periodo = v_item->>'ano_periodo',
            professor = v_item->>'professor',
            nome_historico = v_item->>'nome',
            codigo_historico = v_item->>'codigo'
          WHERE id_materia = v_match_id;
        END IF;
        CONTINUE; -- skip insert for duplicate
      END IF;

      INSERT INTO _casadas VALUES (
        v_i, v_item->>'tipo_dado',
        coalesce(v_match_nome, v_item->>'nome'), v_match_codigo,
        v_disc_status, v_item->>'mencao',
        (v_item->>'creditos')::numeric, (v_item->>'carga_horaria')::int,
        v_item->>'ano_periodo', v_item->>'prefixo', v_item->>'professor',
        v_match_id, v_match_codigo, v_match_nome,
        v_item->>'nome', v_item->>'codigo',
        true, v_match_nivel,
        CASE WHEN v_match_tipo_natureza = 1 THEN 'optativa' WHEN v_match_nivel = 0 THEN 'optativa' ELSE 'obrigatoria' END
      );
    ELSE
      -- No match found
      INSERT INTO _casadas VALUES (
        v_i, v_item->>'tipo_dado',
        v_item->>'nome', v_item->>'codigo',
        v_disc_status, v_item->>'mencao',
        (v_item->>'creditos')::numeric, (v_item->>'carga_horaria')::int,
        v_item->>'ano_periodo', v_item->>'prefixo', v_item->>'professor',
        NULL, NULL, NULL,
        v_item->>'nome', v_item->>'codigo',
        false, NULL, 'nao_encontrada'
      );
    END IF;
  END LOOP;

  RAISE NOTICE 'casar_disciplinas: matched % disciplines (% found, % not found)',
    (SELECT count(*) FROM _casadas),
    (SELECT count(*) FROM _casadas WHERE encontrada),
    (SELECT count(*) FROM _casadas WHERE NOT encontrada);

  -- ═══════════════════════════════════════════════════════════════
  -- 6. BUILD disciplinas_casadas JSON
  -- ═══════════════════════════════════════════════════════════════
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'tipo_dado', tipo_dado, 'nome', nome, 'codigo', codigo,
      'status', status, 'mencao', mencao, 'creditos', creditos,
      'carga_horaria', carga_horaria, 'ano_periodo', ano_periodo,
      'prefixo', prefixo, 'professor', professor,
      'id_materia', id_materia, 'codigo_materia', codigo_materia,
      'nome_materia', nome_materia, 'nome_historico', nome_historico,
      'codigo_historico', codigo_historico,
      'encontrada_no_banco', encontrada, 'nivel', nivel, 'tipo', tipo
    ) ORDER BY idx
  ), '[]'::jsonb) INTO v_disc_casadas FROM _casadas;

  -- Horas integralizadas
  SELECT coalesce(sum(carga_horaria), 0) INTO v_horas
  FROM _casadas
  WHERE upper(status) IN ('APR','CUMP','DISP') AND carga_horaria IS NOT NULL;

  -- ═══════════════════════════════════════════════════════════════
  -- 7. CLASSIFY: concluidas, pendentes, optativas
  -- ═══════════════════════════════════════════════════════════════

  -- 7a. Missing mandatory subjects (obrigatórias: tipo_natureza != 1 e nivel > 0)
  CREATE TEMP TABLE _missing (
    id_materia bigint, codigo text, nome text, nivel int
  ) ON COMMIT DROP;

  INSERT INTO _missing
  SELECT mb.id_materia, mb.codigo, mb.nome, mb.nivel
  FROM _mat mb
  WHERE (mb.tipo_natureza IS NULL OR mb.tipo_natureza != 1)
    AND mb.nivel > 0
    AND mb.id_materia NOT IN (
      SELECT c.id_materia FROM _casadas c WHERE c.id_materia IS NOT NULL
    );

  -- 7b. Check equivalencies for missing mandatory subjects (SET-BASED)
  --     Replaces the old nested FOR loop with a single INSERT ... SELECT
  CREATE TEMP TABLE _equiv_concl (
    id_materia bigint, codigo text, nome text, nivel int,
    codigo_equivalente text, nome_equivalente text,
    professor text, mencao text, status text, ano_periodo text
  ) ON COMMIT DROP;

  INSERT INTO _equiv_concl
  SELECT DISTINCT ON (m.id_materia)
    m.id_materia, m.codigo, m.nome, m.nivel,
    coalesce(c.codigo, m.codigo),
    coalesce(c.nome, m.nome),
    coalesce(c.professor, ''),
    coalesce(c.mencao, '-'),
    coalesce(c.status, 'CUMP'),
    c.ano_periodo
  FROM _missing m
  JOIN _eq eq ON eq.codigo_origem = m.codigo
  CROSS JOIN LATERAL (
    SELECT upper(rm[1]) AS code
    FROM regexp_matches(eq.expressao, '([A-Za-z]{2,}\d{3,})', 'g') rm
  ) codes
  JOIN _casadas c ON upper(trim(c.codigo)) = codes.code
    AND upper(c.status) IN ('APR','CUMP','DISP')
  WHERE eq.expressao IS NOT NULL AND eq.expressao != ''
  ORDER BY m.id_materia, c.ano_periodo DESC NULLS LAST;

  -- Remove resolved subjects from _missing
  DELETE FROM _missing
  WHERE id_materia IN (SELECT id_materia FROM _equiv_concl);

  RAISE NOTICE 'casar_disciplinas: equivalency resolution found % additional completions, % still missing',
    (SELECT count(*) FROM _equiv_concl), (SELECT count(*) FROM _missing);

  -- 7c. Check if completed optativas can fulfill still-missing mandatory via equivalency (SET-BASED)
  --     For each completed optativa, check if its code appears in any equivalency expression
  --     that targets a still-missing mandatory subject.
  <<opt_equiv_block>>
  DECLARE
    v_opt_equiv_count int;
  BEGIN
    -- Find optativas that can fulfill missing mandatory via equivalencies
    CREATE TEMP TABLE _opt_fulfills (
      id_materia_missing bigint, codigo_missing text, nome_missing text, nivel_missing int,
      codigo_equivalente text, nome_equivalente text,
      professor text, mencao text, status text, ano_periodo text,
      id_materia_opt bigint
    ) ON COMMIT DROP;

    INSERT INTO _opt_fulfills
    SELECT DISTINCT ON (m.id_materia)
      m.id_materia, m.codigo, m.nome, m.nivel,
      coalesce(c.codigo, opt.codigo),
      coalesce(c.nome, opt.nome),
      coalesce(c.professor, ''),
      coalesce(c.mencao, '-'),
      coalesce(c.status, 'CUMP'),
      c.ano_periodo,
      opt.id_materia AS id_materia_opt
    FROM _missing m
    JOIN _eq eq ON eq.codigo_origem = m.codigo
    CROSS JOIN LATERAL (
      SELECT upper(rm[1]) AS code
      FROM regexp_matches(eq.expressao, '([A-Za-z]{2,}\d{3,})', 'g') rm
    ) codes
    JOIN _casadas opt ON opt.tipo = 'optativa'
      AND upper(opt.status) IN ('APR','CUMP','DISP')
      AND upper(trim(opt.codigo)) = codes.code
    JOIN _casadas c ON upper(trim(c.codigo)) = codes.code
      AND upper(c.status) IN ('APR','CUMP','DISP')
    WHERE eq.expressao IS NOT NULL AND eq.expressao != ''
    ORDER BY m.id_materia, c.ano_periodo DESC NULLS LAST;

    GET DIAGNOSTICS v_opt_equiv_count = ROW_COUNT;

    IF v_opt_equiv_count > 0 THEN
      -- Add to equiv_concl
      INSERT INTO _equiv_concl
      SELECT id_materia_missing, codigo_missing, nome_missing, nivel_missing,
             codigo_equivalente, nome_equivalente, professor, mencao, status, ano_periodo
      FROM _opt_fulfills;

      -- Remove from _missing
      DELETE FROM _missing
      WHERE id_materia IN (SELECT id_materia_missing FROM _opt_fulfills);

      -- Remove these optativas from _casadas
      DELETE FROM _casadas
      WHERE id_materia IN (SELECT id_materia_opt FROM _opt_fulfills)
        AND tipo = 'optativa';

      RAISE NOTICE 'casar_disciplinas: % optativas fulfilled missing mandatory subjects', v_opt_equiv_count;
    END IF;
  END opt_equiv_block;

  -- ═══════════════════════════════════════════════════════════════
  -- 8. BUILD RESULT JSON
  -- ═══════════════════════════════════════════════════════════════

  -- materias_concluidas = completed mandatory (from transcript + equivalencies)
  SELECT coalesce(jsonb_agg(j ORDER BY j->>'codigo'), '[]'::jsonb)
  INTO v_mat_concluidas
  FROM (
    -- From transcript
    SELECT jsonb_build_object(
      'id_materia', id_materia, 'codigo', codigo, 'nome', nome,
      'status', status, 'mencao', mencao, 'nivel', nivel,
      'carga_horaria', carga_horaria, 'ano_periodo', ano_periodo,
      'professor', professor, 'encontrada_no_banco', true, 'tipo', 'obrigatoria',
      'status_fluxograma', CASE
        WHEN codigo_historico IS NOT NULL
             AND upper(trim(codigo_historico)) != upper(trim(codigo))
        THEN 'concluida_equivalencia' ELSE 'concluida' END,
      'codigo_equivalente', CASE
        WHEN codigo_historico IS NOT NULL
             AND upper(trim(codigo_historico)) != upper(trim(codigo))
        THEN codigo_historico ELSE NULL END,
      'nome_equivalente', CASE
        WHEN codigo_historico IS NOT NULL
             AND upper(trim(codigo_historico)) != upper(trim(codigo))
        THEN nome_historico ELSE NULL END
    ) AS j
    FROM _casadas
    WHERE tipo = 'obrigatoria' AND upper(status) IN ('APR','CUMP','DISP')
    UNION ALL
    -- From equivalency resolution
    SELECT jsonb_build_object(
      'id_materia', id_materia, 'codigo', codigo, 'nome', nome,
      'status', status, 'mencao', mencao, 'nivel', nivel,
      'professor', professor, 'ano_periodo', ano_periodo,
      'encontrada_no_banco', true, 'encontrada_no_historico', false,
      'tipo', 'obrigatoria', 'status_fluxograma', 'concluida_equivalencia',
      'codigo_equivalente', codigo_equivalente,
      'nome_equivalente', nome_equivalente
    ) AS j
    FROM _equiv_concl
  ) sub;

  -- materias_pendentes = pending mandatory + missing mandatory (never in transcript)
  SELECT coalesce(jsonb_agg(j ORDER BY j->>'codigo'), '[]'::jsonb)
  INTO v_mat_pendentes
  FROM (
    SELECT jsonb_build_object(
      'id_materia', id_materia, 'codigo', codigo, 'nome', nome,
      'status', status, 'mencao', mencao, 'nivel', nivel,
      'carga_horaria', carga_horaria, 'ano_periodo', ano_periodo,
      'encontrada_no_banco', true, 'tipo', 'obrigatoria',
      'status_fluxograma', CASE
        WHEN upper(status) = 'MATR' THEN 'em_andamento' ELSE 'pendente' END
    ) AS j
    FROM _casadas
    WHERE tipo = 'obrigatoria' AND upper(status) NOT IN ('APR','CUMP','DISP')
    UNION ALL
    SELECT jsonb_build_object(
      'id_materia', id_materia, 'codigo', codigo, 'nome', nome,
      'nivel', nivel, 'encontrada_no_banco', true,
      'encontrada_no_historico', false, 'tipo', 'obrigatoria',
      'status_fluxograma', 'nao_cursada'
    ) AS j
    FROM _missing
  ) sub;

  -- materias_optativas (remaining after equivalency deductions)
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id_materia', id_materia, 'codigo', codigo, 'nome', nome,
      'status', status, 'mencao', mencao, 'nivel', nivel,
      'carga_horaria', carga_horaria, 'ano_periodo', ano_periodo,
      'encontrada_no_banco', true, 'tipo', 'optativa',
      'status_fluxograma', CASE
        WHEN upper(status) IN ('APR','CUMP','DISP') THEN 'concluida'
        WHEN upper(status) = 'MATR' THEN 'em_andamento'
        ELSE 'pendente' END
    ) ORDER BY codigo
  ), '[]'::jsonb)
  INTO v_mat_optativas
  FROM _casadas WHERE tipo = 'optativa';

  -- Summary counts
  v_total_concl := (SELECT count(*) FROM _casadas
                    WHERE tipo = 'obrigatoria' AND upper(status) IN ('APR','CUMP','DISP'))
                 + (SELECT count(*) FROM _equiv_concl);
  v_total_pend  := (SELECT count(*) FROM _casadas
                    WHERE tipo = 'obrigatoria' AND upper(status) NOT IN ('APR','CUMP','DISP'))
                 + (SELECT count(*) FROM _missing);
  v_total_obrig := v_total_concl + v_total_pend;
  v_total_opt   := (SELECT count(*) FROM _casadas WHERE tipo = 'optativa');
  v_percentual  := CASE WHEN v_total_obrig > 0
    THEN round((v_total_concl::numeric / v_total_obrig) * 100, 2)
    ELSE 0 END;

  RETURN jsonb_build_object(
    'disciplinas_casadas', v_disc_casadas,
    'materias_concluidas', v_mat_concluidas,
    'materias_pendentes',  v_mat_pendentes,
    'materias_optativas',  v_mat_optativas,
    'dados_validacao', jsonb_build_object(
      'ira', v_ira,
      'media_ponderada', v_media_ponderada,
      'frequencia_geral', v_frequencia_geral,
      'horas_integralizadas', v_horas,
      'pendencias', v_pendencias,
      'curso_extraido', v_curso_extraido,
      'matriz_curricular', v_curriculo
    ),
    'curso_extraido', v_curso_extraido,
    'matriz_curricular', v_curriculo,
    'resumo', jsonb_build_object(
      'total_disciplinas', (SELECT count(*) FROM _casadas),
      'total_obrigatorias', v_total_obrig,
      'total_obrigatorias_concluidas', v_total_concl,
      'total_obrigatorias_pendentes', v_total_pend,
      'total_optativas', v_total_opt,
      'percentual_conclusao_obrigatorias', v_percentual
    )
  );
END;
$function$;

-- Function: cosine_distance
-- Return type: double precision
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.cosine_distance(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_cosine_distance$function$;

-- Function: cosine_distance
-- Return type: double precision
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.cosine_distance(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$cosine_distance$function$;

-- Function: cosine_distance
-- Return type: double precision
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.cosine_distance(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_cosine_distance$function$;

-- Function: export_schema
-- Return type: jsonb
-- Arguments: (none)
-- Volatility: VOLATILE
-- Security definer: YES

CREATE OR REPLACE FUNCTION public.export_schema()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN jsonb_build_object(
        'exported_at', NOW(),
        'postgres_version', version(),
        
        -- TABLES WITH DETAILED COLUMNS
        'tables', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'table_name', t.table_name,
                'table_type', t.table_type,
                'table_comment', obj_description(pc.oid, 'pg_class'),
                'columns', (
                    SELECT COALESCE(jsonb_agg(jsonb_build_object(
                        'column_name', c.column_name,
                        'data_type', c.data_type,
                        'udt_name', c.udt_name,
                        'is_nullable', c.is_nullable,
                        'column_default', c.column_default,
                        'is_identity', c.is_identity,
                        'identity_generation', c.identity_generation,
                        'ordinal_position', c.ordinal_position,
                        'character_maximum_length', c.character_maximum_length,
                        'numeric_precision', c.numeric_precision,
                        'numeric_scale', c.numeric_scale,
                        'datetime_precision', c.datetime_precision,
                        'is_updatable', c.is_updatable,
                        'column_comment', col_description(pc.oid, c.ordinal_position)
                    ) ORDER BY c.ordinal_position), '[]'::jsonb)
                    FROM information_schema.columns c 
                    WHERE c.table_name = t.table_name 
                    AND c.table_schema = 'public'
                )
            ) ORDER BY t.table_name), '[]'::jsonb)
            FROM information_schema.tables t
            JOIN pg_class pc ON pc.relname = t.table_name AND pc.relnamespace = 'public'::regnamespace
            WHERE t.table_schema = 'public'
            AND t.table_type = 'BASE TABLE'
        ),
        
        -- VIEWS WITH DEFINITIONS
        'views', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'view_name', table_name,
                'view_definition', view_definition,
                'is_updatable', is_updatable,
                'is_insertable_into', is_insertable_into
            ) ORDER BY table_name), '[]'::jsonb)
            FROM information_schema.views
            WHERE table_schema = 'public'
        ),

        -- MATERIALIZED VIEWS WITH DEFINITIONS
        'materialized_views', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'view_name', matviewname,
                'view_definition', definition,
                'is_populated', ispopulated
            ) ORDER BY matviewname), '[]'::jsonb)
            FROM pg_matviews
            WHERE schemaname = 'public'
        ),
        
        -- FUNCTIONS AND PROCEDURES (with full definitions and source code)
        'functions', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'function_name', p.proname,
                'function_oid', p.oid::bigint,
                'return_type', pg_get_function_result(p.oid),
                'arguments', pg_get_function_arguments(p.oid),
                'argument_types', pg_get_function_identity_arguments(p.oid),
                'function_type', CASE 
                    WHEN p.prokind = 'f' THEN 'function'
                    WHEN p.prokind = 'p' THEN 'procedure'
                    WHEN p.prokind = 'a' THEN 'aggregate'
                    WHEN p.prokind = 'w' THEN 'window'
                    ELSE 'unknown'
                END,
                'volatility', CASE p.provolatile
                    WHEN 'i' THEN 'IMMUTABLE'
                    WHEN 's' THEN 'STABLE'
                    WHEN 'v' THEN 'VOLATILE'
                END,
                'parallel_safety', CASE p.proparallel
                    WHEN 's' THEN 'SAFE'
                    WHEN 'r' THEN 'RESTRICTED'
                    WHEN 'u' THEN 'UNSAFE'
                END,
                'security_definer', p.prosecdef,
                'strict', p.proisstrict,
                'returns_set', p.proretset,
                'language', l.lanname,
                'source_code', p.prosrc,
                'definition', pg_get_functiondef(p.oid),
                'config', p.proconfig,
                'comment', obj_description(p.oid, 'pg_proc')
            ) ORDER BY p.proname), '[]'::jsonb)
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            JOIN pg_language l ON p.prolang = l.oid
            WHERE n.nspname = 'public'
            AND p.prokind IN ('f', 'p')
        ),
        
        -- TRIGGERS WITH FULL DEFINITIONS (including the trigger function definition)
        -- Only triggers on PUBLIC schema tables
        'triggers', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'trigger_name', tg.tgname,
                'table_name', tab.relname,
                'table_schema', ns.nspname,
                'trigger_type', CASE 
                    WHEN tg.tgtype & 2 = 2 THEN 'BEFORE'
                    WHEN tg.tgtype & 64 = 64 THEN 'INSTEAD OF'
                    ELSE 'AFTER'
                END,
                'trigger_events', concat_ws(' OR ',
                    CASE WHEN tg.tgtype & 4 = 4 THEN 'INSERT' END,
                    CASE WHEN tg.tgtype & 8 = 8 THEN 'DELETE' END,
                    CASE WHEN tg.tgtype & 16 = 16 THEN 'UPDATE' END,
                    CASE WHEN tg.tgtype & 32 = 32 THEN 'TRUNCATE' END
                ),
                'for_each', CASE WHEN tg.tgtype & 1 = 1 THEN 'ROW' ELSE 'STATEMENT' END,
                'trigger_function_name', p.proname,
                'trigger_function_schema', fn.nspname,
                'trigger_function_definition', pg_get_functiondef(p.oid),
                'trigger_function_source', p.prosrc,
                'is_enabled', CASE tg.tgenabled
                    WHEN 'O' THEN true
                    WHEN 'D' THEN false
                    WHEN 'R' THEN true  -- replica
                    WHEN 'A' THEN true  -- always
                    ELSE true
                END,
                'trigger_definition', pg_get_triggerdef(tg.oid),
                -- NOTE: tg.tgqual can reference both OLD and NEW, which makes pg_get_expr error
                -- ("expression contains variables of more than one relation"). We extract WHEN()
                -- from the full trigger definition instead (best-effort).
                'condition', substring(pg_get_triggerdef(tg.oid) from 'WHEN \\((.*)\\) EXECUTE')
            ) ORDER BY tab.relname, tg.tgname), '[]'::jsonb)
            FROM pg_trigger tg
            JOIN pg_class tab ON tg.tgrelid = tab.oid
            JOIN pg_namespace ns ON tab.relnamespace = ns.oid
            JOIN pg_proc p ON tg.tgfoid = p.oid
            JOIN pg_namespace fn ON p.pronamespace = fn.oid
            WHERE ns.nspname = 'public'
            AND NOT tg.tgisinternal  -- exclude system triggers
        ),
        
        -- TRIGGERS ON auth.users (critical for signup flows)
        -- These triggers fire when users sign up and typically create profiles
        'auth_triggers', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'trigger_name', tg.tgname,
                'table_name', tab.relname,
                'table_schema', ns.nspname,
                'trigger_type', CASE 
                    WHEN tg.tgtype & 2 = 2 THEN 'BEFORE'
                    WHEN tg.tgtype & 64 = 64 THEN 'INSTEAD OF'
                    ELSE 'AFTER'
                END,
                'trigger_events', concat_ws(' OR ',
                    CASE WHEN tg.tgtype & 4 = 4 THEN 'INSERT' END,
                    CASE WHEN tg.tgtype & 8 = 8 THEN 'DELETE' END,
                    CASE WHEN tg.tgtype & 16 = 16 THEN 'UPDATE' END,
                    CASE WHEN tg.tgtype & 32 = 32 THEN 'TRUNCATE' END
                ),
                'for_each', CASE WHEN tg.tgtype & 1 = 1 THEN 'ROW' ELSE 'STATEMENT' END,
                'trigger_function_name', p.proname,
                'trigger_function_schema', fn.nspname,
                'trigger_function_definition', CASE 
                    WHEN fn.nspname = 'public' THEN pg_get_functiondef(p.oid)
                    ELSE NULL  -- Can't always get definition for non-public functions
                END,
                'trigger_function_source', CASE 
                    WHEN fn.nspname = 'public' THEN p.prosrc
                    ELSE NULL
                END,
                'is_enabled', CASE tg.tgenabled
                    WHEN 'O' THEN true
                    WHEN 'D' THEN false
                    WHEN 'R' THEN true
                    WHEN 'A' THEN true
                    ELSE true
                END,
                'trigger_definition', pg_get_triggerdef(tg.oid)
            ) ORDER BY tg.tgname), '[]'::jsonb)
            FROM pg_trigger tg
            JOIN pg_class tab ON tg.tgrelid = tab.oid
            JOIN pg_namespace ns ON tab.relnamespace = ns.oid
            JOIN pg_proc p ON tg.tgfoid = p.oid
            JOIN pg_namespace fn ON p.pronamespace = fn.oid
            WHERE ns.nspname = 'auth'
            AND tab.relname = 'users'
            AND NOT tg.tgisinternal
        ),
        
        -- FOREIGN KEYS (public schema only)
        'foreign_keys', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'constraint_name', tc.constraint_name,
                'table_name', tc.table_name,
                'column_name', kcu.column_name,
                'foreign_table_name', ccu.table_name,
                'foreign_column_name', ccu.column_name,
                'update_rule', rc.update_rule,
                'delete_rule', rc.delete_rule,
                'match_option', rc.match_option
            ) ORDER BY tc.table_name, tc.constraint_name), '[]'::jsonb)
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage ccu
                ON ccu.constraint_name = tc.constraint_name
                AND ccu.table_schema = tc.table_schema
            JOIN information_schema.referential_constraints rc
                ON rc.constraint_name = tc.constraint_name
                AND rc.constraint_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY'
            AND tc.table_schema = 'public'
        ),
        
        -- FOREIGN KEYS REFERENCING auth.users
        -- These are critical for user profile tables that link to auth.users
        'auth_foreign_keys', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'constraint_name', con.conname,
                'table_schema', nsp.nspname,
                'table_name', rel.relname,
                'column_name', att.attname,
                'foreign_table_schema', fnsp.nspname,
                'foreign_table_name', frel.relname,
                'foreign_column_name', fatt.attname,
                'on_delete', CASE con.confdeltype
                    WHEN 'a' THEN 'NO ACTION'
                    WHEN 'r' THEN 'RESTRICT'
                    WHEN 'c' THEN 'CASCADE'
                    WHEN 'n' THEN 'SET NULL'
                    WHEN 'd' THEN 'SET DEFAULT'
                END,
                'on_update', CASE con.confupdtype
                    WHEN 'a' THEN 'NO ACTION'
                    WHEN 'r' THEN 'RESTRICT'
                    WHEN 'c' THEN 'CASCADE'
                    WHEN 'n' THEN 'SET NULL'
                    WHEN 'd' THEN 'SET DEFAULT'
                END
            ) ORDER BY rel.relname), '[]'::jsonb)
            FROM pg_constraint con
            JOIN pg_class rel ON con.conrelid = rel.oid
            JOIN pg_namespace nsp ON rel.relnamespace = nsp.oid
            JOIN pg_class frel ON con.confrelid = frel.oid
            JOIN pg_namespace fnsp ON frel.relnamespace = fnsp.oid
            JOIN pg_attribute att ON att.attrelid = rel.oid AND att.attnum = ANY(con.conkey)
            JOIN pg_attribute fatt ON fatt.attrelid = frel.oid AND fatt.attnum = ANY(con.confkey)
            WHERE con.contype = 'f'
            AND fnsp.nspname = 'auth'
            AND frel.relname = 'users'
        ),
        
        -- PRIMARY KEYS
        'primary_keys', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'constraint_name', tc.constraint_name,
                'table_name', tc.table_name,
                'column_name', kcu.column_name,
                'ordinal_position', kcu.ordinal_position
            ) ORDER BY tc.table_name, kcu.ordinal_position), '[]'::jsonb)
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            WHERE tc.constraint_type = 'PRIMARY KEY'
            AND tc.table_schema = 'public'
        ),
        
        -- UNIQUE CONSTRAINTS
        'unique_constraints', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'constraint_name', tc.constraint_name,
                'table_name', tc.table_name,
                'column_name', kcu.column_name,
                'ordinal_position', kcu.ordinal_position
            ) ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position), '[]'::jsonb)
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            WHERE tc.constraint_type = 'UNIQUE'
            AND tc.table_schema = 'public'
        ),
        
        -- CHECK CONSTRAINTS
        'check_constraints', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'constraint_name', cc.constraint_name,
                'table_name', tc.table_name,
                'check_clause', cc.check_clause
            ) ORDER BY tc.table_name, cc.constraint_name), '[]'::jsonb)
            FROM information_schema.check_constraints cc
            JOIN information_schema.table_constraints tc
                ON cc.constraint_name = tc.constraint_name
                AND cc.constraint_schema = tc.table_schema
            WHERE cc.constraint_schema = 'public'
            AND tc.constraint_type = 'CHECK'
        ),
        
        -- INDEXES (with full definition)
        'indexes', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'index_name', indexname,
                'table_name', tablename,
                'index_definition', indexdef
            ) ORDER BY tablename, indexname), '[]'::jsonb)
            FROM pg_indexes
            WHERE schemaname = 'public'
        ),
        
        -- SEQUENCES (with current values and settings)
        'sequences', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'sequence_name', sq.relname,
                'data_type', sq.seqtypid::regtype::text,
                'start_value', sq.seqstart,
                'min_value', sq.seqmin,
                'max_value', sq.seqmax,
                'increment_by', sq.seqincrement,
                'cycle', sq.seqcycle,
                'cache_size', sq.seqcache,
                'owned_by', sq.owned_by
            ) ORDER BY sq.relname), '[]'::jsonb)
            FROM (
                SELECT 
                    s.relname,
                    s.oid as seq_oid,
                    seq.seqtypid,
                    seq.seqstart,
                    seq.seqmin,
                    seq.seqmax,
                    seq.seqincrement,
                    seq.seqcycle,
                    seq.seqcache,
                    (
                        SELECT a.attrelid::regclass || '.' || a.attname
                        FROM pg_depend d
                        JOIN pg_attribute a ON d.refobjid = a.attrelid AND d.refobjsubid = a.attnum
                        WHERE d.objid = s.oid AND d.deptype = 'a'
                        LIMIT 1
                    ) as owned_by
                FROM pg_class s
                JOIN pg_sequence seq ON s.oid = seq.seqrelid
                JOIN pg_namespace n ON s.relnamespace = n.oid
                WHERE n.nspname = 'public'
                AND s.relkind = 'S'
            ) sq
        ),
        
        -- RLS POLICIES (with roles)
        'policies', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'policy_name', pol.polname,
                'table_name', tab.relname,
                'command', CASE pol.polcmd 
                    WHEN 'r' THEN 'SELECT'
                    WHEN 'a' THEN 'INSERT'
                    WHEN 'w' THEN 'UPDATE'
                    WHEN 'd' THEN 'DELETE'
                    WHEN '*' THEN 'ALL'
                END,
                'permissive', CASE pol.polpermissive 
                    WHEN true THEN 'PERMISSIVE'
                    ELSE 'RESTRICTIVE'
                END,
                'roles', COALESCE(
                    (SELECT array_agg(r.rolname) FROM pg_roles r WHERE r.oid = ANY(pol.polroles)),
                    ARRAY['public']
                ),
                'using_expression', pg_get_expr(pol.polqual, pol.polrelid),
                'with_check_expression', pg_get_expr(pol.polwithcheck, pol.polrelid)
            ) ORDER BY tab.relname, pol.polname), '[]'::jsonb)
            FROM pg_policy pol
            JOIN pg_class tab ON pol.polrelid = tab.oid
            JOIN pg_namespace nsp ON tab.relnamespace = nsp.oid
            WHERE nsp.nspname = 'public'
        ),
        
        -- ENUMS
        'enums', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'enum_name', t.typname,
                'enum_values', (
                    SELECT array_agg(e.enumlabel ORDER BY e.enumsortorder)
                    FROM pg_enum e
                    WHERE e.enumtypid = t.oid
                )
            ) ORDER BY t.typname), '[]'::jsonb)
            FROM pg_type t
            JOIN pg_namespace n ON t.typnamespace = n.oid
            WHERE n.nspname = 'public'
            AND t.typtype = 'e'
        ),
        
        -- EXTENSIONS
        'extensions', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'extension_name', e.extname,
                'schema', n.nspname,
                'version', e.extversion,
                'relocatable', e.extrelocatable
            ) ORDER BY e.extname), '[]'::jsonb)
            FROM pg_extension e
            JOIN pg_namespace n ON e.extnamespace = n.oid
        ),
        
        -- TABLE STATS (row counts and sizes)
        'table_stats', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'table_name', relname,
                'estimated_rows', reltuples::bigint,
                'total_size_bytes', pg_total_relation_size(oid),
                'table_size_bytes', pg_table_size(oid),
                'indexes_size_bytes', pg_indexes_size(oid)
            ) ORDER BY relname), '[]'::jsonb)
            FROM pg_class
            WHERE relnamespace = 'public'::regnamespace
            AND relkind = 'r'
        ),
        
        -- RLS ENABLED TABLES
        'rls_enabled_tables', (
            SELECT COALESCE(jsonb_agg(relname ORDER BY relname), '[]'::jsonb)
            FROM pg_class c
            JOIN pg_namespace n ON c.relnamespace = n.oid
            WHERE n.nspname = 'public'
            AND c.relkind = 'r'
            AND c.relrowsecurity = true
        )
    );
END;
$function$;

-- Function: get_equivalencias_materia
-- Return type: TABLE(id_equivalencia integer, id_materia integer, codigo_materia_origem text, nome_materia_origem text, curriculo text, expressao_original text, expressao_logica jsonb)
-- Arguments: p_codigo text DEFAULT NULL::text, p_nome text DEFAULT NULL::text
-- Volatility: VOLATILE
-- Security definer: YES

CREATE OR REPLACE FUNCTION public.get_equivalencias_materia(p_codigo text DEFAULT NULL::text, p_nome text DEFAULT NULL::text)
 RETURNS TABLE(id_equivalencia integer, id_materia integer, codigo_materia_origem text, nome_materia_origem text, curriculo text, expressao_original text, expressao_logica jsonb)
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
    select
        e.id_equivalencia,
        e.id_materia,
        m.codigo_materia      as codigo_materia_origem,
        m.nome_materia        as nome_materia_origem,
        e.curriculo,
        e.expressao_original,
        e.expressao_logica
    from equivalencias e
    join materias m
      on m.id_materia = e.id_materia
    where (
        p_codigo is not null
        and upper(m.codigo_materia) = upper(p_codigo)
    )
    or (
        p_nome is not null
        and m.nome_materia ilike '%'||p_nome||'%'
    )
    order by e.id_equivalencia;
$function$;

-- Function: get_pre_requisitos_materia
-- Return type: TABLE(id_pre_requisito integer, id_materia integer, codigo_materia text, nome_materia text, expressao_original text, expressao_logica jsonb, codigo_requisito text, nome_requisito text)
-- Arguments: p_codigo text DEFAULT NULL::text, p_nome text DEFAULT NULL::text
-- Volatility: VOLATILE
-- Security definer: YES

CREATE OR REPLACE FUNCTION public.get_pre_requisitos_materia(p_codigo text DEFAULT NULL::text, p_nome text DEFAULT NULL::text)
 RETURNS TABLE(id_pre_requisito integer, id_materia integer, codigo_materia text, nome_materia text, expressao_original text, expressao_logica jsonb, codigo_requisito text, nome_requisito text)
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
    select
        pr.id_pre_requisito,
        pr.id_materia,
        m.codigo_materia,
        m.nome_materia,
        pr.expressao_original,
        pr.expressao_logica,
        mr.codigo_materia   as codigo_requisito,
        mr.nome_materia     as nome_requisito
    from pre_requisitos pr
    join materias m
      on m.id_materia = pr.id_materia
    left join materias mr
      on mr.id_materia = pr.id_materia_requisito
    where (
        p_codigo is not null
        and upper(m.codigo_materia) = upper(p_codigo)
    )
    or (
        p_nome is not null
        and m.nome_materia ilike '%'||p_nome||'%'
    )
    order by pr.id_pre_requisito;
$function$;

-- Function: gin_extract_query_trgm
-- Return type: internal
-- Arguments: text, internal, smallint, internal, internal, internal, internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_query_trgm$function$;

-- Function: gin_extract_value_trgm
-- Return type: internal
-- Arguments: text, internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gin_extract_value_trgm(text, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_value_trgm$function$;

-- Function: gin_trgm_consistent
-- Return type: boolean
-- Arguments: internal, smallint, text, integer, internal, internal, internal, internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_consistent$function$;

-- Function: gin_trgm_triconsistent
-- Return type: "char"
-- Arguments: internal, smallint, text, integer, internal, internal, internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal)
 RETURNS "char"
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_triconsistent$function$;

-- Function: gtrgm_compress
-- Return type: internal
-- Arguments: internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gtrgm_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_compress$function$;

-- Function: gtrgm_consistent
-- Return type: boolean
-- Arguments: internal, text, smallint, oid, internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_consistent$function$;

-- Function: gtrgm_decompress
-- Return type: internal
-- Arguments: internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gtrgm_decompress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_decompress$function$;

-- Function: gtrgm_distance
-- Return type: double precision
-- Arguments: internal, text, smallint, oid, internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_distance$function$;

-- Function: gtrgm_in
-- Return type: gtrgm
-- Arguments: cstring
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gtrgm_in(cstring)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_in$function$;

-- Function: gtrgm_options
-- Return type: void
-- Arguments: internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gtrgm_options(internal)
 RETURNS void
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE
AS '$libdir/pg_trgm', $function$gtrgm_options$function$;

-- Function: gtrgm_out
-- Return type: cstring
-- Arguments: gtrgm
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gtrgm_out(gtrgm)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_out$function$;

-- Function: gtrgm_penalty
-- Return type: internal
-- Arguments: internal, internal, internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gtrgm_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_penalty$function$;

-- Function: gtrgm_picksplit
-- Return type: internal
-- Arguments: internal, internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gtrgm_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_picksplit$function$;

-- Function: gtrgm_same
-- Return type: internal
-- Arguments: gtrgm, gtrgm, internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gtrgm_same(gtrgm, gtrgm, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_same$function$;

-- Function: gtrgm_union
-- Return type: gtrgm
-- Arguments: internal, internal
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.gtrgm_union(internal, internal)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_union$function$;

-- Function: halfvec
-- Return type: halfvec
-- Arguments: halfvec, integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec(halfvec, integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec$function$;

-- Function: halfvec_accum
-- Return type: double precision[]
-- Arguments: double precision[], halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_accum(double precision[], halfvec)
 RETURNS double precision[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_accum$function$;

-- Function: halfvec_add
-- Return type: halfvec
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_add(halfvec, halfvec)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_add$function$;

-- Function: halfvec_avg
-- Return type: halfvec
-- Arguments: double precision[]
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_avg(double precision[])
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_avg$function$;

-- Function: halfvec_cmp
-- Return type: integer
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_cmp(halfvec, halfvec)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_cmp$function$;

-- Function: halfvec_combine
-- Return type: double precision[]
-- Arguments: double precision[], double precision[]
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_combine(double precision[], double precision[])
 RETURNS double precision[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_combine$function$;

-- Function: halfvec_concat
-- Return type: halfvec
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_concat(halfvec, halfvec)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_concat$function$;

-- Function: halfvec_eq
-- Return type: boolean
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_eq(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_eq$function$;

-- Function: halfvec_ge
-- Return type: boolean
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_ge(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_ge$function$;

-- Function: halfvec_gt
-- Return type: boolean
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_gt(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_gt$function$;

-- Function: halfvec_in
-- Return type: halfvec
-- Arguments: cstring, oid, integer
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_in(cstring, oid, integer)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_in$function$;

-- Function: halfvec_l2_squared_distance
-- Return type: double precision
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_l2_squared_distance(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_l2_squared_distance$function$;

-- Function: halfvec_le
-- Return type: boolean
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_le(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_le$function$;

-- Function: halfvec_lt
-- Return type: boolean
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_lt(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_lt$function$;

-- Function: halfvec_mul
-- Return type: halfvec
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_mul(halfvec, halfvec)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_mul$function$;

-- Function: halfvec_ne
-- Return type: boolean
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_ne(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_ne$function$;

-- Function: halfvec_negative_inner_product
-- Return type: double precision
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_negative_inner_product(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_negative_inner_product$function$;

-- Function: halfvec_out
-- Return type: cstring
-- Arguments: halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_out(halfvec)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_out$function$;

-- Function: halfvec_recv
-- Return type: halfvec
-- Arguments: internal, oid, integer
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_recv(internal, oid, integer)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_recv$function$;

-- Function: halfvec_send
-- Return type: bytea
-- Arguments: halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_send(halfvec)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_send$function$;

-- Function: halfvec_spherical_distance
-- Return type: double precision
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_spherical_distance(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_spherical_distance$function$;

-- Function: halfvec_sub
-- Return type: halfvec
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_sub(halfvec, halfvec)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_sub$function$;

-- Function: halfvec_to_float4
-- Return type: real[]
-- Arguments: halfvec, integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_to_float4(halfvec, integer, boolean)
 RETURNS real[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_to_float4$function$;

-- Function: halfvec_to_sparsevec
-- Return type: sparsevec
-- Arguments: halfvec, integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_to_sparsevec(halfvec, integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_to_sparsevec$function$;

-- Function: halfvec_to_vector
-- Return type: vector
-- Arguments: halfvec, integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_to_vector(halfvec, integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_to_vector$function$;

-- Function: halfvec_typmod_in
-- Return type: integer
-- Arguments: cstring[]
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.halfvec_typmod_in(cstring[])
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_typmod_in$function$;

-- Function: hamming_distance
-- Return type: double precision
-- Arguments: bit, bit
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.hamming_distance(bit, bit)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$hamming_distance$function$;

-- Function: hnsw_bit_support
-- Return type: internal
-- Arguments: internal
-- Volatility: VOLATILE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.hnsw_bit_support(internal)
 RETURNS internal
 LANGUAGE c
AS '$libdir/vector', $function$hnsw_bit_support$function$;

-- Function: hnsw_halfvec_support
-- Return type: internal
-- Arguments: internal
-- Volatility: VOLATILE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.hnsw_halfvec_support(internal)
 RETURNS internal
 LANGUAGE c
AS '$libdir/vector', $function$hnsw_halfvec_support$function$;

-- Function: hnsw_sparsevec_support
-- Return type: internal
-- Arguments: internal
-- Volatility: VOLATILE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.hnsw_sparsevec_support(internal)
 RETURNS internal
 LANGUAGE c
AS '$libdir/vector', $function$hnsw_sparsevec_support$function$;

-- Function: hnswhandler
-- Return type: index_am_handler
-- Arguments: internal
-- Volatility: VOLATILE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.hnswhandler(internal)
 RETURNS index_am_handler
 LANGUAGE c
AS '$libdir/vector', $function$hnswhandler$function$;

-- Function: inner_product
-- Return type: double precision
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.inner_product(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_inner_product$function$;

-- Function: inner_product
-- Return type: double precision
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.inner_product(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_inner_product$function$;

-- Function: inner_product
-- Return type: double precision
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.inner_product(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$inner_product$function$;

-- Function: ivfflat_bit_support
-- Return type: internal
-- Arguments: internal
-- Volatility: VOLATILE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.ivfflat_bit_support(internal)
 RETURNS internal
 LANGUAGE c
AS '$libdir/vector', $function$ivfflat_bit_support$function$;

-- Function: ivfflat_halfvec_support
-- Return type: internal
-- Arguments: internal
-- Volatility: VOLATILE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.ivfflat_halfvec_support(internal)
 RETURNS internal
 LANGUAGE c
AS '$libdir/vector', $function$ivfflat_halfvec_support$function$;

-- Function: ivfflathandler
-- Return type: index_am_handler
-- Arguments: internal
-- Volatility: VOLATILE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.ivfflathandler(internal)
 RETURNS index_am_handler
 LANGUAGE c
AS '$libdir/vector', $function$ivfflathandler$function$;

-- Function: jaccard_distance
-- Return type: double precision
-- Arguments: bit, bit
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.jaccard_distance(bit, bit)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$jaccard_distance$function$;

-- Function: l1_distance
-- Return type: double precision
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l1_distance(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_l1_distance$function$;

-- Function: l1_distance
-- Return type: double precision
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l1_distance(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$l1_distance$function$;

-- Function: l1_distance
-- Return type: double precision
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l1_distance(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_l1_distance$function$;

-- Function: l2_distance
-- Return type: double precision
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l2_distance(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_l2_distance$function$;

-- Function: l2_distance
-- Return type: double precision
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l2_distance(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_l2_distance$function$;

-- Function: l2_distance
-- Return type: double precision
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l2_distance(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$l2_distance$function$;

-- Function: l2_norm
-- Return type: double precision
-- Arguments: sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l2_norm(sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_l2_norm$function$;

-- Function: l2_norm
-- Return type: double precision
-- Arguments: halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l2_norm(halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_l2_norm$function$;

-- Function: l2_normalize
-- Return type: sparsevec
-- Arguments: sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l2_normalize(sparsevec)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_l2_normalize$function$;

-- Function: l2_normalize
-- Return type: vector
-- Arguments: vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l2_normalize(vector)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$l2_normalize$function$;

-- Function: l2_normalize
-- Return type: halfvec
-- Arguments: halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l2_normalize(halfvec)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_l2_normalize$function$;

-- Function: match_materias
-- Return type: TABLE(codigo_materia text, nome_materia text, departamento text, ementa text, similaridade double precision)
-- Arguments: query_embedding vector, match_threshold double precision, match_count integer
-- Volatility: STABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.match_materias(query_embedding vector, match_threshold double precision, match_count integer)
 RETURNS TABLE(codigo_materia text, nome_materia text, departamento text, ementa text, similaridade double precision)
 LANGUAGE sql
 STABLE
AS $function$
  select
    codigo_materia,
    nome_materia,
    departamento,
    ementa,
    1 - (embedding <=> query_embedding) as similaridade
  from materias_vetorizadas
  where embedding is not null and 1 - (embedding <=> query_embedding) > match_threshold
  order by embedding <=> query_embedding
  limit match_count;
$function$;

-- Function: set_limit
-- Return type: real
-- Arguments: real
-- Volatility: VOLATILE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.set_limit(real)
 RETURNS real
 LANGUAGE c
 STRICT
AS '$libdir/pg_trgm', $function$set_limit$function$;

-- Function: show_limit
-- Return type: real
-- Arguments: (none)
-- Volatility: STABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.show_limit()
 RETURNS real
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_limit$function$;

-- Function: show_trgm
-- Return type: text[]
-- Arguments: text
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.show_trgm(text)
 RETURNS text[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_trgm$function$;

-- Function: similarity
-- Return type: real
-- Arguments: text, text
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity$function$;

-- Function: similarity_dist
-- Return type: real
-- Arguments: text, text
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.similarity_dist(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_dist$function$;

-- Function: similarity_op
-- Return type: boolean
-- Arguments: text, text
-- Volatility: STABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_op$function$;

-- Function: sparsevec
-- Return type: sparsevec
-- Arguments: sparsevec, integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec(sparsevec, integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec$function$;

-- Function: sparsevec_cmp
-- Return type: integer
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_cmp(sparsevec, sparsevec)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_cmp$function$;

-- Function: sparsevec_eq
-- Return type: boolean
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_eq(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_eq$function$;

-- Function: sparsevec_ge
-- Return type: boolean
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_ge(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_ge$function$;

-- Function: sparsevec_gt
-- Return type: boolean
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_gt(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_gt$function$;

-- Function: sparsevec_in
-- Return type: sparsevec
-- Arguments: cstring, oid, integer
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_in(cstring, oid, integer)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_in$function$;

-- Function: sparsevec_l2_squared_distance
-- Return type: double precision
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_l2_squared_distance(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_l2_squared_distance$function$;

-- Function: sparsevec_le
-- Return type: boolean
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_le(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_le$function$;

-- Function: sparsevec_lt
-- Return type: boolean
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_lt(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_lt$function$;

-- Function: sparsevec_ne
-- Return type: boolean
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_ne(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_ne$function$;

-- Function: sparsevec_negative_inner_product
-- Return type: double precision
-- Arguments: sparsevec, sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_negative_inner_product(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_negative_inner_product$function$;

-- Function: sparsevec_out
-- Return type: cstring
-- Arguments: sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_out(sparsevec)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_out$function$;

-- Function: sparsevec_recv
-- Return type: sparsevec
-- Arguments: internal, oid, integer
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_recv(internal, oid, integer)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_recv$function$;

-- Function: sparsevec_send
-- Return type: bytea
-- Arguments: sparsevec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_send(sparsevec)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_send$function$;

-- Function: sparsevec_to_halfvec
-- Return type: halfvec
-- Arguments: sparsevec, integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_to_halfvec(sparsevec, integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_to_halfvec$function$;

-- Function: sparsevec_to_vector
-- Return type: vector
-- Arguments: sparsevec, integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_to_vector(sparsevec, integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_to_vector$function$;

-- Function: sparsevec_typmod_in
-- Return type: integer
-- Arguments: cstring[]
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.sparsevec_typmod_in(cstring[])
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_typmod_in$function$;

-- Function: strict_word_similarity
-- Return type: real
-- Arguments: text, text
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.strict_word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity$function$;

-- Function: strict_word_similarity_commutator_op
-- Return type: boolean
-- Arguments: text, text
-- Volatility: STABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.strict_word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_commutator_op$function$;

-- Function: strict_word_similarity_dist_commutator_op
-- Return type: real
-- Arguments: text, text
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_commutator_op$function$;

-- Function: strict_word_similarity_dist_op
-- Return type: real
-- Arguments: text, text
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_op$function$;

-- Function: strict_word_similarity_op
-- Return type: boolean
-- Arguments: text, text
-- Volatility: STABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.strict_word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_op$function$;

-- Function: subvector
-- Return type: vector
-- Arguments: vector, integer, integer
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.subvector(vector, integer, integer)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$subvector$function$;

-- Function: subvector
-- Return type: halfvec
-- Arguments: halfvec, integer, integer
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.subvector(halfvec, integer, integer)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_subvector$function$;

-- Function: update_updated_at
-- Return type: trigger
-- Arguments: (none)
-- Volatility: VOLATILE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.update_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- Function: vector
-- Return type: vector
-- Arguments: vector, integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector(vector, integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector$function$;

-- Function: vector_accum
-- Return type: double precision[]
-- Arguments: double precision[], vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_accum(double precision[], vector)
 RETURNS double precision[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_accum$function$;

-- Function: vector_add
-- Return type: vector
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_add(vector, vector)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_add$function$;

-- Function: vector_avg
-- Return type: vector
-- Arguments: double precision[]
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_avg(double precision[])
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_avg$function$;

-- Function: vector_cmp
-- Return type: integer
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_cmp(vector, vector)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_cmp$function$;

-- Function: vector_combine
-- Return type: double precision[]
-- Arguments: double precision[], double precision[]
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_combine(double precision[], double precision[])
 RETURNS double precision[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_combine$function$;

-- Function: vector_concat
-- Return type: vector
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_concat(vector, vector)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_concat$function$;

-- Function: vector_dims
-- Return type: integer
-- Arguments: vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_dims(vector)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_dims$function$;

-- Function: vector_dims
-- Return type: integer
-- Arguments: halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_dims(halfvec)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_vector_dims$function$;

-- Function: vector_eq
-- Return type: boolean
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_eq(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_eq$function$;

-- Function: vector_ge
-- Return type: boolean
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_ge(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_ge$function$;

-- Function: vector_gt
-- Return type: boolean
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_gt(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_gt$function$;

-- Function: vector_in
-- Return type: vector
-- Arguments: cstring, oid, integer
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_in(cstring, oid, integer)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_in$function$;

-- Function: vector_l2_squared_distance
-- Return type: double precision
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_l2_squared_distance(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_l2_squared_distance$function$;

-- Function: vector_le
-- Return type: boolean
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_le(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_le$function$;

-- Function: vector_lt
-- Return type: boolean
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_lt(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_lt$function$;

-- Function: vector_mul
-- Return type: vector
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_mul(vector, vector)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_mul$function$;

-- Function: vector_ne
-- Return type: boolean
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_ne(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_ne$function$;

-- Function: vector_negative_inner_product
-- Return type: double precision
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_negative_inner_product(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_negative_inner_product$function$;

-- Function: vector_norm
-- Return type: double precision
-- Arguments: vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_norm(vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_norm$function$;

-- Function: vector_out
-- Return type: cstring
-- Arguments: vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_out(vector)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_out$function$;

-- Function: vector_recv
-- Return type: vector
-- Arguments: internal, oid, integer
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_recv(internal, oid, integer)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_recv$function$;

-- Function: vector_send
-- Return type: bytea
-- Arguments: vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_send(vector)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_send$function$;

-- Function: vector_spherical_distance
-- Return type: double precision
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_spherical_distance(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_spherical_distance$function$;

-- Function: vector_sub
-- Return type: vector
-- Arguments: vector, vector
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_sub(vector, vector)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_sub$function$;

-- Function: vector_to_float4
-- Return type: real[]
-- Arguments: vector, integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_to_float4(vector, integer, boolean)
 RETURNS real[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_to_float4$function$;

-- Function: vector_to_halfvec
-- Return type: halfvec
-- Arguments: vector, integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_to_halfvec(vector, integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_to_halfvec$function$;

-- Function: vector_to_sparsevec
-- Return type: sparsevec
-- Arguments: vector, integer, boolean
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_to_sparsevec(vector, integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_to_sparsevec$function$;

-- Function: vector_typmod_in
-- Return type: integer
-- Arguments: cstring[]
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_typmod_in(cstring[])
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_typmod_in$function$;

-- Function: word_similarity
-- Return type: real
-- Arguments: text, text
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity$function$;

-- Function: word_similarity_commutator_op
-- Return type: boolean
-- Arguments: text, text
-- Volatility: STABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_commutator_op$function$;

-- Function: word_similarity_dist_commutator_op
-- Return type: real
-- Arguments: text, text
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_commutator_op$function$;

-- Function: word_similarity_dist_op
-- Return type: real
-- Arguments: text, text
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_op$function$;

-- Function: word_similarity_op
-- Return type: boolean
-- Arguments: text, text
-- Volatility: STABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_op$function$;

-- =============================================================================
-- End of functions export (153 total)
-- =============================================================================
-- Database Functions Export
-- Exported at: 2026-02-27T17:44:42.150435+00:00
-- Source: lijmhbstgdinsukovyfl.supabase.co
-- Total functions: 150

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Other Functions
-- -----------------------------------------------------------------------------

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
-- Arguments: halfvec, halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.l1_distance(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_l1_distance$function$;

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
-- Return type: halfvec
-- Arguments: halfvec, integer, integer
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.subvector(halfvec, integer, integer)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_subvector$function$;

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
-- Arguments: halfvec
-- Volatility: IMMUTABLE
-- Security definer: NO

CREATE OR REPLACE FUNCTION public.vector_dims(halfvec)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_vector_dims$function$;

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
-- End of functions export (150 total)
-- =============================================================================
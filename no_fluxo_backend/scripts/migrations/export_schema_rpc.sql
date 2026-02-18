-- ===========================================
-- EXPORT SCHEMA RPC FUNCTION
-- ===========================================
-- Run this migration in Supabase SQL Editor to create the export_schema function
-- This allows the backend to fetch the complete database schema via RPC
-- Exports: tables, columns, views, materialized views, functions (with bodies),
--          triggers (with function definitions), constraints, indexes, policies, enums, sequences

CREATE OR REPLACE FUNCTION public.export_schema()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- Grant execute permission only to service_role (requires service key to call)
REVOKE EXECUTE ON FUNCTION public.export_schema() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.export_schema() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.export_schema() TO service_role;

-- Add a comment for documentation
COMMENT ON FUNCTION public.export_schema() IS 'Exports the complete database schema as JSON including tables, views, functions (with full source code), triggers (with function definitions), all constraints, indexes, policies, enums, sequences, and extensions.';

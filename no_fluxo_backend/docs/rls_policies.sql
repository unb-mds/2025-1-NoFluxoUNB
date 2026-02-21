-- RLS Policies Export
-- Exported at: 2026-02-21T02:45:34.066172+00:00
-- Source: lijmhbstgdinsukovyfl.supabase.co

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE public."co_requisitos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."cursos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."dados_users" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."equivalencias" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."materias" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."materias_por_curso" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."pre_requisitos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."users" ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- DROP EXISTING POLICIES (optional - uncomment if needed)
-- =============================================================================

-- DROP POLICY IF EXISTS "co_requisitos_select_public" ON public."co_requisitos";
-- DROP POLICY IF EXISTS "cursos_select_public" ON public."cursos";
-- DROP POLICY IF EXISTS "dados_users_delete_own" ON public."dados_users";
-- DROP POLICY IF EXISTS "dados_users_insert_own" ON public."dados_users";
-- DROP POLICY IF EXISTS "dados_users_select_own" ON public."dados_users";
-- DROP POLICY IF EXISTS "dados_users_update_own" ON public."dados_users";
-- DROP POLICY IF EXISTS "equivalencias_select_public" ON public."equivalencias";
-- DROP POLICY IF EXISTS "materias_select_public" ON public."materias";
-- DROP POLICY IF EXISTS "materias_por_curso_select_public" ON public."materias_por_curso";
-- DROP POLICY IF EXISTS "pre_requisitos_select_public" ON public."pre_requisitos";
-- DROP POLICY IF EXISTS "users_insert_own" ON public."users";
-- DROP POLICY IF EXISTS "users_select_own" ON public."users";
-- DROP POLICY IF EXISTS "users_update_own" ON public."users";

-- =============================================================================
-- CREATE POLICIES
-- =============================================================================

-- Table: co_requisitos

CREATE POLICY "co_requisitos_select_public"
    ON public."co_requisitos"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (true)
;

-- Table: cursos

CREATE POLICY "cursos_select_public"
    ON public."cursos"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (true)
;

-- Table: dados_users

CREATE POLICY "dados_users_delete_own"
    ON public."dados_users"
    AS PERMISSIVE
    FOR DELETE
    TO authenticated
    USING ((id_user IN ( SELECT users.id_user
   FROM users
  WHERE (users.auth_id = auth.uid()))))
;

CREATE POLICY "dados_users_insert_own"
    ON public."dados_users"
    AS PERMISSIVE
    FOR INSERT
    TO authenticated
    WITH CHECK ((id_user IN ( SELECT users.id_user
   FROM users
  WHERE (users.auth_id = auth.uid()))))
;

CREATE POLICY "dados_users_select_own"
    ON public."dados_users"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING ((id_user IN ( SELECT users.id_user
   FROM users
  WHERE (users.auth_id = auth.uid()))))
;

CREATE POLICY "dados_users_update_own"
    ON public."dados_users"
    AS PERMISSIVE
    FOR UPDATE
    TO authenticated
    USING ((id_user IN ( SELECT users.id_user
   FROM users
  WHERE (users.auth_id = auth.uid()))))
    WITH CHECK ((id_user IN ( SELECT users.id_user
   FROM users
  WHERE (users.auth_id = auth.uid()))))
;

-- Table: equivalencias

CREATE POLICY "equivalencias_select_public"
    ON public."equivalencias"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (true)
;

-- Table: materias

CREATE POLICY "materias_select_public"
    ON public."materias"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (true)
;

-- Table: materias_por_curso

CREATE POLICY "materias_por_curso_select_public"
    ON public."materias_por_curso"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (true)
;

-- Table: pre_requisitos

CREATE POLICY "pre_requisitos_select_public"
    ON public."pre_requisitos"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (true)
;

-- Table: users

CREATE POLICY "users_insert_own"
    ON public."users"
    AS PERMISSIVE
    FOR INSERT
    TO authenticated
    WITH CHECK ((auth_id = auth.uid()))
;

CREATE POLICY "users_select_own"
    ON public."users"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING ((auth_id = auth.uid()))
;

CREATE POLICY "users_update_own"
    ON public."users"
    AS PERMISSIVE
    FOR UPDATE
    TO authenticated
    USING ((auth_id = auth.uid()))
    WITH CHECK ((auth_id = auth.uid()))
;

-- =============================================================================
-- Total: 13 policies across 8 tables
-- =============================================================================
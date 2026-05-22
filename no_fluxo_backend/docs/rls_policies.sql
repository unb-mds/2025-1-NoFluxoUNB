-- RLS Policies Export
-- Exported at: 2026-05-17T03:28:11.944554+00:00
-- Source: lijmhbstgdinsukovyfl.supabase.co

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE public."admins" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."co_requisitos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."cursos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."dados_users" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."equivalencias" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."historicos_usuarios" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."materias" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."materias_por_curso" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."pre_requisitos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ticket_audit_log" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."tickets" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."users" ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- DROP EXISTING POLICIES (optional - uncomment if needed)
-- =============================================================================

-- DROP POLICY IF EXISTS "admins_delete_superadmin" ON public."admins";
-- DROP POLICY IF EXISTS "admins_insert_superadmin" ON public."admins";
-- DROP POLICY IF EXISTS "admins_select_self_or_superadmin" ON public."admins";
-- DROP POLICY IF EXISTS "admins_update_superadmin" ON public."admins";
-- DROP POLICY IF EXISTS "co_requisitos_select_public" ON public."co_requisitos";
-- DROP POLICY IF EXISTS "cursos_select_public" ON public."cursos";
-- DROP POLICY IF EXISTS "dados_users_delete_own" ON public."dados_users";
-- DROP POLICY IF EXISTS "dados_users_insert_own" ON public."dados_users";
-- DROP POLICY IF EXISTS "dados_users_select_own" ON public."dados_users";
-- DROP POLICY IF EXISTS "dados_users_update_own" ON public."dados_users";
-- DROP POLICY IF EXISTS "equivalencias_select_public" ON public."equivalencias";
-- DROP POLICY IF EXISTS "historicos_usuarios_insert_own" ON public."historicos_usuarios";
-- DROP POLICY IF EXISTS "historicos_usuarios_select_own" ON public."historicos_usuarios";
-- DROP POLICY IF EXISTS "materias_select_public" ON public."materias";
-- DROP POLICY IF EXISTS "materias_por_curso_select_public" ON public."materias_por_curso";
-- DROP POLICY IF EXISTS "pre_requisitos_select_public" ON public."pre_requisitos";
-- DROP POLICY IF EXISTS "audit_select_own_or_admin" ON public."ticket_audit_log";
-- DROP POLICY IF EXISTS "tickets_delete_admin" ON public."tickets";
-- DROP POLICY IF EXISTS "tickets_insert_own" ON public."tickets";
-- DROP POLICY IF EXISTS "tickets_select_own_or_admin" ON public."tickets";
-- DROP POLICY IF EXISTS "tickets_update_admin" ON public."tickets";
-- DROP POLICY IF EXISTS "users_insert_own" ON public."users";
-- DROP POLICY IF EXISTS "users_select_own" ON public."users";
-- DROP POLICY IF EXISTS "users_update_own" ON public."users";

-- =============================================================================
-- CREATE POLICIES
-- =============================================================================

-- Table: admins

CREATE POLICY "admins_delete_superadmin"
    ON public."admins"
    AS PERMISSIVE
    FOR DELETE
    TO authenticated
    USING (is_superadmin())
;

CREATE POLICY "admins_insert_superadmin"
    ON public."admins"
    AS PERMISSIVE
    FOR INSERT
    TO authenticated
    WITH CHECK (is_superadmin())
;

CREATE POLICY "admins_select_self_or_superadmin"
    ON public."admins"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (((auth_id = auth.uid()) OR is_superadmin()))
;

CREATE POLICY "admins_update_superadmin"
    ON public."admins"
    AS PERMISSIVE
    FOR UPDATE
    TO authenticated
    USING (is_superadmin())
    WITH CHECK (is_superadmin())
;

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

-- Table: historicos_usuarios

CREATE POLICY "historicos_usuarios_insert_own"
    ON public."historicos_usuarios"
    AS PERMISSIVE
    FOR INSERT
    TO authenticated
    WITH CHECK ((id_user IN ( SELECT users.id_user
   FROM users
  WHERE (users.auth_id = auth.uid()))))
;

CREATE POLICY "historicos_usuarios_select_own"
    ON public."historicos_usuarios"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING ((id_user IN ( SELECT users.id_user
   FROM users
  WHERE (users.auth_id = auth.uid()))))
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

-- Table: ticket_audit_log

CREATE POLICY "audit_select_own_or_admin"
    ON public."ticket_audit_log"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING ((is_ticket_admin() OR (EXISTS ( SELECT 1
   FROM tickets t
  WHERE ((t.id = ticket_audit_log.ticket_id) AND (t.created_by = auth.uid()))))))
;

-- Table: tickets

CREATE POLICY "tickets_delete_admin"
    ON public."tickets"
    AS PERMISSIVE
    FOR DELETE
    TO authenticated
    USING (is_ticket_admin())
;

CREATE POLICY "tickets_insert_own"
    ON public."tickets"
    AS PERMISSIVE
    FOR INSERT
    TO authenticated
    WITH CHECK ((created_by = auth.uid()))
;

CREATE POLICY "tickets_select_own_or_admin"
    ON public."tickets"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (((created_by = auth.uid()) OR is_ticket_admin()))
;

CREATE POLICY "tickets_update_admin"
    ON public."tickets"
    AS PERMISSIVE
    FOR UPDATE
    TO authenticated
    USING (is_ticket_admin())
    WITH CHECK (is_ticket_admin())
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
-- Total: 24 policies across 12 tables
-- =============================================================================
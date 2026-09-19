-- RLS Policies Export
-- Exported at: 2026-07-16T23:00:16.419383+00:00
-- Source: lijmhbstgdinsukovyfl.supabase.co

-- =============================================================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE public."admins" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ai_pricing" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ai_usage_log" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."co_requisitos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."cursos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."dados_users" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."equivalencias" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."historicos_usuarios" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."materias" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."materias_por_curso" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."notificacoes" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."pre_requisitos" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."system_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."ticket_audit_log" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."tickets" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."turmas" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."users" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."vaga_assinaturas" ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- DROP EXISTING POLICIES (optional - uncomment if needed)
-- =============================================================================

-- DROP POLICY IF EXISTS "admins_delete_superadmin" ON public."admins";
-- DROP POLICY IF EXISTS "admins_insert_superadmin" ON public."admins";
-- DROP POLICY IF EXISTS "admins_select_self_or_superadmin" ON public."admins";
-- DROP POLICY IF EXISTS "admins_update_superadmin" ON public."admins";
-- DROP POLICY IF EXISTS "ai_pricing_select_dashboard" ON public."ai_pricing";
-- DROP POLICY IF EXISTS "ai_pricing_write_superadmin" ON public."ai_pricing";
-- DROP POLICY IF EXISTS "ai_usage_select_dashboard" ON public."ai_usage_log";
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
-- DROP POLICY IF EXISTS "notificacoes_select_own" ON public."notificacoes";
-- DROP POLICY IF EXISTS "notificacoes_update_own" ON public."notificacoes";
-- DROP POLICY IF EXISTS "pre_requisitos_select_public" ON public."pre_requisitos";
-- DROP POLICY IF EXISTS "system_settings_select_authenticated" ON public."system_settings";
-- DROP POLICY IF EXISTS "audit_select_own_or_admin" ON public."ticket_audit_log";
-- DROP POLICY IF EXISTS "tickets_delete_admin" ON public."tickets";
-- DROP POLICY IF EXISTS "tickets_insert_own" ON public."tickets";
-- DROP POLICY IF EXISTS "tickets_select_own_or_admin" ON public."tickets";
-- DROP POLICY IF EXISTS "tickets_update_admin" ON public."tickets";
-- DROP POLICY IF EXISTS "turmas_select_public" ON public."turmas";
-- DROP POLICY IF EXISTS "users_insert_own" ON public."users";
-- DROP POLICY IF EXISTS "users_select_own" ON public."users";
-- DROP POLICY IF EXISTS "users_update_own" ON public."users";
-- DROP POLICY IF EXISTS "vaga_assinaturas_delete_own" ON public."vaga_assinaturas";
-- DROP POLICY IF EXISTS "vaga_assinaturas_insert_own" ON public."vaga_assinaturas";
-- DROP POLICY IF EXISTS "vaga_assinaturas_select_own" ON public."vaga_assinaturas";
-- DROP POLICY IF EXISTS "vaga_assinaturas_update_own" ON public."vaga_assinaturas";

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

-- Table: ai_pricing

CREATE POLICY "ai_pricing_select_dashboard"
    ON public."ai_pricing"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (has_admin_scope('dashboard'::text))
;

CREATE POLICY "ai_pricing_write_superadmin"
    ON public."ai_pricing"
    AS PERMISSIVE
    FOR ALL
    TO authenticated
    USING (is_superadmin())
    WITH CHECK (is_superadmin())
;

-- Table: ai_usage_log

CREATE POLICY "ai_usage_select_dashboard"
    ON public."ai_usage_log"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (has_admin_scope('dashboard'::text))
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

-- Table: notificacoes

CREATE POLICY "notificacoes_select_own"
    ON public."notificacoes"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING ((id_user IN ( SELECT users.id_user
   FROM users
  WHERE (users.auth_id = auth.uid()))))
;

CREATE POLICY "notificacoes_update_own"
    ON public."notificacoes"
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

-- Table: pre_requisitos

CREATE POLICY "pre_requisitos_select_public"
    ON public."pre_requisitos"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING (true)
;

-- Table: system_settings

CREATE POLICY "system_settings_select_authenticated"
    ON public."system_settings"
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

-- Table: turmas

CREATE POLICY "turmas_select_public"
    ON public."turmas"
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

-- Table: vaga_assinaturas

CREATE POLICY "vaga_assinaturas_delete_own"
    ON public."vaga_assinaturas"
    AS PERMISSIVE
    FOR DELETE
    TO authenticated
    USING ((id_user IN ( SELECT users.id_user
   FROM users
  WHERE (users.auth_id = auth.uid()))))
;

CREATE POLICY "vaga_assinaturas_insert_own"
    ON public."vaga_assinaturas"
    AS PERMISSIVE
    FOR INSERT
    TO authenticated
    WITH CHECK ((id_user IN ( SELECT users.id_user
   FROM users
  WHERE (users.auth_id = auth.uid()))))
;

CREATE POLICY "vaga_assinaturas_select_own"
    ON public."vaga_assinaturas"
    AS PERMISSIVE
    FOR SELECT
    TO authenticated
    USING ((id_user IN ( SELECT users.id_user
   FROM users
  WHERE (users.auth_id = auth.uid()))))
;

CREATE POLICY "vaga_assinaturas_update_own"
    ON public."vaga_assinaturas"
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

-- =============================================================================
-- Total: 35 policies across 18 tables
-- =============================================================================
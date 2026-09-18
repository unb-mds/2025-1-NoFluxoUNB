-- Bot de rastreamento de segredos (gitleaks) — armazenamento e RPC do dashboard.
-- Aplicar manualmente no SQL Editor do Supabase (idempotente).
--
-- Escrita: somente o workflow security_scan.yml, via secret key (bypassa RLS).
-- Leitura: admins com escopo 'dashboard', via RPC get_security_health().

BEGIN;

CREATE TABLE IF NOT EXISTS public.security_scans (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  run_at         timestamptz NOT NULL DEFAULT now(),
  scan_type      text NOT NULL,                          -- push | schedule | workflow_dispatch
  branch         text,
  commit_sha     text,
  run_url        text,
  tool           text NOT NULL DEFAULT 'gitleaks',
  new_findings   integer NOT NULL DEFAULT 0,             -- achados além da baseline => alerta
  status         text NOT NULL CHECK (status IN ('ok', 'leaks_found')),
  -- Apenas fingerprint/regra/arquivo/commit — NUNCA valores de segredos.
  findings       jsonb NOT NULL DEFAULT '[]'::jsonb
);

CREATE INDEX IF NOT EXISTS security_scans_run_at_idx ON public.security_scans (run_at DESC);

ALTER TABLE public.security_scans ENABLE ROW LEVEL SECURITY;

-- Sem policies de INSERT/UPDATE/DELETE: só a secret key do CI escreve (bypassa RLS).
DROP POLICY IF EXISTS security_scans_select_admin ON public.security_scans;
CREATE POLICY security_scans_select_admin ON public.security_scans
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (public.has_admin_scope('dashboard'));

CREATE OR REPLACE FUNCTION public.get_security_health()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ultimo        public.security_scans%ROWTYPE;
  v_ultimo_ok     timestamptz;
  v_scans_7d      bigint;
  v_falhas_7d     bigint;
BEGIN
  IF NOT public.has_admin_scope('dashboard') THEN
    RAISE EXCEPTION 'forbidden: dashboard scope required';
  END IF;

  SELECT * INTO v_ultimo
  FROM public.security_scans ORDER BY run_at DESC LIMIT 1;

  SELECT max(run_at) INTO v_ultimo_ok
  FROM public.security_scans WHERE status = 'ok';

  SELECT count(*),
         count(*) FILTER (WHERE status = 'leaks_found')
  INTO v_scans_7d, v_falhas_7d
  FROM public.security_scans
  WHERE run_at >= now() - interval '7 days';

  RETURN jsonb_build_object(
    'ultimo_scan_em',    v_ultimo.run_at,
    'ultimo_status',     v_ultimo.status,
    'novos_achados',     COALESCE(v_ultimo.new_findings, 0),
    'ultimo_tipo',       v_ultimo.scan_type,
    'ultimo_run_url',    v_ultimo.run_url,
    'ultimo_ok_em',      v_ultimo_ok,
    'scans_7d',          COALESCE(v_scans_7d, 0),
    'falhas_7d',         COALESCE(v_falhas_7d, 0),
    'achados',           COALESCE(v_ultimo.findings, '[]'::jsonb)
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_security_health() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_security_health() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_security_health() TO authenticated;

COMMIT;

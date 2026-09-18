-- Chat de tickets — mensagens não lidas e resumo da conversa nas listagens.
-- Aplicar manualmente no SQL Editor do Supabase (idempotente), DEPOIS de ticket_chat.sql.
--
-- O que entrega:
--   - ticket_reads: até onde cada usuário leu cada conversa (last_read_message_id).
--   - RPC ticket_mark_read: marca a conversa como lida (chamada ao abrir o chat).
--   - RPC get_my_tickets: "meus chamados" com unread_count + última mensagem.
--   - get_tickets_paginated ganha unread_count + última mensagem (recriada:
--     mudar RETURNS TABLE exige DROP; o front usa as colunas por nome).

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Tabela de leitura (cursor por usuário e ticket)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.ticket_reads (
  ticket_id            bigint NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  user_id              uuid NOT NULL,
  last_read_message_id bigint NOT NULL DEFAULT 0,
  updated_at           timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (ticket_id, user_id)
);

ALTER TABLE public.ticket_reads ENABLE ROW LEVEL SECURITY;

-- Leitura da própria linha; escrita só via RPC (SECURITY DEFINER).
DROP POLICY IF EXISTS ticket_reads_select_own ON public.ticket_reads;
CREATE POLICY ticket_reads_select_own ON public.ticket_reads
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (user_id = auth.uid());

REVOKE ALL ON public.ticket_reads FROM anon;
GRANT SELECT ON public.ticket_reads TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. RPC: marcar conversa como lida
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.ticket_mark_read(p_ticket_id bigint)
RETURNS void
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_ticket public.tickets%ROWTYPE;
  v_max bigint;
BEGIN
  SELECT t.* INTO v_ticket FROM public.tickets t WHERE t.id = p_ticket_id;

  IF v_ticket.id IS NULL THEN
    RAISE EXCEPTION 'ticket not found: %', p_ticket_id;
  END IF;

  IF v_ticket.created_by <> auth.uid() AND NOT public.is_ticket_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COALESCE(max(m.id), 0) INTO v_max
  FROM public.ticket_messages m
  WHERE m.ticket_id = p_ticket_id;

  INSERT INTO public.ticket_reads (ticket_id, user_id, last_read_message_id, updated_at)
  VALUES (p_ticket_id, auth.uid(), v_max, now())
  ON CONFLICT (ticket_id, user_id) DO UPDATE
    SET last_read_message_id = GREATEST(public.ticket_reads.last_read_message_id, EXCLUDED.last_read_message_id),
        updated_at = now();
END;
$function$;

REVOKE ALL ON FUNCTION public.ticket_mark_read(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ticket_mark_read(bigint) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. RPC: meus chamados com resumo da conversa
--    (substitui o SELECT direto em tickets no front do usuário)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_my_tickets()
RETURNS TABLE(
  id bigint, created_by uuid, assigned_to uuid,
  title text, description text, category text, status text, priority text,
  metadata jsonb, attachments jsonb, admin_notes text,
  created_at timestamptz, updated_at timestamptz, resolved_at timestamptz,
  last_message_at timestamptz, last_message_role text, unread_count bigint
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    t.id, t.created_by, t.assigned_to,
    t.title, t.description, t.category, t.status, t.priority,
    t.metadata, t.attachments, t.admin_notes,
    t.created_at, t.updated_at, t.resolved_at,
    lm.created_at  AS last_message_at,
    lm.author_role AS last_message_role,
    (
      SELECT count(*)
      FROM public.ticket_messages m2
      WHERE m2.ticket_id = t.id
        AND m2.author_id <> auth.uid()
        AND m2.id > COALESCE(r.last_read_message_id, 0)
    )::bigint AS unread_count
  FROM public.tickets t
  LEFT JOIN public.ticket_reads r
    ON r.ticket_id = t.id AND r.user_id = auth.uid()
  LEFT JOIN LATERAL (
    SELECT m.created_at, m.author_role
    FROM public.ticket_messages m
    WHERE m.ticket_id = t.id
    ORDER BY m.id DESC
    LIMIT 1
  ) lm ON true
  WHERE t.created_by = auth.uid()
  ORDER BY t.created_at DESC;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_tickets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_tickets() TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. get_tickets_paginated com resumo da conversa (admin)
--    DROP + CREATE porque o RETURNS TABLE muda (3 colunas novas no final).
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.get_tickets_paginated(integer, integer, text, text, text);

CREATE FUNCTION public.get_tickets_paginated(
  p_limit integer DEFAULT 50, p_offset integer DEFAULT 0,
  p_status text DEFAULT NULL::text, p_category text DEFAULT NULL::text,
  p_search text DEFAULT NULL::text
)
RETURNS TABLE(
  id bigint, title text, description text, status text, category text, priority text,
  created_by uuid, creator_name text, creator_email text, assigned_to uuid,
  created_at timestamptz, updated_at timestamptz, resolved_at timestamptz,
  total_count bigint,
  last_message_at timestamptz, last_message_role text, unread_count bigint
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.is_ticket_admin() THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;

  RETURN QUERY
  WITH filtered AS (
    SELECT t.*
    FROM public.tickets t
    WHERE (p_status   IS NULL OR t.status   = p_status)
      AND (p_category IS NULL OR t.category = p_category)
      AND (
        p_search IS NULL OR
        t.title       ILIKE '%' || p_search || '%' OR
        t.description ILIKE '%' || p_search || '%' OR
        t.id::text = p_search
      )
  )
  SELECT
    f.id, f.title, f.description, f.status, f.category, f.priority,
    f.created_by,
    u.nome_completo AS creator_name,
    u.email         AS creator_email,
    f.assigned_to,
    f.created_at, f.updated_at, f.resolved_at,
    (SELECT count(*) FROM filtered)::bigint AS total_count,
    lm.created_at  AS last_message_at,
    lm.author_role AS last_message_role,
    (
      SELECT count(*)
      FROM public.ticket_messages m2
      WHERE m2.ticket_id = f.id
        AND m2.author_id <> auth.uid()
        AND m2.id > COALESCE(r.last_read_message_id, 0)
    )::bigint AS unread_count
  FROM filtered f
  LEFT JOIN public.users u ON u.auth_id = f.created_by
  LEFT JOIN public.ticket_reads r
    ON r.ticket_id = f.id AND r.user_id = auth.uid()
  LEFT JOIN LATERAL (
    SELECT m.created_at, m.author_role
    FROM public.ticket_messages m
    WHERE m.ticket_id = f.id
    ORDER BY m.id DESC
    LIMIT 1
  ) lm ON true
  ORDER BY
    CASE WHEN f.status = 'resolvido' THEN 1 ELSE 0 END,
    f.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_tickets_paginated(integer, integer, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_tickets_paginated(integer, integer, text, text, text) TO authenticated;

COMMIT;

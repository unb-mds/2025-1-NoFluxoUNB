-- =============================================================================
-- Sistema de Tickets (bug + sugestao + duvida) com rastreabilidade
-- Referência: planos/PLANO_SISTEMA_TICKETS_GENERICO.md
--
-- Respostas da Fase 0:
--   Q1 (categorias): 3 fixas — bug, sugestao, duvida
--   Q2 (status):     4 fixos — aberto, em_andamento, aguardando_info, resolvido
--                    'resolvido' é terminal
--   Q3 (comunicação): one-way (sem chat, sem notificação)
--   Q4 (abertura):   campos fixos (título + descrição + categoria + anexos)
--
-- Categorias e status são gerenciados via CHECK constraint (não há tabelas
-- ticket_categories/ticket_statuses porque são poucos e não mudam).
-- Não há tabela ticket_messages porque a comunicação é one-way.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Coluna is_admin em public.users (papel tech do dashboard de tickets)
-- -----------------------------------------------------------------------------
ALTER TABLE public."users"
  ADD COLUMN IF NOT EXISTS "is_admin" boolean NOT NULL DEFAULT false;

-- -----------------------------------------------------------------------------
-- 2. Tabela principal: tickets
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tickets (
  id           bigserial PRIMARY KEY,
  created_by   uuid NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  assigned_to  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title        text NOT NULL,
  description  text NOT NULL,
  category     text NOT NULL CHECK (category IN ('bug','sugestao','duvida')),
  status       text NOT NULL DEFAULT 'aberto'
               CHECK (status IN ('aberto','em_andamento','aguardando_info','resolvido')),
  priority     text NOT NULL DEFAULT 'normal'
               CHECK (priority IN ('low','normal','high','critical')),
  metadata     jsonb NOT NULL DEFAULT '{}'::jsonb,
  attachments  jsonb NOT NULL DEFAULT '[]'::jsonb,
  admin_notes  text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  resolved_at  timestamptz
);

CREATE INDEX IF NOT EXISTS idx_tickets_created_by  ON public.tickets(created_by);
CREATE INDEX IF NOT EXISTS idx_tickets_status      ON public.tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_category    ON public.tickets(category);
CREATE INDEX IF NOT EXISTS idx_tickets_created_at  ON public.tickets(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tickets_metadata    ON public.tickets USING gin (metadata);

-- -----------------------------------------------------------------------------
-- 3. Audit log (coração da rastreabilidade)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ticket_audit_log (
  id         bigserial PRIMARY KEY,
  ticket_id  bigint NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  actor_id   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action     text NOT NULL CHECK (action IN (
               'created','status_changed','assigned','priority_changed',
               'category_changed','note_updated','closed'
             )),
  from_value text,
  to_value   text,
  notes      text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ticket_audit_ticket
  ON public.ticket_audit_log(ticket_id, created_at);

-- -----------------------------------------------------------------------------
-- 4. Helper: é admin?
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_ticket_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_id = auth.uid() AND u.is_admin = true
  );
$$;

-- -----------------------------------------------------------------------------
-- 5. Triggers: audit on INSERT/UPDATE + updated_at + resolved_at stamp
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tickets_on_insert() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.ticket_audit_log(ticket_id, actor_id, action, to_value, notes)
  VALUES (NEW.id, NEW.created_by, 'created', NEW.status,
          'Ticket criado na categoria ' || NEW.category);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.tickets_on_update() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  NEW.updated_at := now();

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO public.ticket_audit_log(ticket_id, actor_id, action, from_value, to_value)
    VALUES (NEW.id, auth.uid(), 'status_changed', OLD.status, NEW.status);

    IF NEW.status = 'resolvido' THEN
      NEW.resolved_at := COALESCE(NEW.resolved_at, now());
    ELSIF OLD.status = 'resolvido' THEN
      -- reabriu: limpar resolved_at
      NEW.resolved_at := NULL;
    END IF;
  END IF;

  IF NEW.assigned_to IS DISTINCT FROM OLD.assigned_to THEN
    INSERT INTO public.ticket_audit_log(ticket_id, actor_id, action, from_value, to_value)
    VALUES (NEW.id, auth.uid(), 'assigned',
            OLD.assigned_to::text, NEW.assigned_to::text);
  END IF;

  IF NEW.priority IS DISTINCT FROM OLD.priority THEN
    INSERT INTO public.ticket_audit_log(ticket_id, actor_id, action, from_value, to_value)
    VALUES (NEW.id, auth.uid(), 'priority_changed', OLD.priority, NEW.priority);
  END IF;

  IF NEW.category IS DISTINCT FROM OLD.category THEN
    INSERT INTO public.ticket_audit_log(ticket_id, actor_id, action, from_value, to_value)
    VALUES (NEW.id, auth.uid(), 'category_changed', OLD.category, NEW.category);
  END IF;

  IF NEW.admin_notes IS DISTINCT FROM OLD.admin_notes THEN
    INSERT INTO public.ticket_audit_log(ticket_id, actor_id, action, notes)
    VALUES (NEW.id, auth.uid(), 'note_updated',
            left(COALESCE(NEW.admin_notes, ''), 200));
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tickets_on_insert ON public.tickets;
CREATE TRIGGER trg_tickets_on_insert
  AFTER INSERT ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.tickets_on_insert();

DROP TRIGGER IF EXISTS trg_tickets_on_update ON public.tickets;
CREATE TRIGGER trg_tickets_on_update
  BEFORE UPDATE ON public.tickets
  FOR EACH ROW EXECUTE FUNCTION public.tickets_on_update();

-- -----------------------------------------------------------------------------
-- 6. RLS
-- -----------------------------------------------------------------------------
ALTER TABLE public.tickets          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_audit_log ENABLE ROW LEVEL SECURITY;

-- tickets: usuário vê os próprios; admin vê tudo
DROP POLICY IF EXISTS "tickets_select_own_or_admin" ON public.tickets;
CREATE POLICY "tickets_select_own_or_admin" ON public.tickets
  FOR SELECT USING (
    created_by = auth.uid() OR public.is_ticket_admin()
  );

DROP POLICY IF EXISTS "tickets_insert_own" ON public.tickets;
CREATE POLICY "tickets_insert_own" ON public.tickets
  FOR INSERT WITH CHECK (created_by = auth.uid());

-- só admin pode atualizar (usuário não edita o próprio ticket após criar)
DROP POLICY IF EXISTS "tickets_update_admin" ON public.tickets;
CREATE POLICY "tickets_update_admin" ON public.tickets
  FOR UPDATE USING (public.is_ticket_admin())
  WITH CHECK (public.is_ticket_admin());

DROP POLICY IF EXISTS "tickets_delete_admin" ON public.tickets;
CREATE POLICY "tickets_delete_admin" ON public.tickets
  FOR DELETE USING (public.is_ticket_admin());

-- audit log: usuário vê log dos próprios tickets; admin vê todos
DROP POLICY IF EXISTS "audit_select_own_or_admin" ON public.ticket_audit_log;
CREATE POLICY "audit_select_own_or_admin" ON public.ticket_audit_log
  FOR SELECT USING (
    public.is_ticket_admin()
    OR EXISTS (
      SELECT 1 FROM public.tickets t
      WHERE t.id = ticket_audit_log.ticket_id AND t.created_by = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- 7. RPC: listagem paginada com filtros (admin-only)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_tickets_paginated(
  p_limit    int  DEFAULT 50,
  p_offset   int  DEFAULT 0,
  p_status   text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_search   text DEFAULT NULL
) RETURNS TABLE (
  id           bigint,
  title        text,
  description  text,
  status       text,
  category     text,
  priority     text,
  created_by   uuid,
  creator_name text,
  creator_email text,
  assigned_to  uuid,
  created_at   timestamptz,
  updated_at   timestamptz,
  resolved_at  timestamptz,
  total_count  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
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
    (SELECT count(*) FROM filtered)::bigint AS total_count
  FROM filtered f
  LEFT JOIN public.users u ON u.auth_id = f.created_by
  ORDER BY
    CASE WHEN f.status = 'resolvido' THEN 1 ELSE 0 END,
    f.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- -----------------------------------------------------------------------------
-- 8. RPC: detalhe (ticket + audit log + creator info)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_ticket_by_id(p_id bigint)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ticket  jsonb;
  v_audit   jsonb;
  v_is_admin boolean := public.is_ticket_admin();
BEGIN
  SELECT to_jsonb(t) || jsonb_build_object(
           'creator_name',  u.nome_completo,
           'creator_email', u.email
         )
    INTO v_ticket
  FROM public.tickets t
  LEFT JOIN public.users u ON u.auth_id = t.created_by
  WHERE t.id = p_id
    AND (v_is_admin OR t.created_by = auth.uid());

  IF v_ticket IS NULL THEN
    RAISE EXCEPTION 'ticket not found or access denied';
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(a) || jsonb_build_object(
           'actor_name', au.nome_completo
         ) ORDER BY a.created_at), '[]'::jsonb)
    INTO v_audit
  FROM public.ticket_audit_log a
  LEFT JOIN public.users au ON au.auth_id = a.actor_id
  WHERE a.ticket_id = p_id;

  RETURN jsonb_build_object('ticket', v_ticket, 'audit_log', v_audit);
END;
$$;

-- -----------------------------------------------------------------------------
-- 9. RPC: mudar status (admin-only, registra nota opcional no audit)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_ticket_status(
  p_id     bigint,
  p_status text,
  p_note   text DEFAULT NULL
) RETURNS public.tickets
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.tickets;
BEGIN
  IF NOT public.is_ticket_admin() THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;

  IF p_status NOT IN ('aberto','em_andamento','aguardando_info','resolvido') THEN
    RAISE EXCEPTION 'invalid status: %', p_status;
  END IF;

  UPDATE public.tickets
     SET status = p_status
   WHERE id = p_id
   RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'ticket not found: %', p_id;
  END IF;

  IF p_note IS NOT NULL AND length(trim(p_note)) > 0 THEN
    UPDATE public.ticket_audit_log
       SET notes = p_note
     WHERE id = (
       SELECT id FROM public.ticket_audit_log
        WHERE ticket_id = p_id AND action = 'status_changed'
        ORDER BY created_at DESC LIMIT 1
     );
  END IF;

  RETURN v_row;
END;
$$;

-- -----------------------------------------------------------------------------
-- 10. Storage bucket para anexos + policies
--     Bucket: ticket-attachments (privado)
--     Path:   {auth.uid()}/{ticket_id}/{filename}
-- -----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('ticket-attachments', 'ticket-attachments', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "ticket_attachments_owner_insert" ON storage.objects;
CREATE POLICY "ticket_attachments_owner_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'ticket-attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "ticket_attachments_owner_or_admin_select" ON storage.objects;
CREATE POLICY "ticket_attachments_owner_or_admin_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'ticket-attachments'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_ticket_admin()
    )
  );

DROP POLICY IF EXISTS "ticket_attachments_owner_delete" ON storage.objects;
CREATE POLICY "ticket_attachments_owner_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'ticket-attachments'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.is_ticket_admin()
    )
  );

-- -----------------------------------------------------------------------------
-- 11. Grants para as RPCs (role authenticated)
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.is_ticket_admin()                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tickets_paginated(int,int,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_ticket_by_id(bigint)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_ticket_status(bigint,text,text) TO authenticated;

COMMIT;

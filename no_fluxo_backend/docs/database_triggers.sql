-- Database Triggers Export
-- Exported at: 2026-05-17T03:28:11.944554+00:00
-- Source: lijmhbstgdinsukovyfl.supabase.co
-- Total triggers: 3

-- =============================================================================
-- TRIGGERS AND TRIGGER FUNCTIONS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Trigger Functions
-- -----------------------------------------------------------------------------

-- Function: public.tickets_on_insert
-- Used by trigger: trg_tickets_on_insert on tickets

CREATE OR REPLACE FUNCTION public.tickets_on_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.ticket_audit_log(ticket_id, actor_id, action, to_value, notes)
  VALUES (NEW.id, NEW.created_by, 'created', NEW.status,
          'Ticket criado na categoria ' || NEW.category);
  RETURN NEW;
END;
$function$;

-- Function: public.tickets_on_update
-- Used by trigger: trg_tickets_on_update on tickets

CREATE OR REPLACE FUNCTION public.tickets_on_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

-- Function: public.set_last_updated_at
-- Used by trigger: trg_set_last_updated_at on turmas

CREATE OR REPLACE FUNCTION public.set_last_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.last_updated_at = now();
  RETURN NEW;
END;
$function$;

-- -----------------------------------------------------------------------------
-- Triggers
-- -----------------------------------------------------------------------------

-- Trigger: trg_tickets_on_insert
-- Table: tickets
-- Type: AFTER INSERT
-- For each: ROW
-- Enabled: YES

CREATE TRIGGER trg_tickets_on_insert AFTER INSERT ON public.tickets FOR EACH ROW EXECUTE FUNCTION tickets_on_insert();

-- Trigger: trg_tickets_on_update
-- Table: tickets
-- Type: BEFORE UPDATE
-- For each: ROW
-- Enabled: YES

CREATE TRIGGER trg_tickets_on_update BEFORE UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION tickets_on_update();

-- Trigger: trg_set_last_updated_at
-- Table: turmas
-- Type: BEFORE UPDATE
-- For each: ROW
-- Enabled: YES

CREATE TRIGGER trg_set_last_updated_at BEFORE UPDATE ON public.turmas FOR EACH ROW EXECUTE FUNCTION set_last_updated_at();

-- =============================================================================
-- End of triggers export (3 triggers)
-- =============================================================================
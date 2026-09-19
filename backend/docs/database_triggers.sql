-- Database Triggers Export
-- Exported at: 2026-07-16T23:00:16.419383+00:00
-- Source: lijmhbstgdinsukovyfl.supabase.co
-- Total triggers: 5

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

-- Function: public.registrar_turma_historico
-- Used by trigger: trg_turmas_historico on turmas

CREATE OR REPLACE FUNCTION public.registrar_turma_historico()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.vagas_ofertadas IS NOT DISTINCT FROM OLD.vagas_ofertadas
     AND NEW.vagas_ocupadas  IS NOT DISTINCT FROM OLD.vagas_ocupadas
     AND NEW.vagas_sobrando  IS NOT DISTINCT FROM OLD.vagas_sobrando
     AND NEW.docente         IS NOT DISTINCT FROM OLD.docente
     AND NEW.horario         IS NOT DISTINCT FROM OLD.horario
     AND NEW.local           IS NOT DISTINCT FROM OLD.local
  THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.turmas_historico (
    id_turmas, id_materia, turma, ano_periodo, observed_at,
    vagas_ofertadas, vagas_ocupadas, vagas_sobrando, docente, horario, local
  ) VALUES (
    NEW.id_turmas, NEW.id_materia, NEW.turma, NEW.ano_periodo, now(),
    NEW.vagas_ofertadas, NEW.vagas_ocupadas, NEW.vagas_sobrando,
    NEW.docente, NEW.horario, NEW.local
  );

  RETURN NEW;
END;
$function$;

-- Function: public.notificar_vaga_disponivel
-- Used by trigger: trg_turmas_notificar_vaga on turmas

CREATE OR REPLACE FUNCTION public.notificar_vaga_disponivel()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_codigo_materia text;
  v_nome_materia text;
BEGIN
  IF NOT (
    (TG_OP = 'UPDATE'
      AND (OLD.vagas_sobrando IS NULL OR OLD.vagas_sobrando <= 0)
      AND (NEW.vagas_sobrando IS NOT NULL AND NEW.vagas_sobrando > 0))
    OR
    (TG_OP = 'INSERT'
      AND NEW.vagas_sobrando IS NOT NULL AND NEW.vagas_sobrando > 0)
  ) THEN
    RETURN NEW;
  END IF;

  SELECT codigo_materia, nome_materia
    INTO v_codigo_materia, v_nome_materia
    FROM public.materias
   WHERE id_materia = NEW.id_materia;

  INSERT INTO public.notificacoes (id_user, tipo, titulo, mensagem, metadata)
  SELECT
    va.id_user,
    'vaga_disponivel',
    'Vaga aberta em ' || COALESCE(v_codigo_materia, 'matéria'),
    'A turma ' || COALESCE(NEW.turma, '') || ' de ' ||
      COALESCE(v_nome_materia, v_codigo_materia, 'matéria') ||
      ' (' || NEW.ano_periodo || ') tem ' || NEW.vagas_sobrando || ' vaga(s) disponível(is).',
    jsonb_build_object(
      'id_turmas', NEW.id_turmas,
      'id_materia', NEW.id_materia,
      'codigo_materia', v_codigo_materia,
      'turma', NEW.turma,
      'ano_periodo', NEW.ano_periodo,
      'vagas_sobrando', NEW.vagas_sobrando
    )
  FROM public.vaga_assinaturas va
  WHERE va.ativa
    AND va.id_materia = NEW.id_materia
    AND va.ano_periodo = NEW.ano_periodo
    AND (va.turma IS NULL OR va.turma = NEW.turma);

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

-- Trigger: trg_turmas_historico
-- Table: turmas
-- Type: AFTER INSERT OR UPDATE
-- For each: ROW
-- Enabled: YES

CREATE TRIGGER trg_turmas_historico AFTER INSERT OR UPDATE ON public.turmas FOR EACH ROW EXECUTE FUNCTION registrar_turma_historico();

-- Trigger: trg_turmas_notificar_vaga
-- Table: turmas
-- Type: AFTER INSERT OR UPDATE
-- For each: ROW
-- Enabled: YES

CREATE TRIGGER trg_turmas_notificar_vaga AFTER INSERT OR UPDATE ON public.turmas FOR EACH ROW EXECUTE FUNCTION notificar_vaga_disponivel();

-- =============================================================================
-- End of triggers export (5 triggers)
-- =============================================================================
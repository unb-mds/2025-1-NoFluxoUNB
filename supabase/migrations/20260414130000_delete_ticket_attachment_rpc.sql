-- =============================================================================
-- RPC admin-only para remover um anexo de ticket em uma única transação:
--   1. apaga o arquivo do bucket ticket-attachments
--   2. remove o metadado correspondente do JSONB tickets.attachments
--   3. registra no audit log
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.delete_ticket_attachment(
  p_ticket_id bigint,
  p_path      text
) RETURNS public.tickets
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ticket public.tickets;
BEGIN
  IF NOT public.is_ticket_admin() THEN
    RAISE EXCEPTION 'forbidden: admin role required';
  END IF;

  SELECT * INTO v_ticket FROM public.tickets WHERE id = p_ticket_id;
  IF v_ticket.id IS NULL THEN
    RAISE EXCEPTION 'ticket not found: %', p_ticket_id;
  END IF;

  -- valida que o path realmente pertence a este ticket
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_ticket.attachments) e
    WHERE e->>'path' = p_path
  ) THEN
    RAISE EXCEPTION 'attachment not found in ticket %: %', p_ticket_id, p_path;
  END IF;

  DELETE FROM storage.objects
   WHERE bucket_id = 'ticket-attachments' AND name = p_path;

  UPDATE public.tickets
     SET attachments = (
       SELECT COALESCE(jsonb_agg(e), '[]'::jsonb)
         FROM jsonb_array_elements(attachments) e
        WHERE e->>'path' <> p_path
     )
   WHERE id = p_ticket_id
   RETURNING * INTO v_ticket;

  INSERT INTO public.ticket_audit_log(ticket_id, actor_id, action, notes)
  VALUES (p_ticket_id, auth.uid(), 'note_updated',
          'Anexo removido: ' || p_path);

  RETURN v_ticket;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_ticket_attachment(bigint, text) TO authenticated;

COMMIT;

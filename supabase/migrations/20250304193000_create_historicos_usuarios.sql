  -- Tabela de histórico de envios de histórico escolar
  -- Um registro por cada upload, para acompanhamento ao longo dos anos e estatísticas
  -- Relacionada a dados_users: cada envio atualiza uma linha em dados_users (id_dado_user)
  -- Alinhada à estrutura do banco (users, dados_users)

  CREATE TABLE IF NOT EXISTS public.historicos_usuarios (
    id_historico bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    id_user bigint NOT NULL,
    id_dado_user bigint,

    -- Dados extraídos do PDF
    curso_extraido text,
    matriz_curricular text,
    matricula text,
    semestre_atual bigint,
    numero_semestre bigint,
    ira numeric,
    media_ponderada numeric,
    carga_horaria_integralizada jsonb,
    suspensoes jsonb,

    -- Dados do fluxograma (casado)
    fluxograma_atual jsonb,
    total_disciplinas integer,
    total_obrigatorias integer,
    total_obrigatorias_concluidas integer,
    total_obrigatorias_pendentes integer,
    percentual_conclusao numeric,

    CONSTRAINT historicos_usuarios_pkey PRIMARY KEY (id_historico),
    CONSTRAINT historicos_usuarios_id_user_fkey FOREIGN KEY (id_user) REFERENCES public.users(id_user) ON DELETE CASCADE,
    CONSTRAINT historicos_usuarios_id_dado_user_fkey FOREIGN KEY (id_dado_user) REFERENCES public.dados_users(id_dado_user) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_historicos_usuarios_id_user ON public.historicos_usuarios(id_user);
  CREATE INDEX IF NOT EXISTS idx_historicos_usuarios_id_dado_user ON public.historicos_usuarios(id_dado_user);
  CREATE INDEX IF NOT EXISTS idx_historicos_usuarios_created_at ON public.historicos_usuarios(created_at);

  ALTER TABLE public.historicos_usuarios ENABLE ROW LEVEL SECURITY;

  -- RLS: usuário só acessa seus próprios registros
  CREATE POLICY "historicos_usuarios_select_own" ON public.historicos_usuarios
    FOR SELECT TO authenticated
    USING (id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid()));

  CREATE POLICY "historicos_usuarios_insert_own" ON public.historicos_usuarios
    FOR INSERT TO authenticated
    WITH CHECK (id_user IN (SELECT id_user FROM public.users WHERE auth_id = auth.uid()));

  COMMENT ON TABLE public.historicos_usuarios IS 'Histórico de envios de histórico escolar por usuário, para acompanhamento e estatísticas ao longo dos anos';

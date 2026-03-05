-- Migration: coluna carga_horaria_integralizada em dados_users
-- Armazena valores extraídos da tabela "Carga Horária Integralizada/Pendente" (linha Integralizado)
-- Formato: { "obrigatoria": number, "optativa": number, "complementar": number, "total": number }

ALTER TABLE public.dados_users
ADD COLUMN IF NOT EXISTS carga_horaria_integralizada jsonb;

COMMENT ON COLUMN public.dados_users.carga_horaria_integralizada IS 'CH integralizada por categoria (obrigatória, optativa, complementar) extraída do histórico escolar';

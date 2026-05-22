-- Adiciona coluna preferencias_plano para Motor 2 (cadeia de formatura personalizada).
-- Armazena preferências do usuário usadas no algoritmo de planejamento:
--   - limiteCreditos: limite de créditos por semestre (16 / 24 / 32)
--   - objetivo: "velocidade" | "equilibrado" (impacta priorização)
--   - trabalha: se aluno trabalha/estagia (ajusta carga sugerida)
alter table if exists public.dados_users
add column if not exists preferencias_plano jsonb
    default '{"limiteCreditos":24,"objetivo":"equilibrado","trabalha":false}'::jsonb;

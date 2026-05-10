alter table if exists public.dados_users
add column if not exists optativas_manuais jsonb not null default '[]'::jsonb;


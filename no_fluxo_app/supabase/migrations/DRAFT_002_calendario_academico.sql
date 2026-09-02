-- ============================================================================
-- DRAFT 002 — calendario_academico (datas do calendário da UnB)
-- ============================================================================
-- STATUS: RASCUNHO. NÃO aplicar sem revisão humana.
--
-- Eventos do calendário acadêmico (matrícula, início/fim de semestre etc.)
-- para o app exibir/agendar lembretes. Leitura liberada para qualquer usuário
-- autenticado; escrita restrita a admins (helper has_admin_scope já existente
-- no banco).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabela
-- ----------------------------------------------------------------------------
create table if not exists public.calendario_academico (
  id           bigint generated always as identity primary key,
  evento       text not null,
  tipo         text check (tipo in (
                 'matricula',
                 'matricula_extraordinaria',
                 'inicio_semestre',
                 'fim_semestre',
                 'trancamento',
                 'outro'
               )),
  data_inicio  date not null,
  data_fim     date,
  ano_periodo  text not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  -- Se houver data_fim, ela não pode ser anterior à data_inicio.
  constraint calendario_academico_datas_validas
    check (data_fim is null or data_fim >= data_inicio)
);

comment on table  public.calendario_academico is
  'Eventos do calendário acadêmico da UnB (matrícula, semestre, trancamento...).';
comment on column public.calendario_academico.ano_periodo is
  'Período letivo no formato usado no resto do banco (ex.: 2026.1).';

create index if not exists idx_calendario_academico_ano_periodo
  on public.calendario_academico (ano_periodo);

create index if not exists idx_calendario_academico_data_inicio
  on public.calendario_academico (data_inicio);

-- Mantém updated_at em dia.
create or replace function public.calendario_academico_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_calendario_academico_updated_at
  before update on public.calendario_academico
  for each row execute function public.calendario_academico_set_updated_at();

-- ----------------------------------------------------------------------------
-- RLS: leitura para autenticados, escrita só admin
-- ----------------------------------------------------------------------------
alter table public.calendario_academico enable row level security;

create policy calendario_select_authenticated on public.calendario_academico
  for select to authenticated
  using (true);

create policy calendario_insert_admin on public.calendario_academico
  for insert to authenticated
  with check (public.has_admin_scope('dashboard'));

create policy calendario_update_admin on public.calendario_academico
  for update to authenticated
  using (public.has_admin_scope('dashboard'))
  with check (public.has_admin_scope('dashboard'));

create policy calendario_delete_admin on public.calendario_academico
  for delete to authenticated
  using (public.has_admin_scope('dashboard'));

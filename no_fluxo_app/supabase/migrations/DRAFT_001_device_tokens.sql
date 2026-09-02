-- ============================================================================
-- DRAFT 001 — device_tokens (tokens FCM por aparelho)
-- ============================================================================
-- STATUS: RASCUNHO. NÃO aplicar sem revisão humana.
--
-- Guarda os tokens de push (FCM) de cada aparelho do usuário. Um usuário pode
-- ter vários aparelhos; um aparelho pode trocar de dono (logout/login com
-- outra conta), por isso o upsert da RPC atualiza o id_user pelo token.
--
-- Depende de: public.users (id_user, auth_id).
-- Consumido por: Edge Function push-dispatch (via service role) e pelo app
-- Flutter (RPCs registrar_device_token / remover_device_token).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabela
-- ----------------------------------------------------------------------------
create table if not exists public.device_tokens (
  id            bigint generated always as identity primary key,
  id_user       bigint not null references public.users (id_user) on delete cascade,
  token         text   not null unique,
  platform      text   check (platform in ('android', 'ios')),
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz not null default now()
);

comment on table  public.device_tokens is
  'Tokens FCM dos aparelhos dos usuários (push de vagas).';
comment on column public.device_tokens.token is
  'Token de registro do FCM. Único: um aparelho pertence a no máximo um usuário por vez.';
comment on column public.device_tokens.last_seen_at is
  'Última vez que o app confirmou o token (init/refresh). Útil para expirar tokens velhos.';

create index if not exists idx_device_tokens_id_user
  on public.device_tokens (id_user);

-- ----------------------------------------------------------------------------
-- RLS: cada usuário só enxerga/mexe nos próprios tokens
-- (a Edge Function usa service role e ignora RLS)
-- ----------------------------------------------------------------------------
alter table public.device_tokens enable row level security;

create policy device_tokens_select_own on public.device_tokens
  for select to authenticated
  using (
    exists (
      select 1 from public.users u
      where u.id_user = device_tokens.id_user
        and u.auth_id = auth.uid()
    )
  );

create policy device_tokens_insert_own on public.device_tokens
  for insert to authenticated
  with check (
    exists (
      select 1 from public.users u
      where u.id_user = device_tokens.id_user
        and u.auth_id = auth.uid()
    )
  );

create policy device_tokens_update_own on public.device_tokens
  for update to authenticated
  using (
    exists (
      select 1 from public.users u
      where u.id_user = device_tokens.id_user
        and u.auth_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.users u
      where u.id_user = device_tokens.id_user
        and u.auth_id = auth.uid()
    )
  );

create policy device_tokens_delete_own on public.device_tokens
  for delete to authenticated
  using (
    exists (
      select 1 from public.users u
      where u.id_user = device_tokens.id_user
        and u.auth_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- RPC: registrar_device_token
-- ----------------------------------------------------------------------------
-- SECURITY DEFINER porque o upsert precisa poder "roubar" um token que hoje
-- pertence a outro usuário (aparelho trocou de dono) — a policy de UPDATE
-- own-only não permitiria isso para o novo dono.
create or replace function public.registrar_device_token(
  p_token    text,
  p_platform text default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_id_user bigint;
begin
  -- Tokens FCM reais têm ~140+ caracteres; recusar strings curtas barra
  -- lixo/typos e reduz a superfície do upsert-reassocia-dono.
  if p_token is null or length(trim(p_token)) < 20 then
    raise exception 'Token inválido (muito curto)';
  end if;

  if p_platform is not null and p_platform not in ('android', 'ios') then
    raise exception 'Plataforma inválida: %', p_platform;
  end if;

  select u.id_user into v_id_user
    from public.users u
   where u.auth_id = auth.uid();

  if v_id_user is null then
    raise exception 'Usuário não autenticado ou sem registro em users';
  end if;

  insert into public.device_tokens (id_user, token, platform)
  values (v_id_user, p_token, p_platform)
  on conflict (token) do update
    set id_user      = excluded.id_user,
        platform     = coalesce(excluded.platform, device_tokens.platform),
        last_seen_at = now();
end;
$$;

-- ----------------------------------------------------------------------------
-- RPC: remover_device_token (chamar no logout)
-- ----------------------------------------------------------------------------
-- Só remove se o token pertencer ao usuário autenticado (não deixa um usuário
-- apagar token alheio mesmo sendo SECURITY DEFINER).
create or replace function public.remover_device_token(
  p_token text
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_id_user bigint;
begin
  select u.id_user into v_id_user
    from public.users u
   where u.auth_id = auth.uid();

  if v_id_user is null then
    return; -- deslogado/sem registro: no-op silencioso
  end if;

  delete from public.device_tokens dt
   where dt.token = p_token
     and dt.id_user = v_id_user;
end;
$$;

-- ----------------------------------------------------------------------------
-- Grants: só usuários autenticados chamam as RPCs
-- ----------------------------------------------------------------------------
revoke execute on function public.registrar_device_token(text, text) from public, anon;
revoke execute on function public.remover_device_token(text)          from public, anon;
grant  execute on function public.registrar_device_token(text, text) to authenticated;
grant  execute on function public.remover_device_token(text)          to authenticated;

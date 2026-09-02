-- DRAFT — NÃO APLICADO. Revisar antes de rodar no Supabase.
--
-- Contexto: as policies *_select_public existentes (rls_policies.sql) são
-- "TO authenticated" — apesar do nome, um cliente com apenas a anon key e SEM
-- sessão recebe conjunto vazio. Isso quebra o modo visitante do app mobile
-- (e explica por que o modo visitante do site depende dos endpoints do
-- Express, que usam service role).
--
-- Esta migration adiciona SELECT para o role `anon` nas tabelas de dados
-- acadêmicos públicos (dados scrapeados do SIGAA público — não há informação
-- pessoal em nenhuma delas). As tabelas own-only (dados_users, notificacoes,
-- vaga_assinaturas, historicos_usuarios) NÃO são tocadas.
--
-- Alternativa, caso não queiram expor leitura anônima: manter como está e
-- fazer o modo visitante do app consumir os endpoints não autenticados do
-- Express (/fluxograma/fluxograma, /cursos/all-cursos,
-- /assistente/turmas-by-codigo).

create policy cursos_select_anon
  on public.cursos for select to anon using (true);

create policy matrizes_select_anon
  on public.matrizes for select to anon using (true);
-- Atenção: `matrizes` hoje está SEM "enable row level security" (lacuna
-- apontada em docs/rls_policies.sql). Se o RLS for habilitado nela, esta
-- policy garante a leitura anônima; enquanto estiver desabilitado, a policy
-- é inócua (acesso já é irrestrito).

create policy materias_select_anon
  on public.materias for select to anon using (true);

create policy materias_por_curso_select_anon
  on public.materias_por_curso for select to anon using (true);

create policy pre_requisitos_select_anon
  on public.pre_requisitos for select to anon using (true);

create policy co_requisitos_select_anon
  on public.co_requisitos for select to anon using (true);

create policy equivalencias_select_anon
  on public.equivalencias for select to anon using (true);

create policy turmas_select_anon
  on public.turmas for select to anon using (true);

-- A RPC periodo_letivo_atual() também precisa ser executável pelo visitante:
grant execute on function public.periodo_letivo_atual() to anon;

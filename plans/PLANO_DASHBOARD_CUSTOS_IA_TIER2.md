# Plano — Dashboard Admin: Tier 1 + Custos de IA + Tier 2

## Context

Existem **rascunhos não commitados e não aplicados** do dashboard Tier 1 no disco
(`src/routes/admin/dashboard/+page.svelte`, `dashboard.service.ts`, `types/dashboard.ts`,
`components/admin/AdminNav.svelte` — todos `??` no git) e a migration
`supabase/migrations/20260414150000_dashboard_rpcs.sql` (gitignored, **nunca aplicada
no banco**). Na prática **o Tier 1 não funciona ainda**: RPCs não existem no Postgres,
nada está commitado nem verificado. Logo, este plano cobre a entrega completa em 3
frentes:

0. **Tier 1 (finalizar/validar)** — aplicar a migration `20260414150000`, verificar a
   página/serviço/guard ponta a ponta, ajustar o que estiver quebrado, commitar.
   Inclui: funil de ativação, crescimento de usuários, **total de usuários**, top
   cursos, métricas de tickets (Tier 3 já está dentro dessa migration).
1. **Seção de custos da IA** — hoje **não existe NENHUM log de uso de IA** (tokens,
   requisições, custo). Decisão do usuário: rastrear **tokens reais** (instrumentar o
   pipeline) e guardar preço numa **tabela `ai_pricing` configurável** pelo superadmin.
2. **Tier 2** — demanda × oferta de turmas e saúde do scraping (dados já existem em
   `turmas`, `materias`, `matrizes`).

Pipeline de IA atual (mapeado):
- Frontend → `POST /assistente/analyze-sabia` (e `/analyze-sabia-stream`)
  — `no_fluxo_backend/src/controllers/assistente_controller.ts:120`
- → `SabiaService.analyzarInteresse()`
  — `no_fluxo_backend/src/services/sabia.service.ts:64` (chama FastAPI `/recomendar`)
- → FastAPI Python `recomendar_materias()`
  — `mcp_agent/api_producao.py:295`; 2 chamadas Maritaca:
  `sabiazinho-4` (`:303`) + `sabia-4` (`:346`); stream em `:375` (`:386`, `:423`).
- A resposta da OpenAI SDK tem `.usage` (`prompt_tokens`, `completion_tokens`,
  `total_tokens`) — hoje **descartado**.

## Abordagem recomendada

### 0. Tier 1 — finalizar e validar (pré-requisito)

Os arquivos já existem em rascunho; o trabalho aqui é **fazer funcionar e commitar**:

- Aplicar `supabase/migrations/20260414150000_dashboard_rpcs.sql` no SQL Editor
  (depende de `admins`/`tickets` já em prod). Confere:
  `SELECT proname FROM pg_proc WHERE proname IN ('get_dashboard_overview',
  'get_user_growth','get_top_cursos','get_ticket_metrics');` → 4 linhas.
- Revisar/validar os arquivos rascunho existentes (corrigir o que estiver quebrado):
  - `src/routes/admin/dashboard/+page.svelte` (funil, crescimento, total de
    usuários, top cursos, bloco de tickets)
  - `src/lib/services/dashboard.service.ts`, `src/lib/types/dashboard.ts`
  - `src/lib/components/admin/AdminNav.svelte` (sub-nav Dashboard↔Tickets)
  - `src/routes/admin/tickets/+page.svelte` (já recebeu AdminNav + check de escopo —
    está como `M` no git, validar)
- Verificar guard: `hasAdminScope(user,'dashboard')` no `onMount` e no `authGuard`
  redirecionando não-admin; link "Admin" do `Navbar.svelte` aponta p/ `ADMIN_DASHBOARD`.
- `npm run check`/`eslint`/`vite build` limpos nesses arquivos; testar a página
  logado como admin (desktop + mobile).
- **Commitar** Tier 1 (frontend) num commit próprio antes de seguir p/ IA/Tier 2.

### 1. Banco — nova migration `supabase/migrations/20260414160000_ai_cost_and_tier2.sql`

> Migrations são gitignored — aplicar manualmente no SQL Editor após escrever (mesmo
> fluxo das migrations anteriores). Depende das migrations de `admins` (helper
> `has_admin_scope`) e `tickets` já em produção.

**Tabela `ai_pricing`** (preço por modelo, editável):
```
model text PK, input_per_1k numeric NOT NULL DEFAULT 0,
output_per_1k numeric NOT NULL DEFAULT 0, currency text NOT NULL DEFAULT 'BRL',
updated_at timestamptz DEFAULT now(), updated_by uuid
```
Seed: linhas `sabiazinho-4`, `sabia-4`, `gemini-embedding-001` com preço `0`
(o time preenche o valor real depois — comentário no SQL apontando isso).

**Tabela `ai_usage_log`** (1 linha por requisição de IA):
```
id bigserial PK, created_at timestamptz DEFAULT now(), endpoint text,
model text, prompt_tokens int DEFAULT 0, completion_tokens int DEFAULT 0,
total_tokens int DEFAULT 0, duration_ms int, success boolean DEFAULT true,
request_excerpt text  -- primeiros ~120 chars do "materia", p/ contexto (sem PII de user)
```
Decisão: **sem `user_id`** (log anônimo) para não exigir mudança no contrato
frontend→backend; dá pra adicionar depois. Índice em `created_at` e `model`.

**RLS:** `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`; `SELECT` em ambas gated por
`has_admin_scope('dashboard')`; `INSERT/UPDATE` em `ai_pricing` só `is_superadmin()`.
Backend insere em `ai_usage_log` via **service role** (bypassa RLS).

**RPCs `SECURITY DEFINER` + `has_admin_scope('dashboard')`:**
- `get_ai_cost_metrics(p_days int DEFAULT 30)` → JSON:
  custo = `prompt_tokens/1000*input_per_1k + completion_tokens/1000*output_per_1k`
  (JOIN `ai_usage_log` × `ai_pricing` por `model`); retorna `custo_total`,
  `por_modelo` (tokens+custo), `por_dia` (série), `total_requisicoes`,
  `tokens_medios_por_req`, `moeda`.
- `get_turmas_demanda(p_periodo text DEFAULT NULL)` → JSON: soma
  `vagas_ofertadas/ocupadas/sobrando`, taxa de ocupação global, top 10 matérias mais
  concorridas (JOIN `turmas`×`materias`), filtro opcional por `ano_periodo`.
- `get_scraping_health()` → JSON: `max/min(turmas.last_updated_at)`, % `materias`
  sem `ementa`, nº `cursos` sem `matriz`, contagem de turmas por faixa de idade do dado.
- (Opcional v1) `upsert_ai_pricing(model,input,output,currency)` superadmin-only —
  ou editar preço direto pelo Table Editor; plano usa Table Editor p/ v1, RPC fica como
  follow-up anotado.

### 2. Instrumentação do pipeline de IA (tokens reais)

**`mcp_agent/api_producao.py`** (`recomendar_materias`, ~:295–360):
- Acumular `resp.usage` de cada `client_maritaca.chat.completions.create()`
  (linhas 303 e 346) numa lista `usage_calls=[{model, prompt_tokens, completion_tokens}]`.
- Adicionar `"usage": usage_calls` ao `return {...}` de sucesso (`:357`)
  e `[]` nos returns de erro precoces.
- Stream (`recomendar_materias_stream`, :375): passar
  `stream_options={"include_usage": True}` no `create()` (:423) e capturar o
  chunk final com `usage`; emitir como evento SSE final `{stage:'usage', ...}`.
  **Risco/uncertainty:** Maritaca pode não suportar `include_usage` no stream — se
  não vier, logar a requisição com `tokens=0`/null (conta requisição+duração, custo
  só do fluxo não-stream). Anotado como ponto a validar em runtime.

**`no_fluxo_backend/src/services/sabia.service.ts`:**
- `SabiaResponse` ganha `usage?: { model:string; prompt_tokens:number; completion_tokens:number }[]`.
- `analyzarInteresse` repassa `result.usage` (já vem do JSON do FastAPI).

**`no_fluxo_backend/src/controllers/assistente_controller.ts`** (`analyze-sabia` e o
handler de stream):
- Após obter `result`/fim do stream, **fire-and-forget** (com `.catch` que só loga):
  `SupabaseWrapper.get().from('ai_usage_log').insert({...})` agregando os `usage`
  por modelo (1 linha por modelo). Nunca bloquear nem quebrar a resposta ao usuário
  se o log falhar.

### 3. Frontend

- **`src/lib/types/dashboard.ts`**: `AiCostMetrics`, `TurmasDemanda`, `ScrapingHealth`.
- **`src/lib/services/dashboard.service.ts`**: `getAiCostMetrics()`,
  `getTurmasDemanda()`, `getScrapingHealth()` (mesmo padrão dos métodos existentes).
- **`src/routes/admin/dashboard/+page.svelte`**: 3 seções novas reusando os
  componentes/CSS já existentes (stat cards, barras, ranking):
  - **Custos de IA**: card custo total do período + custo por modelo (ranking) +
    série diária (barras) + nº requisições + tokens médios. Aviso visível se
    `ai_pricing` ainda está com preço 0 ("Preços não configurados — defina em
    ai_pricing").
  - **Demanda de turmas**: vagas ofertadas/ocupadas/sobrando + taxa de ocupação +
    top matérias concorridas.
  - **Saúde do scraping**: data do dado mais antigo/novo, % matérias sem ementa,
    cursos sem matriz.
  - Carregar tudo no `Promise.all` existente do `loadAll()`.

### Arquivos críticos
- `supabase/migrations/20260414160000_ai_cost_and_tier2.sql` (novo)
- `mcp_agent/api_producao.py` (instrumentar usage; ~:295–360, :375–430)
- `no_fluxo_backend/src/services/sabia.service.ts` (propagar usage; ~:17, :64–103)
- `no_fluxo_backend/src/controllers/assistente_controller.ts` (insert log; ~:120–168 + handler stream)
- `no_fluxo_frontend_svelte/src/lib/types/dashboard.ts`
- `no_fluxo_frontend_svelte/src/lib/services/dashboard.service.ts`
- `no_fluxo_frontend_svelte/src/routes/admin/dashboard/+page.svelte`

### Reuso (não recriar)
- `has_admin_scope()` / `is_superadmin()` — migration de admins (já em prod).
- `SupabaseWrapper.get()` — padrão de insert do backend
  (`no_fluxo_backend/src/controllers/users_controller.ts`).
- `dashboardService` + tipos + widgets/CSS do dashboard (já criados).
- `hasAdminScope(user,'dashboard')` no guard/onMount (já implementado).

## Verificação (ponta a ponta)

0. **Tier 1**: migration `20260414150000` aplicada (4 RPCs presentes); abrir
   `/admin/dashboard` logado como admin → funil, crescimento, total de usuários,
   top cursos e bloco de tickets renderizam com dados reais; sub-nav alterna p/
   `/admin/tickets`; não-admin é redirecionado. Tier 1 commitado.
1. **Migration (IA/Tier2)**: aplicar SQL no Supabase; rodar checagem:
   `SELECT proname FROM pg_proc WHERE proname IN
   ('get_ai_cost_metrics','get_turmas_demanda','get_scraping_health');` → 3 linhas;
   `SELECT * FROM ai_pricing;` → 3 seeds.
2. **Backend/IA**: subir `api_producao.py` + backend; fazer 1 pergunta no Assistente
   pela UI; conferir `SELECT * FROM ai_usage_log ORDER BY created_at DESC LIMIT 1;`
   → linha com `prompt_tokens`/`completion_tokens` > 0 e `model` correto.
3. **Preço**: `UPDATE ai_pricing SET input_per_1k=..., output_per_1k=... WHERE
   model='sabia-4';` (valores reais Maritaca) → recarregar dashboard → custo > 0.
4. **Dashboard**: logado como admin com escopo `dashboard`, abrir `/admin/dashboard`;
   ver seções Custos de IA / Demanda turmas / Saúde scraping com dados reais; testar
   desktop e mobile (≤900px empilha).
5. **Resiliência**: forçar erro no insert do log e repetir uma pergunta no Assistente
   → resposta da IA ao usuário **não pode** falhar (log é fire-and-forget).
6. **Qualidade**: `npm run check` (sem erros novos nos arquivos tocados), `eslint`
   nos arquivos alterados, `vite build` ok. Python: `python -m py_compile
   mcp_agent/api_producao.py`.

## Notas / decisões em aberto
- Stream `include_usage` pode não ser suportado pela Maritaca — fallback definido
  (logar requisição sem tokens). Validar em runtime no passo 2.
- Log anônimo (sem `user_id`) por simplicidade; atribuição por usuário é follow-up.
- Edição de preço via Table Editor no v1; RPC `upsert_ai_pricing` + UI fica como
  follow-up.
- Embeddings de catálogo (`materias_vetorizadas`) são one-off local (sem custo
  recorrente) — fora do tracking. Só Gemini de busca seria recorrente; baixo volume,
  follow-up opcional.

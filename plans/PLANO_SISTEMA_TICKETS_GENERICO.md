# Plano Genérico: Sistema de Tickets (Bug + Suporte) com Rastreabilidade

> **Leitor-alvo:** uma IA (Claude Code, ou similar) que vai implementar este plano em **outro repositório** — não no GuiaFlix. Este arquivo é o contrato de trabalho.

> **Stack-neutro:** este plano descreve **arquitetura e estruturas**, não uma stack fixa. Os exemplos de código (SQL, Dart, TypeScript) servem como **referência canônica** — você **deve traduzi-los para a stack real do projeto-alvo** (ver §0.1 abaixo) antes de implementar. A lógica, os nomes de tabelas/colunas, os padrões de RPC/RLS e a topologia de UI são o que importa replicar.

---

## Context

Este plano existe para replicar, em **outro app**, a mesma arquitetura robusta de tickets que já está em produção no GuiaFlix Dashboard. O app-alvo precisa de **rastreabilidade de bugs e solicitações de suporte**, com uma interface administrativa enxuta usada **apenas pelo time técnico**. Não haverá devolução de tickets ao usuário final, não haverá múltiplos níveis de triagem nem formulários multi-step — a camada admin é só para o tech visualizar, classificar, comentar (se aplicável) e fechar.

A estrutura de referência vem do repositório-fonte **`guiaflix-dashboard`** (Flutter Web + Supabase/Postgres). Os padrões relevantes para estudo (quando o projeto-alvo tiver acesso ao fonte) estão em:

- **Banco:** `supabase/migrations/20260406000000_chatbot_tables.sql`, `supabase/migrations/20260406000300_chatbot_rpcs_update_tickets_paginated.sql`, `supabase/migrations/20260313000000_tickets_flags_preciso_voltar.sql`
- **Edge Function (opcional / IA):** `supabase/functions/chatbot-process/`
- **Serviço Flutter:** `lib/features/tickets/domain/ticket_service.dart`
- **Controller + UI:** `lib/features/tickets/presentation/controllers/ticket_controller.dart`, `lib/features/tickets/presentation/pages/ticket_page_getx.dart`

O que NÃO deve ser transportado:
- Terminologia de domínio do Guia (aluno, id_admin, acesso_dashboard, TICKETS_problems, USUARIO_planos, textos em pt-BR hardcoded como "Aberto"/"Resolvido", formulário multi-step de tech handoff, flags "preciso voltar", mascote do pato).
- Nomes de categoria/status concretos — esses são definidos na **Fase 0** abaixo.
- **Framework/SDK específico** — Flutter + Supabase é apenas a stack de origem; o plano descreve intenção arquitetural, não código literal.

---

## Fase 0 — Perguntas obrigatórias ao usuário (fazer ANTES de codar)

> A IA executora **deve** usar um mecanismo de pergunta estruturada (ex.: `AskUserQuestion`) para coletar estas respostas. **Não assumir defaults.** Registrar as respostas no topo do plano antes de seguir.

### §0.1. Detecção de stack (fazer ANTES das perguntas de negócio)

Antes de perguntar ao usuário sobre categorias/status/comunicação, **inspecionar o repositório-alvo** e identificar:

| Camada | O que descobrir | Fontes típicas |
|---|---|---|
| **Frontend** | Framework (Flutter, React, React Native, Next.js, SwiftUI, Kotlin/Compose, etc.), gerenciador de estado (GetX, Riverpod, Redux, Zustand, MobX, Bloc, SwiftUI @Observable, etc.), roteador, design system existente | `pubspec.yaml`, `package.json`, `Podfile`, `build.gradle`, estrutura de pastas |
| **Backend** | Modelo (BaaS como Supabase/Firebase/Appwrite, ou API própria em Node/Go/Rails/Django/Elixir/etc.), ORM, padrão de autenticação (JWT, cookie, OAuth) | `supabase/`, `firebase.json`, `prisma/`, `migrations/`, `app/controllers/`, `main.go` |
| **Banco** | Engine (Postgres, MySQL, SQLite, Firestore, DynamoDB, MongoDB), ferramenta de migration (Supabase CLI, Prisma, Flyway, Alembic, Ecto, Rails, Knex) | `migrations/`, `schema.prisma`, `db/schema.rb` |
| **Realtime** | Se existe (Supabase Realtime, Firebase Realtime DB, Pusher/Ably, WebSocket próprio) ou não | Dependências, imports no código atual |
| **Storage** | Onde armazenar anexos (Supabase Storage, S3, Cloudinary, Firebase Storage) | Configurações de upload existentes |
| **Idioma/i18n** | Como copy de UI é gerenciada (i18n, hardcode, ARB, JSON) | Pasta `l10n/`, `locales/`, `i18n/` |

**Saída:** uma seção "Stack detectada" no topo da implementação, registrando cada item. Toda decisão seguinte do plano deve **traduzir** os exemplos deste documento para essa stack — não copiar literalmente.

**Exemplos de tradução:**
- SQL de Postgres → equivalente em MySQL / Firestore schema / Prisma model / ActiveRecord migration.
- `await supabase.from('tickets').insert(...)` → `prisma.ticket.create(...)` / `db.collection('tickets').add(...)` / `ticketRepository.create(...)` / `POST /api/tickets`.
- Supabase Realtime → Firestore snapshots / Pusher channels / WebSocket handler / polling se nada mais existir.
- Supabase RLS → middleware de autorização / policies do ORM / regras de Firestore.
- Flutter `GetX` controller → hook React + Zustand / ViewModel MVVM / Riverpod provider / store Pinia.
- Supabase Edge Functions (Deno) → Cloud Functions / AWS Lambda / rota da API do backend / serverless function equivalente.

Se alguma camada **não existe** no projeto-alvo (ex.: não há realtime, não há storage), anotar e escolher alternativa antes de prosseguir (push via polling, anexos como URL externa, etc.).

### Q1. Quantas categorias de ticket?
- **2 categorias** — Ex.: `bug`, `suporte`. Minimalista.
- **3–5 categorias** — Ex.: `bug`, `sugestao`, `duvida`, `financeiro`, `outros`.
- **6+ categorias** — Granular, para roteamento preciso.
- **1 categoria + campo livre** — Começa simples, estrutura depois.

> **Saída esperada:** lista final de slugs (`snake_case`) + labels legíveis + cor sugerida por categoria. Ex.: `[{slug:"bug", label:"Bug", color:"red"}, {slug:"feature", label:"Sugestão", color:"purple"}]`.

### Q2. Quantos status de ticket? Quer que sejam configuráveis em tabela?
- **3 status** — `aberto` → `em_andamento` → `resolvido`.
- **4 status** — adiciona `aguardando_info`.
- **5–6 status** — `novo`, `triagem`, `em_andamento`, `aguardando`, `resolvido`, `fechado`.
- **Configurável via tabela** — status vivem em `ticket_statuses` e podem ser editados sem migration de código.

> **Saída esperada:** lista final de slugs + labels + cor + ordem + `is_terminal` (boolean, marca status finais como `resolvido`/`fechado`).

### Q3. Como será a comunicação com o usuário que abriu o ticket?
- **Somente recebimento (one-way)** — usuário envia e pronto. Tech só lê. Sem chat, sem status notificado.
- **Recebimento + notificação de status** — tech não conversa, mas o app dispara push/email quando o status muda.
- **Chat bidirecional** — tech e usuário trocam mensagens até resolver (como no GuiaFlix hoje).
- **Chat + chatbot IA de triagem** — IA coleta dados antes de escalar para o tech.

> **Saída esperada:** uma das 4 opções. Esta resposta **ativa ou desativa seções inteiras** deste plano (ver §5).

### Q4. Como o usuário abre o ticket?
- **Campo único livre** — apenas título + descrição + categoria.
- **Campos fixos iguais para todas as categorias** — título, descrição, passos, anexo.
- **Formulário dinâmico por categoria** — cada categoria pede campos diferentes.
- **Livre + anexos** — texto livre + upload de 1–3 arquivos/imagens.

> **Saída esperada:** schema do payload de criação e, se for formulário dinâmico, mapa `categoria → campos[]`.

---

## 1. Visão geral da arquitetura (genérica)

```
┌──────────────────────────────────────────────────────────────────┐
│  APP DO USUÁRIO FINAL  (qualquer framework cliente)              │
│   - Cria ticket (payload conforme Q4)                            │
│   - [Se Q3 = chat] recebe/envia mensagens                        │
│   - [Se Q3 = notificação] ouve mudanças de status                │
└───────────────────────────┬──────────────────────────────────────┘
                            │ SDK/HTTP do backend (JWT do usuário)
                            │ + canal de realtime (se aplicável)
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│  BACKEND + BANCO  (BaaS ou API própria)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │  tickets     │  │ ticket_      │  │ ticket_statuses      │   │
│  │              │  │ messages*    │  │ (se Q2=configurável) │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ ticket_      │  │ ticket_      │  │ ticket_audit_log     │   │
│  │ categories*  │  │ attachments* │  │ (rastreabilidade)    │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
│  Endpoints/RPCs: list_paginated, get_by_id,                      │
│                  update_status, add_message*                     │
│  Função serverless (opcional, só se Q3 = Chat + IA): triage-bot  │
│  Autorização: user vê só os próprios; role=tech vê tudo          │
└──────────────────────────────────┬───────────────────────────────┘
                                   │ JWT do admin tech
                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│  DASHBOARD TECH  (mesmo framework do app, ou web dedicada)       │
│   - Lista paginada + filtros (status, categoria, busca)          │
│   - Detalhe split-pane (lista à esquerda, conteúdo à direita)    │
│   - Ações: trocar status, [se Q3=chat] responder, fechar         │
└──────────────────────────────────────────────────────────────────┘
```

`*` = tabelas/endpoints condicionais — criar apenas se a resposta da Fase 0 exigir.

> **Nota:** "RPC", "endpoint", "função remota" e "mutation" são intercambiáveis aqui. Nas stacks Supabase/Postgres usa-se RPC via `create function`. Em Firebase, Cloud Functions; em REST/GraphQL, rotas/resolvers. O contrato (parâmetros, retorno) é o que importa.

---

## 2. Banco de dados

> **Leia antes:** os blocos SQL abaixo são **referência canônica em PostgreSQL**. Se o projeto-alvo usa outra engine ou uma camada de abstração (Prisma, TypeORM, ActiveRecord, Ecto, Firestore, DynamoDB), **traduza preservando os mesmos campos, tipos semânticos, índices e constraints**. Exemplos de tradução por stack aparecem no final desta seção.

### 2.1 Tabela `tickets` (sempre criar)

```sql
create table public.tickets (
  id             bigserial primary key,
  created_by     uuid not null references auth.users(id) on delete set null,
  assigned_to    uuid references auth.users(id) on delete set null,  -- tech responsável (opcional)
  title          text not null,
  description    text not null,
  category       text not null,       -- slug definido em Q1
  status         text not null,       -- slug definido em Q2
  priority       text default 'normal', -- low | normal | high | critical
  metadata       jsonb default '{}'::jsonb, -- payload livre (form dinâmico de Q4, contexto do app, user-agent, etc.)
  attachments    jsonb default '[]'::jsonb, -- array de {url, name, mime, size} se Q4 permitir anexos
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  resolved_at    timestamptz,
  closed_at      timestamptz
);

create index idx_tickets_created_by on public.tickets(created_by);
create index idx_tickets_status     on public.tickets(status);
create index idx_tickets_category   on public.tickets(category);
create index idx_tickets_created_at on public.tickets(created_at desc);
create index idx_tickets_metadata   on public.tickets using gin (metadata);
```

**Decisões deliberadas (aplicar à sua stack):**
- `created_by` e `assigned_to` referenciam a tabela/coleção de **usuários autenticados do projeto-alvo**. Em Supabase, `auth.users(id)` (uuid). Em Firebase, `uid` (string). Em API própria, a PK da tabela `users`. **Não criar `id_admin` custom.**
- `metadata` é um **campo JSON/JSONB arbitrário** — absorve campos específicos do app-alvo sem novas migrations. Equivalentes: JSON em MySQL 5.7+, Map em Firestore, jsonb no Postgres, `text` + parse em SQLite antigo.
- `resolved_at` e `closed_at` são separados para permitir fluxo "resolvido → reaberto → fechado" se Q2 pedir.
- `attachments` como JSON inline é ideal para Supabase/Postgres. Em Firestore, subcolleção `attachments`. Em SQL tradicional com ORM, pode virar tabela filha `ticket_attachments`.

### 2.2 Tabela `ticket_categories` — **criar somente se Q1 = 6+ ou "configurável"**

```sql
create table public.ticket_categories (
  slug       text primary key,
  label      text not null,
  color      text,           -- token de cor do design system
  icon       text,
  sort_order int default 0,
  is_active  boolean default true
);
```

Se Q1 = 2 a 5 categorias fixas: **não criar tabela** — manter como CHECK constraint ou enum:

```sql
alter table tickets add constraint tickets_category_check
  check (category in ('bug','feature','duvida' /* ... */));
```

### 2.3 Tabela `ticket_statuses` — **criar somente se Q2 = "configurável"**

```sql
create table public.ticket_statuses (
  slug        text primary key,
  label       text not null,
  color       text,
  sort_order  int default 0,
  is_terminal boolean default false,  -- true p/ "resolvido", "fechado"
  is_active   boolean default true
);
```

Caso contrário, use CHECK constraint com os slugs definidos em Q2.

### 2.4 Tabela `ticket_messages` — **criar somente se Q3 = chat bidirecional ou chat+IA**

```sql
create table public.ticket_messages (
  id          bigserial primary key,
  ticket_id   bigint not null references public.tickets(id) on delete cascade,
  author_id   uuid not null references auth.users(id) on delete set null,
  author_role text not null check (author_role in ('user','tech','ai','system')),
  content     text not null,
  attachments jsonb default '[]'::jsonb,
  created_at  timestamptz not null default now()
);
create index idx_ticket_messages_ticket on public.ticket_messages(ticket_id, created_at);
```

**NÃO use o padrão `ticket_json` em coluna TEXT do GuiaFlix** — é um débito técnico (dificulta query, quebra realtime por mensagem). Use tabela normalizada.

### 2.5 Tabela `ticket_attachments` — opcional, se quiser metadados separados

Para a maioria dos casos, o JSONB `attachments` em `tickets`/`ticket_messages` é suficiente. Só crie tabela separada se for necessário listar/buscar anexos globalmente.

### 2.6 Tabela `ticket_audit_log` (sempre criar — é o coração da rastreabilidade)

```sql
create table public.ticket_audit_log (
  id         bigserial primary key,
  ticket_id  bigint not null references public.tickets(id) on delete cascade,
  actor_id   uuid references auth.users(id) on delete set null,
  action     text not null,        -- 'created' | 'status_changed' | 'assigned' | 'message_added' | 'category_changed' | 'closed'
  from_value text,
  to_value   text,
  notes      text,
  created_at timestamptz not null default now()
);
create index idx_ticket_audit_ticket on public.ticket_audit_log(ticket_id, created_at);
```

Esta tabela é o diferencial para **rastreabilidade** — toda mudança de status, atribuição, categoria vira uma linha. Nenhum dashboard de suporte sério fica sem isso.

### 2.7 Trigger de atualização

```sql
create or replace function public.tickets_on_update() returns trigger as $$
begin
  new.updated_at := now();
  if new.status <> old.status then
    insert into public.ticket_audit_log(ticket_id, actor_id, action, from_value, to_value)
    values (new.id, auth.uid(), 'status_changed', old.status, new.status);

    -- se status virou terminal, carimbar resolved_at/closed_at
    if new.status in (select slug from public.ticket_statuses where is_terminal) then
      new.resolved_at := coalesce(new.resolved_at, now());
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_tickets_on_update
  before update on public.tickets
  for each row execute function public.tickets_on_update();
```

> Se Q2 usar CHECK constraint em vez de tabela, adaptar a lista de status terminais dentro da função.

### 2.8 RLS (Row Level Security)

```sql
alter table public.tickets enable row level security;

-- Usuário vê/cria apenas os próprios tickets
create policy "users_see_own_tickets" on public.tickets
  for select using (created_by = auth.uid());

create policy "users_insert_own_tickets" on public.tickets
  for insert with check (created_by = auth.uid());

-- Tech role (definir via custom claim no JWT ou tabela tech_users)
create policy "tech_full_access" on public.tickets
  for all using (
    auth.jwt() ->> 'role' = 'tech'  -- ou: exists (select 1 from tech_users where id = auth.uid())
  );
```

> Replicar políticas análogas em `ticket_messages` e `ticket_audit_log`. **Nunca** expor `ticket_audit_log` para o usuário final.

### 2.9 RPCs essenciais

**`get_tickets_paginated`** — filtros + busca + contagem total numa query só (padrão do Guia).

```sql
create or replace function public.get_tickets_paginated(
  p_limit    int default 50,
  p_offset   int default 0,
  p_status   text default null,
  p_category text default null,
  p_search   text default null
) returns table (
  id bigint, title text, status text, category text, priority text,
  created_by uuid, assigned_to uuid, created_at timestamptz, updated_at timestamptz,
  total_count bigint
) language sql stable security definer as $$
  with filtered as (
    select * from public.tickets t
    where (p_status   is null or t.status = p_status)
      and (p_category is null or t.category = p_category)
      and (p_search   is null or
           t.title ilike '%'||p_search||'%' or
           t.description ilike '%'||p_search||'%' or
           t.id::text = p_search)
  )
  select f.id, f.title, f.status, f.category, f.priority,
         f.created_by, f.assigned_to, f.created_at, f.updated_at,
         (select count(*) from filtered)::bigint as total_count
  from filtered f
  order by
    case when f.status in (select slug from public.ticket_statuses where is_terminal) then 1 else 0 end,
    f.created_at desc
  limit p_limit offset p_offset;
$$;
```

**Outras RPCs:**
- `get_ticket_by_id(p_id bigint)` — ticket + mensagens + audit log numa resposta.
- `update_ticket_status(p_id bigint, p_status text, p_note text)` — muda status, registra audit, retorna novo ticket.
- `ticket_add_message(p_ticket_id, p_content, p_attachments)` — apenas se Q3 = chat. Insere mensagem e registra audit.

### 2.10 Realtime

Objetivo: dashboard tech recebe notificações de `INSERT`/`UPDATE` em `tickets` e `ticket_messages` sem polling.

Tradução por stack:
- **Supabase:** habilitar Realtime nas tabelas (`alter publication supabase_realtime add table tickets;`) + `replica identity full`; cliente usa `.channel().on('postgres_changes', ...)`.
- **Firebase/Firestore:** `onSnapshot()` nas coleções.
- **API própria:** WebSocket (ex.: `socket.io`), Server-Sent Events, ou serviço externo (Pusher/Ably). Publicar evento no handler que faz INSERT/UPDATE.
- **Sem realtime:** polling no cliente a cada 15–30s do RPC de listagem. Aceitável para volume baixo.

### 2.11 Tradução rápida do SQL por stack (referência)

| Conceito Postgres/Supabase | Prisma | Firestore | MongoDB | Rails/ActiveRecord |
|---|---|---|---|---|
| `bigserial primary key` | `Int @id @default(autoincrement())` | doc ID auto | `_id` ObjectId | `primary_key: :bigint` |
| `uuid references auth.users(id)` | `String` + relation | campo `uid: string` | `userId: ObjectId` | `belongs_to :user` |
| `jsonb` | `Json` | Map nativo | Document nativo | `jsonb` (Postgres) / `json` (MySQL) |
| `timestamptz default now()` | `DateTime @default(now())` | `Timestamp` | `Date` | `timestamps` |
| CHECK constraint | `enum` no schema | validação no client/rules | validação no client | validação no model |
| GIN index em jsonb | `@@index([field])` quando suportado | índice composto Firestore | índice no campo | `add_index ... using: :gin` |
| RLS policy | middleware + `where` injetado | Security Rules | middleware no endpoint | Pundit/CanCan |
| RPC (`create function`) | método no service layer | Cloud Function callable | rota Express/Fastify | controller action |
| Trigger | hook do ORM (`@BeforeUpdate`) | Firestore trigger (Cloud Fn) | change stream | `after_update` callback |

---

## 3. Backend / Funções de servidor

> Os exemplos abaixo mencionam "Edge Function" (Supabase/Deno) por vir da stack de origem. **Traduza para a unidade de computação da sua stack:** Cloud Functions (Firebase/GCP), AWS Lambda, rota Express/Fastify/NestJS, controller Rails, endpoint Django, serviço Go, etc. A **lógica** e os **contratos de entrada/saída** são o que importa.

### 3.1 Caminho simples (Q3 = one-way ou notificação)

**Sem função de servidor custom.** O cliente cria ticket direto via SDK/HTTP do backend, a trigger/hook cuida do audit log, a autorização (RLS/middleware) cuida da segurança. Fim.

### 3.2 Caminho notificação (Q3 = recebimento + notificação)

Criar handler `notify-status-change`:
- **Trigger:** database webhook quando `tickets.status` muda (Supabase) / trigger Firestore / `after_update` do ORM / evento emitido no service layer.
- **Lógica:**
  1. Lê `created_by` e `status` do ticket atualizado.
  2. Busca tokens de push do usuário (tabela `user_notification_tokens` ou equivalente).
  3. Dispara push via provider adotado pelo projeto-alvo (FCM, APNs, OneSignal, Expo Push, etc.).
  4. (Opcional) Envia email via Resend/SendGrid/SES/Postmark.

### 3.3 Caminho completo (Q3 = chat + IA)

Replicar a estrutura modular da edge function `chatbot-process` do GuiaFlix, **enxuta**, como função serverless ou microserviço na stack-alvo:

| Módulo | Responsabilidade | Tecnologia-alvo |
|---|---|---|
| `index` (entrypoint) | Recebe `ticket_id` ou `message_id`, orquestra resposta | Cloud Function / Lambda / rota HTTP |
| `ai-client` | Wrapper do LLM (recomendo **Claude Haiku 4.5** por custo/latência, ou Gemini Flash) | SDK Anthropic / Google AI |
| `context-builder` | Monta histórico + RAG de FAQ (se houver base de conhecimento) | Lib de embeddings (Voyage/OpenAI) + vector store |
| `escalation-engine` | Heurísticas keyword + score de frustração → escalar para tech | Lógica pura, sem dependências |
| `prompts` | Template do system prompt | Arquivo de constantes |

Gatilho assíncrono: trigger de DB agenda job numa fila (tabela `pending_responses` + cron; ou fila dedicada: Cloud Tasks, SQS, BullMQ, Sidekiq).

**Importante:** só implemente §3.3 se o projeto realmente tiver base de conhecimento e volume que justifique. Para app pequeno, Q3 = chat bidirecional simples é melhor ROI.

---

## 4. Frontend — App do usuário final

> Os trechos em Dart abaixo são **ilustrativos** do padrão conceitual. Traduza para o framework cliente do projeto-alvo (React/Vue/Svelte/SwiftUI/Compose/RN/etc.) usando o SDK correspondente.

### 4.1 Criação de ticket

Formulário simples (ou dinâmico conforme Q4). Submete via SDK/HTTP do backend. **Exemplo de referência (Dart + Supabase):**

```dart
await supabase.from('tickets').insert({
  'created_by': currentUserId,          // id do usuário autenticado
  'title': title,
  'description': description,
  'category': category,                 // slug de Q1
  'status': initialStatus,              // slug de Q2 (ex.: 'aberto')
  'metadata': {
    'app_version': appVersion,
    'platform': platformName,
    'user_agent': userAgent,
    // + campos de form dinâmico se Q4 pedir
  },
  'attachments': uploadedFiles,         // array após upload ao storage
});
```

Equivalências conceituais:
- **TypeScript/JS (Supabase):** `await supabase.from('tickets').insert({...})`
- **Prisma:** `await prisma.ticket.create({ data: {...} })`
- **Firestore:** `await addDoc(collection(db, 'tickets'), {...})`
- **REST próprio:** `POST /api/tickets` com body JSON
- **GraphQL:** `mutation { createTicket(input: {...}) { id } }`

### 4.2 Upload de anexos (se Q4 permitir)

Padrão a replicar em qualquer storage:
- **Bucket/pasta:** `ticket-attachments` (ou nome equivalente).
- **Path:** `{user_id}/{ticket_id}/{hash}.{ext}` — mantém separação por usuário e previne colisão.
- **Política:** leitura/escrita **apenas do próprio owner**; tech consegue ler via role elevada.
- **Payload armazenado:** `{url, name, mime, size}` em cada item do array `attachments`.

Equivalências: Supabase Storage, S3 (+ CloudFront), Firebase Storage, Cloudinary, Azure Blob. Todas suportam o padrão acima.

### 4.3 Listagem dos próprios tickets (se houver tela para o usuário)

Query filtrada por `created_by = currentUserId`, ordenada por `created_at DESC`. A autorização deve garantir que o usuário **não veja tickets de outros** — seja via RLS (Supabase), Security Rules (Firestore), middleware (API própria), ou `WHERE` injetado no service layer.

### 4.4 Chat (se Q3 = chat)

Padrão:
- Subscribe em `ticket_messages` filtrado por `ticket_id` (via realtime da stack).
- UI de chat bubble: avatar, nome, timestamp, conteúdo renderizado (texto puro ou Markdown/HTML conforme necessidade).
- Envio: insert em `ticket_messages` via SDK/HTTP; realtime entrega ao outro lado.
- Referência visual (opcional): `lib/features/tickets/presentation/widgets/chatbox.dart` no repositório-fonte — copiar estrutura, não código.

---

## 5. Frontend — Dashboard tech (admin-only)

> Esta é a única UI administrativa. **Só o time tech acessa.** Sem formulário de triagem, sem devolução ao usuário.

### 5.1 Padrão de camadas (estrutura conceitual)

A topologia abaixo vem do Flutter + GetX no Guia. **Traduza para a stack do projeto-alvo** preservando a separação de responsabilidades (UI, estado/controller, domínio/service, data/models):

```
presentation / ui /
  pages/tickets_page                    → layout split-pane
  controllers ou hooks ou viewmodels    → estado observável (GetX / Riverpod /
    /tickets_controller                   Zustand / Redux / MobX / ViewModel)
  widgets / components /
    ticket_list_item                    → linha da tabela
    ticket_detail_pane                  → painel direito
    ticket_filters_bar                  → chips de status/categoria + busca
    ticket_audit_timeline               → timeline de eventos (diferencial!)
    ticket_chat_view                    → SOMENTE se Q3 = chat
domain / services / api /
  ticket_service                        → métodos que chamam endpoints/RPCs
data / models / types / dto /
  ticket                                → modelo do ticket
  ticket_message                        → SOMENTE se Q3 = chat
  ticket_audit_entry                    → evento do audit log
```

Mapeamento por framework (exemplos):
- **Flutter:** `presentation/pages`, `GetX`/`Riverpod`/`Bloc`, widgets em `presentation/widgets`, `domain/services`.
- **React/Next.js:** `src/pages` ou `app/`, hooks + Zustand/Redux/TanStack Query, componentes em `src/components`, `src/services`.
- **Vue/Nuxt:** `pages/`, Pinia store, componentes em `components/`, composables em `composables/`.
- **Swift/SwiftUI:** `Views/`, `ViewModels/` (MVVM), `Services/`, `Models/`.
- **Kotlin/Compose:** `ui/screens`, `ui/viewmodels`, `domain/repository`, `data/model`.

### 5.2 Layout da página principal (split-pane)

Padrão de UI a replicar (referência: `lib/features/tickets/presentation/pages/ticket_page_getx.dart`):

- **Esquerda (flex 2):** barra de filtros no topo + lista paginada **virtualizada** (~72px por linha). Colunas: título, autor, criado em, status (badge colorido), categoria (chip).
- **Direita (flex 3):** header do ticket (título, autor, datas, status atual) + **timeline de audit log** (diferencial desta versão — mostra toda mudança) + conteúdo principal (descrição + metadata expandível + anexos) + [se Q3=chat] conversa + footer de ações (trocar status, atribuir, fechar).

Virtualização: `ListView.builder` (Flutter), `react-window`/`@tanstack/virtual` (React), `RecyclerView`/`LazyColumn` (Android), `UITableView`/`LazyVStack` (iOS).

### 5.3 Estado do controller (observável)

Fields mínimos (nomes-alvo: adapte ao idioma idiomático da stack — `camelCase`, `snake_case`, etc.):
- `paginatedTickets`, `selectedTicket`, `auditLog`, `messages` (se aplicável).
- Filtros: `selectedStatus`, `selectedCategory`, `searchQuery`.
- Paginação: `currentPage`, `totalPages`, `totalItems`, `itemsPerPage` (50 é bom default).
- Loading states granulares: `isLoadingList`, `isLoadingDetail`, `isSendingAction`.

Métodos-core:
- `loadPage(page)` — chama o endpoint de listagem paginada.
- `selectTicket(id)` — chama endpoint de detalhe + carrega audit log.
- `changeStatus(newStatus, {note})` — chama endpoint de atualização de status.
- `sendMessage(content, {attachments})` — SOMENTE se Q3 = chat.
- `subscribeToRealtime()` — revalida página ao receber evento (ou polling se não houver realtime).

### 5.4 Permissão de acesso ao dashboard

- Guard de rota checa **role do usuário autenticado**. Leituras típicas:
  - **Supabase:** `auth.jwt() ->> 'role' == 'tech'` ou tabela `tech_users`.
  - **Firebase:** custom claim `role: 'tech'` no ID token.
  - **API própria:** campo `role` no JWT ou consulta a `users.role`.
  - **Next.js middleware/Remix loader/Laravel middleware:** verificar claim e redirecionar se não for tech.
- Usuário comum tentando acessar → 403 / redirect.
- **Não reimplementar os 19 níveis de `AdminPriviledge` do Guia.** Aqui são dois papéis: `user` e `tech`.

### 5.5 Design system

- Usar o design system **existente no app-alvo** (se houver). Não portar `app_colors.dart` / `app_typography.dart` do Guia.
- Copiar os *padrões* visuais: badges de status coloridos, chips de categoria, split-pane, virtualização de lista, timeline vertical de audit.
- Se o app-alvo não tiver design system, criar tokens mínimos: 1 paleta (primária + neutra + semânticas para status), 1 tipografia (Inter é uma ótima default), escala de espaçamento, componentes base (badge, chip, card, button).

---

## 6. Arquivos a criar (checklist — adaptar caminhos à stack)

> Os caminhos abaixo usam as convenções do repositório-fonte (Supabase + Flutter). **Mapeie para as convenções do projeto-alvo** — mantendo a mesma decomposição lógica.

**Banco / migrations:**
- [ ] Migration de schema base — §2.1 + 2.6 + 2.7 + 2.8
- [ ] Migration de categorias/statuses configuráveis — §2.2 + 2.3 (se Q1/Q2 exigirem)
- [ ] Migration de mensagens — §2.4 (se Q3 = chat)
- [ ] Migration de endpoints/RPCs — §2.9
- [ ] Habilitação de realtime — §2.10 (se aplicável à stack)

Exemplos de localização:
- Supabase: `supabase/migrations/NNNNNN_*.sql`
- Prisma: `prisma/schema.prisma` + `prisma/migrations/`
- Rails: `db/migrate/*.rb`
- Django: `apps/tickets/migrations/*.py`
- Flyway/Liquibase: `db/migration/V{N}__*.sql`
- Firestore: `firestore.rules` + `firestore.indexes.json`

**Backend / funções:**
- [ ] Handler `notify-status-change` — §3.2 (se Q3 = notificação)
- [ ] Serviço/função `triage-bot` — §3.3 (se Q3 = chat+IA)

Exemplos de localização:
- Supabase: `supabase/functions/{name}/index.ts`
- Firebase: `functions/src/{name}.ts`
- AWS SAM: `functions/{name}/handler.ts`
- Express/NestJS: `src/modules/tickets/*.controller.ts`
- Rails: `app/controllers/api/tickets_controller.rb`

**Frontend — app do usuário:**
- [ ] Tela de criação do ticket (payload conforme Q4).
- [ ] Tela "meus tickets" (listagem simples).
- [ ] Componente de chat (se Q3 = chat).
- [ ] Handler de push notification (se Q3 = notificação).

**Frontend — dashboard tech:**
- [ ] Página `tickets` (split-pane).
- [ ] Controller/ViewModel/Store de tickets (estado + paginação + filtros + realtime).
- [ ] Service/API layer para endpoints de tickets.
- [ ] Models/Types: `Ticket`, `TicketAuditEntry`, `TicketMessage` (se aplicável).
- [ ] Componentes: filtros, lista virtualizada, detalhe, timeline de audit.
- [ ] Guard de rota para `role=tech`.

---

## 7. Verificação (como testar ponta a ponta)

> Comandos abaixo usam SQL (stack de origem). Em outras stacks, use o equivalente: console do ORM, CLI do BaaS, client HTTP (`curl`/Postman/Insomnia), testes de integração.

1. **Smoke do banco**
   - Criar um usuário teste e inserir um ticket. Verificar que o audit log recebeu a entrada `created`.
   - Atualizar status e verificar nova entrada de `status_changed`.
   - Tentar listar tickets como outro usuário → deve retornar 0 linhas (autorização ok).

2. **Endpoints / RPCs**
   - Listagem paginada com filtro — retorna até N tickets + `total_count` correto.
   - Detalhe por id — retorna ticket + mensagens (se aplicável) + audit.
   - Atualização de status — carimba `resolved_at`/`closed_at` quando terminal e cria entrada no audit.

3. **Frontend do usuário**
   - Criar ticket via UI → aparece em "meus tickets".
   - Se Q4 permitir anexos: upload de imagem funciona, URL gravada em `attachments`.
   - Se Q3 = notificação: mudar status no dashboard → push chega no dispositivo.
   - Se Q3 = chat: enviar mensagem, tech recebe via realtime, responde, usuário vê resposta.

4. **Dashboard tech**
   - Login como tech → lista carrega com paginação.
   - Filtro por status/categoria funciona e não reseta página indevidamente.
   - Busca por ID exato e por texto funcionam.
   - Selecionar ticket → timeline de audit log renderiza todos os eventos na ordem correta.
   - Trocar status via UI → audit log ganha linha, `resolved_at` carimba quando vai pra terminal.
   - Logout como tech + login como usuário comum → rota do dashboard dá 403.

5. **Rastreabilidade**
   - Para qualquer ticket, abrir `ticket_audit_log` e reconstruir toda a vida do ticket: criação, mudanças de status, atribuições, mensagens. Nenhuma mudança de estado pode acontecer sem entrada no audit.

---

## 8. Anti-patterns a NÃO replicar do GuiaFlix

- ❌ Coluna `ticket_json` em TEXT guardando mensagens serializadas. **Usar tabela normalizada `ticket_messages`.**
- ❌ `id_aluno` / `id_admin` custom (BIGINT). **Usar `auth.users.id` (uuid) como padrão Supabase.**
- ❌ Formulário de tech handoff multi-step de 6 páginas. **Fora de escopo neste plano.**
- ❌ Sistema de "flags preciso voltar" (bookmarks por admin). Se quiser lembrete, usar `assigned_to` + `priority='high'`.
- ❌ Hardcode de strings pt-BR em migrations (`'Aberto'`, `'Resolvido'`). **Usar slugs em `snake_case` e labels num dicionário de i18n no front.**
- ❌ Status terminal mágico espalhado em triggers. **Centralizar em `ticket_statuses.is_terminal` ou função `is_terminal_status(text)`.**
- ❌ `ticket_json` do GuiaFlix permite auto-close por inatividade injetando uma mensagem sintética. **Se quiser auto-close, usar pg_cron + status change via RPC, sem mensagem fake.**

---

## 9. Resumo executável

1. **§0.1** — Detectar a stack do projeto-alvo (frontend, backend, banco, realtime, storage) e registrar no topo.
2. **Fase 0** — Fazer as 4 perguntas de negócio (categorias, status, comunicação, abertura) e registrar respostas.
3. **§2** — Criar schema do banco (§2.1, §2.6, §2.7, §2.8 sempre; §2.2/§2.3/§2.4 condicionais). Traduzir o SQL de referência para a ferramenta de migration da stack-alvo.
4. **§2.9** — Implementar endpoints/RPCs de listagem, detalhe e mudança de status.
5. **§2.10** — Habilitar realtime ou fallback de polling.
6. **§3** — Criar função(ões) serverless conforme Q3 (notificação ou IA), se aplicável.
7. **§4** — UI do app do usuário conforme Q3/Q4.
8. **§5** — Dashboard tech (split-pane + audit timeline + guard de role).
9. **§7** — Rodar verificação completa ponta a ponta.
10. Commit granular por etapa. **Sem push** até validação do usuário.

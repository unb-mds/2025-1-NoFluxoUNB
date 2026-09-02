# Análise e plano de arquitetura — App Mobile NoFluxoUNB

> Gerado em 2026-08-31, a partir do mapeamento completo do backend, do banco (Supabase),
> do frontend Svelte e do app Flutter legado (recuperado do histórico do git, commit `3dba955a^`).

## 1. Sumário executivo

**Vale a pena fazer o app? Sim — e o custo é menor do que parece.** O motivo central do app
(notificações push de vaga, aula e matrícula) é exatamente a única coisa que a web não entrega
bem, e **~80% do backend necessário já existe**:

- As tabelas `vaga_assinaturas` e `notificacoes` já existem, com o trigger
  `trg_turmas_notificar_vaga` que detecta a transição "sem vaga → com vaga" e insere a
  notificação com payload pronto para deep link (`metadata` com código da matéria, turma, período).
- As RPCs de consumo já existem e estão em produção no site: `seguir_materia`,
  `deixar_de_seguir_materia`, `listar_minhas_assinaturas`, `listar_notificacoes`,
  `marcar_notificacao_lida`.
- Os dados de turmas (docente, horário, local, vagas ofertadas/ocupadas/sobrando) são
  scrapeados do SIGAA a cada 15 min em época de matrícula (flag `scraping_turmas_rapido`;
  fora dela, a cadeia mensal é ementa → equivalências → turmas, e o disparo manual via
  `workflow_dispatch` ignora o flag).
- O RLS já está configurado — o app fala **direto com o Supabase** (anon key + JWT do usuário)
  para quase tudo, igual ao site. O Express só é necessário para IA e plano de formatura.
  **Ressalva verificada no SQL real**: as policies `*_select_public` são `TO authenticated` —
  apesar do nome, **sem sessão nada é lido** (retorno vazio). O modo visitante do app precisa
  ou de novas policies `TO anon` nas 7 tabelas públicas (draft incluído em
  `no_fluxo_app/supabase/`), ou de cair para os endpoints não autenticados do Express
  (`/fluxograma/fluxograma`, `/cursos/all-cursos`, `/assistente/turmas-by-codigo`).

**O que NÃO existe e precisa ser construído** (é o trabalho real do projeto):

| Gap | O que é | Esforço |
| --- | --- | --- |
| Entrega push (FCM) | Zero infra de push existia no repo antes deste trabalho (a web faz polling de 60s). Precisa: tabela `device_tokens`, Edge Function que dispara FCM quando `notificacoes` recebe insert, setup do Firebase no app. | Médio |
| Calendário acadêmico | Não existe tabela nem scraper de datas de matrícula. `periodo_letivo_atual()` é heurística por mês. Notificação de "matrícula abre amanhã" exige tabela `calendario_academico` (entrada manual via admin já resolve o MVP). | Baixo–médio |
| "Minhas aulas" | Notificação de horário de aula precisa da grade confirmada do aluno. O Montador de Grade já salva cenários (hoje em localStorage no site) — no app, a grade escolhida vira fonte de notificações **locais** (agendadas no aparelho, sem servidor). | Baixo |
| O app em si | Reescrita mobile-first. O Flutter legado rende ~20–25% (models de domínio, contratos de API, paleta) — as telas eram web-first e não valem migrar. | Alto (é o projeto) |

## 2. Por que Flutter (de novo)

1. **Histórico do time**: o NoFluxo nasceu em Flutter; há familiaridade com Dart e o código
   legado serve de especificação de comportamento (models com as regras de menção/status do
   SIGAA já codificadas — `APR/CUMP/DISP/MATR/REP/TRC`, `SS/MS/MM/MI/II/SR`).
2. **`supabase_flutter` é maduro** (auth com PKCE, OAuth Google nativo, Realtime, RPC) — o
   padrão de acesso a dados do site Svelte se traduz 1:1.
3. **Push é cidadão de primeira classe**: `firebase_messaging` + `flutter_local_notifications`
   cobrem os três casos (push remoto para vagas/matrícula, notificação local agendada para aulas).
4. Uma codebase para Android + iOS; e se um dia quiserem, o mesmo app roda como web/desktop.

Alternativas descartadas: React Native/Expo (nenhuma familiaridade no time, sem legado);
PWA com web push (iOS suporta mal — exige app instalado na home screen, entrega não confiável;
justamente o caso de uso crítico ficaria capenga).

### O que reaproveitar do Flutter legado (recuperado em `git show 3dba955a^:no_fluxo_frontend/...`)

| Vale copiar | Por quê |
| --- | --- |
| `lib/models/user_model.dart` | `UserModel`/`DadosFluxogramaUser`/`DadosMateria` — regra de negócio do SIGAA codificada |
| `lib/screens/fluxogramas/data/*` | `curso_model`, `materia_model`, `equivalencia_model`, árvore de pré-requisitos |
| Services (`meu_fluxograma_service`, `upload_historico_service`) | Como **contrato de API** (shapes de request/response, protocolo `SELECAO_CURSO:`) |
| `lib/config/app_colors.dart` | Paleta e gradientes por status de matéria |
| Matemática do `prerequisite_connections_widget` | Roteamento das linhas entre cards (CustomPainter) |

Jogar fora: telas (web-first, hover em 16 arquivos, arquivos de 1.000–1.800 linhas), navbar de
site, `auth_service` duplicado, roteador sem guard real, ausência total de state management.

## 3. Monorepo vs multirepo — **recomendação: monorepo**

**Colocar o app em `no_fluxo_app/` dentro do repo atual.** Razões:

1. **O contrato vive no banco.** O app depende das mesmas RPCs, tabelas e policies que o site.
   Uma mudança de schema (ex.: renomear campo de `listar_notificacoes`) quebra app e site
   juntos — no monorepo, o mesmo PR atualiza os três; em multirepo, vira drift silencioso
   descoberto em produção.
2. **Time pequeno de estudantes.** Multirepo multiplica: secrets do GitHub Actions, config de
   CI, issues/boards, permissões, releases. O custo de coordenação não se paga nesse tamanho.
3. **A infra de push atravessa as fronteiras.** A migration `device_tokens`, a Edge Function de
   FCM e o app precisam evoluir juntos (mesma razão do item 1).
4. **Open source não é argumento contra**: o app não tem segredo nenhum que o site já não
   tenha — anon key do Supabase é pública por design (RLS protege), e as chaves do Firebase
   (`google-services.json`) também são públicas por design. Service keys continuam em GitHub
   Secrets, como hoje.
5. **Porta de saída barata**: se um dia o app precisar de cadência própria de release ou de um
   repositório privado (ex.: chaves de assinatura da Play Store em repo restrito), um
   `git subtree split -P no_fluxo_app` extrai a pasta **com todo o histórico preservado**.
   A decisão de hoje não tranca nada.

O único cenário em que multirepo ganharia: se o app fosse ter mantenedores distintos do site
com ciclos de release independentes e CI pesado próprio (builds iOS são lentos). Não é o caso
agora; e a porta de saída existe.

**Cuidado prático no monorepo**: filtrar CI por path (`paths: [no_fluxo_app/**]`) para o build
Flutter não rodar em todo PR do site, e vice-versa.

## 4. Arquitetura do app

```text
no_fluxo_app/
├── lib/
│   ├── main.dart                  # bootstrap: Supabase.initialize, Firebase, ProviderScope
│   ├── app/                       # MaterialApp.router, tema, go_router
│   ├── core/
│   │   ├── config/                # env via --dart-define (SUPABASE_URL, ANON_KEY, API_URL)
│   │   ├── theme/                 # dark premium: fundo #060608, roxo #8B44F5, lilás IA #C39DFA
│   │   ├── models/                # UserModel, DadosMateria, CursoModel, MateriaModel, TurmaModel…
│   │   ├── services/              # supabase_service, api_client (Express), auth_service
│   │   └── utils/                 # horario_slots.dart (porte do bitmask de 96 bits), formatters
│   └── features/                  # feature-first, cada uma com data/ + providers/ + ui/
│       ├── auth/                  # login e-mail/senha, Google OAuth, modo visitante
│       ├── fluxograma/            # viewer do fluxograma (colunas por semestre, status colorido)
│       ├── turmas/                # busca de turmas, vagas ao vivo, "seguir matéria"
│       ├── notificacoes/          # inbox (RPCs) + badge via Supabase Realtime
│       ├── grade/                 # minha grade horária + agendamento de notificações locais
│       └── perfil/                # dados do aluno, progresso, configurações de notificação
├── supabase/                      # drafts de migration + edge function (revisar antes de aplicar)
└── docs/
```

**Decisões:**

- **State management: Riverpod** (o legado não tinha nenhum — era `setState` + estático global).
- **Navegação: go_router** com guard de rota real (o legado tinha guard fake) + deep links
  `nofluxo://` para abrir a notificação direto na turma.
- **Acesso a dados: replica o padrão do site** — `supabase_flutter` (anon key + RLS) para
  ~80% (cursos, matérias, fluxograma, turmas, notificações, assinaturas, dados do usuário);
  HTTP contra o Express só para IA/plano (`/chat/send`, `/assistente/*`, `/planejamento/*`).
  Atenção aos dois headers das rotas autenticadas do Express: `Authorization` **e** `User-ID`.
- **Upload de histórico PDF fica fora do MVP mobile.** O parser é PDF.js posicional no site —
  portar para Dart é o maior risco de paridade e não é necessário: o aluno importa o histórico
  pelo site (fluxo já maduro) e o app lê o resultado de `dados_users`. Fase 2: mover o parser
  para Edge Function e servir os dois clientes.

## 5. Arquitetura de push (o coração do projeto)

Três tipos de notificação, três mecanismos:

### 5.1 Vaga abriu → push remoto (FCM), infra nova sobre trigger existente

```text
SIGAA ──scraper 15min──▶ turmas ──trigger existente──▶ notificacoes (INSERT)
                                                            │
                                              Database Webhook (novo)
                                                            ▼
                                          Edge Function push-dispatch (nova)
                                          lê device_tokens do id_user
                                                            ▼
                                                    FCM v1 API ──▶ celular
                                                    (deep link p/ turma)
```

- **Nova tabela `device_tokens`**: `id_user`, `token`, `platform`, `last_seen_at`, UNIQUE(token),
  RLS own-only. App registra/renova o token no login e no refresh do FCM.
- **Edge Function `push-dispatch`**: acionada por Database Webhook no INSERT de `notificacoes`;
  busca os tokens do usuário, monta a mensagem a partir de `titulo`/`mensagem`/`metadata` e
  chama o FCM HTTP v1 (service account do Firebase em secret da função). Remove tokens
  inválidos (`UNREGISTERED`).
- Vantagem: **zero mudança no pipeline existente** — o trigger que já funciona continua sendo
  a única fonte de verdade; o push é um efeito colateral do INSERT.

### 5.2 Aula começando → notificação local (sem servidor)

A grade confirmada do aluno (feature `grade`) vira agendamentos no próprio aparelho via
`flutter_local_notifications` (`zonedSchedule`, recorrência semanal): "CIC0004 em 30 min,
PJC BT 077". Funciona offline, custo zero de backend. O parser `horario_slots` portado para
Dart converte o código SIGAA (`"246M12"`) em dias/horários reais.

### 5.3 Matrícula abrindo → push por tópico FCM (broadcast)

- **Nova tabela `calendario_academico`**: `evento`, `tipo` (matricula, matricula_extraordinaria,
  inicio_semestre…), `data_inicio`, `data_fim`, `ano_periodo`. MVP: entrada manual pela tela de
  admin do site (mesmo padrão do flag de scraping). Fase 2: scraper do calendário do DEG.
- App inscreve todo mundo no tópico FCM `matricula`; um job agendado (Edge Function com
  `pg_cron` ou GitHub Action diário) publica no tópico quando um evento está a N dias.
- **Bônus**: essa tabela substitui a heurística frágil de `periodo_letivo_atual()` e permite
  **automatizar o flag `scraping_turmas_rapido`** — hoje um admin liga na mão; com calendário,
  liga sozinho no período de matrícula. Isso remove o risco operacional nº 1 do produto
  ("prometemos avisar vaga mas o scraping estava no regime mensal").

## 6. Riscos e pendências que dependem do Vitor

1. **Firebase**: criar o projeto no console, baixar `google-services.json` (Android) e
   `GoogleService-Info.plist` (iOS), gerar a service account para a Edge Function. Sem isso o
   push não liga (o código fica pronto com TODOs marcados).
2. **iOS custa dinheiro**: Apple Developer Program US$ 99/ano para push em iOS (APNs). Android
   sai de graça. Sugestão: lançar Android primeiro.
3. **Latência honesta**: mesmo no regime rápido o scraping é de 15 em 15 min — comunicar
   "avisamos em até 15 minutos", nunca "em tempo real". E vagas de matérias concorridas fecham
   em minutos; o histórico `turmas_historico` permite mostrar "velocidade de enchimento" para
   calibrar expectativa.
4. **Aplicar as migrations**: os drafts de `device_tokens` e `calendario_academico` ficam em
   `no_fluxo_app/supabase/` para revisão — **nada foi aplicado no banco**.
5. **`users.auth_id` no registro**: as rotas de registro do Express não gravam `auth_id`, mas as
   RPCs de notificação dependem de `users.auth_id = auth.uid()`. O site grava via insert
   direto; conferir se todo usuário tem `auth_id` preenchido antes do launch (um `UPDATE`
   corretivo pode ser necessário para contas antigas).

## 7. Fases

| Fase | Escopo | Status |
| --- | --- | --- |
| **0 — Esta noite** | Scaffold + core + tema, auth, fluxograma viewer, turmas/vagas/seguir, inbox de notificações com Realtime, grade com notificações locais, drafts SQL/Edge Function, setup FCM com TODOs | Construído (ver relatório da noite) |
| 1 — Push ligado | Criar projeto Firebase, aplicar migrations, deploy da Edge Function, testar ponta a ponta no Android | Depende das credenciais |
| 2 — Matrícula | Tabela calendário + admin UI + broadcast por tópico + automação do flag de scraping | — |
| 3 — Paridade | Assistente IA no app (SSE), plano de formatura, upload de PDF via Edge Function | — |
| 4 — iOS | Conta Apple, APNs, TestFlight | Depende dos US$ 99 |

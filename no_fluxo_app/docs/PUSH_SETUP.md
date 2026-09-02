# Push Notifications — guia de setup (NoFluxoUNB)

Passo a passo para ativar o push de "vaga aberta" no app. **Nada disso foi
aplicado ainda** — as migrations e a Edge Function são DRAFTS para revisão.

## Como funciona (visão geral)

```
turmas (UPDATE abre vaga)
  └─ trigger notificar_vaga_disponivel  → INSERT em notificacoes
       └─ Database Webhook (INSERT)     → Edge Function push-dispatch
            ├─ lê device_tokens do id_user (service role)
            └─ envia FCM HTTP v1 → aparelho (canal Android "vagas")
                 └─ toque na notificação → deep link /turmas?codigo=XXX
```

Arquivos desta infra:

| Arquivo | O que é |
|---|---|
| `supabase/migrations/DRAFT_001_device_tokens.sql` | tabela `device_tokens` + RPCs `registrar_device_token` / `remover_device_token` |
| `supabase/migrations/DRAFT_002_calendario_academico.sql` | tabela `calendario_academico` (leitura autenticada, escrita admin) |
| `supabase/functions/push-dispatch/index.ts` | Edge Function que envia o push via FCM |
| `lib/core/services/push_service.dart` | serviço Flutter (token, foreground, deep link) |
| `test/core/push_service_test.dart` | testes da conversão data FCM → rota |

## 1. Criar o projeto Firebase

1. Acesse <https://console.firebase.google.com> e crie um projeto
   (ex.: `nofluxo-unb`). Google Analytics é opcional (pode desligar).
2. Não precisa adicionar o app Android manualmente — o `flutterfire
   configure` do passo 2 faz isso.

## 2. `flutterfire configure` + google-services.json

```bash
dart pub global activate flutterfire_cli
cd no_fluxo_app
flutterfire configure --project=<id-do-projeto-firebase> --platforms=android
```

Isso gera:
- `lib/firebase_options.dart`
- `android/app/google-services.json`

Depois disso, **descomente os TODOs de gradle**:
- `android/settings.gradle.kts` → linha `id("com.google.gms.google-services") version "4.4.3" apply false`
- `android/app/build.gradle.kts` → linha `id("com.google.gms.google-services")`

E no `lib/main.dart`, antes do `runApp` (e antes do `pushService.init`):

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

Aí inicialize o push (ex.: depois do login resolver), injetando a navegação:

```dart
final push = ref.read(pushServiceProvider);
final router = ref.read(routerProvider);
await push.init(onNavigate: (rota) => router.go(rota));
// no logout, ANTES do signOut:
await push.unregister();
```

> O `PushService` é no-op seguro: enquanto o Firebase não estiver
> inicializado, `init()`/`unregister()` só logam e não quebram nada.

## 3. Aplicar as migrations (REVISAR ANTES)

Revise os dois arquivos em `supabase/migrations/` e rode o conteúdo no SQL
Editor do dashboard (ou renomeie para o padrão `YYYYMMDDHHMMSS_nome.sql` e use
`supabase db push`). Ordem: DRAFT_001 e depois DRAFT_002 (são independentes,
mas a Edge Function depende da 001).

Checagem rápida pós-migration, logado no app como usuário de teste:

```sql
select registrar_device_token('token-de-teste', 'android'); -- via app/RPC
select * from device_tokens; -- (como service role no SQL Editor)
```

## 4. Secrets e deploy da Edge Function

```bash
cd no_fluxo_app
# JSON da service account: Firebase Console → Configurações do projeto →
# Contas de serviço → Gerar nova chave privada
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)" --project-ref lijmhbstgdinsukovyfl
supabase secrets set PUSH_WEBHOOK_SECRET="<segredo-forte-aleatorio>" --project-ref lijmhbstgdinsukovyfl

supabase functions deploy push-dispatch --project-ref lijmhbstgdinsukovyfl --no-verify-jwt
```

`--no-verify-jwt` porque quem chama é o webhook do banco (sem JWT de
usuário); a autenticação fica por conta do header `x-webhook-secret`.
**O `PUSH_WEBHOOK_SECRET` é obrigatório**: a função recusa TODAS as chamadas
(401) enquanto ele não estiver configurado — não é opcional.

## 5. Criar o Database Webhook

No dashboard do Supabase: **Database → Webhooks → Create a new hook**

- Name: `push_notificacoes`
- Table: `public.notificacoes`
- Events: só **INSERT**
- Type: **Supabase Edge Functions** → `push-dispatch`
- HTTP Headers: adicionar `x-webhook-secret` = mesmo valor de
  `PUSH_WEBHOOK_SECRET`
- Timeout: padrão (5s) está ok

## 6. Teste ponta a ponta

1. Rode o app num aparelho/emulador Android **com Google Play services**,
   faça login e aceite a permissão de notificação.
2. Confirme o registro do token (SQL Editor, service role):
   ```sql
   select id_user, platform, last_seen_at from device_tokens order by last_seen_at desc;
   ```
3. Coloque o app em background e insira uma notificação na mão
   (substitua o `id_user` pelo seu):
   ```sql
   insert into notificacoes (id_user, tipo, titulo, mensagem, metadata)
   values (
     1,
     'vaga_disponivel',
     'Vaga aberta em FGA0158 (teste)',
     'A turma 01 de Teste (2026.1) tem 3 vaga(s) disponível(is).',
     jsonb_build_object(
       'codigo_materia', 'FGA0158',
       'turma', '01',
       'ano_periodo', '2026.1',
       'vagas_sobrando', 3
     )
   );
   ```
4. O push deve chegar no aparelho em poucos segundos, no canal "vagas".
   Tocar nele deve abrir o app em `/turmas?codigo=FGA0158`.
5. Com o app **aberto** (foreground), repita o insert: a notificação aparece
   como notificação local (mesmo canal).
6. Logs da função: dashboard → Edge Functions → push-dispatch → Logs
   (resposta esperada: `{"enviados":1,"removidos":0,"erros":0}`).
7. Teste de limpeza de token morto: desinstale o app, repita o insert e
   confira que a linha sumiu de `device_tokens` (resposta `removidos: 1`).

## Solução de problemas

- **Push não chega em background**: confira se a notificação do sistema não
  está bloqueada para o canal "vagas" (config. do Android) e se o aparelho
  tem Play services.
- **`enviados: 0, motivo: usuário sem device_tokens`**: o app não registrou o
  token — veja o log `PushService` no `flutter run` (precisa de sessão
  Supabase ativa no momento do `init`).
- **401 no webhook**: o header `x-webhook-secret` do webhook não bate com o
  secret `PUSH_WEBHOOK_SECRET`.
- **Erro `FIREBASE_SERVICE_ACCOUNT não configurado`**: refaça o
  `supabase secrets set` e redeploye a função.

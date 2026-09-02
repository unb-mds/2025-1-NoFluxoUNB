# Relatório da construção noturna — 2026-08-31 → 2026-09-01

## O que existe agora

**Branch `feat/app-mobile-flutter`** (criada a partir da main; **nada foi commitado** — o
Vitor controla o git). Documento de decisão em `documentacao/analise_app_mobile.md`
(viabilidade, por que Flutter, por que monorepo, arquitetura de push) — cada afirmação
factual foi verificada adversarialmente contra o código real do repo por um workflow de
6 agentes.

**App Flutter completo em `no_fluxo_app/`** — Android + iOS, Riverpod + go_router +
supabase_flutter, tema dark premium do site, feature-first:

| Área | O que faz | Testes |
| --- | --- | --- |
| Core | Config por dart-define, tema, models portados do legado com null-safety, auth (e-mail/senha, Google OAuth, visitante), api_client do Express (headers Authorization + User-ID), porte fiel do parser de horário SIGAA (bitmask 96 bits) | 22 |
| Fluxograma | Colunas por semestre, status com equivalências (semântica do site), bottom sheet de detalhes, "Ver turmas", modo visitante com seletor de curso | 30 |
| Turmas | Busca com debounce, vagas ao vivo com badge, "seguir matéria/turma" (RPCs reais), aba Seguindo | 36 |
| Notificações | Inbox via RPC, Realtime com fallback polling 60s, badge na bottom bar, deep link para a turma | 29 |
| Grade | Semana do aluno (fontes: fluxograma MATR + manual), conflitos marcados, notificações locais de aula (recorrência semanal, antecedência 10/30/60 min) | 25 |
| Perfil | Progresso por natureza vs exigências da matriz, IRA, logout | 24 |
| Push | `PushService` (token FCM → RPC, foreground, deep link), no-op seguro sem Firebase | 12 |

**Estado de qualidade:** `flutter analyze` sem issues, `dart format` aplicado,
**178/178 testes passando**, `flutter build apk --debug` ✓.

**Infra de servidor (DRAFTS — NADA aplicado no banco):** em `no_fluxo_app/supabase/`:
- `DRAFT_001_device_tokens.sql` — tabela + RLS + RPCs registrar/remover token
- `DRAFT_002_calendario_academico.sql` — eventos de matrícula (escrita só admin)
- `DRAFT_003_policies_anon_leitura_publica.sql` — **importante**: descoberto na verificação
  que as policies `*_select_public` são `TO authenticated`; sem esta migration (ou fallback
  via Express), o modo visitante não lê nada
- `functions/push-dispatch/index.ts` — Edge Function FCM v1 (webhook de INSERT em
  `notificacoes`), sem dependências externas, `deno check` ok

**CI:** `.github/workflows/app_flutter_ci.yml` — analyze + format + testes, filtrado por
path `no_fluxo_app/**` (não pesa nos PRs do site).

## O que depende do Vitor (em ordem)

1. Revisar e commitar a branch (nada foi commitado).
2. Seguir `no_fluxo_app/docs/PUSH_SETUP.md`: projeto Firebase → `flutterfire configure` →
   descomentar o plugin google-services no gradle → aplicar migrations (revisar!) →
   deploy da Edge Function → criar o Database Webhook.
3. Decidir modo visitante: aplicar `DRAFT_003` (recomendado) ou fallback via Express.
4. Rodar no aparelho: `cd no_fluxo_app && flutter run`.

## Resultado da revisão adversarial do código

Workflow de 16 agentes (5 lentes de revisão — contrato com o banco, corretude
Dart/Riverpod, lógica de domínio, infra push/SQL, fluxos de navegação — + verificação
cética de cada achado grave). **21 achados, 19 confirmados, todos corrigidos**, cada
correção com teste de regressão. Destaques:

### Bugs sérios encontrados e corrigidos

1. **Parser de expressões E/OU herdado do app legado tinha um off-by-one**: qualquer
   expressão terminando em `)` (ex.: `( A ) OU ( B )`) nunca encontrava o operador e
   avaliava como falso. Afetava pré-requisitos E equivalências — matéria disponível
   apareceria bloqueada. Corrigido em `equivalencia_model.dart` com regressão.
   *(Este bug provavelmente existia no app Flutter original em produção.)*
2. **Pré-requisitos ignoravam a `expressao_logica`** (árvore E/OU do banco): "A OU B"
   era tratado como "A E B". O resolver agora avalia a árvore jsonb recursivamente,
   com fallback textual e dedup por linha.
3. **Edge Function**: o secret do webhook virou obrigatório (sem ele: 401 sempre), e
   a remoção de token só acontece com erro estruturado UNREGISTERED do FCM — antes,
   um erro genérico de config apagaria tokens válidos em massa.
4. **Troca de usuário**: inbox de notificações e cache de cursos agora reagem ao
   login/logout (antes mostravam dados da conta anterior / cache vazio do visitante).
5. **Boot offline** não derruba mais o aluno logado para /login: sessão local válida
   com perfil inacessível mantém o login e agenda retry.
6. **Corridas**: filtro de notificações, busca do "+ turma" e mutações de
   assinaturas serializadas/protegidas por geração.
7. **"Seguir matéria" com RPC de período fora do ar**: fallback pelo período derivado
   da data em vez de falhar (e a falha não fica mais cacheada no provider).
8. **UX honesta para o visitante**: sob RLS o visitante recebe listas vazias — as
   telas agora explicam ("entre com sua conta") em vez de "nenhum resultado", e o
   seletor de cursos tem estado vazio com retry. "Trocar curso" ganhou volta.
9. **SQL drafts endurecidos**: `set search_path` nas funções SECURITY DEFINER,
   validação de token mínimo, comentário do trade-off de reassociação de token.

### Achados que NÃO são bugs de código (decisões/pendências)

- **Push só liga com a cadeia completa** (Firebase configurado + migrations aplicadas
  + função deployada + webhook criado): até lá o app funciona normalmente e o
  `PushService` é no-op seguro — mas a promessa "avisamos quando abrir vaga" só entrega
  a notificação **in-app**; o push de verdade depende dos passos do PUSH_SETUP.md.
- **Modo visitante depende da DRAFT_003** (ou de fallback via Express) — decisão sua.

### Segunda rodada: verificação cética dos próprios fixes

Após aplicar as correções, um segundo workflow (4 verificadores) tentou provar que os
fixes estavam errados ou incompletos. Achou **2 bloqueantes** (ambos corrigidos com
regressão):

- O jsonb `{}` — DEFAULT da coluna `expressao_logica` em linhas legadas — era tratado
  como expressão válida e avaliava como falso: matéria com pré-requisito legado já
  cumprido ficaria **bloqueada para sempre** (o site normaliza `{}` para null; o app
  agora também, incl. aspas de valor duplamente codificado `"MAT0026"`).
- O fix de troca de usuário tinha coberto só o badge: a **lista** de notificações
  (provider keep-alive) ainda vazava o inbox da conta anterior após logout+login de
  outra conta. Agora ambos observam o auth.

E 3 menores, também corrigidos: FCM `INVALID_ARGUMENT` de payload não apaga mais
tokens (só com `BadRequest` apontando `message.token`); o estado "logado sem perfil"
(boot offline) ganhou tela própria no Perfil (antes caía na tela de visitante, com
logout que não removia o token push); ordem unregister→signOut respeitada em todos os
caminhos. Limitação conhecida documentada: `EquivalenciaModel` avalia só a expressão
textual (o jsonb de equivalências fica para depois — o scraper atual sempre grava o
texto junto, então não há caso real hoje).

## Estado final

`flutter analyze`: limpo • `dart format`: aplicado • **214/214 testes passando** •
`flutter build apk --debug`: ✓ • `deno check` da Edge Function: ✓

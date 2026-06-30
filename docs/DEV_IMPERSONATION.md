# Dev Impersonation — modo local

Permite logar como qualquer usuário em **localhost** sem precisar de conta no Supabase ou popup do Google OAuth. Útil para Playwright e debug manual.

## Como ligar

1. Backend rodando com `NODE_ENV !== "production"` (qualquer valor que não seja `production`, ou variável ausente — o default do `npm run dev` já serve).
2. Frontend rodando com `PUBLIC_ENVIRONMENT !== "production"` (default em `.env.example`).
3. Acessar `http://localhost:5173/dev/impersonar`.

A rota retorna 404 em produção (gate no `+page.ts`).

## Uso

- **Presets**: clique em "Estudante padrão", "Admin (escopo tickets)" ou "Superadmin" para preencher o form rapidamente.
- **Custom**: edite `idUser`, `email`, `nomeCompleto`, `isAdmin`, `adminRole`, `adminScopes` (separados por vírgula). Defina pra onde redirecionar (`/upload-historico`, `/admin`, `/meu-fluxograma/Engenharia`, etc).
- Click **Impersonar** → o `authStore` recebe o `UserModel` sintético, a flag `localStorage.nofluxo_dev_impersonate=true` é setada, e você é redirecionado.
- **Limpar impersonação** desfaz tudo (`authStore.clear()` + remove flag).

## Como funciona

| Camada | Patch |
|---|---|
| `lib/stores/auth.ts` | `clear()` também remove `nofluxo_dev_impersonate`. |
| `lib/guards/authGuard.ts:checkAuth` | Quando a flag está setada, pula `isSessionValid()` (que faria signOut imediato sem sessão Supabase real). |
| `lib/services/auth.service.ts:getAuthHeaders` | Quando a flag está setada, envia `X-Dev-Impersonate: <email>` em vez de `Authorization: Bearer <token>`. |
| `no_fluxo_backend/src/utils.ts:checkAuthorization` | Quando `NODE_ENV !== "production"` E header `X-Dev-Impersonate` presente, faz lookup em `public.users` por `id_user`, compara o email, e autoriza. |

## Limitações & segurança

- **Gate de produção**: tanto frontend (`+page.ts` 404 + `getAuthHeaders` só atua com flag) quanto backend (`NODE_ENV !== "production"`) bloqueiam o bypass em prod. Se quiser auditar, busque por `nofluxo_dev_impersonate` e `x-dev-impersonate` no código.
- **UI-only vs full-stack**: se o `idUser`/`email` não existirem em `public.users`, as chamadas autenticadas falham no lookup (UI funciona, backend recusa). Para fluxo completo, use um user real do seed (a tabela `users` da sua instância Supabase de desenvolvimento).
- **Não substitui testes E2E reais**: este modo serve pra exploratórios e debug. Cenários de produção (OAuth real, RLS strict) precisam de teste com usuário real.

## Validação

Spec Playwright em `no_fluxo_frontend_svelte/tests-e2e/dev-impersonation.spec.ts` — 5 cenários, todos PASS:

1. Rota carrega e mostra título + presets
2. Submeter form impersona, seta flag e redireciona
3. Após impersonar, `authGuard` libera `/upload-historico` sem `signOut`
4. Preset Admin preenche os campos corretamente
5. Clear remove `user`, flag e exibe status

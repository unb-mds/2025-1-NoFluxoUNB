# Configuração de autenticação no Supabase (NoFluxo)

Este documento descreve o que conferir no **Supabase Dashboard** para o **login com Google** e a **redefinição de senha** funcionarem.

## 1. Login com Google

1. **Supabase Dashboard** → **Authentication** → **Providers** → **Google**  
   - Ative o provedor **Google**.  
   - Preencha **Client ID** e **Client Secret** (obtidos no [Google Cloud Console](https://console.cloud.google.com/) em *APIs & Services* → *Credentials* → *Create OAuth 2.0 Client ID*).  
   - No OAuth do Google, em *Authorized redirect URIs* adicione:  
     `https://<seu-projeto>.supabase.co/auth/v1/callback`

2. **Supabase Dashboard** → **Authentication** → **URL Configuration**  
   - Em **Redirect URLs** inclua a URL do seu frontend após o login, por exemplo:  
     - Desenvolvimento: `http://localhost:5173/auth/callback`  
     - Produção: `https://<seu-dominio>/auth/callback`

Sem o redirect URL correto, o Google redireciona para o Supabase, mas o Supabase não redireciona de volta para a aplicação.

## 2. Redefinição de senha

A redefinição de senha (“Esqueci minha senha”) funciona para **qualquer conta que tenha e-mail** no Supabase:
- contas criadas com **e-mail e senha** (cadastro normal);
- contas criadas com **Google** (que também têm e-mail).

O fluxo é o mesmo: o usuário informa o e-mail em “Recuperar senha”, recebe o link por e-mail, abre o link e define a nova senha. Não é necessário configurar nada diferente para quem se cadastrou com e-mail “normal” em vez do Google.

1. **Supabase Dashboard** → **Authentication** → **URL Configuration**  
   - Em **Redirect URLs** inclua a página de redefinição do frontend:  
     - Desenvolvimento: `http://localhost:5173/auth/reset-password`  
     - Produção: `https://<seu-dominio>/auth/reset-password`  
   - **Site URL**: use a raiz (ex.: `http://localhost:5173` ou `https://<seu-dominio>`).  
   - Se o link do e-mail vier com `redirect_to=http://localhost:5173/` (raiz) em vez de `/auth/reset-password`, o app redireciona automaticamente para a tela de redefinir senha ao detectar recovery na URL. Para que o link já abra na tela certa, o Supabase precisa usar o `redirectTo` que enviamos; confira se a lista **Redirect URLs** contém exatamente `http://localhost:5173/auth/reset-password` (e a versão de produção).

2. **Template de e-mail (opcional)**  
   - **Authentication** → **Email Templates** → **Reset Password**  
   - O template padrão já usa `{{ .ConfirmationURL }}`, que leva o usuário ao Supabase para verificar o token e depois redireciona para o `redirectTo` informado em `resetPasswordForEmail` (no nosso caso, `/auth/reset-password`).  
   - Se o link do e-mail chegar na sua app com `token_hash` e `type=recovery` na URL, a página `/auth/reset-password` usa `verifyOtp` para estabelecer a sessão e permitir trocar a senha.

## 3. Confirmação de e-mail (cadastro)

Para evitar que alguém entre no sistema com um e-mail fictício, o app exige que o usuário **confirme o e-mail** após o cadastro. O usuário só é criado na tabela `users` depois de clicar no link enviado por e-mail.

1. **Supabase Dashboard** → **Authentication** → **Providers** → **Email**  
   - Ative **Confirm email**.  
   - Assim, o Supabase não concede sessão até o usuário clicar no link de confirmação.

2. **Redirect URLs** (mesma tela **URL Configuration**):  
   - O link de confirmação redireciona para `/auth/callback` com `token_hash` e `type=signup` (ou `type=email`).  
   - A lista **Redirect URLs** já deve conter `http://localhost:5173/auth/callback` e a URL de produção (ex.: `https://<seu-dominio>/auth/callback`).  
   - Se não estiver, adicione para que o link do e-mail abra na sua aplicação.

3. **Fluxo no app**  
   - Cadastro: o usuário preenche nome, e-mail e senha → o app chama `signUp` com `emailRedirectTo: origin + '/auth/callback'`.  
   - O Supabase envia o e-mail com o link. O usuário **não** é inserido na tabela `users` ainda.  
   - Ao clicar no link: o Supabase redireciona para `/auth/callback?token_hash=...&type=signup`.  
   - A página de callback chama `verifyEmailAndRegister(tokenHash)`, que faz `verifyOtp` no Supabase, cria o registro em `users` e faz o login.

Se **Confirm email** estiver desativado, o cadastro continua funcionando: o usuário é criado no banco logo após o signUp (comportamento legado).

### E-mail de confirmação não chega

O Supabase usa por padrão um serviço de e-mail **apenas para demonstração**, com limite baixo de envios e **sem garantia de entrega**. Em muitos projetos, o e-mail **só é enviado para endereços de membros da equipe** autorizados no projeto, ou vai para **spam**.

**O que fazer:** configurar SMTP customizado (guia Resend abaixo) ou conferir spam e logs.

#### Configurar Resend como SMTP (recomendado)

O [Resend](https://resend.com) é um provedor de e-mail transacional com plano gratuito e boa entrega.

**1. Conta e API Key no Resend**

- Acesse [resend.com](https://resend.com) → crie conta ou faça login.
- Vá em **API Keys** ([resend.com/api-keys](https://resend.com/api-keys)) → **Create API Key** → copie a chave (começa com `re_`). Guarde: ela só aparece uma vez.

**2. Domínio do remetente**

O Resend exige que o e-mail do remetente seja de um **domínio verificado**.

- **Domínio próprio:** Em **Domains** ([resend.com/domains](https://resend.com/domains)), adicione seu domínio e configure os registros DNS. Use como remetente ex.: `noreply@seudominio.com`.
- **Teste rápido:** Na conta gratuita você pode enviar só para o e-mail da sua conta até verificar um domínio. Use esse e-mail como Sender no Supabase e teste o cadastro com ele; depois verifique o domínio para enviar para qualquer usuário.

**3. Preencher SMTP no Supabase**

- **Supabase** → **Project Settings** (engrenagem) → **Auth** → **SMTP Settings**.
- Ative **Enable custom SMTP**.
- Preencha:

  | Campo | Valor |
  |-------|--------|
  | **Sender email** | E-mail de domínio verificado no Resend (ou, em teste, o e-mail da sua conta Resend). |
  | **Sender name** | `NoFluxo UnB` |
  | **Host** | `smtp.resend.com` |
  | **Port** | `465` |
  | **Username** | `resend` (a palavra "resend") |
  | **Password** | Sua API Key do Resend (a chave `re_...`). |

- Clique em **Save**.

**4. Testar**

- No app, faça um cadastro com um e-mail que você tenha acesso (em teste, use o e-mail verificado no Resend).
- Verifique a caixa de entrada e o spam. Clique no link do e-mail; você deve ser redirecionado ao app e a conta ativada.

Referência: [Resend – Send with Supabase SMTP](https://resend.com/docs/send-with-supabase-smtp).

---

**Outras verificações**

2. **Conferir pasta de spam**  
   - Peça para o usuário verificar spam/lixo eletrônico e marcar como “não é spam” se encontrar.

3. **Verificar logs de Auth**  
   - **Supabase Dashboard** → **Authentication** → **Logs**.  
   - Veja se o signup aparece e se há erro no envio do e-mail (ex.: handover to provider failed).

4. **Em desenvolvimento**  
   - Para testar sem e-mail real, use uma caixa de teste (ex.: [Mailtrap](https://mailtrap.io)) como SMTP, ou desative temporariamente **Confirm email** no Provider Email para o usuário ser criado logo após o cadastro.

## Resumo

| Recurso              | Onde configurar                         | O que adicionar |
|----------------------|------------------------------------------|-----------------|
| Google (provider)    | Auth → Providers → Google                | Client ID, Client Secret; redirect no Google = `.../auth/v1/callback` |
| Redirect após login  | Auth → URL Configuration → Redirect URLs| `.../auth/callback` (dev e prod) |
| Redirect reset senha | Auth → URL Configuration → Redirect URLs| `.../auth/reset-password` (dev e prod) |
| Confirmar e-mail     | Auth → Providers → Email                 | Ativar **Confirm email** para exigir confirmação no cadastro |

Depois de salvar, teste o fluxo completo (login com Google e “Esqueci minha senha” → e-mail → redefinir senha).

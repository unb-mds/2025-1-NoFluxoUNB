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

## Resumo

| Recurso              | Onde configurar                         | O que adicionar |
|----------------------|------------------------------------------|-----------------|
| Google (provider)    | Auth → Providers → Google                | Client ID, Client Secret; redirect no Google = `.../auth/v1/callback` |
| Redirect após login  | Auth → URL Configuration → Redirect URLs| `.../auth/callback` (dev e prod) |
| Redirect reset senha | Auth → URL Configuration → Redirect URLs| `.../auth/reset-password` (dev e prod) |

Depois de salvar, teste o fluxo completo (login com Google e “Esqueci minha senha” → e-mail → redefinir senha).

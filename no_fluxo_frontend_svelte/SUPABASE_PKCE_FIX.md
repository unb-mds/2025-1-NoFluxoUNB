# Correção do Erro PKCE Code Verifier

Este documento explica a correção implementada para o erro "PKCE code verifier not found in storage" que ocorria no login com Google.

## O Problema

O erro aparecia quando:
- O usuário clicava em "Continuar com Google"
- Era redirecionado para o Google, fazia login
- Voltava para a aplicação, mas o `code verifier` do PKCE não estava mais no storage
- Resultado: "Erro na autenticação" e o usuário não conseguia logar

### Causa Raiz

O Supabase usa PKCE (Proof Key for Code Exchange) para OAuth, que requer:
1. **Code Verifier**: string aleatória gerada no início do fluxo
2. **Code Challenge**: hash do code verifier enviado ao Google
3. **Authorization Code**: retornado pelo Google após login
4. **Token Exchange**: troca o code + verifier pelos tokens de acesso

O problema era que o `code verifier` estava sendo armazenado no `localStorage`, que pode ser limpo ou não persistir adequadamente entre redirects em alguns navegadores/cenários.

## A Solução

### 1. Cliente Supabase com Cookies Explícitas

Modificamos `src/lib/supabase/client.ts` para usar cookies em vez de localStorage:

```typescript
export function createSupabaseBrowserClient() {
	return createBrowserClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY, {
		cookies: {
			getAll() {
				// Lê todos os cookies do documento
				return document.cookie.split(';')...
			},
			setAll(cookiesToSet) {
				// Define cookies com configurações adequadas
				cookiesToSet.forEach(({ name, value, options }) => {
					// Configura Path, MaxAge, SameSite, Secure
				});
			}
		},
		cookieOptions: {
			name: 'sb-auth-token',
			maxAge: 60 * 60 * 24 * 7, // 7 dias
			path: '/',
			sameSite: 'lax'
		}
	});
}
```

### 2. Fallback no AuthService

Adicionamos tratamento de erro com fallback em `exchangeCodeForSessionAndHandleCallback`:

```typescript
try {
	const { data, error } = await this.supabase.auth.exchangeCodeForSession(code);
	
	if (error && error.message?.includes('code verifier')) {
		// Se PKCE falhar, tenta fallback com getSession
		console.warn('PKCE code verifier not found, trying fallback');
		return this.handleOAuthCallback();
	}
	
	// Continua normalmente...
} catch (error) {
	// Mesmo tratamento para exceções
}
```

### 3. Mensagens de Erro Melhoradas

No callback (`src/routes/auth/callback/+page.svelte`), detectamos erros de PKCE e mostramos mensagem mais clara:

```typescript
if (errorMessage.includes('code verifier') || errorMessage.includes('PKCE')) {
	error = 'Erro na autenticação: o processo foi iniciado em outra aba ou navegador. Tente fazer login novamente.';
}
```

## Vantagens da Solução

1. **Cookies são mais persistentes** que localStorage em redirects OAuth
2. **Fallback robusto** para casos onde mesmo cookies falham
3. **Mensagens claras** para o usuário sobre o que fazer
4. **Compatibilidade** mantida com o fluxo existente

## Como Testar

1. Abra a aplicação em `http://localhost:5173`
2. Clique em "Continuar com Google"
3. Faça login no Google
4. Verifique se volta para a aplicação logado (sem erro de PKCE)

Se ainda houver problemas:
- Limpe cookies/localStorage do navegador
- Tente em aba anônima
- Verifique se as URLs de redirect no Supabase estão corretas

## Configurações Necessárias no Supabase

Certifique-se de que em **Authentication → URL Configuration** você tem:

**Redirect URLs:**
- `http://localhost:5173/auth/callback`
- `https://seu-dominio.com/auth/callback` (produção)

**Site URL:**
- `http://localhost:5173` (desenvolvimento)
- `https://seu-dominio.com` (produção)
import { describe, it, expect, vi, beforeEach } from 'vitest';

/**
 * Uma instância de cliente Supabase por página, não uma por serviço.
 *
 * Cada `createBrowserClient` monta um `GoTrueClient`, e todos disputam o mesmo
 * lock exclusivo do Navigator LockManager para renovar o token. Com catorze
 * instâncias — o estado do app antes disto — os perdedores da corrida estouram
 * "Acquiring an exclusive Navigator LockManager lock ... immediately failed" no
 * console, e a renovação da sessão passa a depender de qual cliente ganhou.
 */
let criados = 0;

vi.mock('@supabase/ssr', () => ({
	createBrowserClient: () => {
		criados++;
		return { id: criados } as unknown as never;
	}
}));

vi.mock('$env/static/public', () => ({
	PUBLIC_SUPABASE_URL: 'https://exemplo.supabase.co',
	PUBLIC_SUPABASE_ANON_KEY: 'chave-de-teste'
}));

beforeEach(() => {
	criados = 0;
	vi.resetModules();
});

describe('createSupabaseBrowserClient', () => {
	it('no browser, devolve sempre a mesma instância', async () => {
		const janela = globalThis.window;
		// O ambiente padrão do vitest aqui é node; a memoização é justamente a que
		// só vale no browser, então ele precisa existir para o caso ser o real.
		globalThis.window = {} as never;
		try {
			const { createSupabaseBrowserClient } = await import('./client');

			const a = createSupabaseBrowserClient();
			const b = createSupabaseBrowserClient();
			const c = createSupabaseBrowserClient();

			expect(a).toBe(b);
			expect(b).toBe(c);
			expect(criados).toBe(1);
		} finally {
			if (janela === undefined) {
				// @ts-expect-error — devolve o ambiente ao estado de servidor
				delete globalThis.window;
			} else {
				globalThis.window = janela;
			}
		}
	});

	/**
	 * No servidor cada requisição precisa do seu próprio cliente: compartilhar a
	 * instância faria a sessão de um usuário vazar para a requisição de outro.
	 */
	it('sem window, cria um cliente novo a cada chamada', async () => {
		const janela = globalThis.window;
		// @ts-expect-error — simula o ambiente de servidor
		delete globalThis.window;
		try {

			const { createSupabaseBrowserClient } = await import('./client');

			const a = createSupabaseBrowserClient();
			const b = createSupabaseBrowserClient();

			expect(a).not.toBe(b);
			expect(criados).toBe(2);
		} finally {
			if (janela !== undefined) globalThis.window = janela;
		}
	});
});

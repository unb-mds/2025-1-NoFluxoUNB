import { test, expect, Page } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Sessão Exploratória — Login / Autenticação (Vini)
 * Evidências automatizadas das técnicas Transição de Estados, Tabela de Decisão
 * e Error Guessing aplicadas ao fluxo de auth do NoFluxoUNB.
 *
 * Limites conhecidos:
 * - SEM usuário Supabase de teste; credenciais sintéticas só capturam telas
 *   de erro (D5/D7/erros de mensagem).
 * - OAuth Google só é exercitado até o clique inicial; o redirect para Google
 *   é capturado por screenshot do estado da página, sem prosseguir.
 */

const EVID = path.resolve(__dirname, '../../docs/testes/evidencias');

async function asAnon(page: Page) {
	await page.addInitScript(() => {
		try {
			localStorage.setItem('nofluxo_anonimo', 'true');
		} catch {}
	});
}

async function clearAll(page: Page, context: any) {
	await context.clearCookies();
	await page.addInitScript(() => {
		try {
			localStorage.clear();
			sessionStorage.clear();
		} catch {}
	});
}

async function shot(page: Page, name: string) {
	await page.screenshot({ path: path.join(EVID, `${name}.png`), fullPage: true });
}

async function gotoAndSettle(page: Page, url: string, timeout = 8_000) {
	try {
		await page.goto(url, { waitUntil: 'networkidle', timeout });
	} catch {
		// se network nunca fica idle (auth listeners pendentes), continua
	}
	await page.waitForTimeout(600);
}

test.describe('Login/Auth — Sessão Exploratória (Vini)', () => {
	test('BASELINE: tela /login renderiza com Google + form + visitante', async ({ page, context }) => {
		await clearAll(page, context);
		await gotoAndSettle(page, '/login');
		await shot(page, 'vini-00-baseline-login');
		// botões esperados na superfície
		const hasGoogle = await page.getByRole('button', { name: /google/i }).count();
		const hasVisitor = await page.getByRole('button', { name: /visitante/i }).count();
		expect(hasGoogle + hasVisitor).toBeGreaterThan(0);
	});

	test('TE1: NotLoggedIn -> Anonymous via /login-anonimo grava flag e cookie', async ({ page, context }) => {
		await clearAll(page, context);
		await gotoAndSettle(page, '/login-anonimo');
		await shot(page, 'vini-01-te1-tela-anonimo');
		const btn = page.getByRole('button', { name: /continuar sem conta/i });
		await btn.click();
		await page.waitForTimeout(1500);
		await shot(page, 'vini-02-te1-pos-anonimo-redirect');
		const storage = await page.evaluate(() => ({
			anon: localStorage.getItem('nofluxo_anonimo'),
			cookie: document.cookie
		}));
		console.log('Storage pós-anônimo:', storage);
		// flag em localStorage deve existir após setAnonymous
		// (cookie pode não aparecer em document.cookie se for HttpOnly ou
		// gravado em path diferente — registramos só como evidência)
	});

	test('EG6/D9: deep-link /upload-historico DESLOGADO — guard redireciona?', async ({ page, context }) => {
		await clearAll(page, context);
		// não setAnonymous: nem logado nem anônimo
		try {
			await page.goto('/upload-historico', { timeout: 8_000 });
		} catch {}
		await page.waitForTimeout(3000);
		await shot(page, 'vini-03-eg6-d9-deeplink-upload-deslogado');
		const url = page.url();
		// Confirma comportamento (mesmo defeito D9 do Vitor): guard cliente-side
		// frequentemente NÃO redireciona quando isLoading ainda true.
		// Apenas registra o que aconteceu — não força assert.
		console.log('URL após deep-link upload deslogado:', url);
	});

	test('EG6b: deep-link /meu-fluxograma DESLOGADO', async ({ page, context }) => {
		await clearAll(page, context);
		try {
			await page.goto('/meu-fluxograma', { timeout: 8_000 });
		} catch {}
		await page.waitForTimeout(3000);
		await shot(page, 'vini-04-eg6b-deeplink-meufluxograma-deslogado');
		console.log('URL após deep-link meu-fluxograma deslogado:', page.url());
	});

	test('TC5/D5: redirect para /login?error=session_expired NÃO é exibido', async ({ page, context }) => {
		await clearAll(page, context);
		await gotoAndSettle(page, '/login?error=session_expired&redirect=%2Fupload-historico');
		await shot(page, 'vini-05-d5-error-param-nao-exibido');
		// Buscar qualquer texto que mencione "expirou"/"sessão"/"session_expired"
		const body = (await page.locator('body').innerText()).toLowerCase();
		const showsExpired = /expir|sess[aã]o/.test(body);
		// CONFIRMA D5 se a página não mostrar nenhuma mensagem sobre expiração
		expect(showsExpired).toBe(false);
	});

	test('EG-validation: email inválido — validação client mostra erro', async ({ page, context }) => {
		await clearAll(page, context);
		await gotoAndSettle(page, '/login');
		const emailInput = page.locator('#login-email');
		const passInput = page.locator('#login-password');
		await emailInput.fill('nao-eh-email');
		await passInput.fill('qualquer123');
		// blur para acionar validação
		await emailInput.blur();
		await page.waitForTimeout(400);
		await shot(page, 'vini-06-eg-email-invalido-client-validation');
		const errorVisible = await page.locator('text=/email|inv[aá]lido|formato/i').count();
		expect(errorVisible).toBeGreaterThan(0);
	});

	test('EG-credsynteticas: login com credenciais sintéticas mostra erro do Supabase', async ({ page, context }) => {
		await clearAll(page, context);
		await gotoAndSettle(page, '/login');
		await page.locator('#login-email').fill('naoexiste-vini@example.com');
		await page.locator('#login-password').fill('senhaerrada123');
		// submit via Enter ou botão
		const submit = page.getByRole('button', { name: /^entrar$/i });
		await submit.click();
		// aguardar resposta do supabase (pode falhar por rede também)
		await page.waitForTimeout(6_000);
		await shot(page, 'vini-07-eg-creds-sinteticas-erro');
		const body = (await page.locator('body').innerText()).toLowerCase();
		console.log('Trechos de erro detectados:', body.match(/erro|inv[aá]lido|email|senha|credenci/g));
	});

	test('TE3/D1: anônimo + tentativa de login mantém cookie nofluxo_anonimo (defeito)', async ({ page, context }) => {
		await clearAll(page, context);
		// 1) entra como anônimo
		await gotoAndSettle(page, '/login-anonimo');
		await page.getByRole('button', { name: /continuar sem conta/i }).click();
		await page.waitForTimeout(1500);
		const beforeCookie = await page.evaluate(() => document.cookie);
		console.log('Cookie ANTES tentativa login (após anônimo):', beforeCookie);
		// 2) vai para /login e tenta login com creds sintéticas
		await gotoAndSettle(page, '/login');
		await page.locator('#login-email').fill('vini-test@example.com');
		await page.locator('#login-password').fill('senhainexistente');
		await page.getByRole('button', { name: /^entrar$/i }).click();
		await page.waitForTimeout(5_000);
		await shot(page, 'vini-08-te3-d1-cookie-anon-apos-tentativa-login');
		const afterCookie = await page.evaluate(() => document.cookie);
		console.log('Cookie após tentativa de login (anon era ' + beforeCookie + '):', afterCookie);
		// D1: setUser não remove cookie — como aqui o login FALHA, não dá pra
		// confirmar D1 sem usuário real. Documenta-se evidência parcial:
		// cookie permanece anônimo após falha (esperado), confirmando que o
		// código que removeria viveria em setUser (não exercitado).
	});

	test('EG7/D8: /auth/reset-password com token_hash forjado mostra link inválido', async ({ page, context }) => {
		await clearAll(page, context);
		await gotoAndSettle(
			page,
			'/auth/reset-password?token_hash=forjado-pelo-vini-12345&type=recovery',
			15_000
		);
		// onMount chama verifyOtp; aguardamos resposta
		await page.waitForTimeout(6_000);
		await shot(page, 'vini-09-eg7-d8-recovery-token-forjado');
		const body = (await page.locator('body').innerText()).toLowerCase();
		// Esperado: "Link inválido ou expirado" ou similar
		const showsInvalid = /inv[aá]lido|expirado|solicitar/.test(body);
		console.log('Mensagem de recovery com token forjado contém erro?', showsInvalid);
	});

	test('EG7b: /auth/reset-password SEM token_hash exibe mensagem de orientação', async ({ page, context }) => {
		await clearAll(page, context);
		await gotoAndSettle(page, '/auth/reset-password');
		await page.waitForTimeout(4_000);
		await shot(page, 'vini-10-eg7b-recovery-sem-token');
		const body = (await page.locator('body').innerText()).toLowerCase();
		expect(/acesse|link|e-mail|email/.test(body)).toBe(true);
	});

	test('TE5: /password-recovery — formulário de envio renderiza', async ({ page, context }) => {
		await clearAll(page, context);
		await gotoAndSettle(page, '/password-recovery');
		await shot(page, 'vini-11-te5-tela-recovery');
		const emailInput = page.locator('#recovery-email');
		await expect(emailInput).toBeVisible();
		await emailInput.fill('teste-vini@unb.br');
		await page.getByRole('button', { name: /enviar link/i }).click();
		await page.waitForTimeout(5_000);
		await shot(page, 'vini-12-te5-recovery-pos-envio');
	});

	test('TE7/D4: localStorage.nofluxo_user JSON sem idUser cria user fantasma', async ({ page, context }) => {
		await clearAll(page, context);
		// injeta JSON malformado ANTES de qualquer script da app rodar
		await page.addInitScript(() => {
			localStorage.setItem('nofluxo_user', JSON.stringify({ email: 'fantasma@exploit.com' }));
		});
		await gotoAndSettle(page, '/');
		await page.waitForTimeout(2_000);
		await shot(page, 'vini-13-te7-d4-localstorage-malformado');
		const state = await page.evaluate(() => ({
			user: localStorage.getItem('nofluxo_user'),
			anon: localStorage.getItem('nofluxo_anonimo')
		}));
		console.log('Estado pós-init com user malformado:', state);
		// Se idUser=0 for criado, o app pode mostrar área autenticada
		// (D4: confirmado se o user permanecer no localStorage).
	});

	test('EG-google: clique em "Continuar com Google" inicia redirect (PKCE)', async ({ page, context }) => {
		await clearAll(page, context);
		await gotoAndSettle(page, '/login');
		const googleBtn = page.getByRole('button', { name: /google/i });
		await googleBtn.click();
		// aguarda popup/redirect; em ambiente de teste sem credenciais reais,
		// pode resultar em erro do Supabase ou navegação para accounts.google.com
		await page.waitForTimeout(4_000);
		await shot(page, 'vini-14-eg-google-click-inicial');
		console.log('URL após clique Google:', page.url());
		// PKCE: verifier deve ter sido escrito em localStorage
		const sbKeys = await page.evaluate(() => {
			const out: string[] = [];
			for (let i = 0; i < localStorage.length; i++) {
				const k = localStorage.key(i);
				if (k && /sb-|verifier|pkce/i.test(k)) out.push(k);
			}
			return out;
		});
		console.log('Chaves PKCE/supabase no localStorage:', sbKeys);
	});

	test('TC8: rota privada deslogado deveria mandar para /login?redirect=...', async ({ page, context }) => {
		await clearAll(page, context);
		try {
			await page.goto('/admin/dashboards', { timeout: 8_000 });
		} catch {}
		await page.waitForTimeout(3_000);
		await shot(page, 'vini-15-tc8-admin-deslogado');
		const url = page.url();
		console.log('URL após /admin deslogado:', url);
		// se redirecionou para login, conferir query param redirect
		if (/\/login/.test(url)) {
			expect(url).toMatch(/redirect=/);
		}
	});
});

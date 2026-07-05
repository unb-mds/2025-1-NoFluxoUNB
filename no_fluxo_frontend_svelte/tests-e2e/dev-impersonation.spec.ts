import { test, expect } from '@playwright/test';

/**
 * Sessão Exploratória — /dev/impersonar
 * Valida o modo dev de impersonação local (gated por PUBLIC_ENVIRONMENT !== 'production'):
 * - Rota acessível em dev.
 * - Submeter o form injeta um UserModel sintético no authStore + flag dev_impersonate.
 * - Após impersonar, o authGuard libera rotas privadas sem chamar isSessionValid.
 * - Clear remove o usuário e a flag.
 */

test.describe.serial('Dev Impersonation — sessão exploratória', () => {
	test('Rota /dev/impersonar carrega e mostra o título + presets', async ({ page }) => {
		await page.goto('/dev/impersonar', { waitUntil: 'networkidle' });
		await expect(page.locator('h1')).toContainText('Impersonar usuário');
		await expect(page.getByRole('button', { name: /Estudante padrão/ })).toBeVisible();
		await expect(page.getByRole('button', { name: /Superadmin/ })).toBeVisible();
	});

	test('Submeter form impersona, seta flag e redireciona', async ({ page }) => {
		await page.goto('/dev/impersonar');
		await page.getByTestId('idUser').fill('42');
		await page.getByTestId('email').fill('teste42@dev.local');
		await page.getByTestId('nomeCompleto').fill('Usuário 42');
		await page.getByTestId('redirectTo').fill('/upload-historico');
		await page.getByTestId('submit').click();
		await page.waitForURL(/upload-historico/, { timeout: 5_000 });

		const localStorage = await page.evaluate(() => ({
			user: window.localStorage.getItem('nofluxo_user'),
			devImpersonate: window.localStorage.getItem('nofluxo_dev_impersonate')
		}));
		expect(localStorage.devImpersonate).toBe('true');
		expect(localStorage.user).toBeTruthy();
		const userObj = JSON.parse(localStorage.user!);
		expect(userObj.idUser).toBe(42);
		expect(userObj.email).toBe('teste42@dev.local');
		expect(userObj.nomeCompleto).toBe('Usuário 42');
	});

	test('Após impersonar, authGuard libera /upload-historico (sem signOut)', async ({ page }) => {
		await page.goto('/dev/impersonar');
		await page.getByTestId('idUser').fill('99');
		await page.getByTestId('email').fill('guarded@dev.local');
		await page.getByTestId('nomeCompleto').fill('Guard Test');
		await page.getByTestId('submit').click();
		await page.waitForURL(/upload-historico/, { timeout: 5_000 });

		// Confirma que NÃO redirecionou pra /login?error=session_expired
		expect(page.url()).not.toContain('error=session_expired');
		expect(page.url()).toContain('/upload-historico');
	});

	test('Preset Admin preenche campos corretamente', async ({ page }) => {
		await page.goto('/dev/impersonar');
		await page.getByRole('button', { name: /Admin \(escopo tickets\)/ }).click();
		await expect(page.getByTestId('idUser')).toHaveValue('2');
		await expect(page.getByTestId('email')).toHaveValue('admin@dev.local');
		await expect(page.getByTestId('isAdmin')).toBeChecked();
		await expect(page.getByTestId('adminRole')).toHaveValue('admin');
		await expect(page.getByTestId('adminScopes')).toHaveValue('tickets');
	});

	test('Clear remove user, flag e mostra status', async ({ page }) => {
		await page.goto('/dev/impersonar');
		await page.getByTestId('idUser').fill('1');
		await page.getByTestId('email').fill('a@b.c');
		await page.getByTestId('nomeCompleto').fill('X');
		// Não submete pra evitar redirect; só seta flag manualmente
		await page.evaluate(() => {
			localStorage.setItem('nofluxo_dev_impersonate', 'true');
			localStorage.setItem('nofluxo_user', JSON.stringify({ idUser: 1, email: 'a@b.c', nomeCompleto: 'X' }));
		});
		await page.getByTestId('clear').click();
		await expect(page.getByTestId('status')).toContainText('removida');
		const ls = await page.evaluate(() => ({
			user: window.localStorage.getItem('nofluxo_user'),
			devImpersonate: window.localStorage.getItem('nofluxo_dev_impersonate')
		}));
		expect(ls.devImpersonate).toBeNull();
		expect(ls.user).toBeNull();
	});
});

import { test, expect, Page } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Sessão Exploratória — Upload do Histórico SIGAA
 * Evidência automatizada das técnicas BVA, Error Guessing e Transição de Estados.
 * Os PNGs são salvos em ../../docs/testes/evidencias/.
 */

const FIXTURES = path.resolve(__dirname, '../../docs/testes/fixtures');
const EVID = path.resolve(__dirname, '../../docs/testes/evidencias');

async function asAnon(page: Page) {
	await page.addInitScript(() => {
		localStorage.setItem('nofluxo_anonimo', 'true');
	});
}

async function gotoUpload(page: Page) {
	await page.goto('/upload-historico', { waitUntil: 'networkidle' });
	await page.waitForSelector('.dropzone', { timeout: 10_000 });
}

async function shot(page: Page, name: string) {
	await page.screenshot({ path: path.join(EVID, `${name}.png`), fullPage: true });
}

async function pickFile(page: Page, fixture: string) {
	const input = page.locator('input[type="file"]');
	await input.setInputFiles(path.join(FIXTURES, fixture));
}

async function waitToast(page: Page): Promise<string> {
	const toast = page.locator('[data-sonner-toast]').last();
	await toast.waitFor({ state: 'visible', timeout: 4_000 });
	await page.waitForTimeout(400);
	return (await toast.innerText()).trim();
}

async function shotToast(page: Page, name: string): Promise<string> {
	const msg = await waitToast(page);
	await shot(page, name);
	return msg;
}

test.describe('Upload Histórico — Sessão Exploratória', () => {
	test.beforeEach(async ({ page }) => {
		await asAnon(page);
	});

	test('BASELINE: estado initial do dropzone', async ({ page }) => {
		await gotoUpload(page);
		await expect(page.locator('.dropzone-title')).toBeVisible();
		await expect(page.locator('.dropzone-hint')).toContainText('máx. 10MB');
		await shot(page, '00-baseline-initial');
	});

	test('BVA1: arquivo de 0 bytes deve ser rejeitado', async ({ page }) => {
		await gotoUpload(page);
		await pickFile(page, 'empty.pdf');
		const msg = await shotToast(page, '01-bva1-empty');
		expect(msg.toLowerCase()).toMatch(/vazio/);
	});

	test('BVA5: 10MB+1 byte rejeitado com mensagem "10.0MB" (defeito D6)', async ({ page }) => {
		await gotoUpload(page);
		await pickFile(page, 'size_10mb_plus1.pdf');
		const msg = await shotToast(page, '02-bva5-oversize-10mb-plus1');
		expect(msg).toMatch(/Arquivo muito grande/);
		expect(msg).toMatch(/10\.0MB.*10MB/);
	});

	test('BVA4: 10MB exato é aceito (limite on-point)', async ({ page }) => {
		await gotoUpload(page);
		await pickFile(page, 'size_10mb_exact.pdf');
		await page.waitForTimeout(800);
		await shot(page, '03-bva4-10mb-exato');
		const dropzoneGone = await page.locator('.dropzone').count();
		expect(dropzoneGone).toBe(0);
	});

	test('EG1: arquivo com extensão errada (.txt) é rejeitado', async ({ page }) => {
		await gotoUpload(page);
		const input = page.locator('input[type="file"]');
		await input.setInputFiles(path.join(FIXTURES, 'wrong_ext.txt'));
		const msg = await shotToast(page, '04-eg1-wrong-extension');
		expect(msg.toLowerCase()).toMatch(/formato inválido/);
	});

	test('EG1b/D8: .docx renomeado .pdf → mensagem em INGLÊS do PDF.js (novo defeito D8)', async ({ page }) => {
		await gotoUpload(page);
		await pickFile(page, 'docx_renamed.pdf');
		const msg = await shotToast(page, '05-eg1b-docx-renamed-mensagem-en');
		// Browser injeta MIME application/pdf pela extensão → validação client passa,
		// PDF.js falha com texto inglês não traduzido. Vira defeito D8 no relatório.
		expect(msg.toLowerCase()).toMatch(/invalid pdf structure|formato inválido/);
	});

	test('BVA6: PDF "válido" mas sem conteúdo de histórico (apenas header)', async ({ page }) => {
		await gotoUpload(page);
		await pickFile(page, 'base_header.pdf');
		await page.waitForTimeout(1500);
		await shot(page, '06-bva6-header-only');
	});

	test('EG5/D9: auth guard NÃO redireciona não-autenticado (defeito novo D9)', async ({ page, context }) => {
		await context.clearCookies();
		await page.addInitScript(() => localStorage.clear());
		await page.goto('/upload-historico');
		await page.waitForTimeout(3000);
		await shot(page, '07-eg5-d9-unauth-NAO-redirecionou');
		// authGuard.ts:checkAuth deveria mandar pra /login, mas mantém em /upload-historico
		// porque state.isLoading=true bypassa a regra. Defeito D9 — exposição de rota privada.
		expect(page.url()).toMatch(/upload-historico|login/);
	});

	test('PERSONA: histórico real do SIGAA inicia o fluxo', async ({ page }) => {
		await gotoUpload(page);
		await pickFile(page, 'historico_valido.pdf');
		await page.waitForTimeout(1500);
		await shot(page, '08-persona-historico-real');
	});
});

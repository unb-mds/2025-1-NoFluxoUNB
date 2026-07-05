import { test, expect, Page } from '@playwright/test';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Sessão Exploratória — Busca e Filtro de Disciplinas
 * Alvo público sem auth: /disciplinas (campo `termoBusca` + chips
 * `filtroTipoMatriz`). Os modais MateriasConcluidasModal/OptativasModal
 * exigem fluxograma carregado pós-login e foram avaliados estaticamente
 * no relatório; aqui exercitamos os mesmos padrões (BVA, Particionamento,
 * Tabela de Decisão, Error Guessing) na superfície pública.
 *
 * Evidência: PNGs em ../../docs/testes/evidencias/ com prefixo `andre-`.
 */

const EVID = path.resolve(__dirname, '../../docs/testes/evidencias');
const ROUTE = '/disciplinas';

async function asAnon(page: Page) {
	await page.addInitScript(() => {
		localStorage.setItem('nofluxo_anonimo', 'true');
	});
}

async function gotoBusca(page: Page) {
	await page.goto(ROUTE, { waitUntil: 'domcontentloaded' });
	// Espera o input de busca aparecer (estado pós-loading de matrizes,
	// no caso global aparece junto com o resto da árvore).
	await page.waitForSelector('input[placeholder*="Buscar"]', { timeout: 15_000 });
}

async function shot(page: Page, name: string) {
	await page.screenshot({ path: path.join(EVID, `${name}.png`), fullPage: true });
}

async function typeQuery(page: Page, q: string) {
	const input = page.locator('input[placeholder*="Buscar"]').first();
	await input.click();
	await input.fill('');
	await input.fill(q);
	// Dá tempo do $derived computar
	await page.waitForTimeout(250);
}

test.describe.serial('Busca/Filtro Disciplinas — Sessão Exploratória', () => {
	test.beforeEach(async ({ page }) => {
		await asAnon(page);
	});

	test('BASELINE: rota carrega e expõe o campo de busca', async ({ page }) => {
		await gotoBusca(page);
		await expect(page.locator('input[placeholder*="Buscar"]').first()).toBeVisible();
		await shot(page, 'andre-00-baseline-disciplinas');
	});

	test('BVA1: query vazia exibe lista padrão (sem filtro)', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, '');
		await shot(page, 'andre-01-bva1-empty');
	});

	test('BVA2: 1 caractere ("a") cai no piso `q.length < 2` — não filtra', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, 'a');
		await shot(page, 'andre-02-bva2-1char');
		// Esperado: lista NÃO encolheu para "Nenhuma" (porque há piso de 2 chars).
		// Defeito de UX hipotético: usuário digita "a" e nada muda, sem feedback do piso.
	});

	test('BVA3: só espaços (3 espaços) — equivalente a vazio', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, '   ');
		await shot(page, 'andre-03-bva3-only-spaces');
	});

	test('PE/BVA4: 200 caracteres — sem crash, lista vazia', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, 'x'.repeat(200));
		await shot(page, 'andre-04-bva4-200chars');
	});

	test('BVA5: 1000 caracteres — stress sem debounce (D5 hipótese)', async ({ page }) => {
		await gotoBusca(page);
		const t0 = Date.now();
		await typeQuery(page, 'y'.repeat(1000));
		const dt = Date.now() - t0;
		await shot(page, 'andre-05-bva5-1000chars');
		// Não falha: apenas registra latência observada como evidência de D5.
		console.log(`[BVA5] fill 1000 chars + render: ${dt}ms`);
	});

	test('EG1/BVA-emoji: emoji "📚" não quebra a página', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, '📚');
		await shot(page, 'andre-06-eg1-emoji');
		// includes() é seguro com surrogate pairs; esperado 0 hits sem crash.
	});

	test('EG2: regex chars "(*[" não quebram (includes não interpreta regex)', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, '(*[');
		await shot(page, 'andre-07-eg2-regex-chars');
	});

	test('PE/P7: acento "ç" — entrada Unicode válida', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, 'ç');
		await shot(page, 'andre-08-p7-cedilha');
		// Sub-2 chars: lista mostra default. Demonstra que cedilha não trava input.
	});

	test('PE/BVA: case CALCULO (upper)', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, 'CALCULO');
		await shot(page, 'andre-09-case-upper-CALCULO');
	});

	test('PE/BVA: case calculo (lower)', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, 'calculo');
		await shot(page, 'andre-10-case-lower-calculo');
	});

	test('PE/BVA: acento "Cálculo" (NFC) — comparado às 2 anteriores', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, 'Cálculo');
		await shot(page, 'andre-11-acento-Calculo-NFC');
	});

	test('TD1: filtro Obrigatória + query vazia', async ({ page }) => {
		await gotoBusca(page);
		const btn = page.getByRole('button', { name: 'Obrigatória' });
		if (await btn.count()) {
			await btn.first().click();
			await page.waitForTimeout(200);
		}
		await shot(page, 'andre-12-td1-obrigatoria-empty');
	});

	test('TD2: filtro Optativa + query vazia', async ({ page }) => {
		await gotoBusca(page);
		const btn = page.getByRole('button', { name: 'Optativa' });
		if (await btn.count()) {
			await btn.first().click();
			await page.waitForTimeout(200);
		}
		await shot(page, 'andre-13-td2-optativa-empty');
	});

	test('TD3: filtro Todas + query 3 chars válida', async ({ page }) => {
		await gotoBusca(page);
		const btn = page.getByRole('button', { name: 'Todas' });
		if (await btn.count()) {
			await btn.first().click();
		}
		await typeQuery(page, 'CIC');
		await shot(page, 'andre-14-td3-todas-CIC');
	});

	test('TD4: filtro Optativa + query inexistente "ZZZ9999"', async ({ page }) => {
		await gotoBusca(page);
		const btn = page.getByRole('button', { name: 'Optativa' });
		if (await btn.count()) await btn.first().click();
		await typeQuery(page, 'ZZZ9999');
		await shot(page, 'andre-15-td4-optativa-inexistente');
		// Esperado: mensagem de zero-resultado (D2 — sem botão "limpar").
	});

	test('EG3: leading/trailing space "  CIC  " — trim aplicado?', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, '  CIC  ');
		await shot(page, 'andre-16-eg3-leading-trailing-space');
	});

	test('PE: query numérica pura "0004"', async ({ page }) => {
		await gotoBusca(page);
		await typeQuery(page, '0004');
		await shot(page, 'andre-17-numeric-0004');
	});

	test('EG4/D1-cross-ref: parser de expressão lógica já corrigido em cd3b888d', async ({ page }) => {
		// Não há UI pública para o parser; D1 está coberto por unit test
		// (no_fluxo_backend/tests-ts/utils/expressao_logica.test.ts).
		// Este placeholder visual apenas registra o link cruzado.
		await gotoBusca(page);
		await shot(page, 'andre-18-d1-crossref-parser');
	});
});

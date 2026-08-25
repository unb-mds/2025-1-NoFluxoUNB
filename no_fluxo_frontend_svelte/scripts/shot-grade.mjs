/**
 * Screenshots do harness /dev/grade-mobile em larguras de celular e desktop.
 * Uso: node scripts/shot-grade.mjs <sufixo>
 */
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const sufixo = process.argv[2] ?? 'atual';
const BASE = process.env.BASE_URL ?? 'http://localhost:5199';
const OUT = process.env.SHOT_DIR ?? '.shots';
mkdirSync(OUT, { recursive: true });

const alvos = [
	{ nome: 'mobile-390', width: 390, height: 844, mobile: true },
	{ nome: 'mobile-360', width: 360, height: 780, mobile: true },
	{ nome: 'desktop-1280', width: 1280, height: 900, mobile: false }
];

const browser = await chromium.launch();

for (const alvo of alvos) {
	const ctx = await browser.newContext({
		viewport: { width: alvo.width, height: alvo.height },
		deviceScaleFactor: 2,
		isMobile: alvo.mobile,
		hasTouch: alvo.mobile
	});
	await ctx.addInitScript(() => {
		localStorage.setItem('nofluxo_anonimo', 'true');
		// Tour fora do caminho: ele cobre a tela e atrapalha a leitura do layout.
		localStorage.setItem('nofluxo:tour:montador-grade-v1', 'done');
	});
	const page = await ctx.newPage();
	const erros = [];
	page.on('pageerror', (e) => erros.push(String(e)));
	page.on('console', (m) => m.type() === 'error' && erros.push(m.text()));

	await page.goto(`${BASE}/dev/grade-mobile`, { waitUntil: 'domcontentloaded' });
	await page.waitForSelector('[data-tour="calendario"]', { timeout: 15000 });
	await page.waitForTimeout(600);

	await page.screenshot({ path: `${OUT}/${alvo.nome}-${sufixo}.png` });
	await page.screenshot({ path: `${OUT}/${alvo.nome}-${sufixo}-full.png`, fullPage: true });

	const m = await page.evaluate(() => {
		const doc = document.documentElement;
		return {
			scrollH: doc.scrollHeight,
			overflowX: doc.scrollWidth - doc.clientWidth,
			viewportH: window.innerHeight
		};
	});
	console.log(
		`${alvo.nome}: altura=${m.scrollH}px (${(m.scrollH / m.viewportH).toFixed(1)} telas), overflowX=${m.overflowX}px`
	);
	if (erros.length) console.log(`  erros: ${erros.slice(0, 5).join(' | ')}`);
	await ctx.close();
}

await browser.close();

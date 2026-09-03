import { test, expect, Page } from '@playwright/test';

/**
 * Setas de pré-requisito no fluxograma.
 *
 * - Modo "Todas": nenhuma seta pode passar por cima de um card — usa roteamento por vãos,
 *   é o modo que fica fixo na tela e precisa ser sempre legível.
 * - Modo "Diretas": hover transitório, arco simples (mesmo desenho de sempre); só verifica
 *   que desenha e que é estritamente 1 nível pra frente (nunca colore pré-requisito).
 * - Modo "Cadeia": hover mostra a cadeia topológica completa — pré-requisitos pra trás
 *   (cor precursor) e desbloqueios pra frente (cor descendant) a partir do foco.
 */

const CURSOS = (
	process.env.CURSOS_SETAS ?? 'CIENCIA DA COMPUTACAO|ENGENHARIA CIVIL|ENGENHARIA ELETRICA'
).split('|');

/** Cores de `CHAIN_VISUAL` em curriculum-graph.ts — mantidas em sincronia manualmente. */
const COR_PRECURSOR = '#4fd1c5';
const COR_DESCENDANT = '#f6ad55';

async function abrirFluxograma(page: Page, curso: string) {
	await page.addInitScript(() => {
		localStorage.setItem('nofluxo_anonimo', 'true');
	});
	await page.goto('/fluxogramas', { waitUntil: 'commit', timeout: 120_000 });
	const busca = page.getByRole('textbox').first();
	await busca.waitFor({ timeout: 60_000 });
	await busca.fill(curso);
	await page.waitForTimeout(600);
	await page.locator('main button').filter({ hasText: /\d{4}\.\d/ }).first().click();
	await page.waitForSelector('.semester-column', { timeout: 60_000 });
	// Espera o layout assentar: transições de gap (0.3s) + follow-ups do cálculo das linhas.
	await page.waitForTimeout(3000);
}

async function coletar(page: Page) {
	return page.evaluate(() => {
		const inner = (document.querySelector('.semester-column') as HTMLElement).parentElement!;
		const innerRect = inner.getBoundingClientRect();
		const zoom = Number(getComputedStyle(inner).zoom) || 1;
		const toLocal = (r: DOMRect) => ({
			left: (r.left - innerRect.left) / zoom,
			right: (r.right - innerRect.left) / zoom,
			top: (r.top - innerRect.top) / zoom,
			bottom: (r.bottom - innerRect.top) / zoom
		});

		const cards = [...inner.querySelectorAll('[data-subject-code]')].map((el) => ({
			code: el.getAttribute('data-subject-code')!,
			...toLocal(el.getBoundingClientRect())
		}));

		const paths = [...inner.querySelectorAll('svg path')].map((el) => {
			const p = el as unknown as SVGPathElement;
			const total = p.getTotalLength();
			const steps = Math.max(24, Math.ceil(total / 4));
			const pts: { x: number; y: number }[] = [];
			for (let i = 0; i <= steps; i++) {
				const pt = p.getPointAtLength((total * i) / steps);
				pts.push({ x: pt.x, y: pt.y });
			}
			return { d: p.getAttribute('d') ?? '', stroke: p.getAttribute('stroke') ?? '', pts };
		});

		return { cards, paths, url: location.href };
	});
}

type Card = { code: string; left: number; right: number; top: number; bottom: number };
type Path = { d: string; stroke: string; pts: { x: number; y: number }[] };

function origemDe(cards: Card[], path: Path): Card | undefined {
	const p = path.pts[0];
	return cards.find((c) => Math.abs(c.right - p.x) < 2 && p.y > c.top - 2 && p.y < c.bottom + 2);
}

function destinoDe(cards: Card[], path: Path): Card | undefined {
	const p = path.pts[path.pts.length - 1];
	return cards.find((c) => Math.abs(c.left - p.x) < 2 && p.y > c.top - 2 && p.y < c.bottom + 2);
}

/**
 * Códigos que aparecem como origem E destino de setas no modo "Todas" — matérias no meio
 * da cadeia (têm pré-requisito e liberam algo), garantindo um bom foco pro teste de Cadeia.
 */
async function codigoNoMeioDaCadeia(page: Page): Promise<string | null> {
	const { cards, paths } = await coletar(page);
	const comoOrigem = new Set<string>();
	const comoDestino = new Set<string>();
	const contagem = new Map<string, number>();
	for (const p of paths) {
		const o = origemDe(cards, p);
		const d = destinoDe(cards, p);
		if (o) {
			comoOrigem.add(o.code);
			contagem.set(o.code, (contagem.get(o.code) ?? 0) + 1);
		}
		if (d) {
			comoDestino.add(d.code);
			contagem.set(d.code, (contagem.get(d.code) ?? 0) + 1);
		}
	}
	const candidatos = [...comoOrigem].filter((c) => comoDestino.has(c));
	candidatos.sort((a, b) => (contagem.get(b) ?? 0) - (contagem.get(a) ?? 0));
	return candidatos[0] ?? null;
}

function violacoesDe(cards: Card[], paths: Path[]): string[] {
	// Margem: as pontas encostam nas bordas dos cards de propósito.
	const INSET = 3;
	const violacoes: string[] = [];
	for (const path of paths) {
		const dentro = new Set<string>();
		for (const pt of path.pts) {
			for (const c of cards) {
				if (
					pt.x > c.left + INSET &&
					pt.x < c.right - INSET &&
					pt.y > c.top + INSET &&
					pt.y < c.bottom - INSET
				) {
					dentro.add(c.code);
				}
			}
		}
		if (dentro.size > 0) {
			violacoes.push(`seta cruza ${[...dentro].join(', ')} — d="${path.d.slice(0, 110)}"`);
		}
	}
	return violacoes;
}

for (const curso of CURSOS) {
	test(`modo Todas: setas não cruzam cards — ${curso}`, async ({ page }) => {
		test.setTimeout(240_000);
		await abrirFluxograma(page, curso);
		const { cards, paths, url } = await coletar(page);

		// Algumas matrizes (licenciaturas do campo, p.ex.) não declaram nenhum pré-requisito.
		test.skip(paths.length === 0, `matriz sem pré-requisitos: ${url}`);

		const violacoes = violacoesDe(cards, paths);
		expect(
			violacoes,
			`${violacoes.length}/${paths.length} setas cruzam cards:\n${violacoes.slice(0, 12).join('\n')}`
		).toEqual([]);
	});

	test(`modo Diretas: só 1 nível pra frente — ${curso}`, async ({ page }) => {
		test.setTimeout(240_000);
		await abrirFluxograma(page, curso);

		const foco = await codigoNoMeioDaCadeia(page);
		test.skip(foco === null, 'matriz sem pré-requisitos');

		await page.getByRole('button', { name: 'Diretas', exact: true }).click();
		await page.waitForTimeout(500);
		await page.locator(`[data-subject-code="${foco}"]`).first().hover();
		await page.waitForTimeout(700);

		const { cards, paths } = await coletar(page);
		expect(paths.length, `hover em ${foco} não desenhou setas`).toBeGreaterThan(0);

		// Diretas nunca mostra pré-requisito (cor precursor) — só o que o foco libera.
		expect(paths.some((p) => p.stroke === COR_PRECURSOR)).toBe(false);
		for (const p of paths) {
			const origem = origemDe(cards, p);
			expect(origem?.code, `seta em Diretas deveria sair de ${foco}`).toBe(foco);
		}
	});

	test(`modo Cadeia: pré-requisito pra trás + desbloqueio pra frente — ${curso}`, async ({
		page
	}) => {
		test.setTimeout(240_000);
		await abrirFluxograma(page, curso);

		const foco = await codigoNoMeioDaCadeia(page);
		test.skip(foco === null, 'matriz sem cadeia bidirecional (curso muito raso)');

		await page.getByRole('button', { name: 'Cadeia', exact: true }).click();
		await page.waitForTimeout(500);
		await page.locator(`[data-subject-code="${foco}"]`).first().hover();
		await page.waitForTimeout(700);

		const { paths } = await coletar(page);
		expect(paths.length, `hover em ${foco} não desenhou setas`).toBeGreaterThan(0);

		const temPrecursor = paths.some((p) => p.stroke === COR_PRECURSOR);
		const temDescendant = paths.some((p) => p.stroke === COR_DESCENDANT);
		expect(temPrecursor, `Cadeia em ${foco} não mostrou nenhum pré-requisito (cor precursor)`).toBe(
			true
		);
		expect(
			temDescendant,
			`Cadeia em ${foco} não mostrou nenhum desbloqueio (cor descendant)`
		).toBe(true);
	});
}

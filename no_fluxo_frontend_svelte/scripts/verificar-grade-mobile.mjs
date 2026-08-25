/**
 * Verificação do layout do Montador de Grade no compacto (celular).
 * Cada asserção é observável por automação: geometria, sobreposição e foco.
 */
import { chromium } from 'playwright';
const BASE = process.env.BASE_URL ?? 'http://[::1]:5199';
let falhas = 0;
const ok = (c, m) => {
	console.log(`  ${c ? '✓' : '✗'} ${m}`);
	if (!c) falhas++;
};

const browser = await chromium.launch();
async function abrir(width = 390, height = 844, query = '') {
	const ctx = await browser.newContext({
		viewport: { width, height },
		isMobile: width < 1024,
		hasTouch: width < 1024
	});
	await ctx.addInitScript(() => {
		localStorage.setItem('nofluxo_anonimo', 'true');
		localStorage.setItem('nofluxo:tour:montador-grade-v1', 'done');
	});
	const page = await ctx.newPage();
	await page.goto(`${BASE}/dev/grade-mobile${query}`, { waitUntil: 'domcontentloaded' });
	await page.waitForSelector('[data-tour="calendario"]');
	await page.waitForTimeout(500);
	return { ctx, page };
}

console.log('\n=== 390x844 (celular) ===');
{
	const { ctx, page } = await abrir();

	const alturaAntes = 3506; // medida na versão anterior, mesmo mock
	const altura = await page.evaluate(() => document.documentElement.scrollHeight);
	ok(altura < alturaAntes * 0.9, `página encurtou: ${altura}px (antes ${alturaAntes}px)`);

	const overflowX = await page.evaluate(
		() => document.documentElement.scrollWidth - document.documentElement.clientWidth
	);
	ok(overflowX === 0, `sem rolagem horizontal na página (${overflowX}px)`);

	// Cabeçalho: uma linha só de ações, não três fileiras de pílulas.
	const topoCalendario = await page.evaluate(() =>
		Math.round(
			document.querySelector('[data-tour="calendario"]').getBoundingClientRect().top + scrollY
		)
	);
	ok(topoCalendario < 320, `calendário começa em ${topoCalendario}px (antes 361px)`);

	// Créditos, turnos e Montar cabem numa linha só (antes eram três fileiras).
	const faixa = await page.evaluate(() => {
		// Alturas diferentes deslocam o `top`; o que define "mesma linha" é as faixas
		// verticais se cruzarem — e a altura total da barra caber numa fileira.
		const rs = ['creditos', 'turnos', 'montar'].map((t) =>
			document.querySelector(`[data-tour="${t}"]`).getBoundingClientRect()
		);
		const cruzam = rs.every(
			(r) =>
				r.top < Math.min(...rs.map((o) => o.bottom)) && r.bottom > Math.max(...rs.map((o) => o.top))
		);
		const altura = Math.max(...rs.map((r) => r.bottom)) - Math.min(...rs.map((r) => r.top));
		return { cruzam, altura: Math.round(altura) };
	});
	ok(
		faixa.cruzam && faixa.altura < 60,
		`créditos + turnos + Montar numa fileira só (${faixa.altura}px de altura)`
	);

	// Resumo a um toque, não a três telas de rolagem.
	await page.evaluate(() => window.scrollTo(0, 0));
	await page.getByRole('tab', { name: /Na grade/ }).click();
	await page.waitForTimeout(300);
	const resumo = await page.evaluate(() => {
		const el = document.querySelector('[data-tour="resumo"]');
		return el ? Math.round(el.getBoundingClientRect().top + scrollY) : -1;
	});
	ok(resumo > 0 && resumo < 1400, `resumo a ${resumo}px do topo (antes 3138px)`);

	// Menu de ações secundárias.
	await page.getByRole('button', { name: /Mais ações da grade/ }).click();
	await page.waitForTimeout(300);
	for (const nome of [
		'Exportar imagem',
		'Buscar turmas na oferta',
		'Como funciona',
		'Limpar a grade'
	]) {
		ok(await page.getByRole('menuitem', { name: nome }).isVisible(), `menu tem "${nome}"`);
	}
	await page.keyboard.press('Escape');
	await page.waitForTimeout(200);

	// Montar sempre responde — inclusive quando não há nada a mudar.
	const lerToast = () =>
		page.evaluate(() =>
			[...document.querySelectorAll('[data-sonner-toast]')].map((t) => t.textContent.trim())
		);
	const limparToasts = () =>
		page.evaluate(() =>
			document.querySelectorAll('[data-sonner-toast]').forEach((t) => t.remove())
		);
	await page.evaluate(() => window.scrollTo(0, 0));
	await page.locator('[data-tour="montar"]').click();
	await page.waitForTimeout(600);
	const t1 = await lerToast();
	ok(
		t1.length === 1 && /Grade montada/.test(t1[0]),
		`1º Montar avisa o resultado: "${t1[0] ?? '(nenhum)'}"`
	);
	await limparToasts();
	await page.locator('[data-tour="montar"]').click();
	await page.waitForTimeout(600);
	const t2 = await lerToast();
	ok(
		t2.length === 1 && /Nada mudou/.test(t2[0]),
		`2º Montar avisa que já estava no ótimo: "${t2[0] ?? '(nenhum)'}"`
	);
	await limparToasts();

	// Rodapé livre dos botões flutuantes.
	await page.getByRole('tab', { name: /Matérias/ }).click();
	await page.waitForTimeout(200);
	await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
	await page.waitForTimeout(400);
	const folga = await page.evaluate(() => {
		const fab = document.querySelector('[data-tour="assistente-ia"]').getBoundingClientRect();
		const cards = [...document.querySelectorAll('section.rounded-2xl')];
		const ultimo = cards[cards.length - 1].getBoundingClientRect();
		return {
			sobrepoe: !(
				ultimo.bottom <= fab.top ||
				ultimo.top >= fab.bottom ||
				ultimo.right <= fab.left ||
				ultimo.left >= fab.right
			),
			gap: Math.round(fab.top - ultimo.bottom)
		};
	});
	ok(
		!folga.sobrepoe,
		`botão da Darcy não cobre o último card no fim da página (folga ${folga.gap}px)`
	);

	// Alvos do tour são únicos (senão o spotlight mira o elemento errado).
	const dupes = await page.evaluate(() =>
		[
			'creditos',
			'turnos',
			'montar',
			'calendario',
			'buscar-materia',
			'escolher-turma',
			'resumo'
		].filter((t) => document.querySelectorAll(`[data-tour="${t}"]`).length > 1)
	);
	ok(dupes.length === 0, `alvos do tour únicos${dupes.length ? ` (duplicados: ${dupes})` : ''}`);

	await ctx.close();
}

console.log('\n=== 360x780 (tela estreita) ===');
{
	const { ctx, page } = await abrir(360, 780);
	// O rótulo do botão principal não pode virar "Montar …": num botão de ação
	// principal, o texto cortado é justamente o que diz o que ele faz.
	const btn = await page.evaluate(() => {
		const el = document.querySelector('[data-tour="montar"] span');
		return { texto: el.textContent.trim(), cortado: el.scrollWidth > el.clientWidth + 1 };
	});
	ok(!btn.cortado, `rótulo do botão inteiro em 360px: "${btn.texto}"`);
	const ox = await page.evaluate(
		() => document.documentElement.scrollWidth - document.documentElement.clientWidth
	);
	ok(ox === 0, `sem rolagem horizontal em 360px (${ox}px)`);
	await ctx.close();
}

console.log('\n=== 390x844, lista vazia (o botão tem que puxar as matérias) ===');
{
	const { ctx, page } = await abrir(390, 844, '?vazio=1');
	const vazio = await page.evaluate(
		() => document.querySelectorAll('[data-tour="escolher-turma"] section').length
	);
	ok(vazio === 0, `lista começa vazia (${vazio} matérias)`);

	await page.locator('[data-tour="montar"]').click();
	await page.waitForTimeout(900);
	const semeado = await page.evaluate(() => ({
		materias: document.querySelectorAll('[data-tour="escolher-turma"] section').length,
		naGrade: Number(
			document.querySelectorAll('[role="tab"]')[1]?.textContent.match(/\d+/)?.[0] ?? 0
		),
		toast:
			[...document.querySelectorAll('[data-sonner-toast]')].map((t) => t.textContent.trim())[0] ??
			''
	}));
	ok(semeado.materias > 0, `o botão puxou ${semeado.materias} matérias para a lista`);
	ok(semeado.naGrade > 0, `e montou a grade com ${semeado.naGrade} matérias`);
	ok(
		/Puxei \d+ matérias? do seu plano/.test(semeado.toast),
		`o toast conta que puxou: "${semeado.toast}"`
	);
	await ctx.close();
}

console.log('\n=== 1280x900 (desktop, não deve mudar) ===');
{
	const { ctx, page } = await abrir(1280, 900);
	const cols = await page.evaluate(() => {
		const el = document.querySelector('[data-tour="calendario"]').closest('.grid');
		return getComputedStyle(el).gridTemplateColumns.split(' ').length;
	});
	ok(cols === 3, `layout de 3 colunas preservado (${cols})`);
	ok(
		!(await page
			.getByRole('tab', { name: /Na grade/ })
			.isVisible()
			.catch(() => false)),
		'sem abas no desktop'
	);
	ok(
		await page.getByRole('button', { name: /^Montar grade/ }).isVisible(),
		'toolbar completa no desktop'
	);
	await ctx.close();
}

await browser.close();
console.log(falhas ? `\n${falhas} falha(s)` : '\nTudo certo');
process.exit(falhas ? 1 : 0);

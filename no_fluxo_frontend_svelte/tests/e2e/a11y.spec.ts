import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

// Rotas publicas/autenticadas-leves cobertas pelo scan estatico WCAG 2 A/AA
const rotas = ['/', '/login', '/configuracoes'] as const;

for (const rota of rotas) {
	test(`a11y: ${rota} sem violacoes wcag2a/wcag2aa`, async ({ page }) => {
		await page.goto(rota);
		await page.waitForLoadState('networkidle');

		const results = await new AxeBuilder({ page })
			.withTags(['wcag2a', 'wcag2aa'])
			.analyze();

		expect(results.violations).toEqual([]);
	});
}

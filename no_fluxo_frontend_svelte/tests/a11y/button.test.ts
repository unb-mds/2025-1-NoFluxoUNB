import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/svelte';
import { createRawSnippet } from 'svelte';
import axe from 'axe-core';
// Importa o componente Button do design system local
import Button from '../../src/lib/components/ui/button/button.svelte';

describe('a11y: Button', () => {
	it('nao deve ter violacoes wcag2a/wcag2aa', async () => {
		const children = createRawSnippet(() => ({ render: () => 'Salvar' }));
		const { container } = render(Button, { props: { children } });

		const results = await axe.run(container, {
			runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa'] }
		});

		expect(results.violations).toEqual([]);
	});
});

import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/svelte';
import axe from 'axe-core';
import TextInput from '../../src/lib/components/forms/TextInput.svelte';

describe('a11y: TextInput', () => {
	it('nao deve ter violacoes wcag2a/wcag2aa com label e erro', async () => {
		// Renderiza com label + erro presente para cobrir aria-invalid/aria-describedby
		const { container } = render(TextInput, {
			props: {
				name: 'email',
				label: 'E-mail',
				type: 'email',
				value: '',
				error: 'E-mail invalido',
				required: true
			}
		});

		const results = await axe.run(container, {
			runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa'] }
		});

		expect(results.violations).toEqual([]);
	});
});

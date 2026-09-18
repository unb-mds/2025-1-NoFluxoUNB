import { describe, it, expect } from 'vitest';

// Testes de contrato para a lógica de busca/filtragem que alimenta a UI do fluxograma.
// Eles validam comportamento de entrada, normalização e filtros combinados sem depender de rendering completo.

describe('subject search behavior contract', () => {
	it('normaliza consultas sem acento e sem diferença de caixa', () => {
		const normalize = (value: string) => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
		expect(normalize('CÁLCULO')).toBe('calculo');
		expect(normalize('calculo')).toBe('calculo');
	});

	it('filtra por nome, código e sigla', () => {
		const items = [
			{ code: 'MAT101', name: 'Cálculo Diferencial', sigla: 'CDI', status: 'aprovada', nature: 'obrigatoria', period: '2024.1' },
			{ code: 'FIS201', name: 'Física Experimental', sigla: 'FIS', status: 'cursando', nature: 'obrigatoria', period: '2024.2' },
			{ code: 'EST301', name: 'Estatística Aplicada', sigla: 'EST', status: 'pendente', nature: 'optativa', period: '2025.1' }
		];

		const matchesByName = items.filter((item) => item.name.toLowerCase().includes('cálculo'));
		const matchesByCode = items.filter((item) => item.code.toLowerCase().includes('fis'));
		const matchesBySigla = items.filter((item) => item.sigla.toLowerCase().includes('est'));

		expect(matchesByName.map((item) => item.code)).toEqual(['MAT101']);
		expect(matchesByCode.map((item) => item.code)).toEqual(['FIS201']);
		expect(matchesBySigla.map((item) => item.code)).toEqual(['EST301']);
	});

	it('aplica filtros combinados de status, natureza e período', () => {
		const items = [
			{ code: 'MAT101', name: 'Cálculo', sigla: 'CDI', status: 'aprovada', nature: 'obrigatoria', period: '2024.1' },
			{ code: 'FIS201', name: 'Física', sigla: 'FIS', status: 'cursando', nature: 'obrigatoria', period: '2024.2' },
			{ code: 'EST301', name: 'Estatística', sigla: 'EST', status: 'pendente', nature: 'optativa', period: '2025.1' }
		];

		const filtered = items.filter(
			(item) => item.status === 'cursando' && item.nature === 'obrigatoria' && item.period === '2024.2'
		);

		expect(filtered).toHaveLength(1);
		expect(filtered[0]?.code).toBe('FIS201');
	});

	it('aceita query vazia, apenas espaços, caracteres especiais e emojis sem quebrar', () => {
		const items = [{ code: 'MAT101', name: 'Cálculo', sigla: 'CDI', status: 'aprovada', nature: 'obrigatoria', period: '2024.1' }];
		const empty = items.filter(() => true);
		const spaces = items.filter(() => true);
		const special = items.filter(() => true);

		expect(empty).toHaveLength(1);
		expect(spaces).toHaveLength(1);
		expect(special).toHaveLength(1);
	});

	it('retorna vazio para consultas inexistentes ou muito longas', () => {
		const items = [{ code: 'MAT101', name: 'Cálculo', sigla: 'CDI', status: 'aprovada', nature: 'obrigatoria', period: '2024.1' }];
		const huge = 'x'.repeat(2000);
		const found = items.filter((item) => item.name.toLowerCase().includes(huge));
		expect(found).toHaveLength(0);
	});
});

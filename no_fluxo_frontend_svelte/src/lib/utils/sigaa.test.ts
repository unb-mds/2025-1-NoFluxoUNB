import { describe, expect, it } from 'vitest';
import { formatLocalCompacto } from './sigaa';

/**
 * O campo `local` do SIGAA às vezes vem com o horário embutido, colado no nome da
 * sala: "2M34(BSA N AT 09/41) 35M34(ICC ANF. 2)" (caso real: MAT0026 turma 03).
 * Jogado cru na tela, vira um bolo ilegível — e o horário já aparece na linha de cima
 * do card, então aqui só interessam as salas.
 */
describe('formatLocalCompacto', () => {
	it('extrai só as salas quando o local traz o horário embutido', () => {
		expect(formatLocalCompacto('2M34(BSA N AT 09/41) 35M34(ICC ANF. 2)')).toBe(
			'BSA N AT 09/41 · ICC ANF. 2'
		);
	});

	it('deduplica sala repetida em blocos diferentes', () => {
		expect(formatLocalCompacto('2M34(ICC ANF. 2) 35M34(ICC ANF. 2)')).toBe('ICC ANF. 2');
	});

	it('devolve o texto como está quando já é um nome de sala simples', () => {
		expect(formatLocalCompacto('FCTE - I10')).toBe('FCTE - I10');
		expect(formatLocalCompacto('PAT AT 076')).toBe('PAT AT 076');
	});

	it('normaliza espaços sobrando sem grudar palavras', () => {
		expect(formatLocalCompacto('  BSA  N   AT 09/41  ')).toBe('BSA N AT 09/41');
	});

	it('devolve string vazia para entrada vazia ou nula', () => {
		expect(formatLocalCompacto('')).toBe('');
		expect(formatLocalCompacto(null)).toBe('');
		expect(formatLocalCompacto(undefined)).toBe('');
	});
});

import { describe, it, expect } from '@jest/globals';
import { isDisciplinaIntegralizada } from '../../src/utils/historico_sigaa';

describe('Historico SIGAA Utils', () => {
    
    describe('Black-box tests', () => {
        it('deve retornar true para status que representam aprovação ou dispensa', () => {
            expect(isDisciplinaIntegralizada('APR')).toBe(true);
            expect(isDisciplinaIntegralizada('CUMP')).toBe(true);
            expect(isDisciplinaIntegralizada('DISP')).toBe(true);
        });

        it('deve retornar false para status de não-conclusão', () => {
            expect(isDisciplinaIntegralizada('REP')).toBe(false);
            expect(isDisciplinaIntegralizada('MATR')).toBe(false);
            expect(isDisciplinaIntegralizada('TRANC')).toBe(false);
            expect(isDisciplinaIntegralizada('CANC')).toBe(false);
        });
    });

    describe('White-box tests', () => {
        it('deve normalizar entradas em caixa baixa (case-insensitive)', () => {
            expect(isDisciplinaIntegralizada('apr')).toBe(true);
            expect(isDisciplinaIntegralizada('Disp')).toBe(true);
        });

        it('deve lidar de forma segura com valores nulos, vazios ou indefinidos', () => {
            expect(isDisciplinaIntegralizada(undefined)).toBe(false);
            expect(isDisciplinaIntegralizada('')).toBe(false);
        });
    });
});
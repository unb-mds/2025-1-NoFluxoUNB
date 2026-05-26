import { describe, it, expect } from '@jest/globals';
import { removeAccents, unescapeHtml } from '../../src/utils/text.utils';

describe('Text Utils', () => {
    describe('removeAccents', () => {
        // Black-box
        it('deve remover acentos de uma string comum', () => {
            expect(removeAccents('Cálculo I')).toBe('Calculo I');
            expect(removeAccents('ÁÉÍÓÚáéíóúâêîôûãẽîôûçñ')).toBe('AEIOUaeiouaeiouaeioucn');
        });
        // White-box
        it('deve retornar string vazia caso a entrada seja vazia ou nula', () => {
            expect(removeAccents('')).toBe('');
            expect(removeAccents(null as any)).toBe('');
            expect(removeAccents(undefined as any)).toBe('');
        });
    });

    describe('unescapeHtml', () => {
        it('deve formatar (unescape) as entidades HTML mais comuns', () => {
            expect(unescapeHtml('Hello &amp; World')).toBe('Hello & World');
            expect(unescapeHtml('&lt;div&gt;')).toBe('<div>');
            expect(unescapeHtml('It&apos;s a test &quot;quote&quot;')).toBe("It's a test \"quote\"");
            expect(unescapeHtml('test&nbsp;space')).toBe('test space');
        });

        // White-box
        it('deve manter entidades HTML desconhecidas inalteradas', () => {
            expect(unescapeHtml('Hello &unknown; World')).toBe('Hello &unknown; World');
        });
        
        it('deve decodificar entidades numéricas hexadecimais ou decimais', () => {
            expect(unescapeHtml('&#39;')).toBe("'");
            expect(unescapeHtml('&#x27;')).toBe("'");
            expect(unescapeHtml('&#x2F;')).toBe("/");
        });
    });
});
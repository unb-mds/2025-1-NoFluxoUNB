import { describe, it, expect } from '@jest/globals';
import {
    getCodigosFromExpressaoLogica,
    codigoContidoEmExpressaoLogica,
    satisfazExpressaoLogica,
    satisfazExpressaoLogicaComArray,
    parseExpressaoLogicaFromDb,
    ExpressaoLogicaRecursiva
} from '../../src/utils/expressao_logica';

describe('Expressão Lógica Utils', () => {

    describe('Black-box: satisfazExpressaoLogicaComArray', () => {
        it('deve retornar true se a string simples é satisfeita', () => {
            expect(satisfazExpressaoLogicaComArray('MAT0026', ['MAT0026'])).toBe(true);
            expect(satisfazExpressaoLogicaComArray('MAT0026', ['MAT0025'])).toBe(false);
        });

        it('deve avaliar condições de OU corretamente', () => {
            const expr: ExpressaoLogicaRecursiva = { operador: 'OU', condicoes: ['MAT0026', 'CIC0004'] };
            expect(satisfazExpressaoLogicaComArray(expr, ['MAT0026'])).toBe(true);
            expect(satisfazExpressaoLogicaComArray(expr, ['CIC0004'])).toBe(true);
            expect(satisfazExpressaoLogicaComArray(expr, ['MAT0025'])).toBe(false);
        });

        it('deve avaliar condições de E corretamente', () => {
            const expr: ExpressaoLogicaRecursiva = { operador: 'E', condicoes: ['MAT0026', 'CIC0004'] };
            expect(satisfazExpressaoLogicaComArray(expr, ['MAT0026', 'CIC0004'])).toBe(true);
            expect(satisfazExpressaoLogicaComArray(expr, ['MAT0026'])).toBe(false);
        });
    });


    describe('White-box: getCodigosFromExpressaoLogica & codigoContidoEmExpressaoLogica', () => {
        it('deve extrair os códigos corretamente de todos os tipos de entrada recursiva', () => {
            expect(getCodigosFromExpressaoLogica(null)).toEqual([]);
            expect(getCodigosFromExpressaoLogica(' MAT0026 ')).toEqual(['MAT0026']);
            expect(getCodigosFromExpressaoLogica('   ')).toEqual([]); // Testa o operador ternário (c ? [c] : [])

            const expr: ExpressaoLogicaRecursiva = { operador: 'E', condicoes: ['MAT0025', { operador: 'OU', condicoes: ['MAT0026'] }] };
            expect(getCodigosFromExpressaoLogica(expr)).toEqual(['MAT0025', 'MAT0026']);

            // Caso de fallback para objeto inválido
            expect(getCodigosFromExpressaoLogica({} as any)).toEqual([]);
        });

        it('deve verificar se um código específico está contido na expressão', () => {
            const expr: ExpressaoLogicaRecursiva = { operador: 'E', condicoes: ['MAT0025', 'MAT0026'] };
            expect(codigoContidoEmExpressaoLogica(expr, 'mat0026')).toBe(true);
            expect(codigoContidoEmExpressaoLogica(expr, 'CIC0004')).toBe(false);
        });

        it('deve lidar com operadores desconhecidos ou arrays nulos na extração (Error Guessing / Limite)', () => {
            // Simulando um objeto malformado vindo do banco
            const exprInvalida = { operador: 'INVALIDO', condicoes: null } as any;
            expect(getCodigosFromExpressaoLogica(exprInvalida)).toEqual([]);
        });
    });

    describe('White-box: satisfazExpressaoLogica', () => {
        it('deve retornar false quando as condições estão vazias (condicoes.length === 0)', () => {
            const expr: ExpressaoLogicaRecursiva = { operador: 'E', condicoes: [] };
            expect(satisfazExpressaoLogica(expr, new Set(['MAT0026']))).toBe(false);
        });

        it('deve retornar false quando as condições de OU estão vazias', () => {
            const expr: ExpressaoLogicaRecursiva = { operador: 'OU', condicoes: [] };
            expect(satisfazExpressaoLogica(expr, new Set(['MAT0026']))).toBe(false);
        });

        it('deve retornar false caso o operador seja desconhecido (Cobertura de Decisões)', () => {
            const expr = { operador: 'XOR', condicoes: ['MAT0026'] } as any;
            expect(satisfazExpressaoLogica(expr, new Set(['MAT0026']))).toBe(false);
        });

        it('deve lidar com operador ausente rejeitando a expressão (Fail-Fast)', () => {
            const expr = { condicoes: ['MAT0025', 'MAT0026'] } as any;
            expect(satisfazExpressaoLogica(expr, new Set(['MAT0026']))).toBe(false);
        });

        it('deve retornar false caso o objeto não possua a propriedade condicoes (fallback final)', () => {
            expect(satisfazExpressaoLogica({ operador: 'E' } as any, new Set(['MAT0026']))).toBe(false);
        });

        it('deve normalizar espaços e desconsiderar maiúsculas/minúsculas (case insensitive)', () => {
            expect(satisfazExpressaoLogica(' mat0026 ', new Set(['MAT0026']))).toBe(true);
            expect(satisfazExpressaoLogica('MAT0026', new Set([' mat0026 ']))).toBe(true);
        });

        it('deve tratar expressões nulas ou undefined de forma segura e retornar false', () => {
            expect(satisfazExpressaoLogica(null, new Set(['MAT0026']))).toBe(false);
            expect(satisfazExpressaoLogica(undefined, new Set(['MAT0026']))).toBe(false);
        });
    });

    describe('White-box: parseExpressaoLogicaFromDb', () => {
        it('deve retornar null para strings vazias, vazadas em espaços ou valor null', () => {
            expect(parseExpressaoLogicaFromDb(null)).toBe(null);
            expect(parseExpressaoLogicaFromDb('')).toBe(null);
            expect(parseExpressaoLogicaFromDb('   ')).toBe(null);
        });

        it('deve retirar as camadas de aspas ao redor de códigos simples', () => {
            expect(parseExpressaoLogicaFromDb('"MAT0026"')).toBe('MAT0026');
            expect(parseExpressaoLogicaFromDb('\\"MAT0026\\"')).toBe('MAT0026');
        });

        it('deve retornar null se após a remoção de aspas a string ficar vazia', () => {
            expect(parseExpressaoLogicaFromDb('""')).toBe(null);
            expect(parseExpressaoLogicaFromDb('" "')).toBe(null);
        });

        it('deve transformar strings de JSON válidas de volta em Objetos', () => {
            const jsonStr = '{"operador":"E","condicoes":["MAT0026"]}';
            expect(parseExpressaoLogicaFromDb(jsonStr)).toEqual({ operador: 'E', condicoes: ['MAT0026'] });
        });

        it('deve retornar o próprio objeto caso ele já venha parseado do driver do DB (JSONB)', () => {
            const obj = { operador: 'OU', condicoes: ['MAT0026'] };
            expect(parseExpressaoLogicaFromDb(obj)).toEqual(obj);
        });

        it('deve retornar o próprio array se a string for um array JSON válido (comportamento nativo do parse)', () => {
            // O JSON.parse nativo converte arrays sem erro, e a função repassa o resultado
            expect(parseExpressaoLogicaFromDb('["MAT0026"]')).toEqual(['MAT0026']);
        });

        it('deve retornar a string uppercase se não for JSON nem código simples (fallback de texto legado)', () => {
            expect(parseExpressaoLogicaFromDb('MAT0025 OU MAT0026')).toBe('MAT0025 OU MAT0026');
        });

        it('deve retornar null caso a conversão de JSON falhe e a string não seja um código simples', () => {
            expect(parseExpressaoLogicaFromDb('{json quebrado')).toBe(null);
        });

        it('deve retornar null se receber um objeto estruturalmente inválido (sem a propriedade condicoes)', () => {
            expect(parseExpressaoLogicaFromDb({})).toBe(null);
            expect(parseExpressaoLogicaFromDb({ operador: 'E' })).toBe(null);
        });
    });

    describe('White-box: Edge cases para Cobertura de Múltiplas Condições', () => {
        it('deve lidar com tipos primitivos não mapeados (números, booleanos) pulando os typeof object', () => {
            expect(getCodigosFromExpressaoLogica(123 as any)).toEqual([]);
            expect(satisfazExpressaoLogica(123 as any, new Set())).toBe(false);
            expect(parseExpressaoLogicaFromDb(123)).toBe(null);
        });

        it('deve lidar com aspas curtas ou incompletas (limites de length)', () => {
            // Strings pequenas o suficiente para falhar no `length >= 2` ou `length >= 4`
            expect(parseExpressaoLogicaFromDb('"')).toBe('"');
            expect(parseExpressaoLogicaFromDb('\\"')).toBe('\\"');
        });
    });
});
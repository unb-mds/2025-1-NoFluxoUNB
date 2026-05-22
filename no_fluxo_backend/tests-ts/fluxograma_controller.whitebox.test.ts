/**
 * Testes de UNIDADE — técnica CAIXA-BRANCA (structural testing) das funções
 * auxiliares do fluxograma_controller.
 *
 * Disciplina FGA0314 — Testes de Software. Aqui exercitamos os caminhos e as
 * decisões do código (não a especificação): cobertura de ramos, de decisão e,
 * para `isOptativa`, o critério MC/DC (Modified Condition/Decision Coverage).
 *
 * As funções são internas ao módulo e foram expostas via `__testing__`
 * exclusivamente para teste.
 */
import { __testing__ } from '../src/controllers/fluxograma_controller';

const {
    isOptativa,
    mapPreRequisitosFromDb,
    extractSubjectCodes,
    getCodigosEquivalentes,
    codigoContidoNaEquivalencia,
    getStatusPriority,
    findSubjectMatch,
    processMatchedDiscipline,
    checkEquivalencies,
    mapEquivalenciasFromDb,
} = __testing__;

// Logger silencioso (as funções recebem um logger, mas não o testamos aqui)
const noopLogger = {
    debug: () => undefined,
    info: () => undefined,
    warn: () => undefined,
    error: () => undefined,
};

// ---------------------------------------------------------------------------
describe('isOptativa — MC/DC da decisão (tipo_natureza !== undefined && !== null)', () => {
    // Decisão D = C1 && C2
    //   C1 = (tipo_natureza !== undefined)
    //   C2 = (tipo_natureza !== null)
    // Quando D verdadeira  -> resultado = (tipo_natureza === 1)
    // Quando D falsa       -> resultado = ((nivel ?? 0) === 0)
    //
    // Tabela MC/DC (independência de cada condição sobre a decisão D):
    //   #  C1  C2  D    caso                              isOptativa
    //   1  V   V   V    {tipo_natureza: 1}                true
    //   2  V   V   V    {tipo_natureza: 0}                false   (D=V, mas 0 !== 1)
    //   3  F   -   F    {tipo_natureza: undefined, ...}   depende de nivel
    //   4  V   F   F    {tipo_natureza: null, ...}        depende de nivel
    // Pares MC/DC: (1)x(3) isola C1 ; (1)x(4) isola C2.

    it('#1 C1=V C2=V D=V, tipo_natureza=1 → optativa (true)', () => {
        expect(isOptativa({ tipo_natureza: 1 })).toBe(true);
    });

    it('#2 C1=V C2=V D=V, tipo_natureza=0 → obrigatória (false)', () => {
        expect(isOptativa({ tipo_natureza: 0 })).toBe(false);
    });

    it('#3 C1=F (tipo_natureza undefined) → cai no fallback de nivel', () => {
        expect(isOptativa({ tipo_natureza: undefined, nivel: 0 })).toBe(true);
        expect(isOptativa({ tipo_natureza: undefined, nivel: 5 })).toBe(false);
    });

    it('#4 C1=V C2=F (tipo_natureza null) → cai no fallback de nivel', () => {
        expect(isOptativa({ tipo_natureza: null, nivel: 0 })).toBe(true);
        expect(isOptativa({ tipo_natureza: null, nivel: 5 })).toBe(false);
    });

    it('fallback: nivel ausente usa 0 (?? 0) → optativa', () => {
        expect(isOptativa({})).toBe(true);
        expect(isOptativa({ tipo_natureza: undefined })).toBe(true);
    });
});

// ---------------------------------------------------------------------------
describe('extractSubjectCodes — extração por regex', () => {
    it('extrai um único código', () => {
        expect(extractSubjectCodes('MAT0026')).toEqual(['MAT0026']);
    });

    it('extrai múltiplos códigos de uma expressão', () => {
        expect(extractSubjectCodes('MAT0026 ou FGA0211')).toEqual(['MAT0026', 'FGA0211']);
    });

    it('normaliza para maiúsculas', () => {
        expect(extractSubjectCodes('mat0026')).toEqual(['MAT0026']);
    });

    it('string sem código → vazio', () => {
        expect(extractSubjectCodes('nenhum codigo aqui')).toEqual([]);
    });

    it('string vazia → vazio', () => {
        expect(extractSubjectCodes('')).toEqual([]);
    });
});

// ---------------------------------------------------------------------------
describe('getCodigosEquivalentes — prioridade expressao_logica vs fallback', () => {
    it('usa expressao_logica quando há códigos', () => {
        const eq: any = {
            expressao_logica: { operador: 'OU', condicoes: ['MAT0026', 'FGA0211'] },
            expressao: 'IGNORADA0001',
        };
        expect(getCodigosEquivalentes(eq)).toEqual(['MAT0026', 'FGA0211']);
    });

    it('faz fallback para expressao quando expressao_logica não tem códigos', () => {
        const eq: any = { expressao_logica: null, expressao: 'MAT0026' };
        expect(getCodigosEquivalentes(eq)).toEqual(['MAT0026']);
    });

    it('sem expressao_logica e sem expressao → vazio', () => {
        const eq: any = { expressao_logica: null, expressao: '' };
        expect(getCodigosEquivalentes(eq)).toEqual([]);
    });
});

// ---------------------------------------------------------------------------
describe('codigoContidoNaEquivalencia — decisões !codigo / expressao_logica', () => {
    it('código vazio → false (curto-circuito)', () => {
        const eq: any = { expressao_logica: 'MAT0026', expressao: 'MAT0026' };
        expect(codigoContidoNaEquivalencia(eq, '')).toBe(false);
    });

    it('com expressao_logica: contido → true', () => {
        const eq: any = { expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } };
        expect(codigoContidoNaEquivalencia(eq, 'mat0026')).toBe(true);
    });

    it('com expressao_logica: não contido → false', () => {
        const eq: any = { expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } };
        expect(codigoContidoNaEquivalencia(eq, 'FGA0211')).toBe(false);
    });

    it('sem expressao_logica: usa fallback de códigos (normaliza)', () => {
        const eq: any = { expressao_logica: null, expressao: 'MAT0026' };
        expect(codigoContidoNaEquivalencia(eq, '  mat0026 ')).toBe(true);
        expect(codigoContidoNaEquivalencia(eq, 'FGA0211')).toBe(false);
    });
});

// ---------------------------------------------------------------------------
describe('getStatusPriority — 3 ramos de prioridade', () => {
    it('integralizada (APR/CUMP/DISP) → 3', () => {
        expect(getStatusPriority('APR')).toBe(3);
        expect(getStatusPriority('CUMP')).toBe(3);
        expect(getStatusPriority('DISP')).toBe(3);
    });

    it('matriculado (MATR) → 2', () => {
        expect(getStatusPriority('MATR')).toBe(2);
    });

    it('demais (REP, etc.) → 1', () => {
        expect(getStatusPriority('REP')).toBe(1);
        expect(getStatusPriority('QUALQUER')).toBe(1);
    });
});

// ---------------------------------------------------------------------------
describe('findSubjectMatch — fallback em 4 níveis (código/nome × obrig/optativa)', () => {
    const mkBanco = (id: number, codigo: string, nome: string, nivel = 1): any => ({
        id_materia: id,
        nivel,
        materias: { id_materia: id, codigo_materia: codigo, nome_materia: nome },
    });

    const obrig = [mkBanco(1, 'MAT0026', 'Cálculo 1')];
    const opt = [mkBanco(2, 'FGA0211', 'Tópicos Especiais')];

    it('nível 1: casa por código nas obrigatórias', () => {
        const d: any = { codigo: 'mat0026', nome: 'qualquer' };
        expect(findSubjectMatch(d, obrig, opt)?.id_materia).toBe(1);
    });

    it('nível 2: casa por código nas optativas', () => {
        const d: any = { codigo: 'FGA0211', nome: 'qualquer' };
        expect(findSubjectMatch(d, obrig, opt)?.id_materia).toBe(2);
    });

    it('nível 3: casa por nome nas obrigatórias', () => {
        const d: any = { codigo: 'ZZZ9999', nome: 'cálculo 1' };
        expect(findSubjectMatch(d, obrig, opt)?.id_materia).toBe(1);
    });

    it('nível 4: casa por nome nas optativas', () => {
        const d: any = { codigo: 'ZZZ9999', nome: 'tópicos especiais' };
        expect(findSubjectMatch(d, obrig, opt)?.id_materia).toBe(2);
    });

    it('sem correspondência → null', () => {
        const d: any = { codigo: 'ZZZ9999', nome: 'inexistente' };
        expect(findSubjectMatch(d, obrig, opt)).toBeNull();
    });
});

// ---------------------------------------------------------------------------
describe('processMatchedDiscipline — duplicatas e resolução por prioridade', () => {
    const banco = (id: number, nivel: number, tipo_natureza?: number): any => ({
        id_materia: id,
        nivel,
        tipo_natureza,
        materias: { id_materia: id, codigo_materia: 'MAT0026', nome_materia: 'Cálculo 1' },
    });

    it('disciplina nova → adicionada com tipo correto', () => {
        const casadas: any[] = [];
        const d: any = { nome: 'Cálculo 1', codigo: 'MAT0026', status: 'APR' };
        const r = processMatchedDiscipline(d, banco(1, 2, 0), casadas, noopLogger);
        expect(casadas).toHaveLength(1);
        expect(r.tipo).toBe('obrigatoria');
        expect(r.encontrada_no_banco).toBe(true);
    });

    it('tipo optativa quando tipo_natureza=1', () => {
        const casadas: any[] = [];
        const d: any = { nome: 'Cálculo 1', codigo: 'MAT0026', status: 'APR' };
        const r = processMatchedDiscipline(d, banco(1, 2, 1), casadas, noopLogger);
        expect(r.tipo).toBe('optativa');
    });

    it('duplicata com prioridade MAIOR substitui a existente', () => {
        const casadas: any[] = [];
        processMatchedDiscipline(
            { nome: 'Cálculo 1', codigo: 'MAT0026', status: 'REP' } as any,
            banco(1, 2, 0), casadas, noopLogger,
        );
        processMatchedDiscipline(
            { nome: 'Cálculo 1', codigo: 'MAT0026', status: 'APR' } as any,
            banco(1, 2, 0), casadas, noopLogger,
        );
        expect(casadas).toHaveLength(1);
        expect(casadas[0].status).toBe('APR'); // 3 > 1, substituiu
    });

    it('duplicata com prioridade MENOR mantém a existente', () => {
        const casadas: any[] = [];
        processMatchedDiscipline(
            { nome: 'Cálculo 1', codigo: 'MAT0026', status: 'APR' } as any,
            banco(1, 2, 0), casadas, noopLogger,
        );
        processMatchedDiscipline(
            { nome: 'Cálculo 1', codigo: 'MAT0026', status: 'MATR' } as any,
            banco(1, 2, 0), casadas, noopLogger,
        );
        expect(casadas).toHaveLength(1);
        expect(casadas[0].status).toBe('APR'); // 3 >= 2, manteve
    });
});

// ---------------------------------------------------------------------------
describe('checkEquivalencies — satisfação por expressao_logica e por fallback', () => {
    const target = { nome: 'Cálculo 2' };

    it('satisfeita via expressao_logica (código concluído) → true', () => {
        const casadas: any[] = [{ codigo: 'MAT0026', status: 'APR' }];
        const eqs: any[] = [{ expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } }];
        expect(checkEquivalencies(casadas, eqs, target, noopLogger)).toBe(true);
    });

    it('satisfeita via fallback de expressao (string) → true', () => {
        const casadas: any[] = [{ codigo: 'MAT0026', status: 'CUMP' }];
        const eqs: any[] = [{ expressao_logica: null, expressao: 'MAT0026' }];
        expect(checkEquivalencies(casadas, eqs, target, noopLogger)).toBe(true);
    });

    it('código presente mas NÃO integralizado (MATR) → false', () => {
        const casadas: any[] = [{ codigo: 'MAT0026', status: 'MATR' }];
        const eqs: any[] = [{ expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } }];
        expect(checkEquivalencies(casadas, eqs, target, noopLogger)).toBe(false);
    });

    it('nenhuma equivalência satisfeita → false', () => {
        const casadas: any[] = [{ codigo: 'OUTRA0001', status: 'APR' }];
        const eqs: any[] = [{ expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } }];
        expect(checkEquivalencies(casadas, eqs, target, noopLogger)).toBe(false);
    });
});

// ---------------------------------------------------------------------------
describe('mapPreRequisitosFromDb — caminhos sem acesso ao banco', () => {
    it('rows nulo/vazio → array vazio', async () => {
        expect(await mapPreRequisitosFromDb(null as any, [])).toEqual([]);
        expect(await mapPreRequisitosFromDb([], [])).toEqual([]);
    });

    it('expande expressao_logica usando nomes já conhecidos (sem buscar no banco)', async () => {
        const materiasPorCurso = [
            { materias: { codigo_materia: 'MAT0026', nome_materia: 'Cálculo 1' } },
        ];
        const rows = [
            {
                id_pre_requisito: 1,
                id_materia: 5,
                expressao_logica: 'MAT0026',
                expressao_original: 'MAT0026',
            },
        ];
        const out = await mapPreRequisitosFromDb(rows, materiasPorCurso);
        expect(out).toHaveLength(1);
        expect(out[0].codigo_materia_requisito).toBe('MAT0026');
        expect(out[0].nome_materia_requisito).toBe('Cálculo 1');
        expect(out[0].expressao_logica).toBe('MAT0026');
    });

    it('usa o ramo de id_materia_requisito quando não há expressao_logica', async () => {
        const rows = [
            {
                id_pre_requisito: 2,
                id_materia: 6,
                expressao_logica: null,
                id_materia_requisito: 9,
                materias: { codigo_materia: 'FGA0211', nome_materia: 'Tópicos' },
            },
        ];
        const out = await mapPreRequisitosFromDb(rows, []);
        expect(out).toHaveLength(1);
        expect(out[0].id_materia_requisito).toBe(9);
        expect(out[0].codigo_materia_requisito).toBe('FGA0211');
        expect(out[0].expressao_logica).toBe('FGA0211');
    });
});

// ---------------------------------------------------------------------------
describe('mapEquivalenciasFromDb — mapeamento de linhas do banco', () => {
    it('mapeia código de origem e expressão', () => {
        const rows = [{
            id_equivalencia: 10,
            materias: { codigo_materia: 'MAT0026', nome_materia: 'Cálculo 1' },
            expressao_original: 'FGA0211',
        }];
        const out = mapEquivalenciasFromDb(rows);
        expect(out).toHaveLength(1);
        expect(out[0].codigo_materia_origem).toBe('MAT0026');
        expect(out[0].codigo_materia_equivalente).toBe('FGA0211');
    });

    it('entrada nula/indefinida → array vazio', () => {
        expect(mapEquivalenciasFromDb(null as any)).toEqual([]);
        expect(mapEquivalenciasFromDb(undefined as any)).toEqual([]);
    });

    it('trata expressao_logica em formato legado { operador, materias }', () => {
        const rows = [{
            id_equivalencia: 11,
            materias_origem: { codigo_materia: 'FGA0100', nome_materia: 'Origem' },
            expressao_logica: { operador: 'E', materias: ['MAT0026', 'FGA0211'] },
        }];
        const out = mapEquivalenciasFromDb(rows);
        expect(out[0].codigo_materia_origem).toBe('FGA0100');
        expect(out[0].expressao_logica).toEqual({ operador: 'E', condicoes: ['MAT0026', 'FGA0211'] });
    });
});

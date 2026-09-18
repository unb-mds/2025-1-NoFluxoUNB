/**
 * Testes de UNIDADE — tecnica CAIXA-PRETA (specification-based testing) das funcoes
 * auxiliares do fluxograma_controller.
 *
 * Disciplina FGA0314 — Testes de Software (PTOSS-2).
 * Aqui exercitamos os requisitos e a especificacao das funcoes (nao a estrutura):
 *   - Particionamento de equivalencia
 *   - Analise de valor limite
 *
 * Complementa o arquivo .whitebox.test.ts que cobre a perspectiva caixa-branca.
 */
import { __testing__ } from '../src/controllers/fluxograma_controller';

const {
    isOptativa,
    extractSubjectCodes,
    getCodigosEquivalentes,
    codigoContidoNaEquivalencia,
    getStatusPriority,
    findSubjectMatch,
    processMatchedDiscipline,
    checkEquivalencies,
    mapEquivalenciasFromDb,
    mapPreRequisitosFromDb,
} = __testing__;

const noopLogger = {
    debug: () => undefined,
    info: () => undefined,
    warn: () => undefined,
    error: () => undefined,
};

// =============================================================================
// isOptativa — Particionamento de Equivalencia + Valor Limite
// =============================================================================
describe('CAIXA-PRETA: isOptativa — particionamento de equivalencia', () => {
    // Particoes de equivalencia para tipo_natureza:
    //   P1: tipo_natureza = 1  (optativa)
    //   P2: tipo_natureza = 0  (obrigatoria)
    //   P3: tipo_natureza = null/undefined (fallback para nivel)
    //   P4: tipo_natureza = outro numero (ex: 2, -1)

    it('P1: tipo_natureza=1 -> optativa', () => {
        expect(isOptativa({ tipo_natureza: 1 })).toBe(true);
    });

    it('P2: tipo_natureza=0 -> obrigatoria', () => {
        expect(isOptativa({ tipo_natureza: 0 })).toBe(false);
    });

    it('P3a: tipo_natureza=null com nivel=0 -> optativa (fallback)', () => {
        expect(isOptativa({ tipo_natureza: null, nivel: 0 })).toBe(true);
    });

    it('P3b: tipo_natureza=undefined com nivel=5 -> obrigatoria (fallback)', () => {
        expect(isOptativa({ tipo_natureza: undefined, nivel: 5 })).toBe(false);
    });

    it('P4: tipo_natureza=2 (outro valor) -> obrigatoria (2 !== 1)', () => {
        expect(isOptativa({ tipo_natureza: 2 })).toBe(false);
    });

    it('P4: tipo_natureza=-1 (negativo) -> obrigatoria (-1 !== 1)', () => {
        expect(isOptativa({ tipo_natureza: -1 })).toBe(false);
    });
});

describe('CAIXA-PRETA: isOptativa — analise de valor limite', () => {
    // Limites para tipo_natureza: o valor decisivo e 1
    //   VL1: tipo_natureza = 0  (imediatamente abaixo)
    //   VL2: tipo_natureza = 1  (exato)
    //   VL3: tipo_natureza = 2  (imediatamente acima)

    it('VL: tipo_natureza=0 (limite inferior) -> false', () => {
        expect(isOptativa({ tipo_natureza: 0 })).toBe(false);
    });

    it('VL: tipo_natureza=1 (limite exato) -> true', () => {
        expect(isOptativa({ tipo_natureza: 1 })).toBe(true);
    });

    it('VL: tipo_natureza=2 (limite superior) -> false', () => {
        expect(isOptativa({ tipo_natureza: 2 })).toBe(false);
    });

    // Limites para nivel no fallback: o valor decisivo e 0
    //   VL: nivel = -1 (abaixo)
    //   VL: nivel = 0  (exato)
    //   VL: nivel = 1  (acima)

    it('VL: fallback nivel=-1 -> obrigatoria (-1 !== 0)', () => {
        expect(isOptativa({ nivel: -1 })).toBe(false);
    });

    it('VL: fallback nivel=0 -> optativa', () => {
        expect(isOptativa({ nivel: 0 })).toBe(true);
    });

    it('VL: fallback nivel=1 -> obrigatoria', () => {
        expect(isOptativa({ nivel: 1 })).toBe(false);
    });
});

// =============================================================================
// extractSubjectCodes — Particionamento de Equivalencia + Valor Limite
// =============================================================================
describe('CAIXA-PRETA: extractSubjectCodes — particionamento de equivalencia', () => {
    // Particoes:
    //   P1: string com 1 codigo valido (3 letras + 4 digitos)
    //   P2: string com multiplos codigos
    //   P3: string sem codigos validos
    //   P4: string vazia
    //   P5: codigo em minusculas (normalizacao)

    it('P1: um unico codigo valido', () => {
        expect(extractSubjectCodes('MAT0026')).toEqual(['MAT0026']);
    });

    it('P2: multiplos codigos em expressao', () => {
        expect(extractSubjectCodes('MAT0026 OU FGA0211 E CIC0097')).toEqual(['MAT0026', 'FGA0211', 'CIC0097']);
    });

    it('P3: texto sem codigos validos', () => {
        expect(extractSubjectCodes('sem codigos aqui')).toEqual([]);
    });

    it('P4: string vazia', () => {
        expect(extractSubjectCodes('')).toEqual([]);
    });

    it('P5: normaliza minusculas para maiusculas', () => {
        expect(extractSubjectCodes('mat0026')).toEqual(['MAT0026']);
    });
});

describe('CAIXA-PRETA: extractSubjectCodes — analise de valor limite', () => {
    // Limites do formato do codigo: exatamente 3 letras + 4 digitos
    //   VL1: 2 letras + 4 digitos (abaixo do limite) — depende da regex
    //   VL2: 3 letras + 4 digitos (exato)
    //   VL3: 4 letras + 4 digitos (acima)
    //   VL4: 3 letras + 3 digitos (menos digitos)
    //   VL5: 3 letras + 5 digitos (mais digitos)

    it('VL: codigo valido exato (3 letras + 4 digitos)', () => {
        expect(extractSubjectCodes('MAT0026')).toEqual(['MAT0026']);
    });

    it('VL: um unico caractere', () => {
        expect(extractSubjectCodes('M')).toEqual([]);
    });

    it('VL: string com apenas espacos', () => {
        expect(extractSubjectCodes('   ')).toEqual([]);
    });
});

// =============================================================================
// getCodigosEquivalentes — Particionamento de Equivalencia
// =============================================================================
describe('CAIXA-PRETA: getCodigosEquivalentes — particionamento de equivalencia', () => {
    // Particoes:
    //   P1: expressao_logica com codigos -> retorna codigos da expressao_logica
    //   P2: expressao_logica null, expressao com codigos -> fallback para expressao
    //   P3: ambos vazios/nulos -> retorna array vazio

    it('P1: expressao_logica valida tem prioridade', () => {
        const eq: any = {
            expressao_logica: { operador: 'OU', condicoes: ['MAT0026', 'FGA0211'] },
            expressao: 'IGNORADA0001',
        };
        expect(getCodigosEquivalentes(eq)).toEqual(['MAT0026', 'FGA0211']);
    });

    it('P2: fallback para expressao quando expressao_logica e nula', () => {
        const eq: any = { expressao_logica: null, expressao: 'MAT0026 OU FGA0211' };
        const result = getCodigosEquivalentes(eq);
        expect(result).toContain('MAT0026');
        expect(result).toContain('FGA0211');
    });

    it('P3: ambos vazios -> array vazio', () => {
        const eq: any = { expressao_logica: null, expressao: '' };
        expect(getCodigosEquivalentes(eq)).toEqual([]);
    });
});

// =============================================================================
// codigoContidoNaEquivalencia — Particionamento de Equivalencia + Valor Limite
// =============================================================================
describe('CAIXA-PRETA: codigoContidoNaEquivalencia — particionamento de equivalencia', () => {
    // Particoes:
    //   P1: codigo vazio -> false
    //   P2: codigo presente na equivalencia -> true
    //   P3: codigo ausente da equivalencia -> false
    //   P4: codigo com espacos/minusculas (normalizacao) -> true

    it('P1: codigo vazio retorna false', () => {
        const eq: any = { expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } };
        expect(codigoContidoNaEquivalencia(eq, '')).toBe(false);
    });

    it('P2: codigo presente retorna true', () => {
        const eq: any = { expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } };
        expect(codigoContidoNaEquivalencia(eq, 'MAT0026')).toBe(true);
    });

    it('P3: codigo ausente retorna false', () => {
        const eq: any = { expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } };
        expect(codigoContidoNaEquivalencia(eq, 'FGA0211')).toBe(false);
    });

    it('P4: normalizacao de espacos e case', () => {
        const eq: any = { expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } };
        expect(codigoContidoNaEquivalencia(eq, '  mat0026 ')).toBe(true);
    });
});

// =============================================================================
// getStatusPriority — Particionamento de Equivalencia + Valor Limite
// =============================================================================
describe('CAIXA-PRETA: getStatusPriority — particionamento de equivalencia', () => {
    // Particoes por especificacao:
    //   P1: Status integralizado (APR, CUMP, DISP) -> 3
    //   P2: Status matriculado (MATR) -> 2
    //   P3: Qualquer outro status (REP, TRANC, etc.) -> 1

    it('P1a: APR (aprovado) -> prioridade maxima 3', () => {
        expect(getStatusPriority('APR')).toBe(3);
    });

    it('P1b: CUMP (cumprido) -> prioridade maxima 3', () => {
        expect(getStatusPriority('CUMP')).toBe(3);
    });

    it('P1c: DISP (dispensado) -> prioridade maxima 3', () => {
        expect(getStatusPriority('DISP')).toBe(3);
    });

    it('P2: MATR (matriculado) -> prioridade media 2', () => {
        expect(getStatusPriority('MATR')).toBe(2);
    });

    it('P3a: REP (reprovado) -> prioridade minima 1', () => {
        expect(getStatusPriority('REP')).toBe(1);
    });

    it('P3b: TRANC (trancado) -> prioridade minima 1', () => {
        expect(getStatusPriority('TRANC')).toBe(1);
    });

    it('P3c: string desconhecida -> prioridade minima 1', () => {
        expect(getStatusPriority('DESCONHECIDO')).toBe(1);
    });

    it('P3d: string vazia -> prioridade minima 1', () => {
        expect(getStatusPriority('')).toBe(1);
    });
});

// =============================================================================
// findSubjectMatch — Particionamento de Equivalencia
// =============================================================================
describe('CAIXA-PRETA: findSubjectMatch — particionamento de equivalencia', () => {
    const mkBanco = (id: number, codigo: string, nome: string, nivel = 1): any => ({
        id_materia: id,
        nivel,
        materias: { id_materia: id, codigo_materia: codigo, nome_materia: nome },
    });

    const obrig = [mkBanco(1, 'MAT0026', 'Calculo 1'), mkBanco(3, 'FGA0108', 'Matematica Discreta')];
    const opt = [mkBanco(2, 'FGA0211', 'Topicos Especiais')];

    // Particoes:
    //   P1: match por codigo em obrigatorias
    //   P2: match por codigo em optativas
    //   P3: match por nome em obrigatorias (codigo nao bate)
    //   P4: match por nome em optativas (codigo nao bate)
    //   P5: nenhum match -> null

    it('P1: encontra por codigo nas obrigatorias', () => {
        const d: any = { codigo: 'MAT0026', nome: 'Qualquer' };
        expect(findSubjectMatch(d, obrig, opt)?.id_materia).toBe(1);
    });

    it('P2: encontra por codigo nas optativas', () => {
        const d: any = { codigo: 'FGA0211', nome: 'Qualquer' };
        expect(findSubjectMatch(d, obrig, opt)?.id_materia).toBe(2);
    });

    it('P3: encontra por nome nas obrigatorias', () => {
        const d: any = { codigo: 'ZZZ9999', nome: 'calculo 1' };
        expect(findSubjectMatch(d, obrig, opt)?.id_materia).toBe(1);
    });

    it('P4: encontra por nome nas optativas', () => {
        const d: any = { codigo: 'ZZZ9999', nome: 'topicos especiais' };
        expect(findSubjectMatch(d, obrig, opt)?.id_materia).toBe(2);
    });

    it('P5: sem correspondencia retorna null', () => {
        const d: any = { codigo: 'ZZZ9999', nome: 'Disciplina Inexistente' };
        expect(findSubjectMatch(d, obrig, opt)).toBeNull();
    });

    // Valor Limite: listas vazias
    it('VL: listas vazias -> null', () => {
        const d: any = { codigo: 'MAT0026', nome: 'Calculo 1' };
        expect(findSubjectMatch(d, [], [])).toBeNull();
    });
});

// =============================================================================
// processMatchedDiscipline — Particionamento de Equivalencia
// =============================================================================
describe('CAIXA-PRETA: processMatchedDiscipline — particionamento de equivalencia', () => {
    const mkBanco = (id: number, tipo_natureza?: number): any => ({
        id_materia: id,
        nivel: 2,
        tipo_natureza,
        materias: { id_materia: id, codigo_materia: 'MAT0026', nome_materia: 'Calculo 1' },
    });

    // Particoes:
    //   P1: disciplina nova -> adicionada ao array
    //   P2: disciplina duplicada com maior prioridade -> substitui
    //   P3: disciplina duplicada com menor/igual prioridade -> mantem existente
    //   P4: materia obrigatoria (tipo_natureza=0) -> tipo='obrigatoria'
    //   P5: materia optativa (tipo_natureza=1) -> tipo='optativa'

    it('P1: disciplina nova e adicionada', () => {
        const casadas: any[] = [];
        const d: any = { nome: 'Calculo 1', codigo: 'MAT0026', status: 'APR' };
        processMatchedDiscipline(d, mkBanco(1, 0), casadas, noopLogger);
        expect(casadas).toHaveLength(1);
        expect(casadas[0].encontrada_no_banco).toBe(true);
    });

    it('P2: duplicata com maior prioridade substitui (REP -> APR)', () => {
        const casadas: any[] = [];
        const d1: any = { nome: 'Calculo 1', codigo: 'MAT0026', status: 'REP' };
        const d2: any = { nome: 'Calculo 1', codigo: 'MAT0026', status: 'APR' };
        processMatchedDiscipline(d1, mkBanco(1, 0), casadas, noopLogger);
        processMatchedDiscipline(d2, mkBanco(1, 0), casadas, noopLogger);
        expect(casadas).toHaveLength(1);
        expect(casadas[0].status).toBe('APR');
    });

    it('P3: duplicata com menor prioridade mantem existente (APR nao substitui por MATR)', () => {
        const casadas: any[] = [];
        const d1: any = { nome: 'Calculo 1', codigo: 'MAT0026', status: 'APR' };
        const d2: any = { nome: 'Calculo 1', codigo: 'MAT0026', status: 'MATR' };
        processMatchedDiscipline(d1, mkBanco(1, 0), casadas, noopLogger);
        processMatchedDiscipline(d2, mkBanco(1, 0), casadas, noopLogger);
        expect(casadas).toHaveLength(1);
        expect(casadas[0].status).toBe('APR');
    });

    it('P4: tipo obrigatoria quando tipo_natureza=0', () => {
        const casadas: any[] = [];
        const d: any = { nome: 'Calculo 1', codigo: 'MAT0026', status: 'APR' };
        const r = processMatchedDiscipline(d, mkBanco(1, 0), casadas, noopLogger);
        expect(r.tipo).toBe('obrigatoria');
    });

    it('P5: tipo optativa quando tipo_natureza=1', () => {
        const casadas: any[] = [];
        const d: any = { nome: 'Calculo 1', codigo: 'MAT0026', status: 'APR' };
        const r = processMatchedDiscipline(d, mkBanco(1, 1), casadas, noopLogger);
        expect(r.tipo).toBe('optativa');
    });
});

// =============================================================================
// checkEquivalencies — Particionamento de Equivalencia
// =============================================================================
describe('CAIXA-PRETA: checkEquivalencies — particionamento de equivalencia', () => {
    const target = { nome: 'Calculo 2' };

    // Particoes:
    //   P1: equivalencia satisfeita (codigo concluido com status integralizado) -> true
    //   P2: codigo presente mas nao integralizado (MATR) -> false
    //   P3: codigo ausente das disciplinas casadas -> false
    //   P4: lista de equivalencias vazia -> false

    it('P1: equivalencia satisfeita (APR) -> true', () => {
        const casadas: any[] = [{ codigo: 'MAT0026', status: 'APR' }];
        const eqs: any[] = [{ expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } }];
        expect(checkEquivalencies(casadas, eqs, target, noopLogger)).toBe(true);
    });

    it('P1b: equivalencia satisfeita (CUMP) -> true', () => {
        const casadas: any[] = [{ codigo: 'MAT0026', status: 'CUMP' }];
        const eqs: any[] = [{ expressao_logica: null, expressao: 'MAT0026' }];
        expect(checkEquivalencies(casadas, eqs, target, noopLogger)).toBe(true);
    });

    it('P2: codigo presente mas matriculado (MATR) -> false', () => {
        const casadas: any[] = [{ codigo: 'MAT0026', status: 'MATR' }];
        const eqs: any[] = [{ expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } }];
        expect(checkEquivalencies(casadas, eqs, target, noopLogger)).toBe(false);
    });

    it('P3: codigo nao encontrado -> false', () => {
        const casadas: any[] = [{ codigo: 'OUTRA0001', status: 'APR' }];
        const eqs: any[] = [{ expressao_logica: { operador: 'OU', condicoes: ['MAT0026'] } }];
        expect(checkEquivalencies(casadas, eqs, target, noopLogger)).toBe(false);
    });

    it('P4: lista de equivalencias vazia -> false', () => {
        const casadas: any[] = [{ codigo: 'MAT0026', status: 'APR' }];
        expect(checkEquivalencies(casadas, [], target, noopLogger)).toBe(false);
    });
});

// =============================================================================
// mapEquivalenciasFromDb — Particionamento de Equivalencia + Valor Limite
// =============================================================================
describe('CAIXA-PRETA: mapEquivalenciasFromDb — particionamento de equivalencia', () => {
    // Particoes:
    //   P1: array com dados validos -> mapeado corretamente
    //   P2: entrada null -> array vazio
    //   P3: entrada undefined -> array vazio
    //   P4: array vazio -> array vazio
    //   P5: formato legado (materias em vez de condicoes) -> convertido

    it('P1: dados validos sao mapeados', () => {
        const rows = [{
            id_equivalencia: 10,
            materias: { codigo_materia: 'MAT0026', nome_materia: 'Calculo 1' },
            expressao_original: 'FGA0211',
        }];
        const out = mapEquivalenciasFromDb(rows);
        expect(out).toHaveLength(1);
        expect(out[0].codigo_materia_origem).toBe('MAT0026');
    });

    it('P2: null -> vazio', () => {
        expect(mapEquivalenciasFromDb(null as any)).toEqual([]);
    });

    it('P3: undefined -> vazio', () => {
        expect(mapEquivalenciasFromDb(undefined as any)).toEqual([]);
    });

    it('P4 (VL): array vazio -> array vazio', () => {
        expect(mapEquivalenciasFromDb([])).toEqual([]);
    });

    it('P5: formato legado com "materias" convertido para "condicoes"', () => {
        const rows = [{
            id_equivalencia: 11,
            materias_origem: { codigo_materia: 'FGA0100', nome_materia: 'Origem' },
            expressao_logica: { operador: 'E', materias: ['MAT0026', 'FGA0211'] },
        }];
        const out = mapEquivalenciasFromDb(rows);
        expect(out[0].expressao_logica).toEqual({ operador: 'E', condicoes: ['MAT0026', 'FGA0211'] });
    });
});

// =============================================================================
// mapPreRequisitosFromDb — Particionamento de Equivalencia + Valor Limite
// =============================================================================
describe('CAIXA-PRETA: mapPreRequisitosFromDb — particionamento de equivalencia', () => {
    // Particoes:
    //   P1: rows null -> array vazio
    //   P2: rows vazio -> array vazio
    //   P3: row com expressao_logica valida -> expande codigos
    //   P4: row sem expressao_logica, com id_materia_requisito -> usa join

    it('P1: null -> array vazio', async () => {
        expect(await mapPreRequisitosFromDb(null as any, [])).toEqual([]);
    });

    it('P2 (VL): array vazio -> array vazio', async () => {
        expect(await mapPreRequisitosFromDb([], [])).toEqual([]);
    });

    it('P3: expande expressao_logica com nomes conhecidos', async () => {
        const materiasPorCurso = [
            { materias: { codigo_materia: 'MAT0026', nome_materia: 'Calculo 1' } },
        ];
        const rows = [{
            id_pre_requisito: 1,
            id_materia: 5,
            expressao_logica: 'MAT0026',
            expressao_original: 'MAT0026',
        }];
        const out = await mapPreRequisitosFromDb(rows, materiasPorCurso);
        expect(out).toHaveLength(1);
        expect(out[0].codigo_materia_requisito).toBe('MAT0026');
        expect(out[0].nome_materia_requisito).toBe('Calculo 1');
    });

    it('P4: usa id_materia_requisito quando nao ha expressao_logica', async () => {
        const rows = [{
            id_pre_requisito: 2,
            id_materia: 6,
            expressao_logica: null,
            id_materia_requisito: 9,
            materias: { codigo_materia: 'FGA0211', nome_materia: 'Topicos' },
        }];
        const out = await mapPreRequisitosFromDb(rows, []);
        expect(out).toHaveLength(1);
        expect(out[0].id_materia_requisito).toBe(9);
    });
});

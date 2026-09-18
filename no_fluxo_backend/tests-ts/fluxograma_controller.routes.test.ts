/**
 * Testes de UNIDADE das ROTAS do FluxogramaController.
 *
 * Disciplina FGA0314 — Testes de Software (PTOSS-2).
 * Objetivo: aumentar a cobertura das rotas do controller (linhas 321-1031)
 * que nao sao cobertas pelos testes das funcoes auxiliares.
 *
 * Tecnicas:
 *   - Caixa-preta: particionamento de equivalencia nos inputs de cada rota
 *   - Caixa-branca: cobertura de decisoes/ramos de erro
 */
import { FluxogramaController } from '../src/controllers/fluxograma_controller';
import { Request, Response } from 'express';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

// Mock do logger
jest.mock('../src/utils/controller_logger', () => ({
    createControllerLogger: () => ({
        debug: jest.fn(),
        info: jest.fn(),
        warn: jest.fn(),
        error: jest.fn(),
    }),
}));

// Mock do integralizacao service
const mockCalcularIntegralizacao = jest.fn();
jest.mock('../src/services/integralizacao.service', () => ({
    calcularIntegralizacao: (...args: any[]) => mockCalcularIntegralizacao(...args),
}));

// Mock do Utils — precisa ser var para ser hoisted junto com jest.mock
var mockCheckAuthorization = jest.fn();
jest.mock('../src/utils', () => {
    const actual = jest.requireActual('../src/utils');
    return {
        ...actual,
        Utils: {
            ...actual.Utils,
            checkAuthorization: (...args: any[]) => mockCheckAuthorization(...args),
        },
    };
});

// Mock do SupabaseWrapper com builder pattern
function createMockQueryBuilder(resolvedValue: { data: any; error: any }) {
    const builder: any = {
        select: jest.fn().mockReturnThis(),
        like: jest.fn().mockReturnThis(),
        eq: jest.fn().mockReturnThis(),
        or: jest.fn().mockReturnThis(),
        in: jest.fn().mockReturnThis(),
        order: jest.fn().mockReturnThis(),
        insert: jest.fn().mockReturnThis(),
        delete: jest.fn().mockReturnThis(),
    };
    // The final call in the chain resolves to the data
    // We make all methods return the builder, and add a then() so it resolves as a Promise
    builder.then = (resolve: Function) => resolve(resolvedValue);
    return builder;
}

var mockFromFn: jest.Mock;

jest.mock('../src/supabase_wrapper', () => {
    mockFromFn = jest.fn();
    return {
        SupabaseWrapper: {
            get: () => ({ from: mockFromFn }),
        },
    };
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function mockReqRes(overrides: { query?: any; body?: any; headers?: any } = {}) {
    const req = {
        query: overrides.query || {},
        body: overrides.body || {},
        headers: overrides.headers || {},
    } as unknown as Request;

    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const res = { status, json } as unknown as Response;

    return { req, res, status, json };
}

function getRoute(name: string) {
    return (FluxogramaController.routes as any)[name].value;
}

// =============================================================================
// ROTA: fluxograma (GET)
// =============================================================================
describe('ROTA fluxograma (GET)', () => {
    const handler = getRoute('fluxograma');

    beforeEach(() => jest.clearAllMocks());

    it('CAIXA-PRETA P1: sem nome_curso -> 400', async () => {
        const { req, res, status, json } = mockReqRes({ query: {} });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(400);
        expect(json).toHaveBeenCalledWith(expect.objectContaining({ error: expect.any(String) }));
    });

    it('CAIXA-PRETA P2: nome_curso vazio -> 400', async () => {
        const { req, res, status, json } = mockReqRes({ query: { nome_curso: '' } });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(400);
    });

    it('CAIXA-BRANCA: erro do Supabase na query principal -> 500', async () => {
        const { req, res, status, json } = mockReqRes({ query: { nome_curso: 'Engenharia' } });
        mockFromFn.mockReturnValue(createMockQueryBuilder({
            data: null,
            error: { message: 'DB connection failed' },
        }));
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(500);
        expect(json).toHaveBeenCalledWith(expect.objectContaining({ error: 'DB connection failed' }));
    });

    it('CAIXA-PRETA P3: curso valido sem sub-materias -> 200 com data vazia', async () => {
        const { req, res, status, json } = mockReqRes({ query: { nome_curso: 'Engenharia' } });
        mockFromFn.mockReturnValue(createMockQueryBuilder({
            data: [],
            error: null,
        }));
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(200);
        expect(json).toHaveBeenCalledWith([]);
    });
});

// =============================================================================
// ROTA: integralizacao (POST)
// =============================================================================
describe('ROTA integralizacao (POST)', () => {
    const handler = getRoute('integralizacao');

    beforeEach(() => jest.clearAllMocks());

    it('CAIXA-PRETA P1: sem curriculoCompleto -> 400', async () => {
        const { req, res, status, json } = mockReqRes({ body: {} });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(400);
        expect(json).toHaveBeenCalledWith(expect.objectContaining({ error: expect.stringContaining('obrigat') }));
    });

    it('CAIXA-PRETA P2: curriculoCompleto vazio -> 400', async () => {
        const { req, res, status, json } = mockReqRes({ body: { curriculoCompleto: '' } });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(400);
    });

    it('CAIXA-PRETA P3: curriculoCompleto apenas espacos -> 400', async () => {
        const { req, res, status, json } = mockReqRes({ body: { curriculoCompleto: '   ' } });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(400);
    });

    it('CAIXA-PRETA P4: curriculoCompleto valido, servico retorna dados -> 200', async () => {
        mockCalcularIntegralizacao.mockResolvedValue({ percentual: 85 });
        const { req, res, status, json } = mockReqRes({
            body: { curriculoCompleto: '6912/1 - ENGENHARIA DE SOFTWARE', cargaHorariaIntegralizada: 2400 },
        });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(200);
        expect(json).toHaveBeenCalledWith({ percentual: 85 });
        expect(mockCalcularIntegralizacao).toHaveBeenCalledWith(
            '6912/1 - ENGENHARIA DE SOFTWARE',
            2400,
        );
    });

    it('CAIXA-PRETA P5: curriculoCompleto valido mas matriz nao encontrada -> 404', async () => {
        mockCalcularIntegralizacao.mockResolvedValue(null);
        const { req, res, status, json } = mockReqRes({
            body: { curriculoCompleto: 'CURSO_INEXISTENTE' },
        });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(404);
    });

    it('CAIXA-BRANCA: cargaHorariaIntegralizada ausente -> passa null', async () => {
        mockCalcularIntegralizacao.mockResolvedValue({ percentual: 50 });
        const { req, res } = mockReqRes({ body: { curriculoCompleto: 'CURSO' } });
        await handler(req, res);
        expect(mockCalcularIntegralizacao).toHaveBeenCalledWith('CURSO', null);
    });

    it('CAIXA-BRANCA: servico lanca excecao -> 500', async () => {
        mockCalcularIntegralizacao.mockRejectedValue(new Error('Servico indisponivel'));
        const { req, res, status, json } = mockReqRes({ body: { curriculoCompleto: 'CURSO' } });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(500);
        expect(json).toHaveBeenCalledWith(expect.objectContaining({ error: 'Servico indisponivel' }));
    });
});

// =============================================================================
// ROTA: upload-dados-fluxograma (POST)
// =============================================================================
describe('ROTA upload-dados-fluxograma (POST)', () => {
    const handler = getRoute('upload-dados-fluxograma');

    beforeEach(() => jest.clearAllMocks());

    it('CAIXA-PRETA P1: usuario nao autorizado -> 401', async () => {
        mockCheckAuthorization.mockResolvedValue(false);
        const { req, res, status, json } = mockReqRes({
            body: { fluxograma: {}, periodo_letivo: '2025.1' },
        });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(401);
    });

    it('CAIXA-PRETA P2: usuario autorizado, insert sucesso -> 200', async () => {
        mockCheckAuthorization.mockResolvedValue(true);
        mockFromFn.mockReturnValue(createMockQueryBuilder({
            data: [{ id: 1 }],
            error: null,
        }));
        const { req, res, status, json } = mockReqRes({
            body: { fluxograma: { materias: [] }, periodo_letivo: '2025.1' },
            headers: { 'user-id': 'user-123' },
        });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(200);
    });

    it('CAIXA-BRANCA: erro do Supabase no insert -> 500', async () => {
        mockCheckAuthorization.mockResolvedValue(true);
        mockFromFn.mockReturnValue(createMockQueryBuilder({
            data: null,
            error: { message: 'Insert failed' },
        }));
        const { req, res, status, json } = mockReqRes({
            body: { fluxograma: {}, periodo_letivo: '2025.1' },
            headers: { 'user-id': 'user-123' },
        });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(500);
    });
});

// =============================================================================
// ROTA: delete-fluxograma (DELETE)
// =============================================================================
describe('ROTA delete-fluxograma (DELETE)', () => {
    const handler = getRoute('delete-fluxograma');

    beforeEach(() => jest.clearAllMocks());

    it('CAIXA-PRETA P1: usuario nao autorizado -> 401', async () => {
        mockCheckAuthorization.mockResolvedValue(false);
        const { req, res, status } = mockReqRes();
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(401);
    });

    it('CAIXA-PRETA P2: sem user-id no header -> 400', async () => {
        mockCheckAuthorization.mockResolvedValue(true);
        const { req, res, status, json } = mockReqRes({ headers: {} });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(400);
        expect(json).toHaveBeenCalledWith(expect.objectContaining({ error: expect.stringContaining('User ID') }));
    });

    it('CAIXA-PRETA P3: delete sucesso -> 200', async () => {
        mockCheckAuthorization.mockResolvedValue(true);
        mockFromFn.mockReturnValue(createMockQueryBuilder({
            data: null,
            error: null,
        }));
        const { req, res, status, json } = mockReqRes({ headers: { 'user-id': 'user-123' } });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(200);
        expect(json).toHaveBeenCalledWith({ success: true });
    });

    it('CAIXA-BRANCA: erro do Supabase no delete -> 500', async () => {
        mockCheckAuthorization.mockResolvedValue(true);
        mockFromFn.mockReturnValue(createMockQueryBuilder({
            data: null,
            error: { message: 'Delete failed' },
        }));
        const { req, res, status, json } = mockReqRes({ headers: { 'user-id': 'user-123' } });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(500);
    });
});

// =============================================================================
// ROTA: casar_disciplinas (POST) — cenarios principais
// =============================================================================
describe('ROTA casar_disciplinas (POST)', () => {
    const handler = getRoute('casar_disciplinas');

    beforeEach(() => jest.clearAllMocks());

    it('CAIXA-PRETA P1: sem dados_extraidos -> 400', async () => {
        const { req, res, status, json } = mockReqRes({ body: {} });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(400);
        expect(json).toHaveBeenCalledWith(expect.objectContaining({ error: expect.stringContaining('obrigat') }));
    });

    it('CAIXA-PRETA P2: sem curso_extraido -> 400 com cursos disponiveis', async () => {
        mockFromFn.mockReturnValue(createMockQueryBuilder({
            data: [{ id_curso: 1, nome_curso: 'Eng Software' }],
            error: null,
        }));
        const { req, res, status, json } = mockReqRes({
            body: {
                dados_extraidos: {
                    curso_extraido: null,
                    extracted_data: [],
                },
            },
        });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(400);
        expect(json).toHaveBeenCalledWith(expect.objectContaining({
            message: expect.stringContaining('selecione'),
        }));
    });

    it('CAIXA-BRANCA: erro do Supabase ao buscar curso -> 500', async () => {
        mockFromFn.mockReturnValue(createMockQueryBuilder({
            data: null,
            error: { message: 'Query error' },
        }));
        const { req, res, status, json } = mockReqRes({
            body: {
                dados_extraidos: {
                    curso_extraido: 'ENGENHARIA',
                    extracted_data: [],
                },
            },
        });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(500);
    });

    it('CAIXA-PRETA P3: curso nao encontrado no banco -> 404', async () => {
        // First call: cursos query returns empty
        // Second call: list all cursos
        let callCount = 0;
        mockFromFn.mockImplementation(() => {
            callCount++;
            return createMockQueryBuilder({
                data: callCount === 1 ? [] : [{ id_curso: 1, nome_curso: 'Outro Curso' }],
                error: null,
            });
        });
        const { req, res, status, json } = mockReqRes({
            body: {
                dados_extraidos: {
                    curso_extraido: 'CURSO_QUE_NAO_EXISTE',
                    extracted_data: [],
                },
            },
        });
        await handler(req, res);
        expect(status).toHaveBeenCalledWith(404);
    });
});

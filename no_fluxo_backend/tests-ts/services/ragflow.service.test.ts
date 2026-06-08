/**
 * Testes unitários do RagflowService (PTOSS-2).
 *
 * Técnicas combinadas:
 *  - CAIXA-PRETA: respostas de sucesso, payload/headers esperados, parâmetros típicos.
 *  - CAIXA-BRANCA: ramos de erro (AxiosError com/sem response, Error comum),
 *    ausência de session_id, serviço não configurado e isAvailable() em ambos os estados.
 *
 * Mocks:
 *  - axios.post/get são jest.fn(); AxiosError é o real (para que `instanceof` funcione).
 *  - '../../src/logger' é mockado para não poluir a saída dos testes.
 */

import axios, { AxiosError } from 'axios';
import { RagflowService } from '../../src/services/ragflow.service';
import { RagflowResponse } from '../../src/services/ragflow.types';

jest.mock('axios', () => {
    const actual = jest.requireActual('axios');
    return {
        __esModule: true,
        default: { post: jest.fn(), get: jest.fn() },
        AxiosError: actual.AxiosError,
    };
});

jest.mock('../../src/logger', () => ({
    __esModule: true,
    default: {
        info: jest.fn(),
        warn: jest.fn(),
        error: jest.fn(),
        debug: jest.fn(),
        http: jest.fn(),
    },
}));

import logger from '../../src/logger';

const mockedPost = axios.post as jest.Mock;
const mockedLogger = logger as jest.Mocked<typeof logger>;

const ENV_OK = {
    RAGFLOW_API_KEY: 'test-api-key',
    RAGFLOW_BASE_URL: 'https://ragflow.test',
    RAGFLOW_AGENT_ID: 'agent-123',
};

const EXPECTED_URL = `${ENV_OK.RAGFLOW_BASE_URL}/api/v1/agents/${ENV_OK.RAGFLOW_AGENT_ID}/completions`;

/** Resposta típica de sucesso da API RAGFlow. */
function okResponse(sessionId = 'session-abc'): { data: RagflowResponse } {
    return {
        data: {
            code: 0,
            data: { answer: 'resposta gerada', session_id: sessionId },
            message: 'ok',
        },
    };
}

const ORIGINAL_ENV = process.env;

describe('RagflowService', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        // Estado configurado por padrão; testes que precisam do estado "ausente" sobrescrevem.
        process.env = { ...ORIGINAL_ENV, ...ENV_OK };
    });

    afterEach(() => {
        process.env = ORIGINAL_ENV;
    });

    describe('isAvailable() / configuração (caixa-branca)', () => {
        it('retorna true quando todas as env vars estão presentes', () => {
            const service = new RagflowService();
            expect(service.isAvailable()).toBe(true);
        });

        it('retorna false quando falta a RAGFLOW_API_KEY', () => {
            delete process.env.RAGFLOW_API_KEY;
            const service = new RagflowService();
            expect(service.isAvailable()).toBe(false);
            expect(mockedLogger.warn).toHaveBeenCalled();
        });

        it('retorna false quando faltam todas as env vars', () => {
            delete process.env.RAGFLOW_API_KEY;
            delete process.env.RAGFLOW_BASE_URL;
            delete process.env.RAGFLOW_AGENT_ID;
            const service = new RagflowService();
            expect(service.isAvailable()).toBe(false);
        });
    });

    describe('startSession()', () => {
        it('CAIXA-PRETA: retorna o session_id e envia payload/headers corretos', async () => {
            mockedPost.mockResolvedValueOnce(okResponse('session-xyz'));
            const service = new RagflowService();

            const sessionId = await service.startSession('Cálculo 1');

            expect(sessionId).toBe('session-xyz');
            expect(mockedPost).toHaveBeenCalledWith(
                EXPECTED_URL,
                { materia: 'Cálculo 1', stream: false },
                expect.objectContaining({
                    headers: expect.objectContaining({
                        Authorization: `Bearer ${ENV_OK.RAGFLOW_API_KEY}`,
                        'Content-Type': 'application/json',
                    }),
                    timeout: 30_000,
                }),
            );
        });

        it('CAIXA-PRETA: aceita matéria vazia', async () => {
            mockedPost.mockResolvedValueOnce(okResponse('session-empty'));
            const service = new RagflowService();

            await expect(service.startSession('')).resolves.toBe('session-empty');
        });

        it('CAIXA-BRANCA: lança erro quando o serviço não está configurado', async () => {
            delete process.env.RAGFLOW_API_KEY;
            const service = new RagflowService();

            await expect(service.startSession('Física')).rejects.toThrow(
                'RAGFlow service is not configured',
            );
            expect(mockedPost).not.toHaveBeenCalled();
        });

        it('CAIXA-BRANCA: lança erro quando a resposta não traz session_id', async () => {
            mockedPost.mockResolvedValueOnce({
                data: { code: 0, data: { answer: 'sem sessão' } },
            });
            const service = new RagflowService();

            await expect(service.startSession('Algoritmos')).rejects.toThrow(
                'session_id not found in RAGFlow API response',
            );
            expect(mockedLogger.error).toHaveBeenCalled();
        });

        it('CAIXA-BRANCA: propaga AxiosError com response e registra status/body', async () => {
            const axiosError = new AxiosError('Request failed', 'ERR_BAD_RESPONSE');
            axiosError.response = {
                status: 500,
                data: { detail: 'internal' },
                statusText: 'Internal Server Error',
                headers: {},
                config: {} as never,
            };
            mockedPost.mockRejectedValueOnce(axiosError);
            const service = new RagflowService();

            await expect(service.startSession('Banco de Dados')).rejects.toBe(axiosError);
            expect(mockedLogger.error).toHaveBeenCalledWith(
                expect.stringContaining('startSession failed'),
            );
            expect(mockedLogger.error).toHaveBeenCalledWith(
                expect.stringContaining('Status: 500'),
            );
        });

        it('CAIXA-BRANCA: propaga AxiosError de timeout (sem response)', async () => {
            const timeoutError = new AxiosError('timeout of 30000ms exceeded', 'ECONNABORTED');
            mockedPost.mockRejectedValueOnce(timeoutError);
            const service = new RagflowService();

            await expect(service.startSession('Redes')).rejects.toBe(timeoutError);
            expect(mockedLogger.error).toHaveBeenCalledWith(
                expect.stringContaining('startSession failed'),
            );
        });

        it('CAIXA-BRANCA: propaga erro genérico (não-Axios)', async () => {
            const genericError = new Error('boom');
            mockedPost.mockRejectedValueOnce(genericError);
            const service = new RagflowService();

            await expect(service.startSession('Compiladores')).rejects.toBe(genericError);
            expect(mockedLogger.error).toHaveBeenCalledWith(
                expect.stringContaining('startSession failed'),
            );
        });
    });

    describe('analyzeMateria()', () => {
        it('CAIXA-PRETA: retorna os dados e envia payload/headers corretos', async () => {
            const response = okResponse('session-1');
            mockedPost.mockResolvedValueOnce(response);
            const service = new RagflowService();

            const data = await service.analyzeMateria('Cálculo 1', 'session-1');

            expect(data).toEqual(response.data);
            expect(mockedPost).toHaveBeenCalledWith(
                EXPECTED_URL,
                { question: 'Cálculo 1', session_id: 'session-1', stream: false },
                expect.objectContaining({ timeout: 60_000 }),
            );
        });

        it('CAIXA-BRANCA: lança erro quando o serviço não está configurado', async () => {
            delete process.env.RAGFLOW_BASE_URL;
            const service = new RagflowService();

            await expect(service.analyzeMateria('Física', 'sess')).rejects.toThrow(
                'RAGFlow service is not configured',
            );
        });

        it('CAIXA-BRANCA: propaga AxiosError e registra o erro', async () => {
            const axiosError = new AxiosError('Network Error');
            mockedPost.mockRejectedValueOnce(axiosError);
            const service = new RagflowService();

            await expect(service.analyzeMateria('IA', 'sess')).rejects.toBe(axiosError);
            expect(mockedLogger.error).toHaveBeenCalledWith(
                expect.stringContaining('analyzeMateria failed'),
            );
        });
    });
});

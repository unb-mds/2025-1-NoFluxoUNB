/**
 * Testes unitários do SabiaService (PTOSS-2).
 *
 * Técnicas combinadas:
 *  - CAIXA-PRETA: respostas de sucesso, parâmetro default (matriz=''),
 *    formatAsMarkdown com resposta típica e variações de emoji por nota.
 *  - CAIXA-BRANCA: ramos de erro (res.ok=false, fetch rejeitando, ECONNREFUSED),
 *    stream sem body, isAvailable() em ambos os estados e serviço não configurado.
 *
 * Mocks:
 *  - global.fetch é substituído por jest.fn().
 *  - '../../src/logger' é mockado.
 *  - Para o stream, é passado um mock de express Response (write/end/setHeader).
 */

import { SabiaService, SabiaResponse } from '../../src/services/sabia.service';
import { Response } from 'express';

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

const mockedLogger = logger as jest.Mocked<typeof logger>;
const mockFetch = jest.fn();

const ENV_OK = {
    SABIA_API_URL: 'http://sabia.test:8000',
    MARITACA_API_KEY: 'maritaca-key',
    GOOGLE_API_KEY: 'google-key',
    SUPABASE_URL: 'https://test.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
};

const ORIGINAL_ENV = process.env;

/** Cria um mock de express Response com os métodos usados pelo stream. */
function mockResponse(extra: Partial<Response> = {}): Response {
    return {
        write: jest.fn(),
        end: jest.fn(),
        setHeader: jest.fn(),
        ...extra,
    } as unknown as Response;
}

describe('SabiaService', () => {
    beforeEach(() => {
        jest.clearAllMocks();
        process.env = { ...ORIGINAL_ENV, ...ENV_OK };
        (global as unknown as { fetch: jest.Mock }).fetch = mockFetch;
        mockFetch.mockReset();
    });

    afterEach(() => {
        process.env = ORIGINAL_ENV;
    });

    describe('isAvailable() / configuração (caixa-branca)', () => {
        it('retorna true quando todas as configurações estão presentes', () => {
            expect(new SabiaService().isAvailable()).toBe(true);
        });

        it('retorna false quando falta MARITACA_API_KEY', () => {
            delete process.env.MARITACA_API_KEY;
            expect(new SabiaService().isAvailable()).toBe(false);
            expect(mockedLogger.warn).toHaveBeenCalled();
        });

        it('retorna false quando falta GOOGLE_API_KEY', () => {
            delete process.env.GOOGLE_API_KEY;
            expect(new SabiaService().isAvailable()).toBe(false);
        });

        it('retorna false quando falta a configuração do Supabase', () => {
            delete process.env.SUPABASE_SERVICE_ROLE_KEY;
            expect(new SabiaService().isAvailable()).toBe(false);
        });

        it('usa a URL default quando SABIA_API_URL não está definida', () => {
            delete process.env.SABIA_API_URL;
            const service = new SabiaService();
            expect(service.isAvailable()).toBe(true); // não depende da SABIA_API_URL
        });
    });

    describe('analyzarInteresse()', () => {
        const disciplinas = [
            { codigo: 'CIC0004', nome: 'IA', nota: 9.5, justificativa: 'núcleo de IA' },
        ];

        it('CAIXA-PRETA: retorna a resposta de sucesso e chama o endpoint correto', async () => {
            mockFetch.mockResolvedValueOnce({
                ok: true,
                json: async () => ({ success: true, disciplinas }),
            });
            const service = new SabiaService();

            const result = await service.analyzarInteresse('inteligência artificial', 'EC2017');

            expect(result.success).toBe(true);
            expect(result.disciplinas).toEqual(disciplinas);
            expect(mockFetch).toHaveBeenCalledWith(
                `${ENV_OK.SABIA_API_URL}/recomendar`,
                expect.objectContaining({
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        interesse: 'inteligência artificial',
                        matriz_curricular: 'EC2017',
                    }),
                }),
            );
        });

        it('CAIXA-PRETA: usa matriz curricular vazia como parâmetro default', async () => {
            mockFetch.mockResolvedValueOnce({
                ok: true,
                json: async () => ({ success: true, disciplinas: [] }),
            });
            const service = new SabiaService();

            await service.analyzarInteresse('banco de dados');

            const body = JSON.parse((mockFetch.mock.calls[0][1] as { body: string }).body);
            expect(body.matriz_curricular).toBe('');
        });

        it('CAIXA-PRETA: aceita resposta de negócio com success=false sem lançar', async () => {
            mockFetch.mockResolvedValueOnce({
                ok: true,
                json: async () => ({ success: false, error: 'fora do escopo' }),
            });
            const service = new SabiaService();

            const result = await service.analyzarInteresse('futebol');

            expect(result.success).toBe(false);
            expect(mockedLogger.error).toHaveBeenCalledWith(
                expect.stringContaining('Analysis failed'),
            );
        });

        it('CAIXA-BRANCA: lança erro quando o serviço não está configurado', async () => {
            delete process.env.MARITACA_API_KEY;
            const service = new SabiaService();

            await expect(service.analyzarInteresse('IA')).rejects.toThrow(
                'Sabiá service is not configured',
            );
            expect(mockFetch).not.toHaveBeenCalled();
        });

        it('CAIXA-BRANCA: propaga erro quando a resposta HTTP não é ok', async () => {
            mockFetch.mockResolvedValueOnce({
                ok: false,
                status: 500,
                text: async () => 'internal error',
            });
            const service = new SabiaService();

            await expect(service.analyzarInteresse('IA')).rejects.toThrow(
                'FastAPI returned 500: internal error',
            );
        });

        it('CAIXA-BRANCA: traduz erro de conexão recusada em mensagem amigável', async () => {
            mockFetch.mockRejectedValueOnce(new Error('connect ECONNREFUSED 127.0.0.1:8000'));
            const service = new SabiaService();

            await expect(service.analyzarInteresse('IA')).rejects.toThrow(
                /Cannot connect to Sabiá API/,
            );
        });

        it('CAIXA-BRANCA: traduz "fetch failed" em mensagem amigável', async () => {
            mockFetch.mockRejectedValueOnce(new Error('fetch failed'));
            const service = new SabiaService();

            await expect(service.analyzarInteresse('IA')).rejects.toThrow(
                /Cannot connect to Sabiá API/,
            );
        });
    });

    describe('analyzarInteresseStream()', () => {
        /** Cria um body com getReader() que emite os chunks informados e depois done. */
        function streamBody(chunks: string[]) {
            const encoder = new TextEncoder();
            let i = 0;
            return {
                getReader: () => ({
                    read: jest.fn().mockImplementation(() => {
                        if (i < chunks.length) {
                            return Promise.resolve({ done: false, value: encoder.encode(chunks[i++]) });
                        }
                        return Promise.resolve({ done: true, value: undefined });
                    }),
                }),
            };
        }

        it('CAIXA-PRETA: escreve os chunks na Response e finaliza com end()', async () => {
            mockFetch.mockResolvedValueOnce({
                ok: true,
                body: streamBody(['data: a\n', 'data: b\n']),
            });
            const res = mockResponse();
            const service = new SabiaService();

            await service.analyzarInteresseStream('IA', '', res);

            expect(res.write).toHaveBeenCalledTimes(2);
            expect(res.write).toHaveBeenNthCalledWith(1, 'data: a\n');
            expect(res.write).toHaveBeenNthCalledWith(2, 'data: b\n');
            expect(res.end).toHaveBeenCalledTimes(1);
        });

        it('CAIXA-BRANCA: chama flush() quando disponível (middleware de compressão)', async () => {
            mockFetch.mockResolvedValueOnce({
                ok: true,
                body: streamBody(['chunk']),
            });
            const flush = jest.fn();
            const res = mockResponse({ flush } as unknown as Partial<Response>);
            const service = new SabiaService();

            await service.analyzarInteresseStream('IA', '', res);

            expect(flush).toHaveBeenCalled();
            expect(res.end).toHaveBeenCalled();
        });

        it('CAIXA-BRANCA: lança erro quando o serviço não está configurado', async () => {
            delete process.env.GOOGLE_API_KEY;
            const service = new SabiaService();

            await expect(
                service.analyzarInteresseStream('IA', '', mockResponse()),
            ).rejects.toThrow('Sabiá service is not configured');
        });

        it('CAIXA-BRANCA: lança erro quando a resposta HTTP não é ok', async () => {
            mockFetch.mockResolvedValueOnce({
                ok: false,
                status: 502,
                text: async () => 'bad gateway',
            });
            const service = new SabiaService();

            await expect(
                service.analyzarInteresseStream('IA', '', mockResponse()),
            ).rejects.toThrow('FastAPI returned 502: bad gateway');
        });

        it('CAIXA-BRANCA: lança erro quando não há body no stream', async () => {
            mockFetch.mockResolvedValueOnce({ ok: true, body: null });
            const service = new SabiaService();

            await expect(
                service.analyzarInteresseStream('IA', '', mockResponse()),
            ).rejects.toThrow('No response body from FastAPI stream');
        });
    });

    describe('formatAsMarkdown()', () => {
        it('CAIXA-PRETA: formata resposta típica com cabeçalho, emojis e análise completa', () => {
            const response: SabiaResponse = {
                success: true,
                disciplinas: [
                    { codigo: 'CIC0004', nome: 'IA', nota: 9.5, justificativa: 'núcleo' },
                    { codigo: 'CIC0090', nome: 'ML', nota: 8, justificativa: 'aplicações' },
                    { codigo: 'CIC0007', nome: 'Intro', nota: 5, justificativa: 'base' },
                ],
                resposta_completa: 'Texto da análise completa.',
            };
            const service = new SabiaService();

            const md = service.formatAsMarkdown(response);

            expect(md).toContain('Disciplinas Recomendadas pelo Sabiá');
            expect(md).toContain('**3 disciplinas**');
            expect(md).toContain('🌟 **CIC0004 - IA**'); // nota >= 9
            expect(md).toContain('✨ **CIC0090 - ML**'); // nota >= 7
            expect(md).toContain('📚 **CIC0007 - Intro**'); // nota < 7
            expect(md).toContain('Texto da análise completa.');
        });

        it('CAIXA-PRETA: omite a seção de análise completa quando não há resposta_completa', () => {
            const response: SabiaResponse = {
                success: true,
                disciplinas: [
                    { codigo: 'CIC0004', nome: 'IA', nota: 9, justificativa: 'núcleo' },
                ],
            };
            const md = new SabiaService().formatAsMarkdown(response);

            expect(md).toContain('CIC0004 - IA');
            expect(md).not.toContain('Análise Completa');
        });

        it('CAIXA-BRANCA: retorna a mensagem padrão quando success=false', () => {
            const md = new SabiaService().formatAsMarkdown({ success: false });
            expect(md).toContain('exclusivamente à recomendação de disciplinas acadêmicas');
        });

        it('CAIXA-BRANCA: retorna a mensagem padrão quando a lista de disciplinas está vazia', () => {
            const md = new SabiaService().formatAsMarkdown({ success: true, disciplinas: [] });
            expect(md).toContain('exclusivamente à recomendação de disciplinas acadêmicas');
        });
    });
});

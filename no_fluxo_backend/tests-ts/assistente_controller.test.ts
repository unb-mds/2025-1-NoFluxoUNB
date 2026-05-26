import { AssistenteController } from '../src/controllers/assistente_controller';
import { Request, Response } from 'express';
import { RagflowService } from '../src/services/ragflow.service';
import { SabiaService } from '../src/services/sabia.service';
import { SupabaseWrapper } from '../src/supabase_wrapper';

// Cria mock de query Supabase encadeável que resolve para `result`
function makeChain(result: { data: any; error: any }) {
  const chain: any = {};
  ['select', 'eq', 'or', 'in', 'order', 'limit', 'single', 'filter'].forEach(method => {
    chain[method] = jest.fn(() => chain);
  });
  chain.then = (res: any, rej: any) => Promise.resolve(result).then(res, rej);
  chain.catch = (fn: any) => Promise.resolve(result).catch(fn);
  chain.finally = (fn: any) => Promise.resolve(result).finally(fn);
  return chain;
}

jest.mock('../src/services/ragflow.service', () => ({
  RagflowService: jest.fn().mockImplementation(() => ({
    isAvailable: jest.fn(),
    startSession: jest.fn(),
    analyzeMateria: jest.fn(),
  })),
}));

jest.mock('../src/services/sabia.service', () => ({
  SabiaService: jest.fn().mockImplementation(() => ({
    isAvailable: jest.fn(),
    analyzarInteresse: jest.fn(),
    analyzarInteresseStream: jest.fn(),
    formatAsMarkdown: jest.fn(),
  })),
}));

jest.mock('../src/supabase_wrapper', () => {
  const mockFrom = jest.fn();
  return {
    SupabaseWrapper: { get: jest.fn(() => ({ from: mockFrom })) },
  };
});

// Evita que formatRanking quebre testes por receber resposta mockada incompleta
jest.mock('../src/utils/ranking.formatter', () => ({
  formatRanking: jest.fn(() => '# Resultado mockado'),
}));

// Instâncias criadas pelo controller no carregamento do módulo
let ragflow: any;
let sabia: any;

beforeAll(() => {
  ragflow = (RagflowService as jest.Mock).mock.results[0].value;
  sabia = (SabiaService as jest.Mock).mock.results[0].value;
});

describe('AssistenteController', () => {
  let req: Partial<Request>;
  let res: Partial<Response>;
  let mockFrom: jest.Mock;

  beforeEach(() => {
    req = { headers: {}, body: {}, query: {} };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      setHeader: jest.fn(),
      flushHeaders: jest.fn(),
      write: jest.fn(),
      end: jest.fn(),
    };
    mockFrom = (SupabaseWrapper.get() as any).from;

    // Default: serviços indisponíveis — testes que precisam sobrescrevem
    ragflow.isAvailable.mockReturnValue(false);
    sabia.isAvailable.mockReturnValue(false);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // POST /assistente/analyze
  // ───────────────────────────────────────────────────────────────────────────
  describe('POST analyze', () => {
    const handler = () => AssistenteController.routes['analyze'].value;

    it('retorna 400 quando materia não é informada', async () => {
      req.body = {};

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({
        erro: "O campo 'materia' é obrigatório no corpo da requisição JSON.",
      });
    });

    it('retorna 400 quando materia é string vazia', async () => {
      req.body = { materia: '   ' };

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    it('retorna 503 quando RAGFlow não está configurado', async () => {
      req.body = { materia: 'Cálculo 1' };
      ragflow.isAvailable.mockReturnValue(false);

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(503);
      expect(res.json).toHaveBeenCalledWith({
        erro: 'Serviço de IA indisponível. Configuração do RAGFlow ausente.',
      });
    });

    it('retorna 500 quando RAGFlow responde com code !== 0', async () => {
      req.body = { materia: 'Cálculo 1' };
      ragflow.isAvailable.mockReturnValue(true);
      ragflow.startSession.mockResolvedValue('session-abc');
      ragflow.analyzeMateria.mockResolvedValue({ code: 1, message: 'Erro no agente' });

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.erro).toContain('Erro no agente');
    });

    it('retorna 500 quando RAGFlow responde com code !== 0 sem mensagem', async () => {
      req.body = { materia: 'Cálculo 1' };
      ragflow.isAvailable.mockReturnValue(true);
      ragflow.startSession.mockResolvedValue('session-abc');
      ragflow.analyzeMateria.mockResolvedValue({ code: 2 });

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.erro).toContain('Erro desconhecido');
    });

    it('retorna 200 com resultado quando bem-sucedido', async () => {
      req.body = { materia: 'Cálculo 1' };
      ragflow.isAvailable.mockReturnValue(true);
      ragflow.startSession.mockResolvedValue('session-abc');
      ragflow.analyzeMateria.mockResolvedValue({ code: 0, data: [] });

      await handler()(req as Request, res as Response);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ resultado: expect.any(String) })
      );
    });

    it('retorna 500 quando startSession lança exceção', async () => {
      req.body = { materia: 'Cálculo 1' };
      ragflow.isAvailable.mockReturnValue(true);
      ragflow.startSession.mockRejectedValue(new Error('Timeout'));

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.erro).toContain('Timeout');
    });

    it('retorna 400 quando materia não é string (typeof check)', async () => {
      req.body = { materia: 123 };

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({
        erro: "O campo 'materia' é obrigatório no corpo da requisição JSON.",
      });
    });

    it('retorna 500 quando analyzeMateria lança exceção', async () => {
      req.body = { materia: 'Cálculo 1' };
      ragflow.isAvailable.mockReturnValue(true);
      ragflow.startSession.mockResolvedValue('session-xyz');
      ragflow.analyzeMateria.mockRejectedValue(new Error('Falha na análise'));

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.erro).toContain('Falha na análise');
    });

    it('retorna 500 com String(error) quando exceção não é instância de Error', async () => {
      req.body = { materia: 'Cálculo 1' };
      ragflow.isAvailable.mockReturnValue(true);
      ragflow.startSession.mockRejectedValue('falha inesperada');

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.erro).toContain('falha inesperada');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GET /assistente/health
  // ───────────────────────────────────────────────────────────────────────────
  describe('GET health', () => {
    const handler = () => AssistenteController.routes['health'].value;

    it('retorna status degraded quando nenhum serviço está disponível', async () => {
      ragflow.isAvailable.mockReturnValue(false);
      sabia.isAvailable.mockReturnValue(false);

      await handler()(req as Request, res as Response);

      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.status).toBe('degraded');
      expect(body.ragflowConfigured).toBe(false);
      expect(body.sabiaConfigured).toBe(false);
    });

    it('retorna status healthy quando RAGFlow disponível', async () => {
      ragflow.isAvailable.mockReturnValue(true);
      sabia.isAvailable.mockReturnValue(false);

      await handler()(req as Request, res as Response);

      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.status).toBe('healthy');
      expect(body.ragflowConfigured).toBe(true);
    });

    it('retorna status healthy quando Sabiá disponível', async () => {
      ragflow.isAvailable.mockReturnValue(false);
      sabia.isAvailable.mockReturnValue(true);

      await handler()(req as Request, res as Response);

      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.status).toBe('healthy');
      expect(body.sabiaConfigured).toBe(true);
    });

    it('resposta inclui service e timestamp', async () => {
      await handler()(req as Request, res as Response);

      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body).toHaveProperty('service');
      expect(body).toHaveProperty('timestamp');
    });

    it('retorna status healthy quando ambos os serviços estão disponíveis', async () => {
      ragflow.isAvailable.mockReturnValue(true);
      sabia.isAvailable.mockReturnValue(true);

      await handler()(req as Request, res as Response);

      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.status).toBe('healthy');
      expect(body.ragflowConfigured).toBe(true);
      expect(body.sabiaConfigured).toBe(true);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // POST /assistente/analyze-sabia
  // ───────────────────────────────────────────────────────────────────────────
  describe('POST analyze-sabia', () => {
    const handler = () => AssistenteController.routes['analyze-sabia'].value;

    it('retorna 400 quando materia não é informada', async () => {
      req.body = {};

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({
        erro: "O campo 'materia' é obrigatório no corpo da requisição JSON.",
      });
    });

    it('retorna 400 quando materia é string vazia', async () => {
      req.body = { materia: '' };

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    it('retorna 503 quando Sabiá não está configurado', async () => {
      req.body = { materia: 'Machine Learning' };
      sabia.isAvailable.mockReturnValue(false);

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(503);
    });

    it('retorna 500 quando Sabiá retorna success: false', async () => {
      req.body = { materia: 'Machine Learning' };
      sabia.isAvailable.mockReturnValue(true);
      sabia.analyzarInteresse.mockResolvedValue({ success: false, error: 'Falha no modelo' });

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.erro).toContain('Falha no modelo');
    });

    it('retorna 200 com resultado, disciplinas e agente quando bem-sucedido', async () => {
      req.body = { materia: 'Machine Learning', matriz_curricular: '2020/1' };
      sabia.isAvailable.mockReturnValue(true);
      const mockDisciplinas = [{ codigo: 'CIC0199', nome: 'IA', nota: 9.5, justificativa: 'Relevante' }];
      sabia.analyzarInteresse.mockResolvedValue({ success: true, disciplinas: mockDisciplinas });
      sabia.formatAsMarkdown.mockReturnValue('# Resultado Sabiá');

      await handler()(req as Request, res as Response);

      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.resultado).toBe('# Resultado Sabiá');
      expect(body.disciplinas).toEqual(mockDisciplinas);
      expect(body.agente).toBe('sabia');
    });

    it('usa string vazia para matriz_curricular quando não informada', async () => {
      req.body = { materia: 'Machine Learning' };
      sabia.isAvailable.mockReturnValue(true);
      sabia.analyzarInteresse.mockResolvedValue({ success: true, disciplinas: [] });
      sabia.formatAsMarkdown.mockReturnValue('');

      await handler()(req as Request, res as Response);

      expect(sabia.analyzarInteresse).toHaveBeenCalledWith('Machine Learning', '');
    });

    it('retorna 500 quando analyzarInteresse lança exceção', async () => {
      req.body = { materia: 'Machine Learning' };
      sabia.isAvailable.mockReturnValue(true);
      sabia.analyzarInteresse.mockRejectedValue(new Error('Conexão recusada'));

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.erro).toContain('Conexão recusada');
    });

    it('retorna 400 quando materia não é string (typeof check)', async () => {
      req.body = { materia: [] };

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({
        erro: "O campo 'materia' é obrigatório no corpo da requisição JSON.",
      });
    });

    it('retorna 500 com mensagem padrão quando success: false sem campo error', async () => {
      req.body = { materia: 'Machine Learning' };
      sabia.isAvailable.mockReturnValue(true);
      sabia.analyzarInteresse.mockResolvedValue({ success: false });

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.erro).toContain('Erro desconhecido no agente Sabiá.');
    });

    it('retorna 500 com String(error) quando exceção não é instância de Error', async () => {
      req.body = { materia: 'Machine Learning' };
      sabia.isAvailable.mockReturnValue(true);
      sabia.analyzarInteresse.mockRejectedValue('timeout de rede');

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.erro).toContain('timeout de rede');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // POST /assistente/analyze-sabia-stream
  // ───────────────────────────────────────────────────────────────────────────
  describe('POST analyze-sabia-stream', () => {
    const handler = () => AssistenteController.routes['analyze-sabia-stream'].value;

    it('retorna 400 quando materia não é informada', async () => {
      req.body = {};

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    it('retorna 503 quando Sabiá não está configurado', async () => {
      req.body = { materia: 'Algoritmos' };
      sabia.isAvailable.mockReturnValue(false);

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(503);
    });

    it('configura headers SSE e chama analyzarInteresseStream quando bem-sucedido', async () => {
      req.body = { materia: 'Algoritmos', matriz_curricular: '2020/1' };
      sabia.isAvailable.mockReturnValue(true);
      sabia.analyzarInteresseStream.mockResolvedValue(undefined);

      await handler()(req as Request, res as Response);

      expect(res.setHeader).toHaveBeenCalledWith('Content-Type', 'text/event-stream');
      expect(res.setHeader).toHaveBeenCalledWith('Cache-Control', 'no-cache');
      expect(res.flushHeaders).toHaveBeenCalled();
      expect(sabia.analyzarInteresseStream).toHaveBeenCalledWith('Algoritmos', '2020/1', res);
    });

    it('escreve evento de erro e encerra stream quando analyzarInteresseStream lança exceção', async () => {
      req.body = { materia: 'Algoritmos' };
      sabia.isAvailable.mockReturnValue(true);
      sabia.analyzarInteresseStream.mockRejectedValue(new Error('Stream falhou'));

      await handler()(req as Request, res as Response);

      const writtenData = (res.write as jest.Mock).mock.calls[0][0] as string;
      expect(writtenData).toContain('error');
      expect(writtenData).toContain('Stream falhou');
      expect(res.end).toHaveBeenCalled();
    });

    it('retorna 400 quando materia não é string no stream', async () => {
      req.body = { materia: null };

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    it('configura todos os 4 headers SSE incluindo Connection e X-Accel-Buffering', async () => {
      req.body = { materia: 'Algoritmos' };
      sabia.isAvailable.mockReturnValue(true);
      sabia.analyzarInteresseStream.mockResolvedValue(undefined);

      await handler()(req as Request, res as Response);

      expect(res.setHeader).toHaveBeenCalledWith('Connection', 'keep-alive');
      expect(res.setHeader).toHaveBeenCalledWith('X-Accel-Buffering', 'no');
    });

    it('normaliza matriz_curricular não-string para string vazia no stream', async () => {
      req.body = { materia: 'Algoritmos', matriz_curricular: 42 };
      sabia.isAvailable.mockReturnValue(true);
      sabia.analyzarInteresseStream.mockResolvedValue(undefined);

      await handler()(req as Request, res as Response);

      expect(sabia.analyzarInteresseStream).toHaveBeenCalledWith('Algoritmos', '', res);
    });

    it('encerra stream com String(error) quando exceção não é instância de Error', async () => {
      req.body = { materia: 'Algoritmos' };
      sabia.isAvailable.mockReturnValue(true);
      sabia.analyzarInteresseStream.mockRejectedValue('erro primitivo');

      await handler()(req as Request, res as Response);

      const writtenData = (res.write as jest.Mock).mock.calls[0][0] as string;
      expect(writtenData).toContain('erro primitivo');
      expect(res.end).toHaveBeenCalled();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GET /assistente/turmas-by-codigo
  // ───────────────────────────────────────────────────────────────────────────
  describe('GET turmas-by-codigo', () => {
    const handler = () => AssistenteController.routes['turmas-by-codigo'].value;

    it('retorna 400 quando codigo não é informado', async () => {
      req.query = {};

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ erro: "Informe o parâmetro 'codigo'." });
    });

    it('retorna turmas vazias quando matéria não é encontrada', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: [], error: null }));

      await handler()(req as Request, res as Response);

      expect(res.json).toHaveBeenCalledWith({ turmas: [], ultimaAtualizacaoTurmas: null });
    });

    it('retorna 500 quando erro ao buscar matéria', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: null, error: { message: 'DB error' } }));

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith({ erro: 'Erro ao buscar matéria.' });
    });

    it('retorna 500 quando erro ao buscar turmas', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: [{ id_materia: 1 }], error: null }));
      mockFrom.mockImplementationOnce(() => makeChain({ data: null, error: { message: 'Turmas error' } }));

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith({ erro: 'Erro ao buscar turmas.' });
    });

    it('retorna turmas formatadas e ultimaAtualizacaoTurmas quando bem-sucedido', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: [{ id_materia: 42 }], error: null }));
      mockFrom.mockImplementationOnce(() =>
        makeChain({
          data: [
            {
              turma: 'A',
              ano_periodo: '2024/1',
              docente: 'Prof. Silva',
              horario: '10:00',
              local: 'S1 02',
              vagas_ofertadas: 40,
              vagas_ocupadas: 35,
              vagas_sobrando: 5,
              last_updated_at: '2024-06-01T00:00:00Z',
            },
          ],
          error: null,
        })
      );

      await handler()(req as Request, res as Response);

      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.turmas).toHaveLength(1);
      expect(body.turmas[0].turma).toBe('A');
      expect(body.turmas[0].docente).toBe('Prof. Silva');
      expect(body.turmas[0].vagasOfertadas).toBe(40);
      expect(body.ultimaAtualizacaoTurmas).toBe('2024-06-01T00:00:00Z');
    });

    it('normaliza codigo para maiúsculo antes de buscar', async () => {
      req.query = { codigo: 'mat0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: [], error: null }));

      await handler()(req as Request, res as Response);

      // Deve buscar turmas vazias (matéria não encontrada) sem erro
      expect(res.json).toHaveBeenCalledWith({ turmas: [], ultimaAtualizacaoTurmas: null });
    });

    it('usa updated_at como fallback quando last_updated_at é null', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: [{ id_materia: 1 }], error: null }));
      mockFrom.mockImplementationOnce(() =>
        makeChain({
          data: [
            {
              turma: 'B',
              ano_periodo: '2024/2',
              docente: 'Prof. Costa',
              horario: '14:00',
              local: 'S2 01',
              vagas_ofertadas: 30,
              vagas_ocupadas: 20,
              vagas_sobrando: 10,
              last_updated_at: null,
              updated_at: '2024-07-01T00:00:00Z',
            },
          ],
          error: null,
        })
      );

      await handler()(req as Request, res as Response);

      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.turmas[0].lastUpdatedAt).toBe('2024-07-01T00:00:00Z');
      expect(body.ultimaAtualizacaoTurmas).toBe('2024-07-01T00:00:00Z');
    });

    it('ultimaAtualizacaoTurmas retorna a data mais recente entre múltiplas turmas', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: [{ id_materia: 1 }], error: null }));
      mockFrom.mockImplementationOnce(() =>
        makeChain({
          data: [
            { turma: 'A', ano_periodo: '2024/1', docente: '', horario: '', local: '',
              vagas_ofertadas: null, vagas_ocupadas: null, vagas_sobrando: null,
              last_updated_at: '2024-01-01T00:00:00Z' },
            { turma: 'B', ano_periodo: '2024/2', docente: '', horario: '', local: '',
              vagas_ofertadas: null, vagas_ocupadas: null, vagas_sobrando: null,
              last_updated_at: '2024-09-01T00:00:00Z' },
            { turma: 'C', ano_periodo: '2023/2', docente: '', horario: '', local: '',
              vagas_ofertadas: null, vagas_ocupadas: null, vagas_sobrando: null,
              last_updated_at: '2023-12-01T00:00:00Z' },
          ],
          error: null,
        })
      );

      await handler()(req as Request, res as Response);

      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.turmas).toHaveLength(3);
      expect(body.ultimaAtualizacaoTurmas).toBe('2024-09-01T00:00:00Z');
    });

    it('retorna 500 com "Erro interno:" quando SupabaseWrapper lança exceção', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => { throw new Error('DB indisponível'); });

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.erro).toContain('Erro interno:');
      expect(body.erro).toContain('DB indisponível');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GET /assistente/prerequisitos-by-codigo
  // ───────────────────────────────────────────────────────────────────────────
  describe('GET prerequisitos-by-codigo', () => {
    const handler = () => AssistenteController.routes['prerequisitos-by-codigo'].value;

    it('retorna 400 quando codigo não é informado', async () => {
      req.query = {};

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ erro: "Informe o parâmetro 'codigo'." });
    });

    it('retorna prerequisitos vazio quando matéria não é encontrada', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: [], error: null }));

      await handler()(req as Request, res as Response);

      expect(res.json).toHaveBeenCalledWith({ prerequisitos: [] });
    });

    it('retorna 500 quando erro ao buscar matéria', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: null, error: { message: 'DB error' } }));

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith({ erro: 'Erro ao buscar matéria.' });
    });

    it('retorna 500 quando erro ao buscar pré-requisitos', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: [{ id_materia: 1 }], error: null }));
      mockFrom.mockImplementationOnce(() => makeChain({ data: null, error: { message: 'PreReq error' } }));

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith({ erro: 'Erro ao buscar pré-requisitos.' });
    });

    it('retorna lista de pré-requisitos quando bem-sucedido', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: [{ id_materia: 1 }], error: null }));
      const mockPreReqs = [
        { id_materia_requisito: 2, expressao_original: 'MAT0025', expressao_logica: 'MAT0025' },
      ];
      mockFrom.mockImplementationOnce(() => makeChain({ data: mockPreReqs, error: null }));

      await handler()(req as Request, res as Response);

      expect(res.json).toHaveBeenCalledWith({ prerequisitos: mockPreReqs });
    });

    it('retorna prerequisitos: [] quando banco retorna null', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: [{ id_materia: 1 }], error: null }));
      mockFrom.mockImplementationOnce(() => makeChain({ data: null, error: null }));

      await handler()(req as Request, res as Response);

      expect(res.json).toHaveBeenCalledWith({ prerequisitos: [] });
    });

    it('retorna 500 com "Erro interno:" quando SupabaseWrapper lança exceção', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => { throw new Error('Conexão perdida'); });

      await handler()(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(500);
      const body = (res.json as jest.Mock).mock.calls[0][0];
      expect(body.erro).toContain('Erro interno:');
      expect(body.erro).toContain('Conexão perdida');
    });

    it('retorna múltiplos pré-requisitos quando banco retorna vários', async () => {
      req.query = { codigo: 'MAT0026' };
      mockFrom.mockImplementationOnce(() => makeChain({ data: [{ id_materia: 5 }], error: null }));
      const mockPreReqs = [
        { id_materia_requisito: 1, expressao_original: 'MAT0001', expressao_logica: 'MAT0001' },
        { id_materia_requisito: 2, expressao_original: 'MAT0002', expressao_logica: 'MAT0002' },
      ];
      mockFrom.mockImplementationOnce(() => makeChain({ data: mockPreReqs, error: null }));

      await handler()(req as Request, res as Response);

      expect(res.json).toHaveBeenCalledWith({ prerequisitos: mockPreReqs });
    });
  });
});

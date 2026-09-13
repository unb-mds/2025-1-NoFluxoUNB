import { MlIngestController } from '../src/controllers/ml_ingest_controller';
import { Request, Response } from 'express';
import { SupabaseWrapper } from '../src/supabase_wrapper';

jest.mock('../src/supabase_wrapper', () => {
  const mockUpsert = jest.fn();
  const mockFrom = jest.fn(() => ({
    upsert: mockUpsert,
  }));
  const mockGet = jest.fn(() => ({
    from: mockFrom,
  }));

  return {
    SupabaseWrapper: {
      get: mockGet,
    },
  };
});

const VALID_KEY = process.env.ML_PUSH_API_KEY as string;

const validScore = {
  id_user: 42,
  risk: 0.73,
  model_version: 'v1',
  computed_at: '2026-09-13T10:00:00Z',
};

describe('MlIngestController — POST /internal/ml/scores', () => {
  let mockRequest: Partial<Request>;
  let mockResponse: Partial<Response>;
  let mockUpsert: jest.Mock;

  const handler = MlIngestController.routes['scores'].value;

  beforeEach(() => {
    mockResponse = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    mockUpsert = (SupabaseWrapper.get().from('ml_risco_scores') as any).upsert;
    mockUpsert.mockResolvedValue({ error: null });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  function makeRequest(headers: Record<string, unknown>, body: unknown): Partial<Request> {
    return { headers: headers as any, body };
  }

  describe('autenticação', () => {
    it('retorna 401 quando o header X-API-Key está ausente', async () => {
      mockRequest = makeRequest({}, { scores: [validScore] });
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(401);
    });

    it('retorna 401 quando o X-API-Key está incorreto', async () => {
      mockRequest = makeRequest({ 'x-api-key': 'chave-errada' }, { scores: [validScore] });
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(401);
    });

    it('não chama o upsert quando a autenticação falha', async () => {
      mockRequest = makeRequest({ 'x-api-key': 'chave-errada' }, { scores: [validScore] });
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockUpsert).not.toHaveBeenCalled();
    });
  });

  describe('validação do body', () => {
    it('retorna 400 quando codigo_materia_critico é uma string vazia', async () => {
      mockRequest = makeRequest(
        { 'x-api-key': VALID_KEY },
        { scores: [{ ...validScore, codigo_materia_critico: '' }] }
      );
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(400);
    });

    it('retorna 400 quando codigo_materia_critico não é string nem null', async () => {
      mockRequest = makeRequest(
        { 'x-api-key': VALID_KEY },
        { scores: [{ ...validScore, codigo_materia_critico: 123 }] }
      );
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(400);
    });

    it('retorna 400 quando scores está ausente', async () => {
      mockRequest = makeRequest({ 'x-api-key': VALID_KEY }, {});
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(400);
    });

    it('retorna 400 quando scores é um array vazio', async () => {
      mockRequest = makeRequest({ 'x-api-key': VALID_KEY }, { scores: [] });
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(400);
    });

    it('retorna 400 quando scores não é um array', async () => {
      mockRequest = makeRequest({ 'x-api-key': VALID_KEY }, { scores: 'não é array' });
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(400);
    });

    it('retorna 400 quando scores excede 500 itens', async () => {
      const many = Array.from({ length: 501 }, (_, i) => ({ ...validScore, id_user: i + 1 }));
      mockRequest = makeRequest({ 'x-api-key': VALID_KEY }, { scores: many });
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(400);
    });

    it('retorna 400 quando id_user não é um inteiro positivo', async () => {
      mockRequest = makeRequest(
        { 'x-api-key': VALID_KEY },
        { scores: [{ ...validScore, id_user: -1 }] }
      );
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(400);
    });

    it('retorna 400 quando id_user é uma string numérica (sem coagir tipo)', async () => {
      mockRequest = makeRequest(
        { 'x-api-key': VALID_KEY },
        { scores: [{ ...validScore, id_user: '42' }] }
      );
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(400);
    });

    it('retorna 400 quando risk está fora da faixa [0,1]', async () => {
      mockRequest = makeRequest(
        { 'x-api-key': VALID_KEY },
        { scores: [{ ...validScore, risk: 1.5 }] }
      );
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(400);
    });

    it('retorna 400 quando model_version está vazio', async () => {
      mockRequest = makeRequest(
        { 'x-api-key': VALID_KEY },
        { scores: [{ ...validScore, model_version: '' }] }
      );
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(400);
    });

    it('retorna 400 quando computed_at não é uma data ISO 8601 válida', async () => {
      mockRequest = makeRequest(
        { 'x-api-key': VALID_KEY },
        { scores: [{ ...validScore, computed_at: 'ontem' }] }
      );
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockResponse.status).toHaveBeenCalledWith(400);
    });

    it('não chama o upsert quando a validação falha', async () => {
      mockRequest = makeRequest({ 'x-api-key': VALID_KEY }, { scores: [] });
      await handler(mockRequest as Request, mockResponse as Response);
      expect(mockUpsert).not.toHaveBeenCalled();
    });
  });

  describe('caminho feliz', () => {
    it('aceita codigo_materia_critico e inclui no upsert', async () => {
      const scoreComDisciplina = { ...validScore, codigo_materia_critico: 'MAT0025' };
      mockRequest = makeRequest({ 'x-api-key': VALID_KEY }, { scores: [scoreComDisciplina] });
      await handler(mockRequest as Request, mockResponse as Response);

      expect(mockUpsert).toHaveBeenCalledWith([scoreComDisciplina], { onConflict: 'id_user' });
      expect(mockResponse.status).toHaveBeenCalledWith(200);
    });

    it('grava null quando codigo_materia_critico está ausente', async () => {
      mockRequest = makeRequest({ 'x-api-key': VALID_KEY }, { scores: [validScore] });
      await handler(mockRequest as Request, mockResponse as Response);

      expect(mockUpsert).toHaveBeenCalledWith(
        [{ ...validScore, codigo_materia_critico: null }],
        { onConflict: 'id_user' }
      );
    });

    it('faz upsert em ml_risco_scores com onConflict id_user e retorna 200', async () => {
      mockRequest = makeRequest({ 'x-api-key': VALID_KEY }, { scores: [validScore] });
      await handler(mockRequest as Request, mockResponse as Response);

      expect(SupabaseWrapper.get().from).toHaveBeenLastCalledWith('ml_risco_scores');
      expect(mockUpsert).toHaveBeenCalledWith([{ ...validScore, codigo_materia_critico: null }], { onConflict: 'id_user' });
      expect(mockResponse.status).toHaveBeenCalledWith(200);
      expect(mockResponse.json).toHaveBeenCalledWith({ ok: true, upserted: 1 });
    });

    it('mesmo id_user duplicado no lote é deduplicado antes do upsert (mantém o último, não duplica)', async () => {
      const primeiraVersao = { ...validScore, risk: 0.1 };
      const ultimaVersao = { ...validScore, risk: 0.9 };
      mockRequest = makeRequest({ 'x-api-key': VALID_KEY }, { scores: [primeiraVersao, ultimaVersao] });
      await handler(mockRequest as Request, mockResponse as Response);

      expect(mockUpsert).toHaveBeenCalledWith(
        [{ ...ultimaVersao, codigo_materia_critico: null }],
        { onConflict: 'id_user' }
      );
      expect(mockResponse.status).toHaveBeenCalledWith(200);
      expect(mockResponse.json).toHaveBeenCalledWith({ ok: true, upserted: 1 });
    });

    it('retorna 500 quando o upsert falha no banco', async () => {
      mockUpsert.mockResolvedValue({ error: { message: 'db indisponível' } });
      mockRequest = makeRequest({ 'x-api-key': VALID_KEY }, { scores: [validScore] });
      await handler(mockRequest as Request, mockResponse as Response);

      expect(mockResponse.status).toHaveBeenCalledWith(500);
    });
  });
});

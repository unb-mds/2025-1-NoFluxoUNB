import { FluxogramaController } from '../src/controllers/fluxograma_controller';
import { Request, Response } from 'express';
import { SupabaseWrapper } from '../src/supabase_wrapper';

// Mock do SupabaseWrapper
jest.mock('../src/supabase_wrapper', () => {
  const mockEq = jest.fn();
  const mockSelect = jest.fn(() => ({
    eq: mockEq,
    like: jest.fn(() => ({
      select: jest.fn(),
    })),
  }));
  const mockLike = jest.fn(() => ({
    select: mockSelect,
  }));
  const mockOr = jest.fn(() => ({
    select: mockSelect,
  }));
  const mockIn = jest.fn(() => ({
    select: mockSelect,
  }));
  const mockFrom = jest.fn(() => ({
    select: mockSelect,
    like: mockLike,
    or: mockOr,
    in: mockIn,
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

describe('FluxogramaController', () => {
  let mockRequest: Partial<Request>;
  let mockResponse: Partial<Response>;
  let statusSpy: jest.SpyInstance;
  let jsonSpy: jest.SpyInstance;
  let mockFrom: jest.Mock;

  beforeEach(() => {
    mockRequest = {};
    mockResponse = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    statusSpy = jest.spyOn(mockResponse, 'status');
    jsonSpy = jest.spyOn(mockResponse, 'json');
    
    // Pega os mocks
    mockFrom = (SupabaseWrapper.get() as any).from;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('fluxograma', () => {
    it('should return 400 if nome_curso is missing', async () => {
      mockRequest.query = {};

      const handler = FluxogramaController.routes["fluxograma"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(400);
      expect(jsonSpy).toHaveBeenCalledWith({ error: "Nome do curso não informado" });
    });

    it('should return 200 with fluxograma data when successful', async () => {
      mockRequest.query = { nome_curso: 'Administração' };
      const mockCursosData = [
        {
          id_curso: 1,
          nome_curso: 'Administração',
          matriz_curricular: 2020,
          materias_por_curso: [
            {
              nivel: 1,
              materias: {
                id_materia: 1,
                nome_materia: 'Matemática',
                codigo_materia: 'MAT001'
              }
            }
          ]
        }
      ];

      // Mock select().like() para cursos
      const mockLike = jest.fn().mockResolvedValue({ data: mockCursosData, error: null });
      const mockSelectCursos = jest.fn(() => ({ like: mockLike }));
      mockFrom.mockImplementationOnce(() => ({ select: mockSelectCursos }));

      // Mock para equivalencias: select().or().or()
      const mockOr2 = jest.fn().mockResolvedValue({ data: [], error: null });
      const mockOr1 = jest.fn(() => ({ or: mockOr2 }));
      const mockSelectEquivalencias = jest.fn(() => ({ or: mockOr1 }));
      mockFrom.mockImplementationOnce(() => ({ select: mockSelectEquivalencias }));

      // Mock para pre_requisitos: select().in()
      const mockIn = jest.fn().mockResolvedValue({ data: [], error: null });
      const mockSelectPreReq = jest.fn(() => ({ in: mockIn }));
      mockFrom.mockImplementationOnce(() => ({ select: mockSelectPreReq }));

      const handler = FluxogramaController.routes["fluxograma"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(200);
      expect(jsonSpy).toHaveBeenCalledWith(mockCursosData);
    });

    it('should return 500 when database error occurs', async () => {
      mockRequest.query = { nome_curso: 'Administração' };
      const mockError = { message: 'Database error' };

      // Mock select().like() para cursos (erro)
      const mockLike = jest.fn().mockResolvedValue({ data: null, error: mockError });
      const mockSelectCursos = jest.fn(() => ({ like: mockLike }));
      mockFrom.mockImplementationOnce(() => ({ select: mockSelectCursos }));

      const handler = FluxogramaController.routes["fluxograma"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(500);
      expect(jsonSpy).toHaveBeenCalledWith({ error: mockError.message });
    });
  });
}); 
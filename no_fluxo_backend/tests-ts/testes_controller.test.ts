import { TestesController } from '../src/controllers/testes_controller';
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
  const mockLimit = jest.fn(() => ({
    select: mockSelect,
  }));
  const mockFrom = jest.fn(() => ({
    select: mockSelect,
    like: mockLike,
    or: mockOr,
    in: mockIn,
    limit: mockLimit,
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

describe('TestesController', () => {
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
    mockFrom = (SupabaseWrapper.get() as any).from;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('banco', () => {
    it('should return 200 with database test results when successful', async () => {
      const mockCursosData = [
        { nome_curso: 'Administração' },
        { nome_curso: 'Engenharia' }
      ];
      
      const mockMateriasData = [
        {
          nome_curso: 'Administração',
          materias_por_curso: [
            {
              id_materia: 1,
              nivel: 1,
              materias: {
                id_materia: 1,
                nome_materia: 'Matemática',
                codigo_materia: 'MAT001'
              }
            },
            {
              id_materia: 2,
              nivel: 2,
              materias: {
                id_materia: 2,
                nome_materia: 'Português',
                codigo_materia: 'PORT001'
              }
            }
          ]
        }
      ];

      // Mock primeira chamada - cursos
      const mockSelectChain1 = jest.fn().mockResolvedValueOnce({
        data: mockCursosData,
        error: null,
      });

      // Mock segunda chamada - materias_por_curso
      const mockSelectChain2 = jest.fn().mockResolvedValueOnce({
        data: mockMateriasData,
        error: null,
      });

      const mockLimitChain = jest.fn().mockReturnValue({
        select: mockSelectChain2,
      });

      mockFrom.mockReturnValueOnce({
        select: mockSelectChain1,
      }).mockReturnValueOnce({
        select: jest.fn().mockReturnValue({
          limit: mockLimitChain,
        }),
      });

      const handler = TestesController.routes["banco"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(200);
      const responseData = jsonSpy.mock.calls[0][0];
      expect(responseData.teste).toBe('conexao_banco');
      expect(responseData.status).toBe('sucesso');
    });

    it('should return 500 when cursos query fails', async () => {
      const mockError = { message: 'Database error' };

      const mockSelectChain = jest.fn().mockResolvedValueOnce({
        data: null,
        error: mockError,
      });

      mockFrom.mockReturnValueOnce({
        select: mockSelectChain,
      });

      const handler = TestesController.routes["banco"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(500);
      expect(jsonSpy).toHaveBeenCalledWith({
        teste: 'conexao_banco',
        status: 'erro',
        erro: mockError.message
      });
    });
  });

  describe('curso', () => {
    it('should return 200 with course test results when course is found', async () => {
      mockRequest.query = { nome_curso: 'Administração' };
      
      const mockMateriasData = [
        {
          nome_curso: 'Administração',
          materias_por_curso: [
            {
              id_materia: 1,
              nivel: 1,
              materias: {
                id_materia: 1,
                nome_materia: 'Matemática',
                codigo_materia: 'MAT001'
              }
            },
            {
              id_materia: 2,
              nivel: 2,
              materias: {
                id_materia: 2,
                nome_materia: 'Português',
                codigo_materia: 'PORT001'
              }
            }
          ]
        }
      ];

      // Primeira chamada: busca curso
      const mockLike = jest.fn().mockResolvedValue({ data: mockMateriasData, error: null });
      const mockSelect = jest.fn(() => ({ like: mockLike }));
      mockFrom.mockImplementationOnce(() => ({ select: mockSelect }));

      const handler = TestesController.routes["curso"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(200);
      const responseData = jsonSpy.mock.calls[0][0];
      expect(responseData.teste).toBe('busca_curso');
      expect(responseData.status).toBe('sucesso');
    });

    it('should return 404 when course is not found', async () => {
      mockRequest.query = { nome_curso: 'Curso Inexistente' };
      
      const mockCursosData = [
        { nome_curso: 'Administração' },
        { nome_curso: 'Engenharia' }
      ];

      // Primeira chamada: busca curso (retorna vazio)
      const mockLike = jest.fn().mockResolvedValue({ data: [], error: null });
      const mockSelect = jest.fn(() => ({ like: mockLike }));
      mockFrom.mockImplementationOnce(() => ({ select: mockSelect }));
      // Segunda chamada: lista todos os cursos
      const mockSelectCursos = jest.fn().mockResolvedValue({ data: mockCursosData, error: null });
      mockFrom.mockImplementationOnce(() => ({ select: mockSelectCursos }));

      const handler = TestesController.routes["curso"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(404);
      expect(jsonSpy).toHaveBeenCalledWith({
        teste: 'busca_curso',
        status: 'curso_nao_encontrado',
        curso_buscado: 'Curso Inexistente',
        cursos_disponiveis: ['Administração', 'Engenharia']
      });
    });
  });

  describe('casamento', () => {
    it('should return 200 with matching results when successful', async () => {
      mockRequest.body = {
        dados_extraidos: {
          extracted_data: [
            {
              tipo_dado: 'Disciplina Regular',
              nome: 'Matemática',
              codigo: 'MAT001',
              status: 'APR'
            }
          ]
        },
        nome_curso: 'Administração'
      };

      const mockMateriasData = [
        {
          nome_curso: 'Administração',
          materias_por_curso: [
            {
              id_materia: 1,
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

      // Primeira chamada: busca curso
      const mockLike = jest.fn().mockResolvedValue({ data: mockMateriasData, error: null });
      const mockSelect = jest.fn(() => ({ like: mockLike }));
      mockFrom.mockImplementationOnce(() => ({ select: mockSelect }));

      const handler = TestesController.routes["casamento"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(200);
      const responseData = jsonSpy.mock.calls[0][0];
      expect(responseData.teste).toBe('casamento_disciplinas');
      expect(responseData.status).toBe('sucesso');
    });
  });
}); 
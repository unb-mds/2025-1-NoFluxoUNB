import { CursosController } from '../src/controllers/cursos_controller';
import { Request, Response } from 'express';
import { SupabaseWrapper } from '../src/supabase_wrapper';

// Mock do SupabaseWrapper
jest.mock('../src/supabase_wrapper', () => {
  const mockSelect = jest.fn();
  const mockFrom = jest.fn(() => ({
    select: mockSelect,
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

describe('CursosController', () => {
  let mockRequest: Partial<Request>;
  let mockResponse: Partial<Response>;
  let statusSpy: jest.SpyInstance;
  let jsonSpy: jest.SpyInstance;

  beforeEach(() => {
    mockRequest = {};
    mockResponse = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    statusSpy = jest.spyOn(mockResponse, 'status');
    jsonSpy = jest.spyOn(mockResponse, 'json');
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should return 200 with cursos data when successful', async () => {
    const mockCursosData = [
      { id_curso: 1, nome_curso: 'Administração' },
      { id_curso: 2, nome_curso: 'Engenharia' }
    ];
    const mockCreditosData = [
      { id_curso: 1, creditos_obrigatorios: 180 },
      { id_curso: 2, creditos_obrigatorios: 240 }
    ];

    // Mock first call to cursos table
    (SupabaseWrapper.get().from('cursos').select as jest.Mock)
      .mockResolvedValueOnce({
        data: mockCursosData,
        error: null,
      })
      // Mock second call to creditos_por_curso table
      .mockResolvedValueOnce({
        data: mockCreditosData,
        error: null,
      });

    const handler = CursosController.routes["all-cursos"].value;
    await handler(mockRequest as Request, mockResponse as Response);

    expect(statusSpy).toHaveBeenCalledWith(200);
    expect(jsonSpy).toHaveBeenCalledWith([
      { id_curso: 1, nome_curso: 'Administração', creditos: 180 },
      { id_curso: 2, nome_curso: 'Engenharia', creditos: 240 }
    ]);
  });

  it('should return 500 when cursos query fails', async () => {
    const mockError = { message: 'Database error' };

    (SupabaseWrapper.get().from('cursos').select as jest.Mock)
      .mockResolvedValueOnce({
        data: null,
        error: mockError,
      });

    const handler = CursosController.routes["all-cursos"].value;
    await handler(mockRequest as Request, mockResponse as Response);

    expect(statusSpy).toHaveBeenCalledWith(500);
    expect(jsonSpy).toHaveBeenCalledWith({ error: mockError.message });
  });

  it('should return 500 when creditos_por_curso query fails', async () => {
    const mockCursosData = [{ id_curso: 1, nome_curso: 'Administração' }];
    const mockError = { message: 'Creditos query error' };

    (SupabaseWrapper.get().from('cursos').select as jest.Mock)
      .mockResolvedValueOnce({
        data: mockCursosData,
        error: null,
      })
      .mockResolvedValueOnce({
        data: null,
        error: mockError,
      });

    const handler = CursosController.routes["all-cursos"].value;
    await handler(mockRequest as Request, mockResponse as Response);

    expect(statusSpy).toHaveBeenCalledWith(500);
    expect(jsonSpy).toHaveBeenCalledWith({ error: mockError.message });
  });
}); 
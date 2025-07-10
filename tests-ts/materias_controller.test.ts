import { MateriasController } from '../materias_controller';
import { Request, Response } from 'express';
import { SupabaseWrapper } from '../../supabase_wrapper';

// Mock do SupabaseWrapper
jest.mock('../../supabase_wrapper', () => {
  const mockIn = jest.fn();
  const mockSelect = jest.fn(() => ({
    in: mockIn,
  }));
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

describe('MateriasController', () => {
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

  it('should return 400 if codes are not provided', async () => {
    mockRequest.body = {};

    const handler = MateriasController.routes["materias-name-by-code"].value;
    await handler(mockRequest as Request, mockResponse as Response);

    expect(statusSpy).toHaveBeenCalledWith(400);
    expect(jsonSpy).toHaveBeenCalledWith({ error: "Códigos não informados" });
  });

  it('should return 200 with data if codes are provided and Supabase returns data', async () => {
    mockRequest.body = { codes: ['FGA0001', 'FGA0002'] };
    const mockData = [{ codigo_materia: 'FGA0001', nome_materia: 'Materia 1' }];

    // Mock the return value of the 'in' method
    (SupabaseWrapper.get().from('materias').select('*').in as jest.Mock).mockResolvedValueOnce({
      data: mockData,
      error: null,
    });

    const handler = MateriasController.routes["materias-name-by-code"].value;
    await handler(mockRequest as Request, mockResponse as Response);

    expect(statusSpy).toHaveBeenCalledWith(200);
    expect(jsonSpy).toHaveBeenCalledWith(mockData);
    expect(SupabaseWrapper.get().from).toHaveBeenCalledWith('materias');
    expect(SupabaseWrapper.get().from('materias').select).toHaveBeenCalledWith('*');
    expect(SupabaseWrapper.get().from('materias').select('*').in).toHaveBeenCalledWith('codigo_materia', ['FGA0001', 'FGA0002']);
  });

  it('should return 500 if Supabase returns an error', async () => {
    mockRequest.body = { codes: ['FGA0001'] };
    const mockError = { message: 'Database error' };

    // Mock the return value of the 'in' method
    (SupabaseWrapper.get().from('materias').select('*').in as jest.Mock).mockResolvedValueOnce({
      data: null,
      error: mockError,
    });

    const handler = MateriasController.routes["materias-name-by-code"].value;
    await handler(mockRequest as Request, mockResponse as Response);

    expect(statusSpy).toHaveBeenCalledWith(500);
    expect(jsonSpy).toHaveBeenCalledWith({ error: mockError.message });
  });
});

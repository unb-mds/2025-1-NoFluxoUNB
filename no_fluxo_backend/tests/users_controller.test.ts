import { UsersController } from '../src/controllers/users_controller';
import { Request, Response } from 'express';
import { SupabaseWrapper } from '../src/supabase_wrapper';

// Mock do SupabaseWrapper
jest.mock('../src/supabase_wrapper', () => {
  const mockEq = jest.fn();
  const mockSelect = jest.fn(() => ({
    eq: mockEq,
  }));
  const mockSingle = jest.fn();
  const mockInsert = jest.fn(() => ({
    select: jest.fn(() => ({
      single: mockSingle,
    })),
  }));
  const mockFrom = jest.fn(() => ({
    select: mockSelect,
    insert: mockInsert,
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

describe('UsersController', () => {
  let mockRequest: Partial<Request>;
  let mockResponse: Partial<Response>;
  let statusSpy: jest.SpyInstance;
  let jsonSpy: jest.SpyInstance;
  let mockEq: jest.Mock;
  let mockInsert: jest.Mock;
  let mockSelect: jest.Mock;
  let mockSingle: jest.Mock;

  beforeEach(() => {
    mockRequest = {};
    mockResponse = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    statusSpy = jest.spyOn(mockResponse, 'status');
    jsonSpy = jest.spyOn(mockResponse, 'json');
    // Pega os mocks
    mockSelect = (SupabaseWrapper.get().from('users') as any).select;
    mockEq = (mockSelect() as any).eq;
    mockInsert = (SupabaseWrapper.get().from('users') as any).insert;
    mockSingle = (mockInsert().select() as any).single;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('register-user-with-google', () => {
    it('should return 400 if email or nome_completo is missing', async () => {
      mockRequest.body = { email: 'test@example.com' };

      const handler = UsersController.routes["register-user-with-google"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(400);
      expect(jsonSpy).toHaveBeenCalledWith({ error: "Email e nome completo são obrigatórios" });
    });

    it('should return 400 if user already exists', async () => {
      mockRequest.body = { email: 'test@example.com', nome_completo: 'Test User' };

      mockEq.mockResolvedValueOnce({
        data: [{ id: 1, email: 'test@example.com' }],
        error: null,
      });

      const handler = UsersController.routes["register-user-with-google"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(400);
      expect(jsonSpy).toHaveBeenCalledWith({ error: "Usuário já cadastrado" });
    });

    it('should return 200 when user is created successfully', async () => {
      mockRequest.body = { email: 'test@example.com', nome_completo: 'Test User' };
      const mockUser = { id: 1, email: 'test@example.com', nome_completo: 'Test User' };

      mockEq.mockResolvedValueOnce({
        data: [],
        error: null,
      });
      mockSingle.mockResolvedValueOnce({
        data: mockUser,
        error: null,
      });

      const handler = UsersController.routes["register-user-with-google"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(200);
      expect(jsonSpy).toHaveBeenCalledWith(mockUser);
    });

    it('should return 500 when database error occurs during user check', async () => {
      mockRequest.body = { email: 'test@example.com', nome_completo: 'Test User' };
      const mockError = { message: 'Database error' };

      mockEq.mockResolvedValueOnce({
        data: null,
        error: mockError,
      });

      const handler = UsersController.routes["register-user-with-google"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(500);
      expect(jsonSpy).toHaveBeenCalledWith({ error: "Erro ao buscar usuário" });
    });
  });

  describe('get-user-by-email', () => {
    it('should return 400 if email is missing', async () => {
      mockRequest.query = {};

      const handler = UsersController.routes["get-user-by-email"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(400);
      expect(jsonSpy).toHaveBeenCalledWith({ error: "Email é obrigatório" });
    });

    it('should return 200 with user data when user is found', async () => {
      mockRequest.query = { email: 'test@example.com' };
      const mockUser = { id: 1, email: 'test@example.com', nome_completo: 'Test User' };

      mockEq.mockResolvedValueOnce({
        data: [mockUser],
        error: null,
      });

      const handler = UsersController.routes["get-user-by-email"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(200);
      expect(jsonSpy).toHaveBeenCalledWith(mockUser);
    });

    it('should return 404 when user is not found', async () => {
      mockRequest.query = { email: 'test@example.com' };

      mockEq.mockResolvedValueOnce({
        data: [],
        error: null,
      });

      const handler = UsersController.routes["get-user-by-email"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(404);
      expect(jsonSpy).toHaveBeenCalledWith({ error: "Usuário não encontrado" });
    });
  });

  describe('registrar-user-with-email', () => {
    it('should return 400 if email or nome_completo is missing', async () => {
      mockRequest.body = { email: 'test@example.com' };

      const handler = UsersController.routes["registrar-user-with-email"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(400);
      expect(jsonSpy).toHaveBeenCalledWith({ error: "Email e nome completo são obrigatórios" });
    });

    it('should return 200 when user is created successfully', async () => {
      mockRequest.body = { email: 'test@example.com', nome_completo: 'Test User' };
      const mockUser = { id: 1, email: 'test@example.com', nome_completo: 'Test User' };

      mockEq.mockResolvedValueOnce({
        data: [],
        error: null,
      });
      mockSingle.mockResolvedValueOnce({
        data: mockUser,
        error: null,
      });

      const handler = UsersController.routes["registrar-user-with-email"].value;
      await handler(mockRequest as Request, mockResponse as Response);

      expect(statusSpy).toHaveBeenCalledWith(200);
      expect(jsonSpy).toHaveBeenCalledWith(mockUser);
    });
  });
}); 
export enum AuthErrorCode {
	INVALID_CREDENTIALS = 'invalid_credentials',
	USER_NOT_FOUND = 'user_not_found',
	EMAIL_NOT_CONFIRMED = 'email_not_confirmed',
	SIGNUP_DISABLED = 'signup_disabled',
	WEAK_PASSWORD = 'weak_password',
	EMAIL_IN_USE = 'email_in_use',
	SESSION_EXPIRED = 'session_expired',
	NETWORK_ERROR = 'network_error',
	BACKEND_ERROR = 'backend_error',
	UNKNOWN = 'unknown'
}

export interface AuthError {
	code: AuthErrorCode;
	message: string;
	originalError?: unknown;
}

export function parseAuthError(error: unknown): AuthError {
	if (error instanceof Error) {
		const message = error.message.toLowerCase();

		if (message.includes('invalid login credentials')) {
			return {
				code: AuthErrorCode.INVALID_CREDENTIALS,
				message: 'Email ou senha incorretos',
				originalError: error
			};
		}

		if (message.includes('email not confirmed')) {
			return {
				code: AuthErrorCode.EMAIL_NOT_CONFIRMED,
				message: 'Por favor, confirme seu email antes de fazer login',
				originalError: error
			};
		}

		if (message.includes('user already registered')) {
			return {
				code: AuthErrorCode.EMAIL_IN_USE,
				message: 'Este email já está em uso',
				originalError: error
			};
		}

		if (message.includes('password should be at least')) {
			return {
				code: AuthErrorCode.WEAK_PASSWORD,
				message: 'A senha deve ter pelo menos 6 caracteres',
				originalError: error
			};
		}

		if (message.includes('session') && message.includes('expired')) {
			return {
				code: AuthErrorCode.SESSION_EXPIRED,
				message: 'Sua sessão expirou. Por favor, faça login novamente',
				originalError: error
			};
		}

		if (message.includes('network') || message.includes('fetch')) {
			return {
				code: AuthErrorCode.NETWORK_ERROR,
				message: 'Erro de conexão. Verifique sua internet',
				originalError: error
			};
		}
	}

	return {
		code: AuthErrorCode.UNKNOWN,
		message: 'Ocorreu um erro inesperado. Tente novamente',
		originalError: error
	};
}

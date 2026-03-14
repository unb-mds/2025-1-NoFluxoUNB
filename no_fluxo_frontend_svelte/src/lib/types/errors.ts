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

const RATE_LIMIT_MESSAGE = 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';

export function parseAuthError(error: unknown): AuthError {
	let message: string;
	if (error instanceof Error) {
		message = error.message;
	} else if (typeof error === 'string') {
		message = error;
	} else if (error && typeof (error as { message?: string }).message === 'string') {
		message = (error as { message: string }).message;
	} else {
		message = String(error);
	}
	const lower = message.toLowerCase();

	// HTTP 429 Too Many Requests (Supabase rate limit em signup/login)
	const status = (error as { status?: number })?.status;
	if (status === 429 || lower.includes('429') || lower.includes('too many requests')) {
		return {
			code: AuthErrorCode.BACKEND_ERROR,
			message: RATE_LIMIT_MESSAGE,
			originalError: error
		};
	}

	if (lower.includes('invalid login credentials')) {
		return {
			code: AuthErrorCode.INVALID_CREDENTIALS,
			message: 'Email ou senha incorretos',
			originalError: error
		};
	}

	if (lower.includes('email not confirmed')) {
		return {
			code: AuthErrorCode.EMAIL_NOT_CONFIRMED,
			message: 'Por favor, confirme seu email antes de fazer login',
			originalError: error
		};
	}

	if (lower.includes('user already registered')) {
		return {
			code: AuthErrorCode.EMAIL_IN_USE,
			message: 'Este email já está cadastrado. Faça login ou use outro email.',
			originalError: error
		};
	}

	if (lower.includes('password should be at least') || lower.includes('password must be')) {
		return {
			code: AuthErrorCode.WEAK_PASSWORD,
			message: 'A senha deve ter pelo menos 6 caracteres',
			originalError: error
		};
	}

	if (lower.includes('session') && lower.includes('expired')) {
		return {
			code: AuthErrorCode.SESSION_EXPIRED,
			message: 'Sua sessão expirou. Por favor, faça login novamente',
			originalError: error
		};
	}

	if (lower.includes('network') || lower.includes('fetch') || lower.includes('econnrefused')) {
		return {
			code: AuthErrorCode.NETWORK_ERROR,
			message: 'Erro de conexão. Verifique sua internet',
			originalError: error
		};
	}

	if (lower.includes('email rate limit') || lower.includes('rate limit')) {
		return {
			code: AuthErrorCode.BACKEND_ERROR,
			message: RATE_LIMIT_MESSAGE,
			originalError: error
		};
	}

	if (lower.includes('signup disabled') || lower.includes('sign up disabled')) {
		return {
			code: AuthErrorCode.SIGNUP_DISABLED,
			message: 'Cadastro temporariamente desativado. Tente mais tarde.',
			originalError: error
		};
	}

	return {
		code: AuthErrorCode.UNKNOWN,
		message: 'Ocorreu um erro inesperado. Tente novamente',
		originalError: error
	};
}

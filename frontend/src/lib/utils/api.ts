import { authService } from '$lib/services/auth.service';
import { PUBLIC_API_URL } from '$env/static/public';

type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';

interface ApiOptions {
	method?: HttpMethod;
	body?: unknown;
	headers?: Record<string, string>;
	requireAuth?: boolean;
}

/**
 * Generic API request helper — for the few remaining backend API calls only.
 * For data queries, use direct Supabase queries instead.
 */
export async function apiRequest<T>(
	endpoint: string,
	options: ApiOptions = {}
): Promise<{ data: T | null; error: string | null; status: number }> {
	const { method = 'GET', body, headers = {}, requireAuth = true } = options;

	try {
		let requestHeaders: Record<string, string> = {
			'Content-Type': 'application/json',
			...headers
		};

		if (requireAuth) {
			const authHeaders = await authService.getAuthHeaders();
			requestHeaders = { ...requestHeaders, ...authHeaders };
		}

		const response = await fetch(`${PUBLIC_API_URL}${endpoint}`, {
			method,
			headers: requestHeaders,
			body: body ? JSON.stringify(body) : undefined
		});

		const status = response.status;

		if (!response.ok) {
			const errorText = await response.text();
			return { data: null, error: errorText, status };
		}

		const data = await response.json();
		return { data, error: null, status };
	} catch (error) {
		return {
			data: null,
			error: error instanceof Error ? error.message : 'Unknown error',
			status: 0
		};
	}
}

/**
 * AI Assistant Service
 * Proxies messages to the AI agent backend
 */

import { config } from '$lib/config';

interface AssistenteRequest {
	materia: string;
}

interface AssistenteResponse {
	resultado?: string;
	erro?: string;
}

export class AssistenteService {
	private readonly endpoint = '/assistente/analyze';

	/**
	 * Send a message to the AI assistant
	 * @param message The user's message
	 * @returns The AI response text
	 */
	async sendMessage(message: string): Promise<string> {
		const url = `${config.apiUrl}${this.endpoint}`;

		try {
			const response = await fetch(url, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ materia: message } satisfies AssistenteRequest)
			});

			if (!response.ok) {
				throw new Error(`HTTP error! status: ${response.status}`);
			}

			const data: AssistenteResponse = await response.json();

			if (data.erro) {
				throw new Error(data.erro);
			}

			return data.resultado || 'Sem resposta da IA.';
		} catch (error) {
			if (error instanceof Error) {
				throw new Error(`Erro ao se comunicar com a IA: ${error.message}`);
			}
			throw new Error('Erro ao se comunicar com a IA.');
		}
	}
}

// Singleton
export const assistenteService = new AssistenteService();

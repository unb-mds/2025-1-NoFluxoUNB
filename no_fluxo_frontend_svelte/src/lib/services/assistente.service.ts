/**
 * AI Assistant Service
 * Proxies messages to the AI agent backend
 * Supports both RAGFlow and Sabiá AI agents
 */

import { config } from '$lib/config';

interface AssistenteRequest {
	materia: string;
}

interface AssistenteResponse {
	resultado?: string;
	erro?: string;
	agente?: 'ragflow' | 'sabia';
	disciplinas?: Array<{
		codigo: string;
		nome: string;
		nota: number;
		justificativa: string;
	}>;
}

export type AgentType = 'ragflow' | 'sabia';

export class AssistenteService {
	private readonly ragflowEndpoint = '/assistente/analyze';
	private readonly sabiaEndpoint = '/assistente/analyze-sabia';

	/**
	 * Send a message to the AI assistant using the specified agent
	 * @param message The user's message
	 * @param agent Which AI agent to use ('ragflow' or 'sabia')
	 * @returns The AI response text
	 */
	async sendMessage(message: string, agent: AgentType = 'sabia'): Promise<string> {
		const endpoint = agent === 'sabia' ? this.sabiaEndpoint : this.ragflowEndpoint;
		const url = `${config.apiUrl}${endpoint}`;

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

	/**
	 * Send a message specifically to the Sabiá AI agent
	 * @param message The user's message
	 * @returns The AI response with structured data
	 */
	async sendMessageToSabia(message: string): Promise<AssistenteResponse> {
		const url = `${config.apiUrl}${this.sabiaEndpoint}`;

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

			return data;
		} catch (error) {
			if (error instanceof Error) {
				throw new Error(`Erro ao se comunicar com o Sabiá: ${error.message}`);
			}
			throw new Error('Erro ao se comunicar com o Sabiá.');
		}
	}
}

// Singleton
export const assistenteService = new AssistenteService();


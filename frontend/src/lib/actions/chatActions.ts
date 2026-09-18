/**
 * Chat action functions that coordinate between the store and service
 */

import { chatStore } from '$lib/stores/chatStore';
import { assistenteService } from '$lib/services/assistente.service';

/**
 * Send a user message and get AI response
 */
export async function sendMessage(text: string): Promise<void> {
	const messageId = chatStore.addUserMessage(text);

	try {
		const response = await assistenteService.sendMessage(text);
		chatStore.updateMessageStatus(messageId, 'sent');
		chatStore.addAIMessage(response);
	} catch (error) {
		chatStore.updateMessageStatus(messageId, 'error');
		chatStore.setError(
			error instanceof Error ? error.message : 'Erro desconhecido'
		);
	}
}

/**
 * Send a quick tag as a message
 */
export async function sendQuickTag(tag: string): Promise<void> {
	await sendMessage(tag);
}

/**
 * Retry a failed message
 */
export async function retryFailedMessage(messageId: string): Promise<void> {
	const text = chatStore.retryMessage(messageId);
	if (text) {
		try {
			const response = await assistenteService.sendMessage(text);
			chatStore.updateMessageStatus(messageId, 'sent');
			chatStore.addAIMessage(response);
		} catch (error) {
			chatStore.updateMessageStatus(messageId, 'error');
			chatStore.setError(
				error instanceof Error ? error.message : 'Erro desconhecido'
			);
		}
	}
}

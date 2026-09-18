import { describe, it, expect, vi, beforeEach } from 'vitest';
import { AI_SEM_CREDITOS_MSG, CHAT_ERRO_GENERICO_MSG } from '$lib/utils/ai-errors';

vi.mock('$lib/services/chat.service', () => ({
	chatService: { enviarMensagem: vi.fn() }
}));
vi.mock('$lib/services/assistente.service', () => {
	class AssistenteService {
		chatAgente = vi.fn();
	}
	return { AssistenteService };
});
vi.mock('$lib/stores/auth', () => ({
	authStore: {
		subscribe: (fn: (v: unknown) => void) => {
			fn({ user: null, isAuthenticated: false, isAnonymous: true, isLoading: false, error: null });
			return () => {};
		}
	}
}));
vi.mock('$lib/stores/fluxograma.store.svelte', () => ({
	fluxogramaStore: { state: { courseData: null }, completedCodes: new Set() }
}));
vi.mock('$lib/services/plano-formatura.service', () => ({
	planoFormaturaService: { loadPreferencias: vi.fn() }
}));

import { chatService } from '$lib/services/chat.service';
import { assistenteChatStore } from './assistente-chat.store.svelte';

describe('assistenteChatStore — bolha de erro do chat', () => {
	beforeEach(() => {
		vi.mocked(chatService.enviarMensagem).mockReset();
		assistenteChatStore.reset();
	});

	it('mostra a mensagem de "sem créditos" quando o backend responde 503/ai_sem_creditos', async () => {
		vi.mocked(chatService.enviarMensagem).mockRejectedValue(
			new Error('Erro 503 ao chamar /chat/send: {"error":"...","code":"ai_sem_creditos"}')
		);

		await assistenteChatStore.enviarMensagem('oi', { contexto: 'montador' });

		expect(assistenteChatStore.chatMessages.at(-1)).toEqual({
			role: 'assistant',
			content: AI_SEM_CREDITOS_MSG
		});
	});

	it('cai no fallback genérico para qualquer outra falha', async () => {
		vi.mocked(chatService.enviarMensagem).mockRejectedValue(
			new Error('Erro 500 ao chamar /chat/send: timeout')
		);

		await assistenteChatStore.enviarMensagem('oi', { contexto: 'montador' });

		expect(assistenteChatStore.chatMessages.at(-1)).toEqual({
			role: 'assistant',
			content: CHAT_ERRO_GENERICO_MSG
		});
	});
});

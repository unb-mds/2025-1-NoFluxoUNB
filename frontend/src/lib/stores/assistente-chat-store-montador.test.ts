import { describe, it, expect, vi, beforeEach } from 'vitest';

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
	authStore: { subscribe: (fn: (v: unknown) => void) => { fn({ user: null, isAuthenticated: false, isAnonymous: true, isLoading: false, error: null }); return () => {}; } }
}));
vi.mock('$lib/stores/fluxograma.store.svelte', () => ({
	fluxogramaStore: { state: { courseData: null }, completedCodes: new Set() }
}));
vi.mock('$lib/services/plano-formatura.service', () => ({
	planoFormaturaService: { loadPreferencias: vi.fn() }
}));

import { chatService } from '$lib/services/chat.service';
import { assistenteChatStore, montadorChatStore } from './assistente-chat.store.svelte';

describe('montadorChatStore — contexto montador usa o pipeline novo', () => {
	beforeEach(() => {
		vi.mocked(chatService.enviarMensagem).mockReset();
		montadorChatStore.reset();
		assistenteChatStore.reset();
	});

	it('contexto montador chama chatService.enviarMensagem, não AssistenteService', async () => {
		vi.mocked(chatService.enviarMensagem).mockResolvedValue({ reply: 'beleza!' });

		await montadorChatStore.enviarMensagem('oi', { contexto: 'montador' });

		expect(chatService.enviarMensagem).toHaveBeenCalledWith('oi', { contexto: 'montador' });
		expect(montadorChatStore.chatMessages.at(-1)).toEqual({ role: 'assistant', content: 'beleza!' });
	});

	it('contexto montador chama chatService.enviarMensagem com horarioLivre e turnos', async () => {
		vi.mocked(chatService.enviarMensagem).mockResolvedValue({ reply: 'beleza!' });

		await montadorChatStore.enviarMensagem('oi', {
			contexto: 'montador',
			curriculoCompleto: '8117/-2 - 2018.2',
			horarioLivre: '12345',
			turnos: ['M']
		});

		expect(chatService.enviarMensagem).toHaveBeenCalledWith('oi', {
			contexto: 'montador',
			curriculoCompleto: '8117/-2 - 2018.2',
			horarioLivre: '12345',
			turnos: ['M']
		});
	});
});

/**
 * Regressão do bug em que os dois chats compartilhavam a MESMA instância: o
 * histórico do Montador ia no corpo da requisição da página /assistente (e
 * vice-versa), fazendo o Darcy responder fora de contexto.
 */
describe('os dois chats do Darcy são independentes', () => {
	beforeEach(() => {
		vi.mocked(chatService.enviarMensagem).mockReset();
		montadorChatStore.reset();
		assistenteChatStore.reset();
	});

	it('mensagem enviada no Montador não aparece no chat da página /assistente', async () => {
		vi.mocked(chatService.enviarMensagem).mockResolvedValue({ reply: 'ok' });

		await montadorChatStore.enviarMensagem('quero optativa de redes', { contexto: 'montador' });

		expect(montadorChatStore.chatMessages.length).toBeGreaterThan(0);
		expect(assistenteChatStore.chatMessages).toHaveLength(0);
	});

	it('reset de um não apaga o histórico do outro', async () => {
		vi.mocked(chatService.enviarMensagem).mockResolvedValue({ reply: 'ok' });

		await montadorChatStore.enviarMensagem('oi', { contexto: 'montador' });
		const antes = montadorChatStore.chatMessages.length;

		assistenteChatStore.reset();

		expect(montadorChatStore.chatMessages).toHaveLength(antes);
	});
});

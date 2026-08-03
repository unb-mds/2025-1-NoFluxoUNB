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
import { assistenteChatStore } from './assistente-chat.store.svelte';

describe('assistenteChatStore — contexto montador usa o pipeline novo', () => {
	beforeEach(() => {
		vi.mocked(chatService.enviarMensagem).mockReset();
		assistenteChatStore.reset();
	});

	it('contexto montador chama chatService.enviarMensagem, não AssistenteService', async () => {
		vi.mocked(chatService.enviarMensagem).mockResolvedValue({ reply: 'beleza!' });

		await assistenteChatStore.enviarMensagem('oi', { contexto: 'montador' });

		expect(chatService.enviarMensagem).toHaveBeenCalledWith('oi', { contexto: 'montador' });
		expect(assistenteChatStore.chatMessages.at(-1)).toEqual({ role: 'assistant', content: 'beleza!' });
	});

	it('contexto montador chama chatService.enviarMensagem com horarioLivre e turnos', async () => {
		vi.mocked(chatService.enviarMensagem).mockResolvedValue({ reply: 'beleza!' });

		await assistenteChatStore.enviarMensagem('oi', {
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

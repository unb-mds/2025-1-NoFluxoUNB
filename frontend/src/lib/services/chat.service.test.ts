import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('$lib/utils/api', () => ({
	apiRequest: vi.fn()
}));

import { apiRequest } from '$lib/utils/api';
import { ChatService } from './chat.service';

describe('ChatService.enviarMensagem', () => {
	beforeEach(() => {
		vi.mocked(apiRequest).mockReset();
	});

	it('chama POST /chat/send só com message quando sem opts', async () => {
		vi.mocked(apiRequest).mockResolvedValue({ data: { reply: 'oi' }, error: null, status: 200 });

		const service = new ChatService();
		const resultado = await service.enviarMensagem('quantos créditos faltam?');

		expect(apiRequest).toHaveBeenCalledWith('/chat/send', {
			method: 'POST',
			body: { message: 'quantos créditos faltam?' }
		});
		expect(resultado).toEqual({ reply: 'oi' });
	});

	it('inclui contexto, curriculoCompleto, horarioLivre e turnos quando fornecidos', async () => {
		vi.mocked(apiRequest).mockResolvedValue({ data: { reply: 'ok' }, error: null, status: 200 });

		const service = new ChatService();
		await service.enviarMensagem('preenche meu horário livre', {
			contexto: 'montador',
			curriculoCompleto: '8117/-2 - 2018.2',
			horarioLivre: '12345',
			turnos: ['M', 'T']
		});

		expect(apiRequest).toHaveBeenCalledWith('/chat/send', {
			method: 'POST',
			body: {
				message: 'preenche meu horário livre',
				contexto: 'montador',
				curriculoCompleto: '8117/-2 - 2018.2',
				horarioLivre: '12345',
				turnos: ['M', 'T']
			}
		});
	});

	it('lança erro legível quando apiRequest devolve erro', async () => {
		vi.mocked(apiRequest).mockResolvedValue({ data: null, error: 'Token inválido.', status: 401 });

		const service = new ChatService();
		await expect(service.enviarMensagem('oi')).rejects.toThrow(/401/);
	});
});

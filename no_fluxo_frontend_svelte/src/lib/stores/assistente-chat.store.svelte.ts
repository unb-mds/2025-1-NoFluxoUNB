/**
 * Assistente Chat Store — chat-agente da aba Assistente (Svelte 5 runes).
 *
 * Espelha o fluxo do chat do planejador (histórico completo, request/response),
 * mas aponta para /assistente/chat. Monta o planoInput a partir de fluxograma +
 * auth + preferências salvas quando o aluno está logado — assim as tools de
 * plano/histórico do agente acendem. Anônimo/sem curso → só as tools genéricas.
 */

import { authStore } from '$lib/stores/auth';
import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
import { AssistenteService, type AssistentePlanoInput } from '$lib/services/assistente.service';
import { planoFormaturaService } from '$lib/services/plano-formatura.service';
import type { PlannerChatMessage } from '$lib/types/plano-formatura';
import type { AuthState } from '$lib/types/auth';

function createAssistenteChatStore() {
	let chatMessages = $state<PlannerChatMessage[]>([]);
	let chatLoading = $state(false);
	let error = $state<string | null>(null);

	let authState = $state<AuthState>({
		user: null,
		isAuthenticated: false,
		isAnonymous: false,
		isLoading: true,
		error: null
	});
	authStore.subscribe((value) => {
		authState = value;
	});

	const service = new AssistenteService();

	// Cache das preferências salvas (evita refetch a cada mensagem).
	let prefsCache: { limiteCreditos: number; objetivo: 'velocidade' | 'equilibrio'; trabalha: boolean } | null = null;

	async function buildPlanoInput(): Promise<AssistentePlanoInput | null> {
		const curriculo = fluxogramaStore.state.courseData?.curriculoCompleto;
		const idUser = authState.user?.idUser;
		if (!curriculo || !idUser) return null; // sem curso/login → contexto leve

		if (!prefsCache) {
			try {
				const p = await planoFormaturaService.loadPreferencias(idUser);
				prefsCache = {
					limiteCreditos: p.limiteCreditos,
					objetivo: p.objetivo === 'velocidade' ? 'velocidade' : 'equilibrio',
					trabalha: p.trabalha
				};
			} catch {
				prefsCache = { limiteCreditos: 24, objetivo: 'equilibrio', trabalha: false };
			}
		}

		return {
			curriculoCompleto: curriculo,
			codigosConcluidos: [...fluxogramaStore.completedCodes],
			semestreAtual: authState.user?.dadosFluxograma?.semestreAtual ?? 1,
			limiteCreditos: prefsCache.limiteCreditos,
			objetivo: prefsCache.objetivo,
			trabalha: prefsCache.trabalha
		};
	}

	return {
		get chatMessages() { return chatMessages; },
		get chatLoading() { return chatLoading; },
		get error() { return error; },

		async enviarMensagem(mensagem: string): Promise<void> {
			if (!mensagem.trim() || chatLoading) return;
			chatMessages = [...chatMessages, { role: 'user', content: mensagem }];
			chatLoading = true;
			error = null;

			try {
				const planoInput = await buildPlanoInput();
				const resposta = await service.chatAgente(chatMessages, planoInput);
				chatMessages = [...chatMessages, { role: 'assistant', content: resposta.reply }];
			} catch (err) {
				const msg = err instanceof Error ? err.message : 'Erro ao falar com o assistente';
				error = msg;
				chatMessages = [
					...chatMessages,
					{ role: 'assistant', content: `Ops, houve um erro no sistema. Tente novamente.` }
				];
			} finally {
				chatLoading = false;
			}
		},

		reset(): void {
			chatMessages = [];
			error = null;
		}
	};
}

export const assistenteChatStore = createAssistenteChatStore();

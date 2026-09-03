import { describe, it, expect } from 'vitest';
import {
	AI_SEM_CREDITOS_MSG,
	CHAT_ERRO_GENERICO_MSG,
	isAiSemCreditos,
	mensagemErroChat
} from './ai-errors';

const CORPO_503 =
	'{"error":"A IA está fora do ar no momento (créditos esgotados). Tente novamente mais tarde.","code":"ai_sem_creditos"}';
const CORPO_MARITACA_403 =
	'{"error":{"message":"Sorry, you need have active credits to use MariTalk via API.","code":"insufficient_funds"}}';

describe('isAiSemCreditos', () => {
	it('reconhece o code do backend (ai_sem_creditos)', () => {
		expect(isAiSemCreditos(CORPO_503)).toBe(true);
		expect(isAiSemCreditos(new Error(`Erro 503 ao chamar /chat/send: ${CORPO_503}`))).toBe(true);
	});

	it('reconhece a assinatura crua da Maritaca (insufficient_funds)', () => {
		expect(isAiSemCreditos(CORPO_MARITACA_403)).toBe(true);
	});

	it('é falso para outras falhas e valores vazios', () => {
		expect(isAiSemCreditos(new Error('Erro 500 ao chamar assistente: timeout'))).toBe(false);
		expect(isAiSemCreditos('')).toBe(false);
		expect(isAiSemCreditos(null)).toBe(false);
		expect(isAiSemCreditos(undefined)).toBe(false);
	});
});

describe('mensagemErroChat', () => {
	it('devolve a mensagem de sem-créditos quando aplicável', () => {
		expect(mensagemErroChat(new Error(CORPO_503))).toBe(AI_SEM_CREDITOS_MSG);
	});

	it('devolve o fallback genérico para o resto', () => {
		expect(mensagemErroChat(new Error('boom'))).toBe(CHAT_ERRO_GENERICO_MSG);
	});
});

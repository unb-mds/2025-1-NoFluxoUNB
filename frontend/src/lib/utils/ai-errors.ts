/**
 * Erros da IA compartilhados entre as páginas com chat (Assistente, Montador de
 * Grade, Plano de Formatura).
 *
 * Quando a conta Maritaca fica sem saldo, o backend responde 503 com corpo
 * `{ "error": "...", "code": "ai_sem_creditos" }`. Os serviços de chat recebem
 * esse corpo como texto cru (via `apiRequest`), então o detector abaixo casa
 * tanto pelo nosso `code` quanto pela assinatura da própria Maritaca
 * (`insufficient_funds`), caso o erro escape sem passar pelo controller.
 */

/** Mensagem exibida como bolha do assistente quando a IA está sem créditos. */
export const AI_SEM_CREDITOS_MSG =
	'A IA está fora do ar no momento (créditos esgotados). Tente novamente mais tarde.';

/** Fallback genérico para qualquer outra falha do chat. */
export const CHAT_ERRO_GENERICO_MSG = 'Algo falhou ao responder. Tente novamente em instantes.';

/** True quando `erro` (mensagem/texto de resposta) é a falta de créditos da Maritaca. */
export function isAiSemCreditos(erro: unknown): boolean {
	if (!erro) return false;
	const texto = (erro instanceof Error ? erro.message : String(erro)).toLowerCase();
	return texto.includes('ai_sem_creditos') || texto.includes('insufficient_funds');
}

/**
 * Traduz qualquer erro lançado por um serviço de chat na frase que vai pra bolha
 * do assistente: mensagem específica de "sem créditos" ou o fallback genérico.
 */
export function mensagemErroChat(erro: unknown): string {
	return isAiSemCreditos(erro) ? AI_SEM_CREDITOS_MSG : CHAT_ERRO_GENERICO_MSG;
}

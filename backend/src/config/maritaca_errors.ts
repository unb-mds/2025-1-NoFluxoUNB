/**
 * Detecção do erro de "sem créditos" da Maritaca.
 *
 * Quando a conta Maritaca fica sem saldo, a API responde 403 com corpo
 * `{"error":{"message":"Sorry, you need have active credits to use MariTalk via
 * API.","type":"invalid_request_error","param":null,"code":"insufficient_funds"}}`.
 *
 * Esse erro chega aos controllers de duas formas: como `Error` lançado pelo
 * `fetch` manual em `planejador_agente.service.ts` (mensagem = "Maritaca API
 * error: 403 {...}") ou como erro do SDK `@openai/agents` na rota /chat/send
 * (objeto com `.status` 403 e corpo serializado na mensagem). O detector abaixo
 * cobre os dois: casa pelo `code` da Maritaca, pela frase do `message` ou pelo
 * par status-403 + assinatura textual.
 */

/** Marcador para o caminho do `fetch` manual sinalizar a causa sem carregar o corpo cru adiante. */
export class MaritacaSemCreditosError extends Error {
    /** Código repassado ao cliente no corpo da resposta HTTP. */
    static readonly code = "ai_sem_creditos";

    constructor(message = "Maritaca sem créditos ativos (insufficient_funds).") {
        super(message);
        this.name = "MaritacaSemCreditosError";
    }
}

/** Mensagem amigável (pt-BR) exibida no chat de qualquer página. */
export const AI_SEM_CREDITOS_MSG =
    "A IA está fora do ar no momento (créditos esgotados). Tente novamente mais tarde.";

/** Corpo JSON padronizado devolvido pelos controllers quando a IA fica sem saldo. */
export const AI_SEM_CREDITOS_BODY = {
    error: AI_SEM_CREDITOS_MSG,
    code: MaritacaSemCreditosError.code,
} as const;

/**
 * True quando `err` (qualquer coisa que caiu num `catch`) é o 403 de saldo da
 * Maritaca. Nunca lança — normaliza o valor antes de inspecionar.
 */
export function isMaritacaSemCreditos(err: unknown): boolean {
    if (err instanceof MaritacaSemCreditosError) return true;

    const status =
        typeof err === "object" && err !== null && "status" in err
            ? Number((err as { status?: unknown }).status)
            : undefined;

    const texto = (
        err instanceof Error ? err.message : typeof err === "string" ? err : JSON.stringify(err ?? "")
    ).toLowerCase();

    if (texto.includes("insufficient_funds")) return true;
    if (texto.includes("active credits to use maritalk")) return true;
    if (status === 403 && texto.includes("maritaca")) return true;

    return false;
}

/**
 * Testes do detector de "sem créditos" da Maritaca (config/maritaca_errors.ts).
 */

import {
    AI_SEM_CREDITOS_BODY,
    AI_SEM_CREDITOS_MSG,
    MaritacaSemCreditosError,
    isMaritacaSemCreditos,
} from "../src/config/maritaca_errors";

// Corpo real devolvido pela Maritaca quando a conta está sem saldo.
const CORPO_403 =
    '{"error":{"message":"Sorry, you need have active credits to use MariTalk via API.","type":"invalid_request_error","param":null,"code":"insufficient_funds"}}';

describe("isMaritacaSemCreditos", () => {
    it("reconhece o Error lançado pelo fetch manual (planejador_agente.service)", () => {
        const err = new Error(`Maritaca API error: 403 ${CORPO_403}`);
        expect(isMaritacaSemCreditos(err)).toBe(true);
    });

    it("reconhece a instância de MaritacaSemCreditosError", () => {
        expect(isMaritacaSemCreditos(new MaritacaSemCreditosError())).toBe(true);
    });

    it("reconhece erro do SDK com status 403 e corpo serializado", () => {
        const err = Object.assign(new Error(`403 status code (no body) ${CORPO_403} maritaca`), {
            status: 403,
        });
        expect(isMaritacaSemCreditos(err)).toBe(true);
    });

    it("reconhece pela frase 'active credits to use MariTalk' mesmo sem o code", () => {
        const err = new Error("Sorry, you need have active credits to use MariTalk via API.");
        expect(isMaritacaSemCreditos(err)).toBe(true);
    });

    it("reconhece string crua", () => {
        expect(isMaritacaSemCreditos(CORPO_403)).toBe(true);
    });

    it("ignora outros erros da Maritaca (ex.: 500, rate limit)", () => {
        expect(isMaritacaSemCreditos(new Error("Maritaca API error: 500 internal error"))).toBe(false);
        expect(isMaritacaSemCreditos(new Error("Maritaca API error: 429 rate limit exceeded"))).toBe(false);
    });

    it("ignora erros não relacionados e valores vazios", () => {
        expect(isMaritacaSemCreditos(new Error("ECONNREFUSED"))).toBe(false);
        expect(isMaritacaSemCreditos(undefined)).toBe(false);
        expect(isMaritacaSemCreditos(null)).toBe(false);
        expect(isMaritacaSemCreditos({})).toBe(false);
    });
});

describe("AI_SEM_CREDITOS_BODY", () => {
    it("carrega a mensagem amigável e o code estável", () => {
        expect(AI_SEM_CREDITOS_BODY).toEqual({
            error: AI_SEM_CREDITOS_MSG,
            code: "ai_sem_creditos",
        });
        expect(MaritacaSemCreditosError.code).toBe("ai_sem_creditos");
    });
});

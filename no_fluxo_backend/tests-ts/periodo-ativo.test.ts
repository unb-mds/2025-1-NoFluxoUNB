/**
 * resolverPeriodoAtivo — a oferta considerada pelo plano tem que ser SEMPRE de um
 * único período (o corrente). O banco tem turmas de 2026.1 e 2026.2 ao mesmo tempo;
 * contar as duas infla `codigosComOferta` com oferta que não existe mais.
 *
 * Spec: docs/superpowers/specs/2026-08-03-equivalencias-oferta-turmas-design.md (D5)
 */

import { resolverPeriodoAtivo } from "../src/controllers/PlanejamentoController";

/** Cliente fake: `rpc` devolve o que mandarem (ou explode, se for um Error). */
function fakeSupabase(rpcData: unknown) {
    return {
        rpc: async () => {
            if (rpcData instanceof Error) throw rpcData;
            return { data: rpcData, error: null };
        },
    } as any;
}

/** Mesma fórmula da RPC `periodo_letivo_atual`: jan–jun = .1, jul–dez = .2. */
function periodoEsperadoAgora(): string {
    const now = new Date();
    return `${now.getFullYear()}.${now.getMonth() + 1 <= 6 ? 1 : 2}`;
}

describe("resolverPeriodoAtivo", () => {
    it("usa o período devolvido pela RPC", async () => {
        expect(await resolverPeriodoAtivo(fakeSupabase("2026.2"))).toBe("2026.2");
    });

    /**
     * O fallback NÃO pode ser "período mais recente em turmas": o banco carrega o
     * próximo período enquanto o atual ainda roda (2026.1 e 2026.2 coexistem hoje),
     * então o máximo passa na frente do corrente. Cair na mesma fórmula de data da
     * RPC mantém a resposta igual à dela, sempre.
     */
    it("cai na fórmula de data quando a RPC não responde", async () => {
        expect(await resolverPeriodoAtivo(fakeSupabase(null))).toBe(periodoEsperadoAgora());
    });

    it("cai na fórmula de data quando a RPC lança erro", async () => {
        expect(await resolverPeriodoAtivo(fakeSupabase(new Error("rede caiu")))).toBe(
            periodoEsperadoAgora()
        );
    });

    it("ignora string vazia da RPC e cai na fórmula de data", async () => {
        expect(await resolverPeriodoAtivo(fakeSupabase(""))).toBe(periodoEsperadoAgora());
    });

    /** Sempre há um período — o chamador nunca precisa lidar com ausência. */
    it("nunca devolve vazio", async () => {
        expect(await resolverPeriodoAtivo(fakeSupabase(null))).toMatch(/^\d{4}\.[12]$/);
    });
});

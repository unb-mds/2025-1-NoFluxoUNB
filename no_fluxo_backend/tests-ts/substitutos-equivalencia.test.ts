/**
 * getSubstitutosFromExpressaoLogica — códigos que substituem SOZINHOS a matéria de
 * origem de uma linha de `equivalencias`.
 *
 * Diferente de getCodigosFromExpressaoLogica, que achata a expressão inteira: sob um
 * nó "E" os códigos só valem cursados JUNTOS, então nenhum deles é substituto isolado.
 * Usado para achar oferta em `turmas` quando a matéria da matriz mudou de código.
 *
 * Spec: docs/superpowers/specs/2026-08-03-equivalencias-oferta-turmas-design.md (D2)
 */

import { getSubstitutosFromExpressaoLogica } from "../src/utils/expressao_logica";

describe("getSubstitutosFromExpressaoLogica", () => {
    it("string simples é substituto direto", () => {
        expect(getSubstitutosFromExpressaoLogica("CIC0198")).toEqual(["CIC0198"]);
    });

    it("OU: cada condição substitui sozinha", () => {
        const expr = { operador: "OU" as const, condicoes: ["CIC0197", "FGA0158"] };
        expect(getSubstitutosFromExpressaoLogica(expr).sort()).toEqual(["CIC0197", "FGA0158"]);
    });

    /**
     * "X E Y" = quem cursou os DOIS está dispensado. Cursar só X não substitui, então
     * a turma de X sozinha não serve como oferta da matéria de origem.
     */
    it("E: nenhuma condição substitui sozinha", () => {
        const expr = { operador: "E" as const, condicoes: ["FGA0001", "FGA0002"] };
        expect(getSubstitutosFromExpressaoLogica(expr)).toEqual([]);
    });

    it("misto: só o ramo OU vira substituto, o ramo E é descartado", () => {
        const expr = {
            operador: "OU" as const,
            condicoes: [
                "MAT0025",
                { operador: "E" as const, condicoes: ["FGA0001", "FGA0002"] },
            ],
        };
        expect(getSubstitutosFromExpressaoLogica(expr)).toEqual(["MAT0025"]);
    });

    it("OU aninhado dentro de OU achata normalmente", () => {
        const expr = {
            operador: "OU" as const,
            condicoes: [
                "CIC0197",
                { operador: "OU" as const, condicoes: ["FGA0158", "CIC0090"] },
            ],
        };
        expect(getSubstitutosFromExpressaoLogica(expr).sort()).toEqual([
            "CIC0090",
            "CIC0197",
            "FGA0158",
        ]);
    });

    it("E na raiz descarta o OU aninhado dentro dele", () => {
        const expr = {
            operador: "E" as const,
            condicoes: [
                "FGA0001",
                { operador: "OU" as const, condicoes: ["FGA0002", "FGA0003"] },
            ],
        };
        expect(getSubstitutosFromExpressaoLogica(expr)).toEqual([]);
    });

    it("normaliza case e espaço, e deduplica", () => {
        const expr = { operador: "OU" as const, condicoes: [" cic0197 ", "CIC0197"] };
        expect(getSubstitutosFromExpressaoLogica(expr)).toEqual(["CIC0197"]);
    });

    it("entrada nula/vazia devolve lista vazia", () => {
        expect(getSubstitutosFromExpressaoLogica(null)).toEqual([]);
        expect(getSubstitutosFromExpressaoLogica(undefined)).toEqual([]);
        expect(getSubstitutosFromExpressaoLogica({ operador: "OU" as const, condicoes: [] })).toEqual([]);
    });
});

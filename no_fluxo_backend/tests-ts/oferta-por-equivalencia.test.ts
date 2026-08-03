/**
 * Oferta por equivalência — quando a matéria da matriz mudou de código, a oferta em
 * `turmas` é publicada sob o código NOVO, mas a matriz continua com o antigo.
 *
 * Caso real medido em produção (matriz 693, Engenharia de Software): CIC0151 não tem
 * turma no período, mas suas equivalentes CIC0197 / FGA0158 têm.
 *
 * Spec: docs/superpowers/specs/2026-08-03-equivalencias-oferta-turmas-design.md
 */

import {
    construirSubstitutosPorCodigo,
    expandirOfertaComEquivalencias,
} from "../src/services/plano_formatura.service";
import type { MateriaInput } from "../src/types/planejamento";

function materia(codigo: string, extra: Partial<MateriaInput> = {}): MateriaInput {
    return { codigo, nome: codigo, creditos: 4, nivel: 1, obrigatoria: true, ...extra };
}

describe("construirSubstitutosPorCodigo", () => {
    it("mapeia a matéria da matriz para os códigos que a substituem", () => {
        const materias = [
            materia("CIC0151", { equivalencias: [{ operador: "OU", condicoes: ["CIC0197", "FGA0158"] }] }),
        ];
        const mapa = construirSubstitutosPorCodigo(materias);

        expect(mapa.get("CIC0151")?.sort()).toEqual(["CIC0197", "FGA0158"]);
    });

    it("une várias linhas de equivalência da mesma matéria (currículos diferentes)", () => {
        const materias = [
            materia("CIC0151", {
                equivalencias: [
                    { operador: "OU", condicoes: ["CIC0197"] },
                    { operador: "OU", condicoes: ["FGA0158"] },
                ],
            }),
        ];
        expect(construirSubstitutosPorCodigo(materias).get("CIC0151")?.sort()).toEqual([
            "CIC0197",
            "FGA0158",
        ]);
    });

    /** "X E Y" = só valem cursados juntos; a turma de X sozinha não serve como oferta. */
    it("expressão E não gera substituto", () => {
        const materias = [
            materia("FGA0100", { equivalencias: [{ operador: "E", condicoes: ["FGA0001", "FGA0002"] }] }),
        ];
        expect(construirSubstitutosPorCodigo(materias).get("FGA0100")).toBeUndefined();
    });

    it("matéria sem equivalência não entra no mapa", () => {
        expect(construirSubstitutosPorCodigo([materia("CIC0090")]).size).toBe(0);
    });

    it("não lista a própria matéria como substituta de si mesma", () => {
        const materias = [
            materia("CIC0151", { equivalencias: [{ operador: "OU", condicoes: ["CIC0151", "FGA0158"] }] }),
        ];
        expect(construirSubstitutosPorCodigo(materias).get("CIC0151")).toEqual(["FGA0158"]);
    });
});

describe("expandirOfertaComEquivalencias", () => {
    it("matéria sem turma própria conta como ofertada quando o substituto tem turma", () => {
        const substitutos = new Map([["CIC0151", ["CIC0197", "FGA0158"]]]);
        const expandido = expandirOfertaComEquivalencias(substitutos, new Set(["FGA0158"]));

        expect(expandido.has("CIC0151")).toBe(true);
        // Não perde a oferta própria que já existia.
        expect(expandido.has("FGA0158")).toBe(true);
    });

    it("não marca quando nenhum substituto tem turma", () => {
        const substitutos = new Map([["CIC0151", ["CIC0197", "FGA0158"]]]);
        expect(expandirOfertaComEquivalencias(substitutos, new Set(["MAT0025"])).has("CIC0151")).toBe(
            false
        );
    });

    /**
     * Mesma regra de passe único de expandirCumpridasComEquivalencias (commit 7e7075f4):
     * só oferta REAL alimenta a expansão. A ⇐ B e B ⇐ C não implica A ⇐ C.
     */
    it("NÃO propaga em cadeia — oferta obtida por equivalência não repassa a outra", () => {
        const substitutos = new Map([
            ["A", ["B"]],
            ["B", ["C"]],
        ]);
        const expandido = expandirOfertaComEquivalencias(substitutos, new Set(["C"]));

        expect(expandido.has("B")).toBe(true);
        expect(expandido.has("A")).toBe(false);
    });

    it("normaliza case e espaço dos dois lados", () => {
        const substitutos = new Map([["cic0151", [" fga0158 "]]]);
        expect(expandirOfertaComEquivalencias(substitutos, new Set(["FGA0158"])).has("CIC0151")).toBe(
            true
        );
    });

    it("não muta o conjunto recebido", () => {
        const original = new Set(["FGA0158"]);
        expandirOfertaComEquivalencias(new Map([["CIC0151", ["FGA0158"]]]), original);
        expect([...original]).toEqual(["FGA0158"]);
    });
});

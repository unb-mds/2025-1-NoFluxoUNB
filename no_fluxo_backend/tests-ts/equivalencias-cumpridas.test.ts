/**
 * expandirCumpridasComEquivalencias — regra de equivalência compartilhada entre o
 * Motor 2 (plano de formatura) e o AtuadorGrade (chat do Montador de Grade).
 *
 * Semântica: se o aluno cursou algo que satisfaz a expressão de equivalência de Y,
 * então Y conta como cumprida — tanto para NÃO ser recomendada de novo quanto para
 * liberar quem depende dela como pré-requisito.
 */

import { expandirCumpridasComEquivalencias } from "../src/services/plano_formatura.service";
import type { MateriaInput } from "../src/types/planejamento";

function materia(codigo: string, extra: Partial<MateriaInput> = {}): MateriaInput {
    return { codigo, nome: codigo, creditos: 4, nivel: 1, obrigatoria: true, ...extra };
}

describe("expandirCumpridasComEquivalencias", () => {
    it("marca Y como cumprida quando o aluno cursou algo equivalente a Y", () => {
        const materias = [
            materia("CIC0198", { equivalencias: [{ condicoes: ["CIC0234"], operador: "OU" }] }),
        ];
        const expandido = expandirCumpridasComEquivalencias(materias, new Set(["CIC0234"]));

        expect(expandido.has("CIC0198")).toBe(true);
        // Não perde o que já estava lá.
        expect(expandido.has("CIC0234")).toBe(true);
    });

    it("não marca quando a equivalência não é satisfeita", () => {
        const materias = [
            materia("CIC0198", { equivalencias: [{ condicoes: ["CIC0234"], operador: "OU" }] }),
        ];
        const expandido = expandirCumpridasComEquivalencias(materias, new Set(["MAT0025"]));

        expect(expandido.has("CIC0198")).toBe(false);
    });

    it("respeita operador E — só marca com TODAS as condições cumpridas", () => {
        const materias = [
            materia("FGA0100", { equivalencias: [{ condicoes: ["FGA0001", "FGA0002"], operador: "E" }] }),
        ];

        expect(expandirCumpridasComEquivalencias(materias, new Set(["FGA0001"])).has("FGA0100")).toBe(false);
        expect(
            expandirCumpridasComEquivalencias(materias, new Set(["FGA0001", "FGA0002"])).has("FGA0100")
        ).toBe(true);
    });

    it("basta UMA das várias linhas de equivalência ser satisfeita", () => {
        const materias = [
            materia("CIC0198", {
                equivalencias: [
                    { condicoes: ["CIC0999"], operador: "OU" }, // currículo antigo, não cursado
                    { condicoes: ["CIC0234"], operador: "OU" }, // esse sim
                ],
            }),
        ];
        const expandido = expandirCumpridasComEquivalencias(materias, new Set(["CIC0234"]));
        expect(expandido.has("CIC0198")).toBe(true);
    });

    it("resolve equivalência em cadeia (X cursada → Y equivalente → Z equivalente a Y)", () => {
        const materias = [
            materia("Y", { equivalencias: [{ condicoes: ["X"], operador: "OU" }] }),
            materia("Z", { equivalencias: [{ condicoes: ["Y"], operador: "OU" }] }),
        ];
        const expandido = expandirCumpridasComEquivalencias(materias, new Set(["X"]));

        expect(expandido.has("Y")).toBe(true);
        expect(expandido.has("Z")).toBe(true);
    });

    it("matéria sem equivalência não é afetada, e o conjunto original não é mutado", () => {
        const materias = [materia("FGA0001"), materia("FGA0002")];
        const original = new Set(["FGA0003"]);
        const expandido = expandirCumpridasComEquivalencias(materias, original);

        expect(expandido.has("FGA0001")).toBe(false);
        expect([...original]).toEqual(["FGA0003"]);
    });

    it("normaliza códigos (case/espaço) dos dois lados", () => {
        const materias = [
            materia("  cic0198 ", { equivalencias: [{ condicoes: ["cic0234"], operador: "OU" }] }),
        ];
        const expandido = expandirCumpridasComEquivalencias(materias, new Set([" CIC0234 "]));
        expect(expandido.has("CIC0198")).toBe(true);
    });
});

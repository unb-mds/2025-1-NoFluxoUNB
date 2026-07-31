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

    /**
     * Equivalência NÃO é transitiva. A UnB registra pares explícitos; o fato de existir
     * X≡Y e Y≡Z não autoriza X≡Z. Medido em 60 alunos reais: realimentar a cadeia
     * inflaria em 30% (406 → 583 matérias) o que conta como cumprido.
     */
    it("NÃO propaga em cadeia — matéria cumprida por equivalência não satisfaz outra equivalência", () => {
        const materias = [
            materia("Y", { equivalencias: [{ condicoes: ["X"], operador: "OU" }] }),
            materia("Z", { equivalencias: [{ condicoes: ["Y"], operador: "OU" }] }),
        ];
        const expandido = expandirCumpridasComEquivalencias(materias, new Set(["X"]));

        // Y sai direto de X, que o aluno cursou de verdade.
        expect(expandido.has("Y")).toBe(true);
        // Z dependeria de Y, que só existe por equivalência — não conta.
        expect(expandido.has("Z")).toBe(false);
    });

    it("ordem das matérias na lista não muda o resultado (sem dependência de iteração)", () => {
        const defs = [
            materia("Y", { equivalencias: [{ condicoes: ["X"], operador: "OU" }] }),
            materia("Z", { equivalencias: [{ condicoes: ["Y"], operador: "OU" }] }),
        ];
        const direta = expandirCumpridasComEquivalencias(defs, new Set(["X"]));
        const invertida = expandirCumpridasComEquivalencias([...defs].reverse(), new Set(["X"]));

        expect([...direta].sort()).toEqual([...invertida].sort());
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

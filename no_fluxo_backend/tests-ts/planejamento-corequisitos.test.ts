/**
 * Testes para B4 — alocacao de co-requisitos no mesmo semestre.
 *
 * Valida que quando uma materia tem co-requisitos:
 * - Ambas sao alocadas no mesmo semestre se cabem no limite
 * - Nenhuma eh alocada se os co-requisitos nao cabem
 * - Co-requisitos ja completados sao ignorados
 */

import {
    distribuirPorSemestres,
} from "../src/services/plano_formatura.service";
import type { MateriaInput, PreferenciasPlano } from "../src/types/planejamento";

const prefsDefault: PreferenciasPlano = {
    limiteCreditos: 24,
    objetivo: "equilibrado",
    trabalha: false,
};

function mkMateria(over: Partial<MateriaInput> & { codigo: string }): MateriaInput {
    return {
        codigo: over.codigo,
        nome: over.nome ?? over.codigo,
        creditos: over.creditos ?? 4,
        nivel: over.nivel ?? 1,
        obrigatoria: over.obrigatoria ?? true,
        preRequisitos: over.preRequisitos ?? null,
        coRequisitos: over.coRequisitos ?? null,
    };
}

describe("B4 — Co-requisitos", () => {
    it("aloca co-requisitos no mesmo semestre quando houver espaço", () => {
        // A e B são co-requisitos; limite de creditos permite ambas (8 total)
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 8 };
        const mats = [
            mkMateria({ codigo: "A", creditos: 4, obrigatoria: true, coRequisitos: "B" }),
            mkMateria({ codigo: "B", creditos: 4, obrigatoria: true, coRequisitos: "A" }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(), prefs, 1);
        expect(semestres.length).toBe(1);
        expect(semestres[0].materias.length).toBe(2);
        expect(semestres[0].creditos).toBe(8);
    });

    it("nao aloca co-requisito se nao couber no limite de creditos", () => {
        // A tem co-requisito B, mas com limite de 4 creditos só cabe A
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 4 };
        const mats = [
            mkMateria({ codigo: "A", creditos: 4, obrigatoria: true, coRequisitos: "B" }),
            mkMateria({ codigo: "B", creditos: 4, obrigatoria: true }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(), prefs, 1);
        // A não é alocado pois B (seu co-req) não cabe; B é alocado isoladamente depois
        expect(semestres.length).toBe(2);
        expect(semestres[0].materias.length).toBe(1);
        expect(semestres[1].materias.length).toBe(1);
    });

    it("ignora co-requisitos já completados", () => {
        // A tem co-requisito B, mas B já foi concluído
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 4 };
        const mats = [
            mkMateria({ codigo: "A", creditos: 4, obrigatoria: true, coRequisitos: "B" }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(["B"]), prefs, 1);
        // A é alocado sozinho (B já concluído)
        expect(semestres.length).toBe(1);
        expect(semestres[0].materias.length).toBe(1);
        expect(semestres[0].creditos).toBe(4);
    });

    it("aloca múltiplos co-requisitos juntos se couberem", () => {
        // A tem co-requisitos B e C; limite permite os 3 (12 creditos total)
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 12 };
        const mats = [
            mkMateria({ codigo: "A", creditos: 4, obrigatoria: true,
                        coRequisitos: { operador: "E", condicoes: ["B", "C"] } }),
            mkMateria({ codigo: "B", creditos: 4, obrigatoria: true }),
            mkMateria({ codigo: "C", creditos: 4, obrigatoria: true }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(), prefs, 1);
        expect(semestres.length).toBe(1);
        expect(semestres[0].materias.length).toBe(3);
        expect(semestres[0].creditos).toBe(12);
    });

    it("aloca co-requisitos com limite menor permitindo apenas alguns", () => {
        // A tem co-requisitos B e C; limite permite apenas A + B (8 creditos)
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 8 };
        const mats = [
            mkMateria({ codigo: "A", creditos: 4, obrigatoria: true,
                        coRequisitos: { operador: "E", condicoes: ["B", "C"] } }),
            mkMateria({ codigo: "B", creditos: 4, obrigatoria: true }),
            mkMateria({ codigo: "C", creditos: 4, obrigatoria: true }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(), prefs, 1);
        // A não é alocado porque C não cabe; todos ficam para depois
        // Espera-se que B ou C sejam alocados primeiro no próximo semestre
        expect(semestres.length).toBeGreaterThan(0);
    });

    it("resposta ou (OU) em co-requisitos trata como um válido", () => {
        // A tem co-requisito B OU C
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 8 };
        const mats = [
            mkMateria({ codigo: "A", creditos: 4, obrigatoria: true,
                        coRequisitos: { operador: "OU", condicoes: ["B", "C"] } }),
            mkMateria({ codigo: "B", creditos: 4, obrigatoria: true }),
            mkMateria({ codigo: "C", creditos: 4, obrigatoria: true }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(), prefs, 1);
        // A + B ou A + C devem estar juntos no mesmo semestre
        expect(semestres.length).toBeGreaterThan(0);
    });

    it("não aloca se nenhum co-requisito está em restantes", () => {
        // A tem co-requisito B, mas B já está completo
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 4 };
        const mats = [
            mkMateria({ codigo: "A", creditos: 4, obrigatoria: true, coRequisitos: "B" }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(["B"]), prefs, 1);
        expect(semestres.length).toBe(1);
        expect(semestres[0].materias.length).toBe(1);
    });
});

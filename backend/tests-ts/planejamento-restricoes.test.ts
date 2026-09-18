/**
 * Testes para restricoes adiar/priorizar no Motor 2.
 * 
 * Cobre:
 *   - restrição adiar tira matéria do semestre 0 e ela volta no semestre 1
 *   - priorizar força matéria pro semestre 0 mesmo com score baixo
 *   - pré-requisitos insatisfeitos NÃO são furados por priorizar
 *   - normalização de códigos (minúsculas)
 *   - sem restrições = comportamento inalterado (regressão)
 */

import { distribuirPorSemestres } from "../src/services/plano_formatura.service";
import type { MateriaInput, PreferenciasPlano } from "../src/types/planejamento";

// ---------- Helpers / Fixtures ----------

function mat(codigo: string, nivel: number, preReq: string | null = null): MateriaInput {
    return {
        codigo,
        nome: codigo,
        creditos: 4,
        carga_horaria: 60,
        nivel,
        obrigatoria: true,
        tipo_natureza: 0,
        preRequisitos: preReq ? { operador: "E", condicoes: [preReq] } : null,
        coRequisitos: null,
    };
}

function prefs(restricoes?: { adiar: string[]; priorizar: string[] }): PreferenciasPlano {
    return { 
        limiteCreditos: 8,  // 120h por semestre → 2 matérias de 60h
        objetivo: "equilibrado", 
        trabalha: false, 
        restricoes 
    };
}

// Helper: em qual índice de semestre a matéria caiu (-1 = não alocada)
function semestreDe(semestres: ReturnType<typeof distribuirPorSemestres>, codigo: string): number {
    for (const s of semestres) {
        for (const m of s.materias) {
            if ("codigo" in m && m.codigo === codigo.toUpperCase()) return s.indice;
        }
    }
    return -1;
}

describe("Motor 2 — restrições adiar/priorizar", () => {
    // limiteCreditos=8 → 120h → 2 matérias de 60h por semestre

    test("sem restrições, comportamento inalterado (regressão)", () => {
        const semestres = distribuirPorSemestres(
            [mat("AAA0001", 1), mat("BBB0002", 1)],
            new Set(),
            prefs(),
            3
        );
        expect(semestres).toHaveLength(1);
        expect(semestreDe(semestres, "AAA0001")).toBe(0);
        expect(semestreDe(semestres, "BBB0002")).toBe(0);
    });

    test("adiar tira a matéria do semestre 0 e ela volta no semestre 1", () => {
        const semestres = distribuirPorSemestres(
            [mat("AAA0001", 1), mat("BBB0002", 1), mat("CCC0003", 1)],
            new Set(),
            prefs({ adiar: ["AAA0001"], priorizar: [] }),
            3
        );
        expect(semestreDe(semestres, "AAA0001")).toBeGreaterThanOrEqual(1);
        expect(semestreDe(semestres, "BBB0002")).toBe(0);
    });

    test("adiar aceita código em minúsculas (normalização)", () => {
        const semestres = distribuirPorSemestres(
            [mat("AAA0001", 1), mat("BBB0002", 1), mat("CCC0003", 1)],
            new Set(),
            prefs({ adiar: ["aaa0001"], priorizar: [] }),
            3
        );
        expect(semestreDe(semestres, "AAA0001")).toBeGreaterThanOrEqual(1);
    });

    test("priorizar força matéria de score baixo pro semestre 0", () => {
        // ZZZ0009 é optativa sem desbloqueios (score baixo); AAA/BBB/CCC obrigatórias.
        const zzz: MateriaInput = { 
            ...mat("ZZZ0009", 5), 
            obrigatoria: false, 
            tipo_natureza: 1 
        };
        const semestres = distribuirPorSemestres(
            [mat("AAA0001", 1), mat("BBB0002", 1), mat("CCC0003", 1), zzz],
            new Set(),
            prefs({ adiar: [], priorizar: ["ZZZ0009"] }),
            3
        );
        expect(semestreDe(semestres, "ZZZ0009")).toBe(0);
    });

    test("priorizar NÃO fura pré-requisito insatisfeito", () => {
        // DDD0004 depende de AAA0001 — mesmo priorizada só entra depois.
        const semestres = distribuirPorSemestres(
            [mat("AAA0001", 1), mat("DDD0004", 2, "AAA0001")],
            new Set(),
            prefs({ adiar: [], priorizar: ["DDD0004"] }),
            3
        );
        const semAAA = semestreDe(semestres, "AAA0001");
        const semDDD = semestreDe(semestres, "DDD0004");
        expect(semDDD).toBeGreaterThan(semAAA);
    });
});

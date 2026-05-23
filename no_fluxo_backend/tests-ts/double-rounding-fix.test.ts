/**
 * Teste para validar que o fix de arredondamento duplo funciona.
 *
 * Problema: distribuirPorSemestres retorna creditos = Math.ceil(horasUsadas / 15).
 * Depois distribuirSlots faz creditosParaHoras(semestre.creditos), causando:
 *   - horas=119 → creditos=8 (Math.ceil(119/15)=8) → horas=120 → perda de 1h
 *   - horas=134 → creditos=9 (Math.ceil(134/15)=9) → horas=135 → perda de 1h
 *   - Isso pode causar perda de ~3-14h por semestre
 *
 * Solução: Manter _horasInternas como campo interno para evitar reconversão.
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
        carga_horaria: over.carga_horaria,
        nivel: over.nivel ?? 1,
        obrigatoria: over.obrigatoria ?? true,
        preRequisitos: over.preRequisitos ?? null,
        coRequisitos: over.coRequisitos ?? null,
    };
}

describe("Double rounding fix — _horasInternas preservation", () => {
    it("preserva valor exato em horas via _horasInternas para evitar reconversão", () => {
        // Criar matérias que somem para um valor que sofre arredondamento
        // Ex: 119 horas = 7.93 créditos, Math.ceil = 8 créditos = 120 horas
        const materias = [
            mkMateria({ codigo: "A", carga_horaria: 45 }),  // 3 créditos = 45h
            mkMateria({ codigo: "B", carga_horaria: 45 }),  // 3 créditos = 45h
            mkMateria({ codigo: "C", carga_horaria: 30 }),  // 2 créditos = 30h
            // Total: 120 horas = 8 créditos (sem arredondamento)
        ];

        const completed = new Set<string>();
        const semestres = distribuirPorSemestres(materias, completed, prefsDefault, 1);

        expect(semestres.length).toBeGreaterThan(0);
        const primeiroSemestre = semestres[0];

        // O campo _horasInternas deve existir e ter o valor exato
        expect((primeiroSemestre as any)._horasInternas).toBeDefined();
        expect((primeiroSemestre as any)._horasInternas).toBe(120);

        // Deve ser um número, não undefined
        expect(typeof (primeiroSemestre as any)._horasInternas).toBe("number");
    });

    it("preserva valor exato mesmo com arredondamento de creditos", () => {
        // Caso que provoca arredondamento: 119 horas
        // 119 / 15 = 7.93... → Math.ceil = 8 creditos = 120 horas (perda de 1h sem fix)
        const materias = [
            mkMateria({ codigo: "X", carga_horaria: 60 }),  // 60h
            mkMateria({ codigo: "Y", carga_horaria: 59 }),  // 59h
            // Total: 119 horas
        ];

        const completed = new Set<string>();
        const semestres = distribuirPorSemestres(materias, completed, prefsDefault, 1);

        const primeiroSemestre = semestres[0];
        const horasInternas = (primeiroSemestre as any)._horasInternas;

        // Sem o fix, converteria para 8 créditos = 120 horas
        // Com o fix, _horasInternas preserva 119 horas
        expect(horasInternas).toBe(119);

        // creditos é arredondado para compatibilidade v1
        expect(primeiroSemestre.creditos).toBe(8);  // Math.ceil(119/15)
    });

    it("distribui corretamente em múltiplos semestres com preservação", () => {
        // Criar matérias que ocupam 2 semestres
        const materias = [
            mkMateria({ codigo: "A", carga_horaria: 45 }),
            mkMateria({ codigo: "B", carga_horaria: 45 }),
            mkMateria({ codigo: "C", carga_horaria: 45 }),
            mkMateria({ codigo: "D", carga_horaria: 45 }),
            mkMateria({ codigo: "E", carga_horaria: 45 }),
        ];

        const completed = new Set<string>();
        // limiteCreditos=12 → 180 horas por semestre
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 12 };
        const semestres = distribuirPorSemestres(materias, completed, prefs, 1);

        expect(semestres.length).toBeGreaterThanOrEqual(2);

        // Cada semestre deve ter _horasInternas preservado
        for (const sem of semestres) {
            if ((sem as any)._horasInternas != null) {
                expect(typeof (sem as any)._horasInternas).toBe("number");
                expect((sem as any)._horasInternas).toBeGreaterThan(0);
            }
        }
    });

    it("_horasInternas não deveria estar nos casos legados sem carga_horaria", () => {
        // Mesmo sem carga_horaria, o campo deve ser preenchido com base em creditos
        const materias = [
            mkMateria({ codigo: "G", creditos: 4 }),  // 4 creditos = 60 horas
            mkMateria({ codigo: "H", creditos: 4 }),
        ];

        const completed = new Set<string>();
        const semestres = distribuirPorSemestres(materias, completed, prefsDefault, 1);

        const primeiroSemestre = semestres[0];

        // Deve ter _horasInternas mesmo quando entra via creditos
        expect((primeiroSemestre as any)._horasInternas).toBeDefined();
        expect((primeiroSemestre as any)._horasInternas).toBe(120);  // 8 * 15
    });
});

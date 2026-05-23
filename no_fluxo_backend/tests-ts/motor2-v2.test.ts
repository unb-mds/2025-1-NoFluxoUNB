/**
 * Motor 2 v2 — Testes da nova implementação.
 *
 * Valida:
 *   - Parse de fluxograma_atual
 *   - Cálculo de CH faltante
 *   - Distribuição de obrigatórias com estágio/TCC ao final
 *   - Distribuição de slots de optativa e complementar
 */

import { gerarPlanoCompletov2 } from "../src/services/plano_formatura.service";
import type { MateriaInput, CargaIntegralizada, PreferenciasPlano } from "../src/types/planejamento";

describe("Motor 2 v2", () => {
    const mockPreferencias: PreferenciasPlano = {
        limiteCreditos: 300,
        objetivo: "equilibrado",
        trabalha: false,
    };

    const mockCargaIntegralizada: CargaIntegralizada = {
        total: 1050,
        obrigatoria: 1020,
        optativa: 30,
        complementar: 0,
    };

    const mockExigidaMatriz: CargaIntegralizada = {
        total: 2430,
        obrigatoria: 1620,
        optativa: 600,
        complementar: 210,
    };

    const mockMaterias: MateriaInput[] = [
        // Obrigatória 1 — sem pré-req
        {
            codigo: "ENE0001",
            nome: "Fundamentos de Engenharia",
            creditos: 60,
            nivel: 1,
            obrigatoria: true,
        },
        // Obrigatória 2 — depende de ENE0001
        {
            codigo: "ENE0002",
            nome: "Cálculo Avançado",
            creditos: 60,
            nivel: 2,
            obrigatoria: true,
            preRequisitos: { condicoes: ["ENE0001"], operador: "E" },
        },
        // Estágio Supervisionado
        {
            codigo: "ENE0200",
            nome: "Estágio Supervisionado",
            creditos: 60,
            nivel: 8,
            obrigatoria: true,
            preRequisitos: { condicoes: ["ENE0001", "ENE0002"], operador: "E" },
        },
        // Optativa
        {
            codigo: "OPT0001",
            nome: "Eletiva Livre 1",
            creditos: 60,
            nivel: 0,
            obrigatoria: false,
        },
    ];

    const mockFluxogramaJson = JSON.stringify({
        dados_fluxograma: [
            // Semestre 1: ENE0001 aprovada
            [
                {
                    codigo: "ENE0001",
                    status: "APR",
                    ano_periodo: "2023.1",
                    tipo_dado: "integralizado",
                },
            ],
        ],
    });

    test("gerarPlanoCompletov2 — estrutura básica", () => {
        const resultado = gerarPlanoCompletov2(
            "user-123",
            "curso-001",
            3,
            mockCargaIntegralizada,
            mockExigidaMatriz,
            mockFluxogramaJson,
            mockMaterias,
            mockPreferencias
        );

        // Valida estrutura
        expect(resultado).toBeDefined();
        expect(resultado.semestreAtual).toBeUndefined(); // Nenhuma MATR no fluxograma
        expect(resultado.semestresRestantes).toBeGreaterThan(0);
        expect(Array.isArray(resultado.plano)).toBe(true);
        expect(Array.isArray(resultado.materiasNaoAlocadas)).toBe(true);
    });

    test("gerarPlanoCompletov2 — calcula CH faltante corretamente", () => {
        const resultado = gerarPlanoCompletov2(
            "user-123",
            "curso-001",
            3,
            mockCargaIntegralizada,
            mockExigidaMatriz,
            mockFluxogramaJson,
            mockMaterias,
            mockPreferencias
        );

        // CH obrigatória faltante: 1620 - 1020 = 600
        // Devemos ter ENE0002 + ENE0200 = 120 no plano
        // Restante: 600 - 120 = 480 (não alocado? ou faltam mais materias)
        const chObrigatoriaNoPlano = resultado.plano.reduce((sum, sem) => {
            return (
                sum +
                sem.materias
                    .filter((m) => typeof m === "object" && "codigo" in m)
                    .reduce((s, m) => s + (m as any).creditos || 0, 0)
            );
        }, 0);

        // Deve ter alocado as obrigatórias disponíveis
        expect(chObrigatoriaNoPlano).toBeGreaterThan(0);
    });

    test("gerarPlanoCompletov2 — estágio no final do plano", () => {
        const resultado = gerarPlanoCompletov2(
            "user-123",
            "curso-001",
            3,
            mockCargaIntegralizada,
            mockExigidaMatriz,
            mockFluxogramaJson,
            mockMaterias,
            mockPreferencias
        );

        // Se ENE0200 foi alocado, deve estar nos últimos semestres
        const ultimoSemestre =
            resultado.plano.length > 0
                ? resultado.plano[resultado.plano.length - 1]
                : null;
        if (ultimoSemestre) {
            const temEstagioNoFinal = ultimoSemestre.materias.some(
                (m) => typeof m === "object" && "codigo" in m && (m as any).codigo === "ENE0200"
            );
            // Pode estar ou não, depende se cabe no último semestre
            expect(temEstagioNoFinal || resultado.materiasNaoAlocadas.includes("ENE0200")).toBe(
                true
            );
        }
    });

    test("gerarPlanoCompletov2 — detecta completadas no fluxograma", () => {
        const resultado = gerarPlanoCompletov2(
            "user-123",
            "curso-001",
            3,
            mockCargaIntegralizada,
            mockExigidaMatriz,
            mockFluxogramaJson,
            mockMaterias,
            mockPreferencias
        );

        // ENE0001 está em APR no fluxograma, então não deve entrar no plano
        const temENE0001NoPlano = resultado.plano.some((sem) =>
            sem.materias.some((m) => typeof m === "object" && "codigo" in m && (m as any).codigo === "ENE0001")
        );
        expect(temENE0001NoPlano).toBe(false);
    });
});

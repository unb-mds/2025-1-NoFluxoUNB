/**
 * Testes unitarios para o Motor 2 — pure functions do servico
 * `plano_formatura.service.ts`. Nao tocam banco.
 *
 * Cobre:
 *   - buildReverseDependencyGraph
 *   - computeTransitiveDependents
 *   - calcularScore
 *   - isDesbloqueada
 *   - distribuirPorSemestres
 *   - gerarPlano (integracao das pure functions)
 */

import {
    buildReverseDependencyGraph,
    computeTransitiveDependents,
    calcularScore,
    isDesbloqueada,
    distribuirPorSemestres,
    gerarPlano,
} from "../src/services/plano_formatura.service";
import type { MateriaInput, PreferenciasPlano } from "../src/types/planejamento";

// ---------- Helpers / fixtures ----------

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

// ---------- buildReverseDependencyGraph ----------

describe("buildReverseDependencyGraph", () => {
    it("retorna mapa vazio quando nao ha materias", () => {
        const graph = buildReverseDependencyGraph([]);
        expect(graph.size).toBe(0);
    });

    it("ignora materias sem pre-requisitos", () => {
        const mats = [
            mkMateria({ codigo: "MAT0026" }),
            mkMateria({ codigo: "CIC0004" }),
        ];
        const graph = buildReverseDependencyGraph(mats);
        // Sem pre-req nenhuma materia eh dependente de outra
        expect(graph.get("MAT0026") ?? new Set()).toEqual(new Set());
        expect(graph.get("CIC0004") ?? new Set()).toEqual(new Set());
    });

    it("monta arestas reversas para pre-requisito simples (string)", () => {
        // CIC0097 -> depende de MAT0026
        const mats = [
            mkMateria({ codigo: "MAT0026" }),
            mkMateria({ codigo: "CIC0097", preRequisitos: "MAT0026" }),
        ];
        const graph = buildReverseDependencyGraph(mats);
        // MAT0026 desbloqueia CIC0097
        expect(graph.get("MAT0026")).toEqual(new Set(["CIC0097"]));
    });

    it("monta arestas reversas para expressao com AND (E)", () => {
        // CIC0110 depende de CIC0097 E MAT0027
        const mats = [
            mkMateria({ codigo: "CIC0097" }),
            mkMateria({ codigo: "MAT0027" }),
            mkMateria({
                codigo: "CIC0110",
                preRequisitos: {
                    operador: "E",
                    condicoes: ["CIC0097", "MAT0027"],
                },
            }),
        ];
        const graph = buildReverseDependencyGraph(mats);
        expect(graph.get("CIC0097")).toEqual(new Set(["CIC0110"]));
        expect(graph.get("MAT0027")).toEqual(new Set(["CIC0110"]));
    });

    it("monta arestas reversas para expressao com OR (OU)", () => {
        const mats = [
            mkMateria({ codigo: "FIS0001" }),
            mkMateria({ codigo: "FIS0002" }),
            mkMateria({
                codigo: "FIS0010",
                preRequisitos: {
                    operador: "OU",
                    condicoes: ["FIS0001", "FIS0002"],
                },
            }),
        ];
        const graph = buildReverseDependencyGraph(mats);
        expect(graph.get("FIS0001")).toEqual(new Set(["FIS0010"]));
        expect(graph.get("FIS0002")).toEqual(new Set(["FIS0010"]));
    });
});

// ---------- computeTransitiveDependents ----------

describe("computeTransitiveDependents", () => {
    it("retorna 0 quando materia nao desbloqueia nada", () => {
        const graph = new Map<string, Set<string>>();
        graph.set("X", new Set());
        const n = computeTransitiveDependents("X", graph);
        expect(n).toBe(0);
    });

    it("conta cadeia transitiva A -> B -> C -> D", () => {
        // A desbloqueia B; B desbloqueia C; C desbloqueia D.
        // Transitive de A = {B,C,D} = 3
        const graph = new Map<string, Set<string>>();
        graph.set("A", new Set(["B"]));
        graph.set("B", new Set(["C"]));
        graph.set("C", new Set(["D"]));
        graph.set("D", new Set());

        expect(computeTransitiveDependents("A", graph)).toBe(3);
        expect(computeTransitiveDependents("B", graph)).toBe(2);
        expect(computeTransitiveDependents("C", graph)).toBe(1);
        expect(computeTransitiveDependents("D", graph)).toBe(0);
    });

    it("nao conta duplicado em diamante (A -> {B,C}; B -> D; C -> D)", () => {
        const graph = new Map<string, Set<string>>();
        graph.set("A", new Set(["B", "C"]));
        graph.set("B", new Set(["D"]));
        graph.set("C", new Set(["D"]));
        graph.set("D", new Set());
        // Transitive(A) = {B,C,D} = 3 (D so conta uma vez)
        expect(computeTransitiveDependents("A", graph)).toBe(3);
    });

    it("nao trava em ciclo (resiliencia)", () => {
        const graph = new Map<string, Set<string>>();
        graph.set("A", new Set(["B"]));
        graph.set("B", new Set(["A"])); // ciclo
        // Nao deve loopar — conta cada no uma vez
        expect(computeTransitiveDependents("A", graph)).toBe(1);
    });
});

// ---------- calcularScore ----------

describe("calcularScore", () => {
    it("obrigatoria sem dependentes e em dia: score = 3", () => {
        const mat = mkMateria({ codigo: "X", obrigatoria: true, nivel: 3 });
        const score = calcularScore(mat, /*direto*/ 0, /*indireto*/ 0, /*semestreAtual*/ 3);
        expect(score).toBe(3);
    });

    it("optativa sem dependentes e em dia: score = 0", () => {
        const mat = mkMateria({ codigo: "X", obrigatoria: false, nivel: 0 });
        const score = calcularScore(mat, 0, 0, 3);
        expect(score).toBe(0);
    });

    it("aplica + 2*diretos + 1*indiretos", () => {
        const mat = mkMateria({ codigo: "X", obrigatoria: false, nivel: 5 });
        // 2 diretos + 3 indiretos = 2*2 + 3 = 7
        const score = calcularScore(mat, 2, 3, 5);
        expect(score).toBe(7);
    });

    it("soma 2 quando nivel < semestre_atual (atrasada)", () => {
        const mat = mkMateria({ codigo: "X", obrigatoria: true, nivel: 2 });
        // 3 (obrig) + 2 (atrasada) = 5
        const score = calcularScore(mat, 0, 0, 4);
        expect(score).toBe(5);
    });

    it("nivel == semestre_atual nao conta como atrasada", () => {
        const mat = mkMateria({ codigo: "X", obrigatoria: true, nivel: 3 });
        const score = calcularScore(mat, 0, 0, 3);
        expect(score).toBe(3);
    });

    it("optativa (nivel=0) nunca eh tratada como atrasada", () => {
        // nivel=0 indica optativa — nao tem semestre esperado
        const mat = mkMateria({ codigo: "X", obrigatoria: false, nivel: 0 });
        const score = calcularScore(mat, 0, 0, 5);
        expect(score).toBe(0); // nao adiciona "+2 atrasada"
    });
});

// ---------- isDesbloqueada ----------

describe("isDesbloqueada", () => {
    it("sem pre-requisitos sempre eh desbloqueada", () => {
        const mat = mkMateria({ codigo: "X", preRequisitos: null });
        const concluidos = new Set<string>();
        expect(isDesbloqueada(mat, concluidos)).toBe(true);
    });

    it("pre-requisito simples cumprido", () => {
        const mat = mkMateria({ codigo: "Y", preRequisitos: "X" });
        expect(isDesbloqueada(mat, new Set(["X"]))).toBe(true);
    });

    it("pre-requisito simples nao cumprido", () => {
        const mat = mkMateria({ codigo: "Y", preRequisitos: "X" });
        expect(isDesbloqueada(mat, new Set())).toBe(false);
    });

    it("AND: todos cumpridos", () => {
        const mat = mkMateria({
            codigo: "Z",
            preRequisitos: { operador: "E", condicoes: ["A", "B"] },
        });
        expect(isDesbloqueada(mat, new Set(["A", "B"]))).toBe(true);
        expect(isDesbloqueada(mat, new Set(["A"]))).toBe(false);
    });

    it("OR: pelo menos um cumprido", () => {
        const mat = mkMateria({
            codigo: "W",
            preRequisitos: { operador: "OU", condicoes: ["A", "B"] },
        });
        expect(isDesbloqueada(mat, new Set(["B"]))).toBe(true);
        expect(isDesbloqueada(mat, new Set())).toBe(false);
    });
});

// ---------- distribuirPorSemestres ----------

describe("distribuirPorSemestres", () => {
    it("aloca todas as materias sem pre-req num unico semestre se cabem no limite", () => {
        const mats = [
            mkMateria({ codigo: "A", creditos: 4 }),
            mkMateria({ codigo: "B", creditos: 4 }),
            mkMateria({ codigo: "C", creditos: 4 }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(), prefsDefault, 1);
        expect(semestres.length).toBe(1);
        expect(semestres[0].materias.map((m) => m.codigo).sort()).toEqual(["A", "B", "C"]);
        expect(semestres[0].creditos).toBe(12);
    });

    it("respeita limite de creditos por semestre", () => {
        // limite 8 -> cabem 2 materias de 4 cred por semestre
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 8 };
        const mats = [
            mkMateria({ codigo: "A", creditos: 4 }),
            mkMateria({ codigo: "B", creditos: 4 }),
            mkMateria({ codigo: "C", creditos: 4 }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(), prefs, 1);
        expect(semestres.length).toBe(2);
        expect(semestres[0].materias.length).toBe(2);
        expect(semestres[1].materias.length).toBe(1);
    });

    it("respeita dependencia: B depende de A => A vai primeiro", () => {
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 4 };
        const mats = [
            mkMateria({ codigo: "A", creditos: 4 }),
            mkMateria({ codigo: "B", creditos: 4, preRequisitos: "A" }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(), prefs, 1);
        expect(semestres.length).toBe(2);
        expect(semestres[0].materias[0].codigo).toBe("A");
        expect(semestres[1].materias[0].codigo).toBe("B");
    });

    it("primeiro semestre eh 'recomendado'; demais 'estimado'", () => {
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 4 };
        const mats = [
            mkMateria({ codigo: "A", creditos: 4 }),
            mkMateria({ codigo: "B", creditos: 4, preRequisitos: "A" }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(), prefs, 1);
        expect(semestres[0].tipo).toBe("recomendado");
        expect(semestres[1].tipo).toBe("estimado");
    });

    it("considera completedCodes ao decidir candidatas", () => {
        // B depende de A; A ja concluida -> B pode entrar no 1o semestre
        const mats = [mkMateria({ codigo: "B", creditos: 4, preRequisitos: "A" })];
        const semestres = distribuirPorSemestres(mats, new Set(["A"]), prefsDefault, 1);
        expect(semestres.length).toBe(1);
        expect(semestres[0].materias[0].codigo).toBe("B");
    });

    it("nao alocaveis (ciclo / dependencia ausente) nao travam o algoritmo", () => {
        // A e B se dependem mutuamente -> nenhuma pode entrar
        const mats = [
            mkMateria({ codigo: "A", preRequisitos: "B" }),
            mkMateria({ codigo: "B", preRequisitos: "A" }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(), prefsDefault, 1);
        // Espera-se que o algoritmo finalize sem loop infinito com plano vazio
        expect(semestres.length).toBe(0);
    });

    it("ordena por score desc dentro do mesmo semestre (alta-prio primeiro)", () => {
        const prefs: PreferenciasPlano = { ...prefsDefault, limiteCreditos: 4 };
        // C desbloqueia 2 outras; A e B nao desbloqueiam ninguem
        const mats = [
            mkMateria({ codigo: "A", creditos: 4, obrigatoria: false, nivel: 0 }),
            mkMateria({ codigo: "B", creditos: 4, obrigatoria: false, nivel: 0 }),
            mkMateria({ codigo: "C", creditos: 4, obrigatoria: true }),
            mkMateria({ codigo: "D", creditos: 4, preRequisitos: "C" }),
            mkMateria({ codigo: "E", creditos: 4, preRequisitos: "C" }),
        ];
        const semestres = distribuirPorSemestres(mats, new Set(), prefs, 1);
        // Primeiro semestre deve ser C (maior score: obrigatoria + 2 diretos)
        expect(semestres[0].materias[0].codigo).toBe("C");
    });
});

// ---------- gerarPlano (integracao) ----------

describe("gerarPlano", () => {
    it("retorna plano vazio quando aluno ja concluiu tudo", () => {
        const plano = gerarPlano({
            curriculoCompleto: "X",
            completedCodes: [],
            numeroPeriodo: 1,
            preferencias: prefsDefault,
            materiasFaltantes: [],
        });
        expect(plano.semestresRestantes).toBe(0);
        expect(plano.plano).toEqual([]);
        expect(plano.materiasNaoAlocadas).toEqual([]);
    });

    it("gera plano completo com cadeia de dependencias", () => {
        const mats = [
            mkMateria({ codigo: "A", creditos: 4 }),
            mkMateria({ codigo: "B", creditos: 4, preRequisitos: "A" }),
            mkMateria({ codigo: "C", creditos: 4, preRequisitos: "B" }),
        ];
        const plano = gerarPlano({
            curriculoCompleto: "X",
            completedCodes: [],
            numeroPeriodo: 1,
            preferencias: { ...prefsDefault, limiteCreditos: 4 },
            materiasFaltantes: mats,
        });
        expect(plano.semestresRestantes).toBe(3);
        expect(plano.plano[0].materias[0].codigo).toBe("A");
        expect(plano.plano[1].materias[0].codigo).toBe("B");
        expect(plano.plano[2].materias[0].codigo).toBe("C");
        expect(plano.plano[0].tipo).toBe("recomendado");
        expect(plano.plano[1].tipo).toBe("estimado");
    });

    it("marca materias criticas (atrasadas ou alto score)", () => {
        const mats = [
            // Atrasada: nivel=1, semestre atual = 4
            mkMateria({ codigo: "ATR", creditos: 4, nivel: 1, obrigatoria: true }),
            // Tranquila: nivel=4 (em dia), sem dependentes, obrigatoria
            mkMateria({ codigo: "OK", creditos: 4, nivel: 4, obrigatoria: true }),
        ];
        const plano = gerarPlano({
            curriculoCompleto: "X",
            completedCodes: [],
            numeroPeriodo: 4,
            preferencias: prefsDefault,
            materiasFaltantes: mats,
        });
        const atr = plano.plano[0].materias.find((m) => m.codigo === "ATR");
        expect(atr).toBeDefined();
        expect(atr!.critica).toBe(true);
    });

    it("lista materias nao alocadas quando ha ciclos", () => {
        const mats = [
            mkMateria({ codigo: "A", preRequisitos: "B" }),
            mkMateria({ codigo: "B", preRequisitos: "A" }),
        ];
        const plano = gerarPlano({
            curriculoCompleto: "X",
            completedCodes: [],
            numeroPeriodo: 1,
            preferencias: prefsDefault,
            materiasFaltantes: mats,
        });
        expect(plano.materiasNaoAlocadas.sort()).toEqual(["A", "B"]);
    });

    it("preenche campo motivo nas materias do plano", () => {
        const mats = [mkMateria({ codigo: "A", creditos: 4 })];
        const plano = gerarPlano({
            curriculoCompleto: "X",
            completedCodes: [],
            numeroPeriodo: 1,
            preferencias: prefsDefault,
            materiasFaltantes: mats,
        });
        expect(plano.plano[0].materias[0].motivo).toBeTruthy();
        expect(typeof plano.plano[0].materias[0].motivo).toBe("string");
    });

    it("respeita completedCodes (considera materias ja feitas como pre-req cumprido)", () => {
        const mats = [
            // A nao esta nas faltantes (ja feita); B depende de A
            mkMateria({ codigo: "B", creditos: 4, preRequisitos: "A" }),
        ];
        const plano = gerarPlano({
            curriculoCompleto: "X",
            completedCodes: ["A"],
            numeroPeriodo: 1,
            preferencias: prefsDefault,
            materiasFaltantes: mats,
        });
        expect(plano.plano[0].materias[0].codigo).toBe("B");
        expect(plano.semestresRestantes).toBe(1);
    });
});

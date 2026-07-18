/**
 * Testes do Tool Registry compartilhado — gating por contexto de plano.
 *
 * Contexto leve (sem plano) => só as tools genéricas.
 * Contexto com plano       => todas as tools.
 */

import { defaultRegistry } from "../src/services/agente/tools";
import { criarContextoLeve, type AgenteContexto } from "../src/services/agente/context";
import type { MateriaInput } from "../src/types/planejamento";

const GENERICAS = [
    "consultar_informacoes_materia",
    "consultar_turmas_materia",
    "buscar_materias_unb",
];
const DE_PLANO = [
    "consultar_historico_aluno",
    "consultar_status_materia",
    "consultar_plano",
    "simular_cenario",
    "ajustar_carga",
    "ajustar_carga_semestre",
    "mover_materia",
];

function ctxComPlano(): AgenteContexto {
    const mat: MateriaInput = {
        codigo: "AAA0001",
        nome: "AAA0001",
        creditos: 4,
        carga_horaria: 60,
        nivel: 1,
        obrigatoria: true,
        tipo_natureza: 0,
        preRequisitos: null,
        coRequisitos: null,
    };
    return { ...criarContextoLeve("user123"), materias: [mat], idCurso: "8117" };
}

function nomesDosSchemas(ctx: AgenteContexto): string[] {
    return defaultRegistry.schemasFor(ctx).map((s) => s.function.name);
}

describe("ToolRegistry — gating por contexto", () => {
    test("contexto leve expõe só as tools genéricas", () => {
        const nomes = nomesDosSchemas(criarContextoLeve());
        expect(nomes.sort()).toEqual([...GENERICAS].sort());
        for (const t of DE_PLANO) expect(nomes).not.toContain(t);
    });

    test("contexto com plano expõe todas as tools", () => {
        const nomes = nomesDosSchemas(ctxComPlano());
        for (const t of [...GENERICAS, ...DE_PLANO]) expect(nomes).toContain(t);
    });

    test("tool de plano chamada em contexto leve retorna erro amigável (não executa)", async () => {
        const r = await defaultRegistry.execute("consultar_plano", {}, criarContextoLeve());
        const parsed = JSON.parse(r.resultado);
        expect(parsed.erro).toContain("plano de formatura");
        expect(r.planoAtualizado).toBeUndefined();
    });

    test("tool desconhecida retorna erro", async () => {
        const r = await defaultRegistry.execute("ferramenta_inexistente", {}, criarContextoLeve());
        expect(JSON.parse(r.resultado).erro).toContain("desconhecida");
    });

    test("consultar_status_materia classifica pelo histórico real (fluxograma_atual)", async () => {
        const ctx = ctxComPlano(); // materias: [AAA0001]
        ctx.materias.push({ ...ctx.materias[0], codigo: "CCC0003" });
        ctx.fluxogramaAtual = JSON.stringify({
            dados_fluxograma: [[
                { codigo: "AAA0001", status: "APR" },
                { codigo: "BBB0002", status: "MATR" },
            ]],
        });
        const status = async (c: string) =>
            JSON.parse((await defaultRegistry.execute("consultar_status_materia", { codigo: c }, ctx)).resultado).status;

        expect(await status("AAA0001")).toBe("concluida");
        expect(await status("BBB0002")).toBe("em_curso");
        expect(await status("CCC0003")).toBe("pendente");
        expect(await status("ZZZ9999")).toBe("fora_do_curriculo");
    });
});

process.env.MARITACA_API_KEY = "test-key";

type Row = Record<string, any>;
const db: { materias: Row[]; turmas: Row[] } = { materias: [], turmas: [] };

/**
 * Mock genérico de tabela Supabase suportando .select().eq().in().then().
 *
 * NOTA sobre o schema: a tabela `turmas` no banco real só tem `id_materia`
 * (sem `codigo_materia` denormalizado) — confirmado lendo
 * PlanejamentoController.ts:217-219 e o padrão já usado em
 * `filtrarPorOfertaAtiva` (optativas_actuator.ts:33-48), que resolve
 * código → id_materia via a tabela `materias` antes de consultar `turmas`.
 * Por isso o mock aqui modela DUAS tabelas (materias e turmas) em vez da
 * versão otimista do brief que assumia `codigo_materia` direto em `turmas`.
 */
function makeTable(rows: Row[]) {
    return {
        select(_cols: string) {
            const filtrosIn: Array<[string, any[]]> = [];
            const filtrosEq: Array<[string, any]> = [];
            const builder: any = {
                in(col: string, vals: any[]) {
                    filtrosIn.push([col, vals]);
                    return builder;
                },
                eq(col: string, val: any) {
                    filtrosEq.push([col, val]);
                    return builder;
                },
                then(resolve: (v: any) => any) {
                    const resultado = rows.filter(
                        (r) =>
                            filtrosEq.every(([c, v]) => r[c] === v) &&
                            filtrosIn.every(([c, vals]) => vals.includes(r[c]))
                    );
                    return resolve({ data: resultado, error: null });
                },
            };
            return builder;
        },
    };
}

function tableFrom(table: string) {
    if (table === "materias") return makeTable(db.materias);
    if (table === "turmas") return makeTable(db.turmas);
    return { select: () => ({ eq: function () { return this; }, in: function () { return this; }, then: (resolve: any) => resolve({ data: [], error: null }) }) };
}

// rpc tipado com (...args: any[]) pra aceitar tanto o mock neutro (Task 6) quanto
// os mocks de match_materias (Task 7), que recebem (fn, args).
const getMock = jest.fn(() => ({ from: (t: string) => tableFrom(t), rpc: async (..._args: any[]): Promise<{ data: any[]; error: any }> => ({ data: [], error: null }) }));
jest.mock("../src/supabase_wrapper", () => ({
    SupabaseWrapper: { get: () => getMock() },
}));

const materiasMapeadasFake = [
    { codigo: "FGA0001", nome: "Obrigatória Pendente", creditos: 4, nivel: 3, obrigatoria: true, tipo_natureza: 0, carga_horaria: 60 },
    { codigo: "FGA0002", nome: "Optativa com Oferta", creditos: 4, nivel: 0, obrigatoria: false, tipo_natureza: 1, carga_horaria: 60 },
    { codigo: "FGA0003", nome: "Optativa sem Oferta", creditos: 4, nivel: 0, obrigatoria: false, tipo_natureza: 1, carga_horaria: 60 },
];

jest.mock("../src/controllers/PlanejamentoController", () => ({
    montarDadosPlano: jest.fn(async () => ({
        dados: {
            idUser: "42",
            idCurso: "1",
            numeroPeriodo: 3,
            preferencias: { limiteCreditos: 24, objetivo: "equilibrado", trabalha: false },
            cargaHorariaIntegralizada: { total: 0, obrigatoria: 0, optativa: 0, complementar: 0 },
            exigidaMatriz: { total: 0, obrigatoria: 0, optativa: 0, complementar: 0 },
            fluxogramaAtual: JSON.stringify({ dados_fluxograma: [] }),
            materiasMapeadas: materiasMapeadasFake,
            codigosComOferta: new Set(["FGA0002"]),
        },
    })),
}));

import { maskLivre, slotMaskFromHorario } from "../src/utils/horario_slots";
import { recomendarPorHorarioLivre } from "../src/services/chat/actuators/grade_actuator";
import { montarDadosPlano } from "../src/controllers/PlanejamentoController";

beforeEach(() => {
    db.materias.length = 0;
    db.turmas.length = 0;
    getMock.mockReset();
    getMock.mockImplementation(() => ({ from: (t: string) => tableFrom(t), rpc: async () => ({ data: [], error: null }) }));

    // Mapeamento código -> id_materia usado pelas duas turmas de teste abaixo.
    db.materias.push({ id_materia: 1, codigo_materia: "FGA0001" });
    db.materias.push({ id_materia: 2, codigo_materia: "FGA0002" });
});

describe("recomendarPorHorarioLivre — filtro determinístico de horário", () => {
    it("só devolve candidatos com turma que cabe inteira no horário livre", async () => {
        // FGA0001 (obrigatória) tem turma na segunda de manhã (2M12) — cabe no livre.
        db.turmas.push({ id_materia: 1, ano_periodo: "2026.2", horario: "2M12" });
        // FGA0002 (optativa com oferta) só tem turma na terça à tarde (3T12) — NÃO cabe.
        db.turmas.push({ id_materia: 2, ano_periodo: "2026.2", horario: "3T12" });

        const livre = maskLivre(0n, ["M", "T", "N"]) & slotMaskFromHorario("2M12"); // só libera 2M12 pro teste
        const resultado = await recomendarPorHorarioLivre("42", "8117/-2 - 2018.2", livre.toString(), "2026.2");

        expect("candidatos" in resultado).toBe(true);
        const candidatos = (resultado as any).candidatos as Array<{ codigo: string }>;
        expect(candidatos.map((c) => c.codigo)).toEqual(["FGA0001"]);
    });

    it("FGA0003 (optativa sem oferta) nunca aparece como candidata, mesmo com horário livre total", async () => {
        db.turmas.push({ id_materia: 1, ano_periodo: "2026.2", horario: "2M12" });
        db.turmas.push({ id_materia: 2, ano_periodo: "2026.2", horario: "3T12" });

        const livreTotal = maskLivre(0n, ["M", "T", "N"]);
        const resultado = await recomendarPorHorarioLivre("42", "8117/-2 - 2018.2", livreTotal.toString(), "2026.2");

        const candidatos = (resultado as any).candidatos as Array<{ codigo: string }>;
        expect(candidatos.map((c) => c.codigo)).not.toContain("FGA0003");
    });

    it("freeMask = 0n devolve lista vazia sem consultar turmas", async () => {
        const resultado = await recomendarPorHorarioLivre("42", "8117/-2 - 2018.2", "0", "2026.2");
        expect((resultado as any).candidatos).toEqual([]);
    });
});

describe("recomendarPorHorarioLivre — ranking por coerência temática (Task 7)", () => {
    it("entre duas optativas que cabem no horário, prioriza a mais parecida com o histórico", async () => {
        // Mapeamento extra código -> id_materia pra FGA0004 (beforeEach só cadastra 0001/0002).
        db.materias.push({ id_materia: 4, codigo_materia: "FGA0004" });
        db.turmas.push({ id_materia: 2, ano_periodo: "2026.2", horario: "2M12" });
        db.turmas.push({ id_materia: 4, ano_periodo: "2026.2", horario: "2M12" });

        const rpcMock = jest.fn(async (fn: string) => {
            if (fn !== "match_materias") return { data: [], error: null };
            // FGA0004 mais similar ao perfil do aluno (baseado em FGA0001 concluída) do que FGA0002.
            return {
                data: [
                    { codigo_materia: "FGA0004", similaridade: 0.9 },
                    { codigo_materia: "FGA0002", similaridade: 0.3 },
                ],
                error: null,
            };
        });
        getMock.mockImplementation(() => ({
            from: (t: string) =>
                t === "materias_vetorizadas"
                    ? {
                          select: () => ({
                              in: () => ({
                                  then: (resolve: any) =>
                                      resolve({ data: [{ codigo_materia: "FGA0001", embedding: [0.1, 0.2] }], error: null }),
                              }),
                          }),
                      }
                    : tableFrom(t),
            rpc: rpcMock,
        }));

        const materiasComQuarta = [
            ...materiasMapeadasFake,
            { codigo: "FGA0004", nome: "Optativa 2 com Oferta", creditos: 4, nivel: 0, obrigatoria: false, tipo_natureza: 1, carga_horaria: 60 },
        ];
        (montarDadosPlano as jest.Mock).mockResolvedValueOnce({
            dados: {
                fluxogramaAtual: JSON.stringify({ dados_fluxograma: [[{ codigo: "FGA0001", status: "APR" }]] }),
                materiasMapeadas: materiasComQuarta,
                codigosComOferta: new Set(["FGA0002", "FGA0004"]),
            },
        });

        const livreTotal = maskLivre(0n, ["M", "T", "N"]);
        const resultado = await recomendarPorHorarioLivre("42", "8117/-2 - 2018.2", livreTotal.toString(), "2026.2");
        const candidatos = (resultado as any).candidatos as Array<{ codigo: string }>;

        const idxFGA0004 = candidatos.findIndex((c) => c.codigo === "FGA0004");
        const idxFGA0002 = candidatos.findIndex((c) => c.codigo === "FGA0002");
        expect(idxFGA0004).toBeGreaterThanOrEqual(0);
        expect(idxFGA0002).toBeGreaterThanOrEqual(0);
        expect(idxFGA0004).toBeLessThan(idxFGA0002);
    });

    it("sem histórico (nenhuma matéria concluída): não quebra, cai pra ordem neutra", async () => {
        // Mock padrão (beforeEach) já tem fluxogramaAtual sem concluídas — calcularVetorPerfil
        // deve retornar cedo (sem sequer consultar materias_vetorizadas) e o resultado
        // segue com candidatos intactos, na ordem neutra do filtro de horário.
        db.turmas.push({ id_materia: 2, ano_periodo: "2026.2", horario: "2M12" });

        const livreTotal = maskLivre(0n, ["M", "T", "N"]);
        const resultado = await recomendarPorHorarioLivre("42", "8117/-2 - 2018.2", livreTotal.toString(), "2026.2");
        expect("candidatos" in resultado).toBe(true);
        expect((resultado as any).candidatos.length).toBeGreaterThan(0);
    });

    it("RPC match_materias falhando: degrada graciosamente (não lança, mantém candidatos do filtro de horário)", async () => {
        db.turmas.push({ id_materia: 2, ano_periodo: "2026.2", horario: "2M12" });

        getMock.mockImplementation(() => ({
            from: (t: string) =>
                t === "materias_vetorizadas"
                    ? {
                          select: () => ({
                              in: () => ({
                                  then: (resolve: any) =>
                                      resolve({ data: [{ codigo_materia: "FGA0001", embedding: [0.1, 0.2] }], error: null }),
                              }),
                          }),
                      }
                    : tableFrom(t),
            rpc: async () => {
                throw new Error("timeout");
            },
        }));

        // Histórico não-vazio (FGA0001 concluída) pra garantir que calcularVetorPerfil
        // de fato chega a chamar buscarSimilaridades/RPC (senão o try/catch nunca seria exercido).
        (montarDadosPlano as jest.Mock).mockResolvedValueOnce({
            dados: {
                fluxogramaAtual: JSON.stringify({ dados_fluxograma: [[{ codigo: "FGA0001", status: "APR" }]] }),
                materiasMapeadas: materiasMapeadasFake,
                codigosComOferta: new Set(["FGA0002"]),
            },
        });

        const livreTotal = maskLivre(0n, ["M", "T", "N"]);
        const resultado = await recomendarPorHorarioLivre("42", "8117/-2 - 2018.2", livreTotal.toString(), "2026.2");
        expect("candidatos" in resultado).toBe(true);
        expect((resultado as any).candidatos.length).toBeGreaterThan(0);
    });
});

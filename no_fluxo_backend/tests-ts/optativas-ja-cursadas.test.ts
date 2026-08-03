/**
 * O atuador de optativas fazia busca semântica por tema e devolvia o resultado sem
 * olhar o histórico do aluno — então sugeria matéria que ele já tinha sido aprovado.
 *
 * Caso real: CIC0004 (ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES), aprovada em 2023.1,
 * voltando como sugestão numa busca por "algoritmos".
 */
process.env.MARITACA_API_KEY = "test-key";

type Row = Record<string, any>;
const db: { materias: Row[]; turmas: Row[]; users: Row[]; dados_users: Row[]; equivalencias: Row[] } = {
    materias: [],
    turmas: [],
    users: [],
    dados_users: [],
    equivalencias: [],
};

function makeTable(rows: Row[]) {
    return {
        select(_cols: string) {
            const filtrosIn: Array<[string, any[]]> = [];
            const filtrosEq: Array<[string, any]> = [];
            let modoSingle: "maybe" | null = null;
            const builder: any = {
                in(col: string, vals: any[]) {
                    filtrosIn.push([col, vals]);
                    return builder;
                },
                eq(col: string, val: any) {
                    filtrosEq.push([col, val]);
                    return builder;
                },
                maybeSingle() {
                    modoSingle = "maybe";
                    return builder;
                },
                then(resolve: (v: any) => any) {
                    const out = rows.filter(
                        (r) =>
                            filtrosEq.every(([c, v]) => r[c] === v) &&
                            filtrosIn.every(([c, vals]) => vals.includes(r[c]))
                    );
                    if (modoSingle === "maybe") return resolve({ data: out[0] ?? null, error: null });
                    return resolve({ data: out, error: null });
                },
            };
            return builder;
        },
    };
}

function tableFrom(table: string) {
    const t = (db as any)[table];
    if (Array.isArray(t)) return makeTable(t);
    return makeTable([]);
}

jest.mock("../src/supabase_wrapper", () => ({
    SupabaseWrapper: {
        get: () => ({
            from: (t: string) => tableFrom(t),
            rpc: async () => ({ data: "2026.2", error: null }),
        }),
    },
}));

const mockBuscarMaterias = jest.fn();
jest.mock("../src/services/sabia.service", () => ({
    SabiaService: jest.fn().mockImplementation(() => ({
        buscarMaterias: mockBuscarMaterias,
    })),
}));

import { buscarOptativas, filtrarJaCursadas } from "../src/services/chat/actuators/optativas_actuator";

/** Fluxograma com CIC0004 aprovada, no formato que parseFluxograma espera. */
const FLUXOGRAMA_COM_CIC0004 = JSON.stringify({
    dados_fluxograma: [
        [
            { codigo: "CIC0004", status: "APR" },
            { codigo: "FGA0124", status: "MATR" },
        ],
    ],
});

beforeEach(() => {
    for (const k of Object.keys(db)) (db as any)[k].length = 0;
    mockBuscarMaterias.mockReset();

    db.users.push({ email: "aluno@unb.br", id_user: 42 });
    db.dados_users.push({ id_user: 42, fluxograma_atual: FLUXOGRAMA_COM_CIC0004 });
    db.materias.push({ id_materia: 398, codigo_materia: "CIC0004" });
    db.materias.push({ id_materia: 500, codigo_materia: "FGA0009" });
    db.materias.push({ id_materia: 501, codigo_materia: "FGA0124" });
    // Oferta no período ativo pra todas (o filtro de oferta não é o alvo deste teste).
    db.turmas.push({ id_materia: 398, ano_periodo: "2026.2" });
    db.turmas.push({ id_materia: 500, ano_periodo: "2026.2" });
    db.turmas.push({ id_materia: 501, ano_periodo: "2026.2" });
});

describe("filtrarJaCursadas", () => {
    it("remove as matérias que o aluno já cumpriu", () => {
        const materias = [
            { codigo: "CIC0004", nome: "ALGORITMOS", similaridade: 0.9 },
            { codigo: "FGA0009", nome: "OUTRA", similaridade: 0.8 },
        ];
        expect(filtrarJaCursadas(materias, new Set(["CIC0004"])).map((m) => m.codigo)).toEqual([
            "FGA0009",
        ]);
    });

    it("normaliza caixa e espaço dos dois lados", () => {
        const materias = [{ codigo: " cic0004 ", nome: "ALGORITMOS", similaridade: 0.9 }];
        expect(filtrarJaCursadas(materias, new Set(["CIC0004"]))).toEqual([]);
    });

    it("sem histórico, devolve tudo", () => {
        const materias = [{ codigo: "CIC0004", nome: "ALGORITMOS", similaridade: 0.9 }];
        expect(filtrarJaCursadas(materias, new Set()).length).toBe(1);
    });
});

describe("buscarOptativas — filtro por histórico do aluno", () => {
    it("não sugere matéria que o aluno já foi aprovado", async () => {
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "CIC0004", nome: "ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES", similaridade: 0.95 },
            { codigo: "FGA0009", nome: "OUTRA COISA", similaridade: 0.7 },
        ]);

        const out = JSON.parse(await buscarOptativas(["algoritmos"], false, "aluno@unb.br"));
        expect(out.materias.map((m: any) => m.codigo)).toEqual(["FGA0009"]);
    });

    /** MATR estará concluída antes do semestre que o aluno vai cursar. */
    it("não sugere matéria que o aluno está cursando agora", async () => {
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "FGA0124", nome: "EM CURSO", similaridade: 0.9 },
            { codigo: "FGA0009", nome: "OUTRA COISA", similaridade: 0.7 },
        ]);

        const out = JSON.parse(await buscarOptativas(["tema"], false, "aluno@unb.br"));
        expect(out.materias.map((m: any) => m.codigo)).toEqual(["FGA0009"]);
    });

    /**
     * O aluno fez CIC0004; FGA0009 é dispensada por quem fez CIC0004, então sugerir
     * FGA0009 seria mandar cursar algo que ele já tem crédito.
     */
    it("não sugere matéria dispensada por equivalência do que o aluno cursou", async () => {
        db.equivalencias.push({
            id_materia: 500,
            expressao_logica: { operador: "OU", condicoes: ["CIC0004"] },
        });
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "FGA0009", nome: "EQUIVALENTE A CIC0004", similaridade: 0.9 },
        ]);

        const out = JSON.parse(await buscarOptativas(["tema"], false, "aluno@unb.br"));
        expect(out.materias).toEqual([]);
        expect(out.aviso).toBeTruthy();
    });

    it("equivalência com operador E não dispensa com só uma das pernas cursada", async () => {
        db.equivalencias.push({
            id_materia: 500,
            expressao_logica: { operador: "E", condicoes: ["CIC0004", "CIC9999"] },
        });
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "FGA0009", nome: "PRECISA DAS DUAS", similaridade: 0.9 },
        ]);

        const out = JSON.parse(await buscarOptativas(["tema"], false, "aluno@unb.br"));
        expect(out.materias.map((m: any) => m.codigo)).toEqual(["FGA0009"]);
    });

    it("sem email (chat deslogado) mantém o comportamento antigo, sem filtrar histórico", async () => {
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "CIC0004", nome: "ALGORITMOS", similaridade: 0.95 },
        ]);

        const out = JSON.parse(await buscarOptativas(["algoritmos"], false));
        expect(out.materias.map((m: any) => m.codigo)).toEqual(["CIC0004"]);
    });

    it("aluno sem cadastro não derruba a busca — só não filtra", async () => {
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "CIC0004", nome: "ALGORITMOS", similaridade: 0.95 },
        ]);

        const out = JSON.parse(await buscarOptativas(["algoritmos"], false, "naoexiste@unb.br"));
        expect(out.materias.map((m: any) => m.codigo)).toEqual(["CIC0004"]);
    });

    it("quando tudo que veio já foi cursado, avisa em vez de devolver lista vazia sem contexto", async () => {
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "CIC0004", nome: "ALGORITMOS", similaridade: 0.95 },
        ]);

        const out = JSON.parse(await buscarOptativas(["algoritmos"], false, "aluno@unb.br"));
        expect(out.materias).toEqual([]);
        expect(String(out.aviso)).toMatch(/já/i);
    });
});

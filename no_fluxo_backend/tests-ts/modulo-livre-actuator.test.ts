/**
 * Módulo livre = qualquer matéria do catálogo da UnB que NÃO é obrigatória nem
 * optativa da matriz do aluno. Como a busca semântica (SabiaService) varre o
 * catálogo inteiro, ela pode devolver uma matéria que É da matriz do aluno —
 * esse atuador precisa filtrar isso fora, senão "módulo livre" reapresentaria
 * a própria obrigatória/optativa do curso do aluno.
 *
 * Convenção de mock igual a optativas-ja-cursadas.test.ts: Supabase mockado na
 * mão (makeTable/tableFrom), sem rede real. Acrescenta as tabelas `matrizes` e
 * `materias_por_curso`, usadas pela resolução de id_matriz e pelo Set de
 * códigos da matriz.
 */
process.env.MARITACA_API_KEY = "test-key";

type Row = Record<string, any>;
const db: {
    materias: Row[];
    turmas: Row[];
    users: Row[];
    dados_users: Row[];
    equivalencias: Row[];
    matrizes: Row[];
    materias_por_curso: Row[];
} = {
    materias: [],
    turmas: [],
    users: [],
    dados_users: [],
    equivalencias: [],
    matrizes: [],
    materias_por_curso: [],
};

function makeTable(rows: Row[]) {
    return {
        select(_cols: string) {
            const filtrosIn: Array<[string, any[]]> = [];
            const filtrosEq: Array<[string, any]> = [];
            const filtrosLike: Array<[string, string]> = [];
            let ordenacao: string | null = null;
            let limite: number | null = null;
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
                like(col: string, pattern: string) {
                    filtrosLike.push([col, pattern]);
                    return builder;
                },
                order(col: string) {
                    ordenacao = col;
                    return builder;
                },
                limit(n: number) {
                    limite = n;
                    return builder;
                },
                maybeSingle() {
                    modoSingle = "maybe";
                    return builder;
                },
                then(resolve: (v: any) => any) {
                    let out = rows.filter((r) => {
                        if (!filtrosEq.every(([c, v]) => r[c] === v)) return false;
                        if (!filtrosIn.every(([c, vals]) => vals.includes(r[c]))) return false;
                        if (
                            !filtrosLike.every(([c, pattern]) => {
                                const prefix = pattern.replace(/%$/, "");
                                return String(r[c] ?? "").startsWith(prefix);
                            })
                        )
                            return false;
                        return true;
                    });
                    if (ordenacao) {
                        const col = ordenacao;
                        out = [...out].sort((a, b) => String(a[col]).localeCompare(String(b[col])));
                    }
                    if (limite != null) out = out.slice(0, limite);
                    if (modoSingle === "maybe") return resolve({ data: out[0] ?? null, error: null });
                    return resolve({ data: out, error: null });
                },
            };
            return builder;
        },
    };
}

/** Ligada num teste isolado pra simular falha transitória do Supabase. */
let falharMateriasPorCurso = false;

function tableFrom(table: string) {
    if (table === "materias_por_curso" && falharMateriasPorCurso) {
        return {
            select: () => ({
                eq: () => ({
                    then: (_resolve: (v: any) => any, reject: (e: any) => any) => {
                        reject(new Error("falha simulada de conexão"));
                    },
                }),
            }),
        };
    }
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

import { buscarModuloLivre } from "../src/services/chat/actuators/modulo_livre_actuator";

const CURRICULO = "8117/-2 - 2018.2";

/** Fluxograma com MOD0002 (módulo livre já cursado) aprovada. */
const FLUXOGRAMA_COM_MOD0002 = JSON.stringify({
    dados_fluxograma: [[{ codigo: "MOD0002", status: "APR" }]],
});

beforeEach(() => {
    for (const k of Object.keys(db)) (db as any)[k].length = 0;
    mockBuscarMaterias.mockReset();
    falharMateriasPorCurso = false;

    db.matrizes.push({ id_matriz: 10, curriculo_completo: CURRICULO });

    // FGA0242 é obrigatória da matriz do aluno.
    db.materias.push({ id_materia: 1, codigo_materia: "FGA0242" });
    db.materias_por_curso.push({ id_materia: 1, id_matriz: 10, tipo_natureza: 0 });

    // FGA0333 é optativa da matriz do aluno.
    db.materias.push({ id_materia: 2, codigo_materia: "FGA0333" });
    db.materias_por_curso.push({ id_materia: 2, id_matriz: 10, tipo_natureza: 1 });

    // MOD0001 e MOD0002 NÃO estão em materias_por_curso pra id_matriz 10 —
    // candidatos legítimos a módulo livre.
    db.materias.push({ id_materia: 3, codigo_materia: "MOD0001" });
    db.materias.push({ id_materia: 4, codigo_materia: "MOD0002" });

    db.users.push({ email: "aluno@unb.br", id_user: 42 });
});

describe("buscarModuloLivre — exclui matérias da matriz do aluno", () => {
    it("matéria obrigatória da matriz é excluída mesmo se a busca semântica devolver ela", async () => {
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "FGA0242", nome: "OBRIGATÓRIA DA MATRIZ", similaridade: 0.95 },
            { codigo: "MOD0001", nome: "MÓDULO LIVRE", similaridade: 0.8 },
        ]);

        const out = JSON.parse(await buscarModuloLivre(["tema"], false, undefined, CURRICULO));
        expect(out.materias.map((m: any) => m.codigo)).toEqual(["MOD0001"]);
    });

    it("matéria optativa da matriz também é excluída (não só obrigatória)", async () => {
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "FGA0333", nome: "OPTATIVA DA MATRIZ", similaridade: 0.9 },
            { codigo: "MOD0001", nome: "MÓDULO LIVRE", similaridade: 0.8 },
        ]);

        const out = JSON.parse(await buscarModuloLivre(["tema"], false, undefined, CURRICULO));
        expect(out.materias.map((m: any) => m.codigo)).toEqual(["MOD0001"]);
    });

    it("matéria fora da matriz (nem obrigatória nem optativa) é mantida", async () => {
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "MOD0001", nome: "MÓDULO LIVRE", similaridade: 0.8 },
        ]);

        const out = JSON.parse(await buscarModuloLivre(["tema"], false, undefined, CURRICULO));
        expect(out.materias.map((m: any) => m.codigo)).toEqual(["MOD0001"]);
    });
});

describe("buscarModuloLivre — filtro de já-cursadas", () => {
    it("não sugere módulo livre que o aluno já cursou", async () => {
        db.dados_users.push({ id_user: 42, fluxograma_atual: FLUXOGRAMA_COM_MOD0002 });
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "MOD0001", nome: "MÓDULO LIVRE NOVO", similaridade: 0.85 },
            { codigo: "MOD0002", nome: "MÓDULO LIVRE JÁ CURSADO", similaridade: 0.9 },
        ]);

        const out = JSON.parse(await buscarModuloLivre(["tema"], false, "aluno@unb.br", CURRICULO));
        expect(out.materias.map((m: any) => m.codigo)).toEqual(["MOD0001"]);
    });
});

describe("buscarModuloLivre — curriculoCompleto não resolve matriz", () => {
    it("devolve o formato erro, sem cair pra lista sem filtro", async () => {
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "FGA0242", nome: "OBRIGATÓRIA DE OUTRA MATRIZ", similaridade: 0.95 },
        ]);

        const out = JSON.parse(await buscarModuloLivre(["tema"], false, undefined, "matriz-inexistente"));
        expect(out.erro).toBeTruthy();
        expect(out.materias).toBeUndefined();
        // Não deve ter chamado a busca semântica em vão nem devolvido nada da "matriz".
        expect(mockBuscarMaterias).not.toHaveBeenCalled();
    });
});

describe("buscarModuloLivre — falha ao consultar a matriz do aluno", () => {
    it("degrada pro erro padrão em vez de propagar exceção crua", async () => {
        falharMateriasPorCurso = true;
        mockBuscarMaterias.mockResolvedValue([
            { codigo: "MOD0001", nome: "MÓDULO LIVRE", similaridade: 0.8 },
        ]);

        const out = JSON.parse(await buscarModuloLivre(["tema"], false, undefined, CURRICULO));
        expect(out.erro).toBeTruthy();
        expect(out.materias).toBeUndefined();
    });
});

describe("buscarModuloLivre — apenasComOferta filtra por oferta ativa", () => {
    it("mantém só quem tem turma no período letivo ativo", async () => {
        // Só MOD0001 tem turma no período ativo (2026.2, mockado no rpc acima).
        db.turmas.push({ id_materia: 3, ano_periodo: "2026.2" });

        mockBuscarMaterias.mockResolvedValue([
            { codigo: "MOD0001", nome: "COM OFERTA", similaridade: 0.9 },
            { codigo: "MOD0002", nome: "SEM OFERTA", similaridade: 0.8 },
        ]);

        const out = JSON.parse(await buscarModuloLivre(["tema"], true, undefined, CURRICULO));
        expect(out.materias.map((m: any) => m.codigo)).toEqual(["MOD0001"]);
    });
});

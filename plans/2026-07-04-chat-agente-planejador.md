# Chat de Agente do Planejador de Formatura — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chat com agente IA (Maritaca sabiá-3, tool calling) embutido em `/plano-formatura` que responde perguntas e executa ações no plano (ajustar carga, adiar/priorizar matérias, simular cenários), com o plano se atualizando na tela.

**Architecture:** Backend Express ganha suporte a restrições (`adiar`/`priorizar`) no greedy do Motor 2, um serviço de agente (`planejador_agente.service.ts`) com loop de tool calling contra a API da Maritaca, e endpoint stateless `POST /planejamento/chat`. Frontend ganha painel de chat colapsável, chips de restrições e extensões no store runes existente.

**Tech Stack:** Express + TypeScript (backend, Jest em `tests-ts/`), Maritaca API (OpenAI-compatible, modelo `sabia-3`), SvelteKit + Svelte 5 runes + Tailwind 4 (frontend).

**Spec:** `docs/chat-agente-planejador-spec.md`

## Global Constraints

- Backend roda na porta 3325 em prod; testes com `npm test` dentro de `no_fluxo_backend/`.
- `MARITACA_API_KEY` já existe no `.env` do backend. URL da API: `https://chat.maritaca.ai/api/chat/completions`, header `Authorization: Key <MARITACA_API_KEY>`, modelo `sabia-3`.
- Loop do agente: máx. **5 iterações**. Histórico enviado: últimas **20 mensagens**.
- Códigos de matéria sempre normalizados com `trim().toUpperCase()`.
- Frontend usa snake_case no body das chamadas (`curriculo_completo`, etc.) — manter.
- Commits frequentes, mensagens em português seguindo padrão do repo (`feat:`, `fix:`, `test:`), rodapé `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Todos os comandos de teste backend: `cd no_fluxo_backend && npx jest tests-ts/<arquivo> -t "<nome>"`.

## File Structure

| Arquivo | Ação | Responsabilidade |
|---|---|---|
| `no_fluxo_backend/src/types/planejamento.ts` | Modify | + `RestricoesPlano`, campo `restricoes?` em `PreferenciasPlano` |
| `no_fluxo_backend/src/services/plano_formatura.service.ts` | Modify | Greedy respeita adiar/priorizar |
| `no_fluxo_backend/src/services/planejador_agente.service.ts` | Create | Executores de tools + loop do agente + cliente Maritaca |
| `no_fluxo_backend/src/controllers/PlanejamentoController.ts` | Modify | Extrai `montarDadosPlano()`, aceita `restricoes` no gerar-plano, + rota `chat` |
| `no_fluxo_backend/tests-ts/planejamento-restricoes.test.ts` | Create | Testes das restrições no greedy |
| `no_fluxo_backend/tests-ts/planejador-agente.test.ts` | Create | Testes dos executores e do loop (Maritaca mockada) |
| `no_fluxo_frontend_svelte/src/lib/types/plano-formatura.ts` | Modify | + `RestricoesPlano`, `PlannerChatMessage`, `PlannerChatResponse` |
| `no_fluxo_frontend_svelte/src/lib/services/plano-formatura.service.ts` | Modify | + método `chat()`, `gerarPlano` envia restrições |
| `no_fluxo_frontend_svelte/src/lib/stores/plano-formatura.store.svelte.ts` | Modify | + estado de chat, `sendMessage`, `removerRestricao` |
| `no_fluxo_frontend_svelte/src/lib/components/plano-formatura/PlannerChatPanel.svelte` | Create | Painel de chat colapsável |
| `no_fluxo_frontend_svelte/src/lib/components/plano-formatura/RestricoesChips.svelte` | Create | Chips removíveis de restrições ativas |
| `no_fluxo_frontend_svelte/src/lib/components/plano-formatura/PlanoFormaturaView.svelte` | Modify | Monta painel + chips |
| `no_fluxo_backend/tests-ts/testes_controller.test.ts` | Delete | Referencia controller já removido |

---

### Task 0: Remover teste órfão do TestesController

O arquivo `testes_controller.ts` foi removido do projeto, mas seu teste ficou para trás e quebra a suíte.

**Files:**
- Delete: `no_fluxo_backend/tests-ts/testes_controller.test.ts`

- [ ] **Step 1: Deletar o arquivo e verificar que a suíte compila**

```bash
rm no_fluxo_backend/tests-ts/testes_controller.test.ts
cd no_fluxo_backend && npx tsc --noEmit
```

Expected: sem erros de compilação referentes a `testes_controller`.

- [ ] **Step 2: Commit**

```bash
git add -A no_fluxo_backend/tests-ts
git commit -m "test: Remove teste órfão do TestesController removido"
```

---

### Task 1: RestricoesPlano no Motor 2 (tipos + greedy)

**Files:**
- Modify: `no_fluxo_backend/src/types/planejamento.ts` (após `ObjetivoPlano`, ~linha 14; e dentro de `PreferenciasPlano`, ~linha 30)
- Modify: `no_fluxo_backend/src/services/plano_formatura.service.ts` (função `distribuirPorSemestres`, linhas 247–404)
- Test: `no_fluxo_backend/tests-ts/planejamento-restricoes.test.ts`

**Interfaces:**
- Consumes: `distribuirPorSemestres(materias, completedCodes, preferencias, numeroPeriodo, ...)` existente.
- Produces: `RestricoesPlano { adiar: string[]; priorizar: string[] }` exportada de `types/planejamento.ts`; `PreferenciasPlano.restricoes?: RestricoesPlano`. Semântica: `adiar` = código excluído das candidatas APENAS do semestre de índice 0; `priorizar` = código vai pro topo da ordenação (antes do score) assim que desbloqueado. Tasks 3–5 dependem exatamente desses nomes.

- [ ] **Step 1: Escrever os testes que falham**

> **Nota sobre fixtures:** antes de escrever, confira em `tests-ts/planejamento.test.ts` o formato exato de `preRequisitos` aceito por `parseExpressaoLogicaFromDb`/`satisfazExpressaoLogica` e use o mesmo formato no helper `mat()`. O formato abaixo (`{ condicoes: [...], operador: "AND" }`) é o esperado, mas os testes existentes são a fonte da verdade.

Criar `no_fluxo_backend/tests-ts/planejamento-restricoes.test.ts`:

```ts
import { distribuirPorSemestres } from "../src/services/plano_formatura.service";
import type { MateriaInput, PreferenciasPlano } from "../src/types/planejamento";

function mat(codigo: string, nivel: number, preReq: string | null = null): MateriaInput {
    return {
        codigo,
        nome: codigo,
        creditos: 4,
        carga_horaria: 60,
        nivel,
        obrigatoria: true,
        tipo_natureza: 0,
        preRequisitos: preReq ? { condicoes: [{ codigo: preReq }], operador: "AND" } : null,
        coRequisitos: null,
    };
}

function prefs(restricoes?: { adiar: string[]; priorizar: string[] }): PreferenciasPlano {
    return { limiteCreditos: 8, objetivo: "equilibrado", trabalha: false, restricoes };
}

// Helper: em qual índice de semestre a matéria caiu (-1 = não alocada)
function semestreDe(semestres: ReturnType<typeof distribuirPorSemestres>, codigo: string): number {
    for (const s of semestres) {
        for (const m of s.materias) {
            if ("codigo" in m && m.codigo === codigo) return s.indice;
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
        const zzz: MateriaInput = { ...mat("ZZZ0009", 5), obrigatoria: false, tipo_natureza: 1 };
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
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd no_fluxo_backend && npx jest tests-ts/planejamento-restricoes.test.ts
```

Expected: FAIL — os testes de adiar/priorizar quebram (comportamento não existe); o de regressão passa.

- [ ] **Step 3: Adicionar o tipo**

Em `no_fluxo_backend/src/types/planejamento.ts`, logo após `export type TipoSemestre` (linha 17):

```ts
/**
 * Restrições impostas pelo aluno (via chat do agente ou chips na UI).
 * Códigos sempre normalizados (trim + uppercase) antes do uso.
 */
export interface RestricoesPlano {
    /** Códigos que NÃO podem entrar no próximo semestre (índice 0 do plano). */
    adiar: string[];
    /** Códigos forçados para o semestre mais cedo possível (respeitando pré-requisitos). */
    priorizar: string[];
}
```

E dentro de `PreferenciasPlano` (após o campo `trabalha`):

```ts
    /** Restrições de alocação impostas pelo aluno. Opcional — ausente = sem restrições. */
    restricoes?: RestricoesPlano;
```

- [ ] **Step 4: Implementar no greedy**

Em `no_fluxo_backend/src/services/plano_formatura.service.ts`, dentro de `distribuirPorSemestres`, logo após `const scores = precomputarScores(...)` (linha ~258):

```ts
    const adiarSet = new Set((preferencias.restricoes?.adiar ?? []).map(norm));
    const priorizarSet = new Set((preferencias.restricoes?.priorizar ?? []).map(norm));
```

No loop de candidatas (linha ~276), pular adiadas apenas no primeiro semestre:

```ts
        for (const cod of restantes) {
            const info = scores.get(cod)!;
            if (indiceSemestre === 0 && adiarSet.has(cod)) continue; // restrição: adiar
            if (isDesbloqueada(info.materia, cumulados)) {
                candidatas.push(info);
            }
        }
```

No sort (linha ~285), priorizadas primeiro:

```ts
        candidatas.sort((a, b) => {
            const aPri = priorizarSet.has(norm(a.materia.codigo)) ? 1 : 0;
            const bPri = priorizarSet.has(norm(b.materia.codigo)) ? 1 : 0;
            if (aPri !== bPri) return bPri - aPri; // restrição: priorizar
            if (b.score !== a.score) return b.score - a.score;
            if (a.materia.nivel !== b.materia.nivel) return a.materia.nivel - b.materia.nivel;
            return a.materia.codigo.localeCompare(b.materia.codigo);
        });
```

Atenção ao caso `candidatas.length === 0` com `restantes.size > 0` no semestre 0 (tudo adiado): o `break` existente encerraria o plano. Trocar o `if (candidatas.length === 0) break;` (linha ~283) por:

```ts
        if (candidatas.length === 0) {
            // Se só não há candidatas porque tudo foi adiado no semestre 0,
            // criar semestre vazio e seguir — as adiadas voltam no índice 1.
            if (indiceSemestre === 0 && adiarSet.size > 0) {
                semestres.push({
                    indice: 0,
                    tipo: "recomendado",
                    semestre: semestreBaseStr ? avancarSemestres(semestreBaseStr, 1) : undefined,
                    creditos: 0,
                    materias: [],
                });
                indiceSemestre++;
                continue;
            }
            break;
        }
```

- [ ] **Step 5: Rodar testes novos + regressão completa**

```bash
cd no_fluxo_backend && npx jest tests-ts/planejamento-restricoes.test.ts && npx jest
```

Expected: PASS nos novos; suíte completa verde (nenhum teste existente depende de restricoes).

- [ ] **Step 6: Commit**

```bash
git add no_fluxo_backend/src/types/planejamento.ts no_fluxo_backend/src/services/plano_formatura.service.ts no_fluxo_backend/tests-ts/planejamento-restricoes.test.ts
git commit -m "feat: Motor 2 aceita restrições adiar/priorizar no greedy"
```

---

### Task 2: Extrair `montarDadosPlano` no controller + gerar-plano aceita restrições

O handler `gerar-plano` tem ~190 linhas de coleta de dados (dados_users → matriz → matérias → turmas → pré/co-requisitos → mapeamento). A rota `chat` (Task 5) precisa exatamente dos mesmos dados. Extrair para função reutilizável, sem mudar comportamento.

**Files:**
- Modify: `no_fluxo_backend/src/controllers/PlanejamentoController.ts`

**Interfaces:**
- Produces (usada pela Task 5):

```ts
interface DadosPlano {
    idUser: string;
    idCurso: string;
    numeroPeriodo: number;
    preferencias: PreferenciasPlano;
    cargaHorariaIntegralizada: CargaIntegralizada;
    exigidaMatriz: CargaIntegralizada;
    fluxogramaAtual: string | null | undefined;
    materiasMapeadas: MateriaInput[];
    codigosComOferta: Set<string>;
}

async function montarDadosPlano(
    idUser: string,
    input: PlanoInput
): Promise<{ dados?: DadosPlano; status?: number; error?: string }>
```

- Produces: `parseBody` passa a aceitar `body.restricoes` (`{ adiar?: string[], priorizar?: string[] }`), anexando em `input.preferencias.restricoes` com códigos normalizados.

- [ ] **Step 1: Extrair a função**

Mover o corpo do handler `gerar-plano` (da busca em `dados_users`, linha ~311, até a montagem de `materiasMapeadas`, linha ~460) para `montarDadosPlano(idUser, input)` declarada junto aos helpers (após `buscarMateriasFaltantes`). Erros que hoje retornam `res.status(404/400)` viram `return { status: 404, error: "..." }`. A função monta `preferencias` com o mesmo fallback atual (body → `dados_users.preferencias_plano` → default 24/equilibrado/false), preservando `input.preferencias.restricoes` se presente:

```ts
    const prefsSalvas = (usuarioData.preferencias_plano as Record<string, any>) || {};
    const preferencias: PreferenciasPlano = input.preferencias ?? {
        limiteCreditos: Number(prefsSalvas.limiteCreditos) || 24,
        objetivo: prefsSalvas.objetivo === "velocidade" ? "velocidade" : "equilibrado",
        trabalha: Boolean(prefsSalvas.trabalha),
    };
```

O handler `gerar-plano` vira: auth → `parseBody` → `montarDadosPlano` → se erro, `res.status(dados.status).json({error})` → `gerarPlanoCompletov2(...)` com os campos de `DadosPlano` → `res.json(plano)`.

- [ ] **Step 2: parseBody aceita restricoes**

Em `parseBody`, antes do `return { input: ... }` (linha ~106):

```ts
    // Restrições opcionais (adiar/priorizar) — normaliza códigos.
    const rawRestricoes = body.restricoes;
    if (isObject(rawRestricoes)) {
        const normList = (v: unknown): string[] =>
            Array.isArray(v) ? v.filter((c): c is string => typeof c === "string").map((c) => c.trim().toUpperCase()) : [];
        const restricoes = { adiar: normList(rawRestricoes.adiar), priorizar: normList(rawRestricoes.priorizar) };
        if (restricoes.adiar.length > 0 || restricoes.priorizar.length > 0) {
            if (preferencias) preferencias.restricoes = restricoes;
        }
    }
```

Obs.: quando o body não traz `preferencias` explícitas mas traz `limite_creditos` (fluxo atual do frontend), `preferencias` já foi construída algumas linhas acima — o attach funciona nos dois caminhos.

- [ ] **Step 3: Compilar e rodar a suíte**

```bash
cd no_fluxo_backend && npx tsc --noEmit && npx jest
```

Expected: compila; todos os testes passam (refactor sem mudança de comportamento).

- [ ] **Step 4: Commit**

```bash
git add no_fluxo_backend/src/controllers/PlanejamentoController.ts
git commit -m "refactor: Extrai montarDadosPlano e aceita restricoes no gerar-plano"
```

---

### Task 3: Executores de tools do agente

**Files:**
- Create: `no_fluxo_backend/src/services/planejador_agente.service.ts`
- Test: `no_fluxo_backend/tests-ts/planejador-agente.test.ts`

**Interfaces:**
- Consumes: `gerarPlanoCompletov2` (Task 1), `RestricoesPlano`, `DadosPlano`-shape (Task 2 — replicada aqui como `AgenteContexto` para não importar do controller).
- Produces (usadas pela Task 4 e testadas aqui):

```ts
export interface AgenteContexto {
    idUser: string;
    idCurso: string;
    numeroPeriodo: number;
    preferencias: PreferenciasPlano;      // mutado por ajustar_carga
    restricoes: RestricoesPlano;          // mutado por mover_materia
    cargaHorariaIntegralizada: CargaIntegralizada;
    exigidaMatriz: CargaIntegralizada;
    fluxogramaAtual: string | null | undefined;
    materias: MateriaInput[];
    codigosComOferta: Set<string>;
}

export function gerarPlanoDoContexto(ctx: AgenteContexto): PlanoFormaturav2;
export function executarTool(
    nome: string,
    args: Record<string, unknown>,
    ctx: AgenteContexto
): { resultado: string; planoAtualizado?: PlanoFormaturav2 };
```

`resultado` é sempre JSON string (vai como mensagem `role:"tool"` pro LLM). `planoAtualizado` presente apenas quando a tool alterou o plano (ajustar_carga, mover_materia).

- [ ] **Step 1: Escrever os testes que falham**

Criar `no_fluxo_backend/tests-ts/planejador-agente.test.ts`:

```ts
import {
    executarTool,
    gerarPlanoDoContexto,
    type AgenteContexto,
} from "../src/services/planejador_agente.service";
import type { MateriaInput } from "../src/types/planejamento";

function mat(codigo: string, nivel: number, preReq: string | null = null): MateriaInput {
    return {
        codigo, nome: `Materia ${codigo}`, creditos: 4, carga_horaria: 60, nivel,
        obrigatoria: true, tipo_natureza: 0,
        preRequisitos: preReq ? { condicoes: [{ codigo: preReq }], operador: "AND" } : null,
        coRequisitos: null,
    };
}

function ctxBase(): AgenteContexto {
    return {
        idUser: "1", idCurso: "1", numeroPeriodo: 3,
        preferencias: { limiteCreditos: 8, objetivo: "equilibrado", trabalha: false },
        restricoes: { adiar: [], priorizar: [] },
        cargaHorariaIntegralizada: { total: 0, obrigatoria: 0, optativa: 0, complementar: 0 },
        exigidaMatriz: { total: 240, obrigatoria: 240, optativa: 0, complementar: 0 },
        fluxogramaAtual: null,
        materias: [mat("AAA0001", 1), mat("BBB0002", 1), mat("CCC0003", 2, "AAA0001"), mat("DDD0004", 2)],
        codigosComOferta: new Set(),
    };
}

describe("planejador_agente — executores de tools", () => {
    test("consultar_plano sem código devolve resumo", () => {
        const { resultado, planoAtualizado } = executarTool("consultar_plano", {}, ctxBase());
        const r = JSON.parse(resultado);
        expect(r.semestresRestantes).toBeGreaterThan(0);
        expect(planoAtualizado).toBeUndefined();
    });

    test("consultar_plano com código devolve detalhes da matéria", () => {
        const { resultado } = executarTool("consultar_plano", { codigo: "aaa0001" }, ctxBase());
        const r = JSON.parse(resultado);
        expect(r.codigo).toBe("AAA0001");
        expect(r.semestreIndice).toBe(0);
        expect(typeof r.score).toBe("number");
    });

    test("consultar_plano com código inexistente devolve erro descritivo", () => {
        const { resultado } = executarTool("consultar_plano", { codigo: "XXX9999" }, ctxBase());
        const r = JSON.parse(resultado);
        expect(r.erro).toContain("XXX9999");
    });

    test("simular_cenario devolve diff sem mutar o contexto", () => {
        const ctx = ctxBase();
        const { resultado, planoAtualizado } = executarTool("simular_cenario", { limiteCreditos: 4 }, ctx);
        const r = JSON.parse(resultado);
        expect(r.depois.semestresRestantes).toBeGreaterThan(r.antes.semestresRestantes);
        expect(r.deltaSemestres).toBeGreaterThan(0);
        expect(planoAtualizado).toBeUndefined();
        expect(ctx.preferencias.limiteCreditos).toBe(8); // não mutou
    });

    test("ajustar_carga muta preferências e devolve plano atualizado", () => {
        const ctx = ctxBase();
        const { resultado, planoAtualizado } = executarTool("ajustar_carga", { limiteCreditos: 4 }, ctx);
        const r = JSON.parse(resultado);
        expect(ctx.preferencias.limiteCreditos).toBe(4);
        expect(planoAtualizado).toBeDefined();
        expect(r.semestresRestantes).toBe(planoAtualizado!.semestresRestantes);
    });

    test("ajustar_carga rejeita limite fora de 8–32", () => {
        const ctx = ctxBase();
        const { resultado, planoAtualizado } = executarTool("ajustar_carga", { limiteCreditos: 50 }, ctx);
        expect(JSON.parse(resultado).erro).toBeDefined();
        expect(planoAtualizado).toBeUndefined();
        expect(ctx.preferencias.limiteCreditos).toBe(8);
    });

    test("mover_materia adiar adiciona restrição e regenera", () => {
        const ctx = ctxBase();
        const { planoAtualizado } = executarTool("mover_materia", { codigo: "AAA0001", acao: "adiar" }, ctx);
        expect(ctx.restricoes.adiar).toContain("AAA0001");
        expect(planoAtualizado).toBeDefined();
        const sem0 = planoAtualizado!.plano[0];
        const codigosSem0 = sem0.materias.filter((m) => "codigo" in m).map((m: any) => m.codigo);
        expect(codigosSem0).not.toContain("AAA0001");
    });

    test("mover_materia priorizar remove código da lista adiar (mutuamente exclusivos)", () => {
        const ctx = ctxBase();
        ctx.restricoes.adiar = ["AAA0001"];
        executarTool("mover_materia", { codigo: "AAA0001", acao: "priorizar" }, ctx);
        expect(ctx.restricoes.adiar).not.toContain("AAA0001");
        expect(ctx.restricoes.priorizar).toContain("AAA0001");
    });

    test("mover_materia remover_restricao limpa o código das duas listas", () => {
        const ctx = ctxBase();
        ctx.restricoes.adiar = ["AAA0001"];
        const { planoAtualizado } = executarTool("mover_materia", { codigo: "AAA0001", acao: "remover_restricao" }, ctx);
        expect(ctx.restricoes.adiar).toHaveLength(0);
        expect(planoAtualizado).toBeDefined();
    });

    test("mover_materia com código fora das faltantes devolve erro", () => {
        const ctx = ctxBase();
        const { resultado, planoAtualizado } = executarTool("mover_materia", { codigo: "XXX9999", acao: "adiar" }, ctx);
        expect(JSON.parse(resultado).erro).toContain("XXX9999");
        expect(planoAtualizado).toBeUndefined();
    });

    test("tool desconhecida devolve erro", () => {
        const { resultado } = executarTool("tool_inexistente", {}, ctxBase());
        expect(JSON.parse(resultado).erro).toBeDefined();
    });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd no_fluxo_backend && npx jest tests-ts/planejador-agente.test.ts
```

Expected: FAIL — módulo não existe.

- [ ] **Step 3: Implementar os executores**

Criar `no_fluxo_backend/src/services/planejador_agente.service.ts` (parte 1 — executores; o loop entra na Task 4):

```ts
/**
 * Agente de chat do planejador de formatura (Motor 2).
 *
 * Executores de tools + loop de tool calling contra a API da Maritaca
 * (sabia-3, OpenAI-compatible). O controller monta o AgenteContexto a
 * partir do banco (montarDadosPlano) e chama `conversar`.
 *
 * Spec: docs/chat-agente-planejador-spec.md
 */

import logger from "../logger";
import { gerarPlanoCompletov2 } from "./plano_formatura.service";
import type {
    CargaIntegralizada,
    MateriaInput,
    MateriaPlano,
    PlanoFormaturav2,
    PreferenciasPlano,
    RestricoesPlano,
} from "../types/planejamento";

function norm(codigo: string): string {
    return (codigo || "").trim().toUpperCase();
}

export interface AgenteContexto {
    idUser: string;
    idCurso: string;
    numeroPeriodo: number;
    preferencias: PreferenciasPlano;
    restricoes: RestricoesPlano;
    cargaHorariaIntegralizada: CargaIntegralizada;
    exigidaMatriz: CargaIntegralizada;
    fluxogramaAtual: string | null | undefined;
    materias: MateriaInput[];
    codigosComOferta: Set<string>;
}

/** Gera o plano v2 a partir do contexto, aplicando as restrições atuais. */
export function gerarPlanoDoContexto(ctx: AgenteContexto): PlanoFormaturav2 {
    const prefs: PreferenciasPlano = { ...ctx.preferencias, restricoes: ctx.restricoes };
    return gerarPlanoCompletov2(
        ctx.idUser,
        ctx.idCurso,
        ctx.numeroPeriodo,
        ctx.cargaHorariaIntegralizada,
        ctx.exigidaMatriz,
        ctx.fluxogramaAtual,
        ctx.materias,
        prefs,
        ctx.codigosComOferta
    );
}

// ---------------------------------------------------------------
// Executores de tools
// ---------------------------------------------------------------

function resumoDoPlano(plano: PlanoFormaturav2) {
    let criticas = 0;
    for (const s of plano.plano) {
        for (const m of s.materias) if ("critica" in m && (m as MateriaPlano).critica) criticas++;
    }
    return {
        semestresRestantes: plano.semestresRestantes,
        formaturaEstimada: plano.formaturaEstimada ?? null,
        materiasCriticas: criticas,
        materiasNaoAlocadas: plano.materiasNaoAlocadas,
        chOptativaFaltante: plano.chOptativaFaltante,
        chComplementarFaltante: plano.chComplementarFaltante,
    };
}

function consultarPlano(args: Record<string, unknown>, ctx: AgenteContexto): string {
    const plano = gerarPlanoDoContexto(ctx);
    const codigo = typeof args.codigo === "string" ? norm(args.codigo) : null;

    if (!codigo) return JSON.stringify(resumoDoPlano(plano));

    for (const s of plano.plano) {
        for (const m of s.materias) {
            if ("codigo" in m && (m as MateriaPlano).codigo === codigo) {
                const mp = m as MateriaPlano;
                return JSON.stringify({
                    codigo: mp.codigo,
                    nome: mp.nome,
                    semestreIndice: s.indice,
                    semestreLabel: s.semestre ?? null,
                    creditos: mp.creditos,
                    critica: mp.critica,
                    score: mp.score,
                    desbloqueiaDireto: mp.desbloqueiaDireto,
                    desbloqueiaIndireto: mp.desbloqueiaIndireto,
                    motivo: mp.motivo,
                });
            }
        }
    }
    return JSON.stringify({
        erro: `Matéria ${codigo} não encontrada no plano. Ela pode já estar concluída, em curso, ou não pertencer ao currículo.`,
    });
}

function simularCenario(args: Record<string, unknown>, ctx: AgenteContexto): string {
    const antes = resumoDoPlano(gerarPlanoDoContexto(ctx));

    const simCtx: AgenteContexto = {
        ...ctx,
        preferencias: { ...ctx.preferencias },
        restricoes: {
            adiar: [...ctx.restricoes.adiar],
            priorizar: [...ctx.restricoes.priorizar],
        },
    };
    const limite = Number(args.limiteCreditos);
    if (Number.isFinite(limite) && limite >= 8 && limite <= 32) {
        simCtx.preferencias.limiteCreditos = Math.floor(limite);
    }
    if (Array.isArray(args.adiar)) {
        for (const c of args.adiar) if (typeof c === "string") simCtx.restricoes.adiar.push(norm(c));
    }
    if (Array.isArray(args.priorizar)) {
        for (const c of args.priorizar) if (typeof c === "string") simCtx.restricoes.priorizar.push(norm(c));
    }

    const depois = resumoDoPlano(gerarPlanoDoContexto(simCtx));
    return JSON.stringify({
        antes,
        depois,
        deltaSemestres: depois.semestresRestantes - antes.semestresRestantes,
    });
}

function ajustarCarga(
    args: Record<string, unknown>,
    ctx: AgenteContexto
): { resultado: string; planoAtualizado?: PlanoFormaturav2 } {
    const limite = Number(args.limiteCreditos);
    if (!Number.isFinite(limite) || limite < 8 || limite > 32) {
        return { resultado: JSON.stringify({ erro: "limiteCreditos deve ser um inteiro entre 8 e 32." }) };
    }
    ctx.preferencias.limiteCreditos = Math.floor(limite);
    if (args.objetivo === "velocidade" || args.objetivo === "equilibrado") {
        ctx.preferencias.objetivo = args.objetivo;
    }
    const plano = gerarPlanoDoContexto(ctx);
    return { resultado: JSON.stringify(resumoDoPlano(plano)), planoAtualizado: plano };
}

function moverMateria(
    args: Record<string, unknown>,
    ctx: AgenteContexto
): { resultado: string; planoAtualizado?: PlanoFormaturav2 } {
    const codigo = typeof args.codigo === "string" ? norm(args.codigo) : "";
    const acao = args.acao;

    if (acao !== "adiar" && acao !== "priorizar" && acao !== "remover_restricao") {
        return { resultado: JSON.stringify({ erro: "acao deve ser 'adiar', 'priorizar' ou 'remover_restricao'." }) };
    }
    const existe = ctx.materias.some((m) => norm(m.codigo) === codigo);
    if (!existe) {
        return {
            resultado: JSON.stringify({
                erro: `Matéria ${codigo || "(vazio)"} não está entre as matérias faltantes do aluno.`,
            }),
        };
    }

    // Listas mutuamente exclusivas: entrar numa remove da outra.
    ctx.restricoes.adiar = ctx.restricoes.adiar.filter((c) => c !== codigo);
    ctx.restricoes.priorizar = ctx.restricoes.priorizar.filter((c) => c !== codigo);
    if (acao === "adiar") ctx.restricoes.adiar.push(codigo);
    if (acao === "priorizar") ctx.restricoes.priorizar.push(codigo);

    const plano = gerarPlanoDoContexto(ctx);
    return {
        resultado: JSON.stringify({ acao, codigo, restricoes: ctx.restricoes, ...resumoDoPlano(plano) }),
        planoAtualizado: plano,
    };
}

export function executarTool(
    nome: string,
    args: Record<string, unknown>,
    ctx: AgenteContexto
): { resultado: string; planoAtualizado?: PlanoFormaturav2 } {
    try {
        switch (nome) {
            case "consultar_plano":
                return { resultado: consultarPlano(args, ctx) };
            case "simular_cenario":
                return { resultado: simularCenario(args, ctx) };
            case "ajustar_carga":
                return ajustarCarga(args, ctx);
            case "mover_materia":
                return moverMateria(args, ctx);
            default:
                return { resultado: JSON.stringify({ erro: `Tool desconhecida: ${nome}` }) };
        }
    } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        logger.error(`[PlanejadorAgente] Erro na tool ${nome}: ${msg}`);
        return { resultado: JSON.stringify({ erro: `Falha interna na tool ${nome}: ${msg}` }) };
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

```bash
cd no_fluxo_backend && npx jest tests-ts/planejador-agente.test.ts
```

Expected: PASS (11 testes).

- [ ] **Step 5: Commit**

```bash
git add no_fluxo_backend/src/services/planejador_agente.service.ts no_fluxo_backend/tests-ts/planejador-agente.test.ts
git commit -m "feat: Executores de tools do agente planejador (consultar/simular/ajustar/mover)"
```

---

### Task 4: Loop do agente + cliente Maritaca

**Files:**
- Modify: `no_fluxo_backend/src/services/planejador_agente.service.ts` (append)
- Test: `no_fluxo_backend/tests-ts/planejador-agente.test.ts` (append)

**Interfaces:**
- Produces (usadas pela Task 5):

```ts
export interface MensagemChat { role: "user" | "assistant"; content: string; }
export interface AgenteResultado {
    reply: string;
    plano?: PlanoFormaturav2;       // presente se alguma tool alterou o plano
    restricoes: RestricoesPlano;    // estado final (sempre devolvido)
}
// Assinatura OpenAI-compatible da resposta do LLM (só os campos usados):
export interface LlmMessage {
    role: string;
    content: string | null;
    tool_calls?: { id: string; function: { name: string; arguments: string } }[];
}
export type ChamarLlmFn = (messages: unknown[], tools: unknown[]) => Promise<LlmMessage>;

export class PlanejadorAgenteService {
    constructor(chamarLlm?: ChamarLlmFn);          // default: Maritaca real
    isAvailable(): boolean;                        // !!process.env.MARITACA_API_KEY
    conversar(historico: MensagemChat[], ctx: AgenteContexto): Promise<AgenteResultado>;
}
```

- [ ] **Step 1: Escrever os testes que falham**

Append em `tests-ts/planejador-agente.test.ts`:

```ts
import {
    PlanejadorAgenteService,
    type LlmMessage,
} from "../src/services/planejador_agente.service";

function respostaFinal(texto: string): LlmMessage {
    return { role: "assistant", content: texto };
}

function respostaComTool(nome: string, args: object, id = "call_1"): LlmMessage {
    return {
        role: "assistant",
        content: null,
        tool_calls: [{ id, function: { name: nome, arguments: JSON.stringify(args) } }],
    };
}

describe("planejador_agente — loop de conversa", () => {
    test("resposta direta sem tool call", async () => {
        const svc = new PlanejadorAgenteService(async () => respostaFinal("Olá! Posso ajudar."));
        const r = await svc.conversar([{ role: "user", content: "oi" }], ctxBase());
        expect(r.reply).toBe("Olá! Posso ajudar.");
        expect(r.plano).toBeUndefined();
    });

    test("tool de leitura não devolve plano; tool de escrita devolve", async () => {
        const respostas: LlmMessage[] = [
            respostaComTool("mover_materia", { codigo: "AAA0001", acao: "adiar" }),
            respostaFinal("Adiei AAA0001 pra você."),
        ];
        let i = 0;
        const svc = new PlanejadorAgenteService(async () => respostas[i++]);
        const ctx = ctxBase();
        const r = await svc.conversar([{ role: "user", content: "adia AAA0001" }], ctx);
        expect(r.reply).toBe("Adiei AAA0001 pra você.");
        expect(r.plano).toBeDefined();
        expect(r.restricoes.adiar).toContain("AAA0001");
    });

    test("mensagem tool com resultado é enviada de volta ao LLM", async () => {
        const capturadas: unknown[][] = [];
        const respostas: LlmMessage[] = [
            respostaComTool("consultar_plano", {}),
            respostaFinal("Seu plano tem X semestres."),
        ];
        let i = 0;
        const svc = new PlanejadorAgenteService(async (messages) => {
            capturadas.push([...messages]);
            return respostas[i++];
        });
        await svc.conversar([{ role: "user", content: "resume meu plano" }], ctxBase());
        const ultimaChamada = capturadas[1] as any[];
        const toolMsg = ultimaChamada.find((m) => m.role === "tool");
        expect(toolMsg).toBeDefined();
        expect(JSON.parse(toolMsg.content).semestresRestantes).toBeGreaterThan(0);
    });

    test("guard-rail: para após 5 iterações de tool calls", async () => {
        let chamadas = 0;
        const svc = new PlanejadorAgenteService(async () => {
            chamadas++;
            return respostaComTool("consultar_plano", {}, `call_${chamadas}`);
        });
        const r = await svc.conversar([{ role: "user", content: "loop" }], ctxBase());
        expect(chamadas).toBeLessThanOrEqual(5);
        expect(r.reply).toContain("não consegui concluir");
    });

    test("histórico é truncado nas últimas 20 mensagens", async () => {
        let recebidas: unknown[] = [];
        const svc = new PlanejadorAgenteService(async (messages) => {
            recebidas = messages;
            return respostaFinal("ok");
        });
        const historico = Array.from({ length: 30 }, (_, i) => ({
            role: (i % 2 === 0 ? "user" : "assistant") as "user" | "assistant",
            content: `msg ${i}`,
        }));
        await svc.conversar(historico, ctxBase());
        // 1 system + 20 do histórico
        expect((recebidas as any[]).filter((m) => m.role !== "system")).toHaveLength(20);
    });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd no_fluxo_backend && npx jest tests-ts/planejador-agente.test.ts -t "loop de conversa"
```

Expected: FAIL — `PlanejadorAgenteService` não existe.

- [ ] **Step 3: Implementar o loop**

Append em `planejador_agente.service.ts`:

```ts
// ---------------------------------------------------------------
// Loop do agente (tool calling, OpenAI-compatible)
// ---------------------------------------------------------------

const MAX_ITERACOES = 5;
const MAX_HISTORICO = 20;
const MARITACA_URL = "https://chat.maritaca.ai/api/chat/completions";
const MARITACA_MODEL = "sabia-3";

export interface MensagemChat {
    role: "user" | "assistant";
    content: string;
}

export interface AgenteResultado {
    reply: string;
    plano?: PlanoFormaturav2;
    restricoes: RestricoesPlano;
}

export interface LlmMessage {
    role: string;
    content: string | null;
    tool_calls?: { id: string; function: { name: string; arguments: string } }[];
}

export type ChamarLlmFn = (messages: unknown[], tools: unknown[]) => Promise<LlmMessage>;

const TOOL_DEFS = [
    {
        type: "function",
        function: {
            name: "consultar_plano",
            description:
                "Consulta o plano de formatura atual. Sem argumentos devolve resumo (semestres restantes, formatura estimada, críticas). Com 'codigo' devolve detalhes de uma matéria (semestre alocado, score, o que desbloqueia, por que é crítica).",
            parameters: {
                type: "object",
                properties: { codigo: { type: "string", description: "Código da matéria, ex: CIC0110" } },
            },
        },
    },
    {
        type: "function",
        function: {
            name: "simular_cenario",
            description:
                "Simula um cenário SEM aplicar: outro limite de créditos e/ou matérias adiadas/priorizadas hipotéticas. Devolve comparação antes/depois com delta de semestres. Use antes de aplicar mudanças para mostrar o impacto ao aluno.",
            parameters: {
                type: "object",
                properties: {
                    limiteCreditos: { type: "number", description: "Limite hipotético (8 a 32)" },
                    adiar: { type: "array", items: { type: "string" }, description: "Códigos hipotéticos a adiar" },
                    priorizar: { type: "array", items: { type: "string" }, description: "Códigos hipotéticos a priorizar" },
                },
            },
        },
    },
    {
        type: "function",
        function: {
            name: "ajustar_carga",
            description: "APLICA novo limite de créditos por semestre (8 a 32) e opcionalmente o objetivo, regenerando o plano.",
            parameters: {
                type: "object",
                properties: {
                    limiteCreditos: { type: "number", description: "Novo limite (8 a 32)" },
                    objetivo: { type: "string", enum: ["velocidade", "equilibrado"] },
                },
                required: ["limiteCreditos"],
            },
        },
    },
    {
        type: "function",
        function: {
            name: "mover_materia",
            description:
                "APLICA restrição a uma matéria e regenera o plano. 'adiar' = tira do próximo semestre; 'priorizar' = antecipa o máximo possível; 'remover_restricao' = limpa restrições da matéria. Antes de adiar uma matéria crítica, avise o aluno do impacto (use simular_cenario).",
            parameters: {
                type: "object",
                properties: {
                    codigo: { type: "string", description: "Código da matéria" },
                    acao: { type: "string", enum: ["adiar", "priorizar", "remover_restricao"] },
                },
                required: ["codigo", "acao"],
            },
        },
    },
];

function montarSystemPrompt(ctx: AgenteContexto): string {
    const resumo = resumoDoPlano(gerarPlanoDoContexto(ctx));
    return [
        "Você é o assistente de planejamento de formatura do NoFluxoUnB, para alunos da UnB.",
        "Responda SEMPRE em português brasileiro, de forma direta e amigável. Não invente matérias nem dados — use as tools.",
        "Use simular_cenario para mostrar impacto antes de aplicar mudanças que o aluno ainda não confirmou.",
        "Quando o aluno pedir explicitamente uma mudança, aplique com ajustar_carga ou mover_materia.",
        "",
        `Estado atual do plano: ${JSON.stringify(resumo)}`,
        `Preferências: limite ${ctx.preferencias.limiteCreditos} créditos/semestre, objetivo ${ctx.preferencias.objetivo}.`,
        `Restrições ativas: adiar=[${ctx.restricoes.adiar.join(", ")}], priorizar=[${ctx.restricoes.priorizar.join(", ")}].`,
        `Semestre atual do aluno: ${ctx.numeroPeriodo}.`,
    ].join("\n");
}

async function chamarMaritaca(messages: unknown[], tools: unknown[]): Promise<LlmMessage> {
    const response = await fetch(MARITACA_URL, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            Authorization: `Key ${process.env.MARITACA_API_KEY}`,
        },
        body: JSON.stringify({
            model: MARITACA_MODEL,
            messages,
            tools,
            tool_choice: "auto",
            max_tokens: 1200,
        }),
    });
    if (!response.ok) {
        const texto = await response.text();
        throw new Error(`Maritaca retornou ${response.status}: ${texto}`);
    }
    const data = (await response.json()) as { choices: { message: LlmMessage }[] };
    if (!data.choices?.[0]?.message) throw new Error("Resposta da Maritaca sem choices[0].message");
    return data.choices[0].message;
}

export class PlanejadorAgenteService {
    private readonly chamarLlm: ChamarLlmFn;

    constructor(chamarLlm?: ChamarLlmFn) {
        this.chamarLlm = chamarLlm ?? chamarMaritaca;
    }

    isAvailable(): boolean {
        return !!process.env.MARITACA_API_KEY;
    }

    async conversar(historico: MensagemChat[], ctx: AgenteContexto): Promise<AgenteResultado> {
        const mensagens: unknown[] = [
            { role: "system", content: montarSystemPrompt(ctx) },
            ...historico.slice(-MAX_HISTORICO),
        ];

        let planoModificado: PlanoFormaturav2 | undefined;

        for (let i = 0; i < MAX_ITERACOES; i++) {
            const resposta = await this.chamarLlm(mensagens, TOOL_DEFS);

            if (!resposta.tool_calls || resposta.tool_calls.length === 0) {
                return {
                    reply: resposta.content ?? "",
                    plano: planoModificado,
                    restricoes: ctx.restricoes,
                };
            }

            mensagens.push(resposta);
            for (const tc of resposta.tool_calls) {
                let args: Record<string, unknown> = {};
                try {
                    args = JSON.parse(tc.function.arguments || "{}");
                } catch {
                    // args inválidos — a tool devolve erro descritivo pro LLM se precisar deles
                }
                logger.info(`[PlanejadorAgente] Tool call: ${tc.function.name}(${tc.function.arguments})`);
                const { resultado, planoAtualizado } = executarTool(tc.function.name, args, ctx);
                if (planoAtualizado) planoModificado = planoAtualizado;
                mensagens.push({ role: "tool", tool_call_id: tc.id, content: resultado });
            }
        }

        return {
            reply:
                "Desculpe, não consegui concluir essa solicitação em tempo hábil. " +
                "As mudanças aplicadas até aqui já estão refletidas no plano.",
            plano: planoModificado,
            restricoes: ctx.restricoes,
        };
    }
}
```

- [ ] **Step 4: Rodar tudo e ver passar**

```bash
cd no_fluxo_backend && npx jest tests-ts/planejador-agente.test.ts && npx tsc --noEmit
```

Expected: PASS (16 testes), compilação limpa.

- [ ] **Step 5: Commit**

```bash
git add no_fluxo_backend/src/services/planejador_agente.service.ts no_fluxo_backend/tests-ts/planejador-agente.test.ts
git commit -m "feat: Loop de tool calling do agente planejador com Maritaca sabia-3"
```

---

### Task 5: Endpoint POST /planejamento/chat

**Files:**
- Modify: `no_fluxo_backend/src/controllers/PlanejamentoController.ts`

**Interfaces:**
- Consumes: `montarDadosPlano` (Task 2), `PlanejadorAgenteService`, `MensagemChat`, `AgenteContexto` (Tasks 3–4).
- Produces (contrato consumido pela Task 6):

```
POST /planejamento/chat
Headers: Authorization (JWT), User-ID
Body: {
  messages: { role: 'user'|'assistant', content: string }[],
  planoInput: { curriculo_completo, codigos_concluidos, semestre_atual, limite_creditos },  // mesmo body do gerar-plano
  restricoes: { adiar: string[], priorizar: string[] }
}
200: { reply: string, plano?: PlanoFormaturav2, restricoes: { adiar, priorizar } }
400: { error }   401: { error }   503: { error: "Assistente de planejamento indisponível" }
```

- [ ] **Step 1: Implementar a rota**

Em `PlanejamentoController.ts`, importar no topo:

```ts
import {
    PlanejadorAgenteService,
    type AgenteContexto,
    type MensagemChat,
} from "../services/planejador_agente.service";
```

Instanciar uma vez, junto aos helpers (fora do objeto de rotas):

```ts
const agenteService = new PlanejadorAgenteService();
```

Helper de validação das mensagens (junto aos outros helpers):

```ts
function parseMensagens(raw: unknown): MensagemChat[] | null {
    if (!Array.isArray(raw)) return null;
    const out: MensagemChat[] = [];
    for (const m of raw) {
        if (!isObject(m)) return null;
        if (m.role !== "user" && m.role !== "assistant") return null;
        if (typeof m.content !== "string") return null;
        out.push({ role: m.role, content: m.content });
    }
    return out;
}
```

Nova rota `"chat"` dentro de `routes` (após `"gerar-plano"`):

```ts
        "chat": new Pair(
            RequestType.POST,
            async (req: Request, res: Response) => {
                const logger = createControllerLogger("PlanejamentoController", "chat");

                try {
                    if (!await Utils.checkAuthorization(req as Request)) {
                        return res.status(401).json({ error: "Usuário não autorizado" });
                    }
                    const id_user = req.headers["user-id"] || req.headers["User-ID"];
                    if (!id_user) {
                        return res.status(401).json({ error: "User-ID não informado" });
                    }

                    if (!agenteService.isAvailable()) {
                        logger.warn("MARITACA_API_KEY ausente — chat indisponível");
                        return res.status(503).json({ error: "Assistente de planejamento indisponível" });
                    }

                    const body = req.body as Record<string, unknown>;

                    const mensagens = parseMensagens(body.messages);
                    if (!mensagens || mensagens.length === 0) {
                        return res.status(400).json({ error: "messages deve ser array não-vazio de {role, content}" });
                    }

                    // planoInput usa o mesmo formato/validação do gerar-plano
                    // (incluindo body.restricoes, que parseBody anexa às preferências).
                    const planoInputRaw = isObject(body.planoInput)
                        ? { ...body.planoInput, restricoes: body.restricoes }
                        : body.planoInput;
                    const { input, error: bodyError } = parseBody(planoInputRaw);
                    if (bodyError) {
                        return res.status(400).json({ error: `planoInput inválido: ${bodyError}` });
                    }

                    const { dados, status, error } = await montarDadosPlano(String(id_user), input!);
                    if (!dados) {
                        return res.status(status ?? 500).json({ error });
                    }

                    const ctx: AgenteContexto = {
                        idUser: dados.idUser,
                        idCurso: dados.idCurso,
                        numeroPeriodo: dados.numeroPeriodo,
                        preferencias: dados.preferencias,
                        restricoes: dados.preferencias.restricoes ?? { adiar: [], priorizar: [] },
                        cargaHorariaIntegralizada: dados.cargaHorariaIntegralizada,
                        exigidaMatriz: dados.exigidaMatriz,
                        fluxogramaAtual: dados.fluxogramaAtual,
                        materias: dados.materiasMapeadas,
                        codigosComOferta: dados.codigosComOferta,
                    };

                    const resultado = await agenteService.conversar(mensagens, ctx);
                    logger.info(`Chat respondido. Plano modificado: ${!!resultado.plano}`);

                    return res.status(200).json(resultado);
                } catch (err: any) {
                    logger.error(`Erro no chat do planejador: ${err?.message || String(err)}`);
                    return res.status(500).json({ error: err?.message || "Erro no chat do planejador" });
                }
            }
        ),
```

- [ ] **Step 2: Compilar e rodar suíte + smoke test manual**

```bash
cd no_fluxo_backend && npx tsc --noEmit && npx jest
```

Expected: compila, suíte verde.

Smoke test (com backend rodando via `npm run dev` e um JWT válido — opcional se não houver credenciais à mão; nesse caso validar apenas que a rota registra no boot: log `Registering route: POST /planejamento/chat`):

```bash
npm run dev
# Em outro terminal, observar no log do boot:
# "Registering route: POST /planejamento/chat"
```

- [ ] **Step 3: Commit**

```bash
git add no_fluxo_backend/src/controllers/PlanejamentoController.ts
git commit -m "feat: Endpoint POST /planejamento/chat com agente do planejador"
```

---

### Task 6: Frontend — tipos e serviço

**Files:**
- Modify: `no_fluxo_frontend_svelte/src/lib/types/plano-formatura.ts` (append no fim)
- Modify: `no_fluxo_frontend_svelte/src/lib/services/plano-formatura.service.ts`

**Interfaces:**
- Produces (consumidas pelas Tasks 7–8):

```ts
// types/plano-formatura.ts
export interface RestricoesPlano { adiar: string[]; priorizar: string[]; }
export interface PlannerChatMessage { id: string; role: 'user' | 'assistant'; content: string; erro?: boolean; }
export interface PlannerChatResponse { reply: string; plano?: PlanoFormaturav2; restricoes: RestricoesPlano; }

// service
planoFormaturaService.chat(payload: {
    messages: { role: 'user' | 'assistant'; content: string }[];
    planoPayload: GerarPlanoPayload;
    restricoes: RestricoesPlano;
}): Promise<PlannerChatResponse>
// gerarPlano ganha 2º parâmetro opcional:
planoFormaturaService.gerarPlano(payload: GerarPlanoPayload, restricoes?: RestricoesPlano)
```

- [ ] **Step 1: Adicionar tipos**

Append no fim de `src/lib/types/plano-formatura.ts`:

```ts
// ─── Chat do agente planejador ──────────────────────────────────────────────

/** Restrições de alocação impostas pelo aluno (chat ou chips). */
export interface RestricoesPlano {
	/** Códigos que não podem entrar no próximo semestre. */
	adiar: string[];
	/** Códigos antecipados ao máximo (respeitando pré-requisitos). */
	priorizar: string[];
}

/** Mensagem do chat do planejador. */
export interface PlannerChatMessage {
	id: string;
	role: 'user' | 'assistant';
	content: string;
	/** true quando o envio falhou. */
	erro?: boolean;
}

/** Resposta do POST /planejamento/chat. */
export interface PlannerChatResponse {
	reply: string;
	/** Presente quando alguma ação do agente alterou o plano. */
	plano?: PlanoFormaturav2;
	restricoes: RestricoesPlano;
}
```

- [ ] **Step 2: Estender o serviço**

Em `src/lib/services/plano-formatura.service.ts`:

Atualizar import de tipos:

```ts
import type {
	PlanoFormatura,
	PlanoFormaturav2,
	PreferenciasPlano,
	RestricoesPlano,
	PlannerChatResponse
} from '$lib/types/plano-formatura';
```

Alterar `gerarPlano` para aceitar restrições (o body só inclui a chave quando há restrição ativa — mantém compat):

```ts
	async gerarPlano(
		payload: GerarPlanoPayload,
		restricoes?: RestricoesPlano
	): Promise<PlanoFormaturav2 | null> {
		const body: Record<string, unknown> = {
			curriculo_completo: payload.curriculoCompleto,
			codigos_concluidos: payload.codigosConcluidos,
			semestre_atual: payload.semestreAtual,
			limite_creditos: payload.limiteCreditos
		};
		if (restricoes && (restricoes.adiar.length > 0 || restricoes.priorizar.length > 0)) {
			body.restricoes = restricoes;
		}

		const { data, error, status } = await apiRequest<PlanoFormaturav2>('/planejamento/gerar-plano', {
			method: 'POST',
			body
		});

		if (error || !data) {
			throw new Error(`Erro ${status} ao gerar plano: ${error ?? 'Resposta inválida'}`);
		}

		return data;
	}
```

Adicionar método `chat` na classe:

```ts
	/**
	 * Envia a conversa ao agente do planejador (POST /planejamento/chat).
	 * O backend roda o loop de tools e devolve a resposta + plano atualizado
	 * quando alguma ação foi aplicada.
	 */
	async chat(payload: {
		messages: { role: 'user' | 'assistant'; content: string }[];
		planoPayload: GerarPlanoPayload;
		restricoes: RestricoesPlano;
	}): Promise<PlannerChatResponse> {
		const { data, error, status } = await apiRequest<PlannerChatResponse>('/planejamento/chat', {
			method: 'POST',
			body: {
				messages: payload.messages,
				planoInput: {
					curriculo_completo: payload.planoPayload.curriculoCompleto,
					codigos_concluidos: payload.planoPayload.codigosConcluidos,
					semestre_atual: payload.planoPayload.semestreAtual,
					limite_creditos: payload.planoPayload.limiteCreditos
				},
				restricoes: payload.restricoes
			}
		});

		if (error || !data) {
			throw new Error(`Erro ${status} no chat: ${error ?? 'Resposta inválida'}`);
		}

		return data;
	}
```

- [ ] **Step 3: Checar tipos**

```bash
cd no_fluxo_frontend_svelte && npm run check
```

Expected: 0 errors (warnings pré-existentes são aceitáveis).

- [ ] **Step 4: Commit**

```bash
git add no_fluxo_frontend_svelte/src/lib/types/plano-formatura.ts no_fluxo_frontend_svelte/src/lib/services/plano-formatura.service.ts
git commit -m "feat: Tipos e serviço frontend do chat do planejador"
```

---

### Task 7: Frontend — store (estado do chat + restrições)

**Files:**
- Modify: `no_fluxo_frontend_svelte/src/lib/stores/plano-formatura.store.svelte.ts`

**Interfaces:**
- Consumes: `planoFormaturaService.chat`/`gerarPlano` (Task 6).
- Produces (consumidas pela Task 8): getters `chatMessages: PlannerChatMessage[]`, `chatLoading: boolean`, `restricoes: RestricoesPlano`; métodos `sendMessage(text: string): Promise<void>`, `removerRestricao(codigo: string): Promise<void>`.

- [ ] **Step 1: Adicionar estado e métodos**

Atualizar imports do store:

```ts
import type {
	PlanoFormatura,
	PreferenciasPlano,
	RestricoesPlano,
	PlannerChatMessage
} from '$lib/types/plano-formatura';
```

Adicionar junto às declarações `$state` existentes:

```ts
	let chatMessages = $state<PlannerChatMessage[]>([
		{
			id: 'welcome',
			role: 'assistant',
			content:
				'Oi! Sou o assistente do seu plano de formatura. Posso simular cenários, ajustar sua carga e adiar ou priorizar matérias. Ex.: "e se eu pegar só 16 créditos?" ou "quero empurrar Cálculo 2".'
		}
	]);
	let chatLoading = $state(false);
	let restricoes = $state<RestricoesPlano>({ adiar: [], priorizar: [] });

	let nextMsgId = 0;
	function msgId(): string {
		nextMsgId += 1;
		return `msg_${Date.now()}_${nextMsgId}`;
	}

	function getPlanoPayload() {
		const curriculoCompleto = getCurriculoCompleto();
		if (!curriculoCompleto) return null;
		return {
			curriculoCompleto,
			codigosConcluidos: getCodigosConcluidos(),
			semestreAtual: getSemestreAtual(),
			limiteCreditos: preferencias.limiteCreditos
		};
	}
```

No objeto retornado, adicionar getters:

```ts
		get chatMessages() { return chatMessages; },
		get chatLoading() { return chatLoading; },
		get restricoes() { return restricoes; },
```

E os métodos:

```ts
		/**
		 * Envia mensagem ao agente do planejador. Se a resposta trouxer plano
		 * atualizado, aplica no store (as colunas re-renderizam sozinhas).
		 */
		async sendMessage(text: string): Promise<void> {
			const trimmed = text.trim();
			if (!trimmed || chatLoading) return;

			const planoPayload = getPlanoPayload();
			if (!planoPayload) {
				chatMessages = [
					...chatMessages,
					{ id: msgId(), role: 'assistant', content: 'Carregue seu fluxograma antes de usar o chat.', erro: true }
				];
				return;
			}

			chatMessages = [...chatMessages, { id: msgId(), role: 'user', content: trimmed }];
			chatLoading = true;

			try {
				const historico = chatMessages
					.filter((m) => !m.erro && m.id !== 'welcome')
					.map((m) => ({ role: m.role, content: m.content }));

				const resposta = await planoFormaturaService.chat({
					messages: historico,
					planoPayload,
					restricoes
				});

				chatMessages = [...chatMessages, { id: msgId(), role: 'assistant', content: resposta.reply }];
				restricoes = resposta.restricoes;
				if (resposta.plano) {
					plano = resposta.plano;
					status = 'success';
					// Sincroniza limite se o agente ajustou a carga
					// (o backend não devolve preferências; inferir não é confiável — manter slider como está)
				}
			} catch (err) {
				const msg = err instanceof Error ? err.message : 'Erro ao falar com o assistente.';
				chatMessages = [...chatMessages, { id: msgId(), role: 'assistant', content: msg, erro: true }];
			} finally {
				chatLoading = false;
			}
		},

		/**
		 * Remove uma restrição (clique no chip) e regenera o plano.
		 */
		async removerRestricao(codigo: string): Promise<void> {
			const cod = codigo.trim().toUpperCase();
			restricoes = {
				adiar: restricoes.adiar.filter((c) => c !== cod),
				priorizar: restricoes.priorizar.filter((c) => c !== cod)
			};
			await this.gerar();
		},
```

Modificar `gerar()` para enviar restrições ativas (trocar a chamada `planoFormaturaService.gerarPlano({...})` existente):

```ts
				const resultado = await planoFormaturaService.gerarPlano(
					{
						curriculoCompleto,
						codigosConcluidos: getCodigosConcluidos(),
						semestreAtual: getSemestreAtual(),
						limiteCreditos: preferencias.limiteCreditos
					},
					restricoes
				);
```

E no `reset()`, adicionar:

```ts
			chatMessages = chatMessages.slice(0, 1); // mantém só a welcome
			chatLoading = false;
			restricoes = { adiar: [], priorizar: [] };
```

- [ ] **Step 2: Checar tipos**

```bash
cd no_fluxo_frontend_svelte && npm run check
```

Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add no_fluxo_frontend_svelte/src/lib/stores/plano-formatura.store.svelte.ts
git commit -m "feat: Estado de chat e restrições no store do plano de formatura"
```

---

### Task 8: Frontend — PlannerChatPanel + chips + integração

**Files:**
- Create: `no_fluxo_frontend_svelte/src/lib/components/plano-formatura/PlannerChatPanel.svelte`
- Create: `no_fluxo_frontend_svelte/src/lib/components/plano-formatura/RestricoesChips.svelte`
- Modify: `no_fluxo_frontend_svelte/src/lib/components/plano-formatura/PlanoFormaturaView.svelte`

**Interfaces:**
- Consumes: `planoFormaturaStore.chatMessages / chatLoading / restricoes / sendMessage / removerRestricao` (Task 7).
- Produces: componentes sem props (leem o store direto), auto-contidos.

- [ ] **Step 1: Criar RestricoesChips.svelte**

```svelte
<script lang="ts">
	import { X, ArrowDownToLine, ArrowUpToLine } from 'lucide-svelte';
	import { planoFormaturaStore } from '$lib/stores/plano-formatura.store.svelte';

	const temRestricoes = $derived(
		planoFormaturaStore.restricoes.adiar.length > 0 ||
			planoFormaturaStore.restricoes.priorizar.length > 0
	);
</script>

{#if temRestricoes}
	<div class="flex flex-wrap items-center gap-2">
		<span class="text-[11px] font-medium uppercase tracking-wider text-white/40">Restrições:</span>
		{#each planoFormaturaStore.restricoes.adiar as codigo (codigo)}
			<button
				onclick={() => planoFormaturaStore.removerRestricao(codigo)}
				class="flex items-center gap-1.5 rounded-full border border-orange-500/25 bg-orange-600/10 px-2.5 py-1 text-[11px] font-medium text-orange-300 transition-colors hover:border-orange-400/50 hover:bg-orange-600/20"
				title="Remover restrição e recalcular"
			>
				<ArrowDownToLine class="h-3 w-3" />
				Adiada: {codigo}
				<X class="h-3 w-3" />
			</button>
		{/each}
		{#each planoFormaturaStore.restricoes.priorizar as codigo (codigo)}
			<button
				onclick={() => planoFormaturaStore.removerRestricao(codigo)}
				class="flex items-center gap-1.5 rounded-full border border-blue-500/25 bg-blue-600/10 px-2.5 py-1 text-[11px] font-medium text-blue-300 transition-colors hover:border-blue-400/50 hover:bg-blue-600/20"
				title="Remover restrição e recalcular"
			>
				<ArrowUpToLine class="h-3 w-3" />
				Priorizada: {codigo}
				<X class="h-3 w-3" />
			</button>
		{/each}
	</div>
{/if}
```

- [ ] **Step 2: Criar PlannerChatPanel.svelte**

Painel fixo à direita, colapsável via botão flutuante — auto-contido, não exige mudanças de layout na view:

```svelte
<script lang="ts">
	import { Bot, Send, X, Loader2 } from 'lucide-svelte';
	import { fly } from 'svelte/transition';
	import { planoFormaturaStore } from '$lib/stores/plano-formatura.store.svelte';

	let aberto = $state(false);
	let texto = $state('');
	let scrollEl = $state<HTMLDivElement | null>(null);

	const sugestoes = [
		'E se eu pegar só 16 créditos?',
		'Qual matéria me atrasa mais?',
		'Por que essa matéria é crítica?'
	];

	async function enviar(msg?: string) {
		const conteudo = (msg ?? texto).trim();
		if (!conteudo) return;
		texto = '';
		await planoFormaturaStore.sendMessage(conteudo);
	}

	// Auto-scroll pro fim quando chegam mensagens
	$effect(() => {
		planoFormaturaStore.chatMessages.length;
		if (scrollEl) scrollEl.scrollTo({ top: scrollEl.scrollHeight, behavior: 'smooth' });
	});

	function onKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			enviar();
		}
	}
</script>

{#if !aberto}
	<button
		onclick={() => (aberto = true)}
		class="fixed bottom-6 right-6 z-40 flex items-center gap-2 rounded-full bg-gradient-to-r from-blue-600 to-purple-600 px-4 py-3 text-sm font-semibold text-white shadow-lg shadow-purple-900/40 transition-transform hover:scale-105"
		transition:fly={{ y: 20, duration: 200 }}
	>
		<Bot class="h-5 w-5" />
		Assistente
	</button>
{:else}
	<aside
		class="fixed bottom-0 right-0 top-0 z-40 flex w-full max-w-md flex-col border-l border-white/10 bg-[#0b0f16] shadow-2xl"
		transition:fly={{ x: 400, duration: 250 }}
	>
		<!-- Header -->
		<div class="flex items-center justify-between border-b border-white/10 px-4 py-3">
			<div class="flex items-center gap-2.5">
				<div class="flex h-8 w-8 items-center justify-center rounded-xl bg-purple-600/20">
					<Bot class="h-4.5 w-4.5 text-purple-400" />
				</div>
				<div>
					<h2 class="text-sm font-bold text-white">Assistente do Plano</h2>
					<p class="text-[10px] text-white/40">simula, ajusta e explica seu plano</p>
				</div>
			</div>
			<button
				onclick={() => (aberto = false)}
				class="rounded-lg p-1.5 text-white/50 transition-colors hover:bg-white/10 hover:text-white"
			>
				<X class="h-4 w-4" />
			</button>
		</div>

		<!-- Mensagens -->
		<div bind:this={scrollEl} class="flex-1 space-y-3 overflow-y-auto px-4 py-4">
			{#each planoFormaturaStore.chatMessages as msg (msg.id)}
				<div class="flex {msg.role === 'user' ? 'justify-end' : 'justify-start'}">
					<div
						class="max-w-[85%] whitespace-pre-wrap rounded-2xl px-3.5 py-2.5 text-[13px] leading-relaxed
						{msg.role === 'user'
							? 'rounded-br-md bg-blue-600 text-white'
							: msg.erro
								? 'rounded-bl-md border border-red-500/30 bg-red-600/10 text-red-300'
								: 'rounded-bl-md border border-white/10 bg-white/5 text-white/85'}"
					>
						{msg.content}
					</div>
				</div>
			{/each}
			{#if planoFormaturaStore.chatLoading}
				<div class="flex justify-start">
					<div class="flex items-center gap-2 rounded-2xl rounded-bl-md border border-white/10 bg-white/5 px-3.5 py-2.5 text-[13px] text-white/50">
						<Loader2 class="h-3.5 w-3.5 animate-spin" />
						pensando...
					</div>
				</div>
			{/if}
		</div>

		<!-- Sugestões (só no início da conversa) -->
		{#if planoFormaturaStore.chatMessages.length <= 1}
			<div class="flex flex-wrap gap-2 px-4 pb-2">
				{#each sugestoes as s (s)}
					<button
						onclick={() => enviar(s)}
						class="rounded-full border border-white/10 bg-white/5 px-3 py-1.5 text-[11px] text-white/60 transition-colors hover:border-purple-400/40 hover:text-white"
					>
						{s}
					</button>
				{/each}
			</div>
		{/if}

		<!-- Input -->
		<div class="border-t border-white/10 p-3">
			<div class="flex items-end gap-2">
				<textarea
					bind:value={texto}
					onkeydown={onKeydown}
					rows="1"
					placeholder="Pergunte ou peça uma mudança no plano..."
					disabled={planoFormaturaStore.chatLoading}
					class="max-h-28 flex-1 resize-none rounded-xl border border-white/10 bg-white/5 px-3.5 py-2.5 text-[13px] text-white placeholder-white/30 outline-none transition-colors focus:border-purple-400/50 disabled:opacity-50"
				></textarea>
				<button
					onclick={() => enviar()}
					disabled={planoFormaturaStore.chatLoading || !texto.trim()}
					class="flex h-10 w-10 items-center justify-center rounded-xl bg-purple-600 text-white transition-colors hover:bg-purple-500 disabled:opacity-40"
				>
					<Send class="h-4 w-4" />
				</button>
			</div>
		</div>
	</aside>
{/if}
```

- [ ] **Step 3: Integrar na PlanoFormaturaView.svelte**

No `<script>`, adicionar imports:

```ts
	import PlannerChatPanel from './PlannerChatPanel.svelte';
	import RestricoesChips from './RestricoesChips.svelte';
```

No template: `<RestricoesChips />` logo após o bloco de stats (o `{#if planoFormaturaStore.status === 'success' ...}` com o grid de 3 cards, dentro do mesmo `{#if}` — após o `</div>` do grid); e `<PlannerChatPanel />` como último elemento antes do fechamento do `</div>` raiz.

- [ ] **Step 4: Verificação manual**

```bash
cd no_fluxo_frontend_svelte && npm run check && npm run dev
```

Expected: 0 erros de tipo. No browser (`/plano-formatura`, logado, com histórico carregado):
1. Botão flutuante "Assistente" visível; abre o painel.
2. Sugestão "E se eu pegar só 16 créditos?" → resposta com comparação de cenário (sem alterar o plano).
3. "Adia <código de uma matéria do próximo semestre>" → resposta + matéria some do semestre Recomendado + chip "Adiada: <código>" aparece.
4. Clicar no ✕ do chip → plano volta ao original.
5. Backend parado ou sem `MARITACA_API_KEY` → mensagem de erro no chat, sem crash.

- [ ] **Step 5: Commit**

```bash
git add no_fluxo_frontend_svelte/src/lib/components/plano-formatura/
git commit -m "feat: Painel de chat do agente e chips de restrições no plano de formatura"
```

---

## Verificação final (após todas as tasks)

```bash
cd no_fluxo_backend && npx tsc --noEmit && npx jest
cd ../no_fluxo_frontend_svelte && npm run check
```

Expected: backend compila e suíte 100% verde; frontend sem erros de tipo. Fluxo manual da Task 8 Step 4 revalidado end-to-end com a Maritaca real.

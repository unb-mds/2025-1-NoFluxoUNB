# PTOSS-2 — Testes unitários dos serviços RagflowService e SabiaService

Documento de processo (handoff). Descreve **o que foi feito**, **como rodar** e o
**plano de commits incrementais** para evidenciar o processo no trabalho de Testes
de Software. Combina **caixa-preta** (partição por entrada/saída) e **caixa-branca**
(cobertura de ramos/decisões).

> ⚠️ **Não dar push sem revisão do Vitor.** Trabalhar na branch
> `test/services-ragflow-sabia`. Os commits abaixo são uma sugestão para
> evidenciar o processo — confirmar com o Vitor antes de publicar.

---

## 1. Arquivos criados

- `no_fluxo_backend/tests-ts/services/ragflow.service.test.ts`
- `no_fluxo_backend/tests-ts/services/sabia.service.test.ts`

Nenhum arquivo de produção (`src/`) foi alterado — apenas testes.

## 2. Alvos e técnicas de teste

### `src/services/ragflow.service.ts` — `RagflowService`
| Método | Caixa-preta | Caixa-branca |
|---|---|---|
| `isAvailable()` | — | retorna `true`/`false` conforme env presente/ausente |
| `startSession(materia)` | sucesso (session_id + payload/headers/timeout 30s), matéria vazia | serviço não configurado, resposta sem `session_id`, `AxiosError` com `response`, `AxiosError` de timeout (sem `response`), `Error` genérico |
| `analyzeMateria(materia, sessionId)` | sucesso (payload com `question`/`session_id`, timeout 60s) | serviço não configurado, `AxiosError` propagado |

### `src/services/sabia.service.ts` — `SabiaService`
| Método | Caixa-preta | Caixa-branca |
|---|---|---|
| `isAvailable()` | — | `true`/`false` por env (MARITACA / GOOGLE / SUPABASE); URL default |
| `analyzarInteresse(interesse, matriz)` | sucesso, **default `matriz=''`**, resposta de negócio `success=false` | não configurado, `res.ok=false`, `ECONNREFUSED`, `fetch failed` |
| `analyzarInteresseStream(...res)` | escreve chunks e chama `end()` | branch do `flush()`, não configurado, `res.ok=false`, sem `body` |
| `formatAsMarkdown(response)` | resposta típica (emojis por nota 🌟/✨/📚, com/sem `resposta_completa`) | `success=false`, lista de disciplinas vazia |

## 3. Estratégia de mock

- **ragflow:** `jest.mock('axios')` com factory que mantém o `AxiosError` **real**
  (para que `error instanceof AxiosError` funcione no serviço) e troca `axios.post/get`
  por `jest.fn()`. Logger mockado via `jest.mock('../../src/logger')`.
- **sabia:** `global.fetch` substituído por `jest.fn()`. Para o stream, um mock de
  `express.Response` (`write`/`end`/`setHeader` como `jest.fn()`), e um `body.getReader()`
  fake que emite os chunks e depois `{ done: true }`. Logger mockado.
- **Env vars:** os serviços leem `process.env` **no construtor**, então cada teste
  define as env vars e só então faz `new XService()`. O padrão usado é snapshot do
  `process.env` no `beforeEach`/`afterEach` para isolamento total entre testes
  (testes do estado "não configurado" apenas removem a var antes de construir).

## 4. Como rodar

```bash
cd no_fluxo_backend

# todos os testes (critério de aceite: tudo verde)
npm test

# apenas os dois serviços, com cobertura
npm test -- tests-ts/services \
  --coverage \
  --collectCoverageFrom='src/services/ragflow.service.ts' \
  --collectCoverageFrom='src/services/sabia.service.ts'
```

### Resultado obtido (meta ≥ 85% statements/branch)

```
File                | % Stmts | % Branch | % Funcs | % Lines
--------------------|---------|----------|---------|--------
 ragflow.service.ts |     100 |   100    |   100   |   100
 sabia.service.ts   |     100 |   91.48  |   100   |   100
--------------------|---------|----------|---------|--------
Tests: 34 passed, 34 total
```

Ambos acima da meta de 85% em statements e branch. ✅

## 5. Plano de commits incrementais (sugestão p/ evidenciar o processo)

Trabalhar na branch:

```bash
git checkout -b test/services-ragflow-sabia
```

Sequência sugerida (um commit por etapa):

1. `test(ragflow): setup de mocks de axios/logger e testes de isAvailable (caixa-branca)`
2. `test(ragflow): casos de sucesso de startSession/analyzeMateria (caixa-preta)`
3. `test(ragflow): ramos de erro AxiosError/timeout/sem session_id (caixa-branca)`
4. `test(sabia): mock de fetch/logger e testes de isAvailable (caixa-branca)`
5. `test(sabia): analyzarInteresse sucesso + default matriz='' (caixa-preta)`
6. `test(sabia): ramos de erro res.ok=false/ECONNREFUSED + stream (caixa-branca)`
7. `test(sabia): formatAsMarkdown — casos típicos e mensagem padrão`
8. `docs(testes): relatório de cobertura dos serviços (PTOSS-2)`

> Os arquivos já estão prontos por inteiro; se quiser commits "por etapa" de verdade,
> dá para usar `git add -p` para fatiar os blocos `describe(...)` correspondentes a
> cada commit acima.

**NÃO dar `git push` sem o Vitor revisar.**

# Plano de Execucao - Implementacao da Suite de Testes NoFluxoUNB

## Contexto

O projeto NoFluxoUNB esta com **20.54% de cobertura** no backend (meta: 80%), **zero testes** no frontend Svelte (222+ arquivos), e **10/10 testes Python quebrados**. O relatorio de 02/04/2026 (relatorio_testes_nofluxo_2.pdf) definiu 4 prioridades: P0 testes unitarios backend, P0 correcao Python, P1 suite Vitest frontend, P1 testes de integracao. Este plano detalha a execucao tecnica dessas prioridades, ordenada por ROI (risco x cobertura-ganha x esforco).

**Publico:** Programadores juniores. Toda documentacao sera escrita com explicacoes claras.
**Capacidade:** 1 dev, ~15h/semana, 4 sprints de 1 semana.
**Meta:** Sair de 45 testes / 20% cobertura para ~300 testes / 55% cobertura + fundacao frontend.

---

## 1. Stack de Testes Recomendada

| Camada | Ferramenta | Justificativa |
|--------|-----------|---------------|
| Backend TS - Framework | **Jest 29 + ts-jest** | Ja configurado e funcionando com 45 testes |
| Backend TS - Mocking | **jest.mock() + jest.fn()** | Padrao ja estabelecido nos 6 arquivos existentes |
| Backend TS - Cobertura | **Jest --coverage + Codecov** | Ja integrado no CI com upload automatico |
| Backend Python | **pytest + pytest-mock** | Ja configurado no pytest.ini com threshold 70% |
| Frontend - Unitarios | **Vitest 4.0** | Ja instalado no package.json, integra nativamente com Vite/SvelteKit |
| Frontend - Componentes | **@testing-library/svelte + jsdom** | Padrao da industria para testes de componente Svelte |
| Frontend - E2E | **Playwright 1.58** | Ja instalado, script `test:integration` pronto |
| CI/CD | **GitHub Actions** | Workflows `all-tests.yml` ja rodando Jest + pytest |

---

## 2. Estrutura de Pastas Proposta

```
no_fluxo_backend/
  tests-ts/                          # (ja existe)
    controller_logger.test.ts        # (existente, 22 testes)
    cursos_controller.test.ts        # (existente, 3 testes)
    fluxograma_controller.test.ts    # (existente, 3 testes -> EXPANDIR para ~35)
    materias_controller.test.ts      # (existente, 3 testes)
    testes_controller.test.ts        # (existente, 5 testes)
    users_controller.test.ts         # (existente, 9 testes)
    assistente_controller.test.ts    # NOVO
    text_utils.test.ts               # NOVO
    expressao_logica.test.ts         # NOVO
    ranking_formatter.test.ts        # NOVO
    historico_sigaa.test.ts          # NOVO
    integralizacao_service.test.ts   # NOVO
    ragflow_service.test.ts          # NOVO
    sabia_service.test.ts            # NOVO

no_fluxo_frontend_svelte/
  vitest.config.ts                   # NOVO (configuracao)
  src/lib/utils/
    ira.test.ts                      # NOVO (co-localizado com ira.ts)
    casar-materias.test.ts           # NOVO
    expressao-logica.test.ts         # NOVO
  src/lib/factories/
    index.test.ts                    # NOVO

tests-python/                        # (ja existe - LIMPAR)
  test_scraping_equivalencias.py     # (funcional, manter)
  test_converter_json_para_txt.py    # CORRIGIR imports
  test_executar_fluxo_dados_RAGFLOW.py # CORRIGIR imports
  test_extrair_turmas_sigaa.py       # CORRIGIR imports
  test_formatar_para_ragflow.py      # CORRIGIR imports
  test_app.py                        # DELETAR (modulo nao existe mais)
  test_config.py                     # DELETAR
  test_ragflow_agent_client.py       # DELETAR
  test_upload_pdf.py                 # DELETAR
  test_visualizaJsonMateriasAssociadas.py # DELETAR
```

---

## 3. Plano de Execucao por Item

### 3.1 [P0] Testes Unitarios - Backend TypeScript

**Objetivo mensuravel:** Elevar cobertura de **20.54% para ~55%** (statements).

**Pre-requisitos:**
- Node.js 20+ e npm instalados (ja atendido)
- `cd no_fluxo_backend && npm install` (deps ja instaladas)
- Nenhuma nova dependencia necessaria - Jest + ts-jest ja configurados

**Convencoes de nomenclatura:**
- Arquivos: `nome_do_modulo.test.ts` (snake_case, sufixo .test.ts)
- Describes: nome da classe/modulo (ex: `describe('ExpressaoLogica', ...)`)
- Its: frase descritiva comecando com "should" (ex: `it('should return true for APR status', ...)`)

#### Ordem de Ataque (por ROI decrescente):

---

#### Tarefa 1: `text_utils.test.ts` — 0.5h, ~12 testes
**Arquivo a criar:** `no_fluxo_backend/tests-ts/text_utils.test.ts`
**Codigo testado:** `no_fluxo_backend/src/utils/text.utils.ts` (33 linhas, 0% cobertura)
**Cobertura esperada:** 0% -> 100%
**Mocks necessarios:** Nenhum (funcoes puras)

**Casos de teste:**
```
describe('removeAccents')
  it('should remove Portuguese accents')          // "educacao" -> "educacao"
  it('should handle empty string')                // "" -> ""
  it('should return unchanged ASCII text')        // "hello" -> "hello"
  it('should handle mixed accented content')      // "cafe acai" -> "cafe acai"
  it('should handle all Portuguese characters')   // a,e,i,o,u,c with tildes

describe('unescapeHtml')
  it('should decode &amp;')                       // "&amp;" -> "&"
  it('should decode &lt; and &gt;')
  it('should decode &quot;')
  it('should decode numeric references')          // "&#65;" -> "A"
  it('should decode hex references')              // "&#x27;" -> "'"
  it('should handle &nbsp;')
  it('should pass through unknown entities')      // "&unknown;" -> "&unknown;"
```

**Criterio de pronto:** 12 testes passando, 100% cobertura do arquivo.
**Por que este primeiro:** Zero dependencias, zero mocks, confianca imediata no setup.

---

#### Tarefa 2: `historico_sigaa.test.ts` — 0.25h, ~8 testes
**Arquivo a criar:** `no_fluxo_backend/tests-ts/historico_sigaa.test.ts`
**Codigo testado:** `no_fluxo_backend/src/utils/historico_sigaa.ts`
**Cobertura esperada:** 40% -> 100%

**Casos de teste:**
```
describe('isDisciplinaIntegralizada')
  it('should return true for APR')
  it('should return true for CUMP')
  it('should return true for DISP')
  it('should return false for REP')
  it('should return false for MATR')
  it('should return false for TRC')
  it('should return false for empty string')
  it('should return false for undefined')
```

**Criterio de pronto:** 8 testes passando, 100% cobertura.
**Por que:** Funcao usada dentro de `casar_disciplinas` — testar antes de atacar o controller.

---

#### Tarefa 3: `expressao_logica.test.ts` — 2h, ~35 testes
**Arquivo a criar:** `no_fluxo_backend/tests-ts/expressao_logica.test.ts`
**Codigo testado:** `no_fluxo_backend/src/utils/expressao_logica.ts` (130 linhas, 10% cobertura)
**Cobertura esperada:** 10% -> 95%+
**Mocks necessarios:** Nenhum (todas funcoes puras)

**Casos de teste:**
```
describe('getCodigosFromExpressaoLogica')
  it('should return empty for null')
  it('should return empty for undefined')
  it('should extract single code string')         // "MAT0026" -> ["MAT0026"]
  it('should extract from OU expression')          // {operador:"OU", condicoes:["A","B"]} -> ["A","B"]
  it('should extract from nested E+OU expression')
  it('should handle deeply nested 3 levels')
  it('should normalize case to uppercase')

describe('codigoContidoEmExpressaoLogica')
  it('should find code in simple string')
  it('should find code in OU expression')
  it('should return false when not present')
  it('should be case insensitive')

describe('satisfazExpressaoLogica')
  it('should satisfy single code when present in set')
  it('should not satisfy when code missing')
  it('should satisfy OU when ANY condition met')
  it('should not satisfy OU when NONE met')
  it('should satisfy E when ALL conditions met')
  it('should not satisfy E when one missing')
  it('should handle nested OU within E')
  it('should handle nested E within OU')
  it('should return false for empty condicoes')
  it('should return false for null expression')

describe('satisfazExpressaoLogicaComArray')
  it('should convert array to set and evaluate')
  it('should normalize array codes to uppercase')

describe('parseExpressaoLogicaFromDb')
  it('should return null for null input')
  it('should return null for undefined')
  it('should parse plain code string')            // "MAT0026" -> "MAT0026"
  it('should parse quoted string')                // '"MAT0026"' -> "MAT0026"
  it('should parse double-escaped string')
  it('should parse JSON object string')           // '{"operador":"OU",...}'
  it('should return object as-is if already parsed')
  it('should return null for invalid JSON')
  it('should handle code with regex pattern')     // "EST001" matches [A-Za-z]{2,}\d{3,}
```

**Criterio de pronto:** 35 testes passando, 95%+ cobertura.
**Por que P0:** Esta logica sustenta todo o sistema de pre-requisitos e equivalencias. Bug aqui = fluxograma errado para o aluno.

---

#### Tarefa 4: Expandir `fluxograma_controller.test.ts` — 8h, ~30 testes
**Arquivo a modificar:** `no_fluxo_backend/tests-ts/fluxograma_controller.test.ts`
**Codigo testado:** `no_fluxo_backend/src/controllers/fluxograma_controller.ts` (1013 linhas)
**Cobertura esperada:** 10% -> ~55%

**Estrategia para `casar_disciplinas` (544 linhas, 0%):**

Criar funcao helper reutilizavel no topo do arquivo de teste para montar os mocks sequenciais:

```typescript
// Helper para configurar os mocks do casar_disciplinas
// Este endpoint faz 4-5 queries sequenciais ao Supabase
function setupCasarMocks(options: {
  cursos?: { data: any[], error: any },
  materiasPorCurso?: { data: any[], error: any },
  equivalencias?: { data: any[], error: any },
  outrasMatrizes?: { data: any[], error: any },
}) {
  // Cada chamada a mockFrom retorna mocks diferentes em sequencia
  mockFrom
    .mockReturnValueOnce(/* cursos query */)
    .mockReturnValueOnce(/* materias query */)
    .mockReturnValueOnce(/* equivalencias query */)
    .mockReturnValueOnce(/* outras matrizes query */);
}
```

**Casos de teste para `casar_disciplinas`:**
```
describe('casar_disciplinas')
  it('should return 400 when dados_extraidos is missing')
  it('should return 400 when extracted_data is empty array')
  it('should return 404 when course not found in database')
  it('should return 500 on database error')
  it('should match discipline by code to mandatory subject')
  it('should match discipline by name when code differs')
  it('should classify APR as concluida')
  it('should classify MATR as em_andamento')
  it('should identify pending mandatory subjects')
  it('should handle optativa subjects separately')
  it('should resolve equivalencies for missing subjects')
  it('should handle PALAVRAS_CHAVE search prefix')
  it('should handle matriz_curricular filter')
  it('should calculate IRA from extracted data')
  it('should calculate integrated hours correctly')
```

**Casos de teste para rotas restantes:**
```
describe('integralizacao')
  it('should return 400 when curriculoCompleto missing')
  it('should return 200 with calculation result')
  it('should return 500 on service error')

describe('upload-dados-fluxograma')
  it('should return 401 when not authorized')
  it('should return 200 when data saved successfully')
  it('should return 500 on database error')

describe('delete-fluxograma')
  it('should return 401 when not authorized')
  it('should return 200 when data deleted')
  it('should return 500 on database error')
```

**Mocks adicionais necessarios:**
- `jest.mock('../src/services/integralizacao.service')` para o endpoint integralizacao
- `jest.mock('../src/utils')` para `Utils.checkAuthorization` nos endpoints protegidos

**Criterio de pronto:** 30+ testes passando, `fluxograma_controller.ts` com 55%+ cobertura.

---

#### Tarefa 5: `assistente_controller.test.ts` — 4h, ~15 testes
**Arquivo a criar:** `no_fluxo_backend/tests-ts/assistente_controller.test.ts`
**Codigo testado:** `no_fluxo_backend/src/controllers/assistente_controller.ts` (165 linhas, 0%)
**Cobertura esperada:** 0% -> 80%+

**Mocks necessarios:**
```typescript
jest.mock('../src/services/ragflow.service', () => {
  return { RagflowService: jest.fn().mockImplementation(() => ({
    isAvailable: jest.fn(),
    startSession: jest.fn(),
    analyzeMateria: jest.fn(),
  }))}
});
jest.mock('../src/services/sabia.service', () => { /* similar */ });
jest.mock('../src/utils/text.utils', () => ({
  removeAccents: jest.fn((t) => t),
}));
jest.mock('../src/utils/ranking.formatter', () => ({
  formatRanking: jest.fn(() => '# Ranking'),
}));
```

**Casos de teste:**
```
describe('analyze')
  it('should return 400 when materia is missing')
  it('should return 503 when RAGFlow is unavailable')
  it('should return 200 with formatted ranking on success')
  it('should return 500 when RAGFlow returns error code')

describe('health')
  it('should return status with service availability flags')

describe('analyze-sabia')
  it('should return 400 when materia is missing')
  it('should return 503 when Sabia is unavailable')
  it('should return 200 with result and disciplinas')
  it('should return 500 on Sabia error')

describe('analyze-sabia-stream')
  it('should return 400 when materia is missing')
  it('should return 503 when Sabia is unavailable')
  it('should set SSE headers correctly')
```

**Criterio de pronto:** 15 testes passando, 80%+ cobertura.

---

#### Tarefa 6: `integralizacao_service.test.ts` — 2h, ~10 testes
**Arquivo a criar:** `no_fluxo_backend/tests-ts/integralizacao_service.test.ts`
**Codigo testado:** `no_fluxo_backend/src/services/integralizacao.service.ts` (95 linhas, 8%)
**Cobertura esperada:** 8% -> 90%+

**Casos de teste:**
```
describe('calcularIntegralizacao')
  it('should return null for empty curriculoCompleto')
  it('should return result with exact match')
  it('should fallback to prefix match when exact fails')
  it('should return null when no matrix found')
  it('should cap percentages at 100%')
  it('should handle zero division safely')
  it('should calculate obrigatoria/optativa/complementar/total separately')

describe('pct helper')
  it('should calculate percentage correctly')
  it('should cap at 100')
  it('should return 0 when exigido is 0')
```

---

#### Tarefa 7: `ranking_formatter.test.ts` — 2.5h, ~12 testes
**Arquivo a criar:** `no_fluxo_backend/tests-ts/ranking_formatter.test.ts`
**Codigo testado:** `no_fluxo_backend/src/utils/ranking.formatter.ts` (200 linhas, 0%)
**Cobertura esperada:** 0% -> 80%+

---

#### Tarefa 8: `ragflow_service.test.ts` — 2h, ~10 testes
**Arquivo a criar:** `no_fluxo_backend/tests-ts/ragflow_service.test.ts`
**Codigo testado:** `no_fluxo_backend/src/services/ragflow.service.ts` (122 linhas, 0%)
**Mock:** `jest.mock('axios')`

---

#### Tarefa 9: `sabia_service.test.ts` — 3h, ~12 testes
**Arquivo a criar:** `no_fluxo_backend/tests-ts/sabia_service.test.ts`
**Codigo testado:** `no_fluxo_backend/src/services/sabia.service.ts` (184 linhas, 0%)
**Mock:** `global.fetch = jest.fn()`

---

### 3.2 [P0] Correcao do Backend Python

**Objetivo mensuravel:** Dos 10 arquivos quebrados, **5 voltam a funcionar** e **5 sao deletados** (modulos que nao existem mais).

**Pre-requisitos:**
- Python 3.9+ instalado
- `pip install pytest pytest-mock beautifulsoup4 requests`

#### Tarefas Atomicas:

| # | Acao | Arquivo | Esforco | Criterio de Pronto |
|---|------|---------|---------|-------------------|
| P1 | Deletar | `test_app.py` | 1 min | Arquivo removido |
| P2 | Deletar | `test_config.py` | 1 min | Arquivo removido |
| P3 | Deletar | `test_ragflow_agent_client.py` | 1 min | Arquivo removido |
| P4 | Deletar | `test_upload_pdf.py` | 1 min | Arquivo removido |
| P5 | Deletar | `test_visualizaJsonMateriasAssociadas.py` | 1 min | Arquivo removido |
| P6 | Corrigir import | `test_converter_json_para_txt.py` | 15 min | `coleta_dados.scraping` -> `DBA.scraping` + teste passa |
| P7 | Corrigir import | `test_executar_fluxo_dados_RAGFLOW.py` | 15 min | Mesmo padrao |
| P8 | Corrigir import | `test_extrair_turmas_sigaa.py` | 15 min | Mesmo padrao |
| P9 | Corrigir import | `test_formatar_para_ragflow.py` | 15 min | Mesmo padrao |
| P10 | Adicionar deps | `tests-python/requirements.txt` | 5 min | Adicionar `pytest`, `pytest-mock`, `pytest-cov` |

**Esforco total:** ~1h
**Definition of Done:** `python3 -m pytest tests-python/ -v` roda sem erros de coleta, testes restantes passam.

**Risco:** Os scripts em `DBA/scraping/` podem ter mudado a interface (nomes de funcoes, parametros). Mitigacao: rodar cada teste isoladamente e ajustar se necessario.

---

### 3.3 [P1] Suite Vitest - Frontend Svelte

**Objetivo mensuravel:** Criar **~63 testes** cobrindo os utils e factories criticos do frontend.

**Pre-requisitos tecnicos:**
```bash
cd no_fluxo_frontend_svelte
pnpm add -D @testing-library/svelte jsdom
```

#### Tarefa F1: Criar `vitest.config.ts` — 1h

**Arquivo a criar:** `no_fluxo_frontend_svelte/vitest.config.ts`
```typescript
import { defineConfig } from 'vitest/config';
import { sveltekit } from '@sveltejs/kit/vite';

export default defineConfig({
  plugins: [sveltekit()],
  test: {
    include: ['src/**/*.test.ts'],
    environment: 'node', // para testes de utils puros (sem DOM)
    globals: true,
  },
});
```

**Criterio de pronto:** `pnpm test` roda sem erro (0 testes encontrados OK).

#### Tarefa F2: `ira.test.ts` — 0.5h, ~10 testes
**Arquivo:** `no_fluxo_frontend_svelte/src/lib/utils/ira.test.ts`
**Testando:** `ira.ts` (41 linhas) - funcoes `iraStringParaNumero()` e `formatarIraParaExibicao()`
**Zero dependencias externas.**

#### Tarefa F3: `casar-materias.test.ts` — 0.5h, ~8 testes
**Arquivo:** `no_fluxo_frontend_svelte/src/lib/utils/casar-materias.test.ts`
**Testando:** `casar-materias.ts` (23 linhas) - filtros de materias obrigatorias

#### Tarefa F4: `expressao-logica.test.ts` — 2.5h, ~25 testes
**Arquivo:** `no_fluxo_frontend_svelte/src/lib/utils/expressao-logica.test.ts`
**Testando:** `expressao-logica.ts` (109 linhas) - logica recursiva AND/OR de pre-requisitos

#### Tarefa F5: `factories/index.test.ts` — 3h, ~20 testes
**Arquivo:** `no_fluxo_frontend_svelte/src/lib/factories/index.test.ts`
**Testando:** Factories de conversao JSON <-> TypeScript (751 linhas)
**Foco:** `createDadosMateriaFromJson`, `dadosMateriaToJson` (roundtrip), `createCursoModelFromJson`, `normalizeDadosFluxogramaFromStored`

---

### 3.4 [P1] Testes de Integracao (Planejamento)

**Objetivo:** Documentar a estrategia para testes com Supabase real (execucao no proximo ciclo).

**Abordagem recomendada:** Supabase CLI local (`npx supabase start`) que sobe PostgreSQL + Auth + Storage em Docker. Permite rodar queries reais contra um banco local identico ao de producao.

**Nao sera implementado neste ciclo de 4 semanas** — requer Docker configurado e seeds de dados. Fica como proximo passo documentado.

---

## 4. Cronograma Semanal (4 Sprints)

### Sprint 1 (Semana 1): Quick Wins + Fundacao — Meta: 20% -> 35%

| Dia | Tarefa | Horas | Testes Novos | Cobertura Backend |
|-----|--------|-------|-------------|-------------------|
| Seg | T1: text_utils.test.ts | 0.5h | +12 | ~21% |
| Seg | T2: historico_sigaa.test.ts | 0.25h | +8 | ~22% |
| Seg-Ter | T3: expressao_logica.test.ts | 2h | +35 | ~25% |
| Ter-Qua | T4: fluxograma_controller (casar_disciplinas - parte 1) | 5h | +10 | ~30% |
| Qui-Sex | T4: fluxograma_controller (rotas restantes) | 3h | +12 | ~35% |
| | Buffer | 4.25h | | |
| **Total** | | **~11h** | **+77** | **~35%** |

**Milestone verificavel:** `npx jest --coverage` mostra >35% statements, 122+ testes passando.

### Sprint 2 (Semana 2): Controllers + Services — Meta: 35% -> 48%

| Dia | Tarefa | Horas | Testes Novos |
|-----|--------|-------|-------------|
| Seg-Ter | T4: casar_disciplinas (parte 2 - cenarios complexos) | 4h | +8 |
| Qua | T5: assistente_controller.test.ts | 4h | +15 |
| Qui | T6: integralizacao_service.test.ts | 2h | +10 |
| Sex | T7: ranking_formatter.test.ts | 2.5h | +12 |
| | Buffer | 2.5h | |
| **Total** | | **~12.5h** | **+45** |

**Milestone verificavel:** 167+ testes passando, >48% cobertura, 0% -> 80%+ no assistente_controller.

### Sprint 3 (Semana 3): Services + Frontend Setup — Meta: 48% -> 55% backend, fundacao frontend

| Dia | Tarefa | Horas | Testes Novos |
|-----|--------|-------|-------------|
| Seg | T8: ragflow_service.test.ts | 2h | +10 |
| Ter | T9: sabia_service.test.ts | 3h | +12 |
| Qua | F1: vitest.config.ts + F2: ira.test.ts + F3: casar-materias.test.ts | 2h | +18 |
| Qui-Sex | F4: expressao-logica.test.ts (frontend) | 2.5h | +25 |
| Sex | P0 Python: deletar 5 arquivos + corrigir 4 imports | 1h | 0 (fix) |
| | Buffer | 4.5h | |
| **Total** | | **~10.5h** | **+65** |

**Milestone verificavel:** Backend 55%+ cobertura, `pnpm test` no frontend roda 43+ testes, pytest sem erros de coleta.

### Sprint 4 (Semana 4): Factories + Documentacao + Polish

| Dia | Tarefa | Horas | Testes Novos |
|-----|--------|-------|-------------|
| Seg-Ter | F5: factories/index.test.ts | 3h | +20 |
| Qua | Edge cases extras para casar_disciplinas | 3h | +8 |
| Qui | Documentacao: TESTING.md + ADR + template de PR | 2h | 0 |
| Sex | Atualizar CI workflow + relatorio final | 2h | 0 |
| | Buffer | 5h | |
| **Total** | | **~10h** | **+28** |

**Milestone verificavel:** ~300 testes totais, 55% backend, 63 testes frontend, documentacao completa.

### Caminho Critico

```
T3 (expressao_logica) -> T4 (casar_disciplinas) -> T4 cont. (semana 2)
                                                         |
T1 (text_utils) -> T7 (ranking_formatter)                |
T2 (historico_sigaa) ------>------>------>------>---------+
                                                         |
F1 (vitest setup) -> F2/F3 (utils simples) -> F4 (expressao) -> F5 (factories)
```

**Bloqueadores:**
- T4 (casar_disciplinas) depende de T3 (expressao_logica) porque usa as funcoes de expressao
- T7 (ranking_formatter) depende de T1 (text_utils) porque importa `unescapeHtml`
- F2-F5 dependem de F1 (vitest config)
- Python cleanup e independente de tudo

---

## 5. Quick Wins da Primeira Semana (Comecar Hoje)

| # | Acao | Tempo | Resultado Visivel |
|---|------|-------|-------------------|
| 1 | Criar `text_utils.test.ts` (12 testes, zero mocks) | 30 min | Primeiro arquivo novo verde no CI |
| 2 | Criar `historico_sigaa.test.ts` (8 testes, zero mocks) | 15 min | +8 testes passando |
| 3 | Criar `expressao_logica.test.ts` (35 testes, zero mocks) | 2h | Cobertura de 10% -> 95% no modulo mais critico |
| 4 | Deletar 5 testes Python quebrados | 5 min | pytest para de mostrar erros vermelhos |
| 5 | Adicionar `pytest pytest-mock pytest-cov` ao requirements.txt | 2 min | Deps documentadas |
| 6 | Criar `vitest.config.ts` no frontend | 15 min | `pnpm test` funciona (mesmo sem testes) |
| 7 | Criar `ira.test.ts` no frontend (10 testes) | 30 min | Primeiro teste do frontend na historia do projeto |

**Resultado apos dia 1:** +65 testes novos, cobertura backend ~25%, frontend com infra pronta.

---

## 6. CI/CD - Atualizacao do Workflow

**Arquivo a modificar:** `.github/workflows/all-tests.yml`

**Adicionar job para frontend Svelte:**
```yaml
  svelte-tests:
    runs-on: ubuntu-latest
    name: Frontend Svelte Tests
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '20.x'
    - uses: pnpm/action-setup@v2
      with:
        version: 10
    - name: Install dependencies
      run: cd no_fluxo_frontend_svelte && pnpm install
    - name: Run Vitest
      run: cd no_fluxo_frontend_svelte && pnpm test:unit
```

**Politica de execucao:**
| Evento | Backend TS | Python | Frontend Svelte |
|--------|-----------|--------|----------------|
| PR para main/dev | Sim | Sim | Sim |
| Push na main | Sim + coverage | Sim + coverage | Sim + coverage |
| Nightly (cron) | Sim | Sim | Sim |

**Gate de merge:** Todos os testes passando obrigatorio. Cobertura nao deve cair >5% (ja configurado no codecov.yml).

---

## 7. Rastreamento e Metricas

**Metricas semanais:**
| Metrica | Ferramenta | Meta Sprint 1 | Meta Sprint 4 |
|---------|-----------|---------------|---------------|
| Total de testes | Jest + Vitest + pytest | 122 | ~300 |
| Cobertura backend (stmts) | Jest --coverage | 35% | 55% |
| Cobertura frontend | Vitest --coverage | 0% | ~5% (utils) |
| Testes quebrados | CI | 0 | 0 |
| Tempo de execucao | CI logs | <15s | <30s |

**Onde armazenar:** Codecov (ja integrado) + GitHub Actions summary (ja configurado em `all-tests.yml`).

**Template de relatorio semanal (colar no Discord/Issue):**
```markdown
## Relatorio Semanal de Testes - Sprint N (DD/MM)

| Metrica | Semana Anterior | Esta Semana | Delta |
|---------|----------------|-------------|-------|
| Testes totais | X | Y | +Z |
| Cobertura backend | X% | Y% | +Z% |
| Cobertura frontend | X% | Y% | +Z% |
| Testes quebrados | X | Y | -Z |

### O que foi feito
- [ ] Tarefa 1: descricao
- [ ] Tarefa 2: descricao

### Proximos passos
- Tarefa A
- Tarefa B

### Bloqueadores
- (nenhum / descricao)
```

---

## 8. Documentacao a Criar

### TESTING.md (na raiz do projeto)

Secoes obrigatorias:
1. **Como rodar os testes localmente** (comandos por stack)
2. **Como rodar no CI** (link para workflow, como ver resultados)
3. **Como adicionar um novo teste** (passo a passo com exemplo)
4. **Convencoes** (nomenclatura, padrao AAA, uso de mocks)
5. **Troubleshooting** (erros comuns e solucoes)

### ADR-001: Escolha de Ferramentas de Teste

```markdown
# ADR-001: Stack de Testes do NoFluxoUNB

## Status: Aceito
## Data: 09/04/2026

## Contexto
Projeto com 3 stacks (TS/Python/Svelte) precisava de suite de testes unificada.

## Decisao
- Backend TS: Jest 29 (ja em uso, 45 testes existentes)
- Frontend: Vitest 4 (integra com Vite/SvelteKit nativamente)
- Python: pytest (padrao da industria, ja configurado)
- E2E: Playwright (ja instalado, suporta multiplos browsers)

## Consequencias
- Positiva: Reutiliza infra existente, sem migracao
- Positiva: Vitest compartilha config do Vite (aliases, plugins)
- Negativa: Duas ferramentas de teste JS (Jest + Vitest), mas em escopos diferentes (backend vs frontend)
```

### Template de PR para Testes

```markdown
## PR de Testes

### Arquivos de teste adicionados/modificados
- `tests-ts/nome_do_teste.test.ts`

### Cobertura
| Arquivo | Antes | Depois |
|---------|-------|--------|
| modulo.ts | X% | Y% |

### Como verificar
\`\`\`bash
cd no_fluxo_backend && npx jest tests-ts/nome_do_teste.test.ts --verbose
\`\`\`

### Checklist
- [ ] Todos os testes passam localmente
- [ ] Cobertura do modulo alvo aumentou
- [ ] Segue padrao AAA (Arrange-Act-Assert)
- [ ] Nomes dos testes descrevem o comportamento esperado
- [ ] Mocks sao limpos no afterEach
```

---

## 9. Riscos e Mitigacoes

| Risco | Probabilidade | Impacto | Mitigacao |
|-------|--------------|---------|-----------|
| Mock do casar_disciplinas muito complexo | Alta | Medio | Criar helper `setupCasarMocks()` reutilizavel |
| Funcoes helpers do fluxograma_controller nao exportadas | Alta | Medio | Testar indiretamente via rotas (mais lento porem sem refactor) |
| Aliases do SvelteKit nao resolvem no Vitest | Media | Alto | Usar plugin `sveltekit()` no vitest.config.ts |
| Python scripts em DBA/ mudaram interface | Media | Baixo | Rodar cada teste isoladamente, ajustar conforme necessario |
| Junior dev nao entende padrao de mocks | Media | Medio | Documentar exemplos no TESTING.md com comentarios inline |

---

## Verificacao Final

Ao final das 4 semanas, rodar:

```bash
# Backend
cd no_fluxo_backend && npx jest --coverage --verbose
# Esperado: ~210 testes passando, ~55% cobertura

# Frontend
cd no_fluxo_frontend_svelte && pnpm test:unit -- --run
# Esperado: ~63 testes passando

# Python
cd .. && python3 -m pytest tests-python/ -v
# Esperado: ~8 testes passando, 0 erros de coleta

# Tudo junto
./run_all_tests.sh
# Esperado: exit 0
```

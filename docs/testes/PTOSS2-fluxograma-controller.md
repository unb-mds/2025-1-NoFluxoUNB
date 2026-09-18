
# PTOSS-2: Relatorio de Testes — fluxograma_controller

## 1. Modulo Testado

`no_fluxo_backend/src/controllers/fluxograma_controller.ts` (~1030 linhas)

Responsavel por: busca de fluxogramas, casamento de disciplinas do historico SIGAA
com materias do banco, calculo de equivalencias, pre-requisitos, integralizacao,
upload e exclusao de dados do usuario.

## 2. Arquivos de Teste

| Arquivo | Perspectiva | Testes |
|---|---|---|
| `fluxograma_controller.whitebox.test.ts` | Caixa-branca (estrutural) | 39 |
| `fluxograma_controller.blackbox.test.ts` | Caixa-preta (especificacao) | ~50 |
| `fluxograma_controller.routes.test.ts` | Caixa-preta + caixa-branca (rotas) | ~18 |

## 3. Tabelas MC/DC

### 3.1 `isOptativa` — Decisao `(tipo_natureza !== undefined && tipo_natureza !== null)`

**Decisao D = C1 AND C2**
- C1 = `tipo_natureza !== undefined`
- C2 = `tipo_natureza !== null`

| # | C1 | C2 | D | Caso de teste | Resultado |
|---|---|---|---|---|---|
| 1 | V | V | V | `{tipo_natureza: 1}` | `true` (1 === 1) |
| 2 | V | V | V | `{tipo_natureza: 0}` | `false` (0 !== 1) |
| 3 | F | - | F | `{tipo_natureza: undefined}` | fallback nivel |
| 4 | V | F | F | `{tipo_natureza: null}` | fallback nivel |

**Pares de independencia:**
- C1: par (1) x (3) — C1 muda de V para F, C2 irrelevante, D muda de V para F
- C2: par (1) x (4) — C2 muda de V para F, C1 permanece V, D muda de V para F

**Testes:** `fluxograma_controller.whitebox.test.ts` linhas 51-72

### 3.2 `mapEquivalenciasFromDb` — Decisao composta na linha 160

**Decisao D = `!expressaoLogica && e.expressao_logica && typeof e.expressao_logica === "object" && (e.expressao_logica as any).materias`**

D = C1 AND C2 AND C3 AND C4
- C1 = `!expressaoLogica` (parseExpressaoLogicaFromDb retornou null)
- C2 = `e.expressao_logica` (campo existe e e truthy)
- C3 = `typeof e.expressao_logica === "object"` (nao e string)
- C4 = `(e.expressao_logica as any).materias` (tem campo materias)

| # | C1 | C2 | C3 | C4 | D | Caso de teste |
|---|---|---|---|---|---|---|
| 1 | V | V | V | V | V | `expressao_logica: {operador:"E", materias:["A","B"]}` (legado) |
| 2 | F | - | - | - | F | `expressao_logica: "MAT0026"` (parseavel) |
| 3 | V | F | - | - | F | `expressao_logica: null` |
| 4 | V | V | F | - | F | Nao aplicavel (se C2=V e C3=F, seria string que nao parseia — coberto implicitamente) |
| 5 | V | V | V | F | F | `expressao_logica: {operador:"E"}` (sem campo materias) |

**Pares de independencia:**
- C1: (1) x (2)
- C2: (1) x (3)
- C4: (1) x (5)

**Testes:** `fluxograma_controller.whitebox.test.ts` linhas 326-354, `fluxograma_controller.blackbox.test.ts` P5

### 3.3 `checkEquivalencies` — Decisao na linha 286

**Decisao D = `eq.expressao_logica && getCodigosFromExpressaoLogica(eq.expressao_logica).length > 0`**

D = C1 AND C2
- C1 = `eq.expressao_logica` (nao null/undefined)
- C2 = `getCodigosFromExpressaoLogica(...).length > 0` (tem codigos)

| # | C1 | C2 | D | Caso de teste |
|---|---|---|---|---|
| 1 | V | V | V | `expressao_logica: {operador:"OU", condicoes:["MAT0026"]}` |
| 2 | F | - | F | `expressao_logica: null, expressao: "MAT0026"` |
| 3 | V | F | F | `expressao_logica: {}` (sem condicoes — codigos vazio) |

**Pares:** C1: (1)x(2); C2: (1)x(3)

**Testes:** `fluxograma_controller.whitebox.test.ts` linhas 253-279, `fluxograma_controller.blackbox.test.ts` P1-P4

### 3.4 `findSubjectMatch` — Cadeia de 4 decisoes

Cada nivel e um `if (!match)` seguido de `.find()`.

| Nivel | Decisao | V (encontrado) | F (nao encontrado, proximo nivel) |
|---|---|---|---|
| 1 | match por codigo em obrigatorias | Retorna match | Continua |
| 2 | match por codigo em optativas | Retorna match | Continua |
| 3 | match por nome em obrigatorias | Retorna match | Continua |
| 4 | match por nome em optativas | Retorna match | Retorna null |

**Testes:** Cada nivel coberto por testes P1-P5 em ambos os arquivos.

### 3.5 `processMatchedDiscipline` — Decisao `newPriority > currentPriority` (linha 256)

D = `newPriority > currentPriority`

| # | Existente | Novo | D | Acao |
|---|---|---|---|---|
| 1 | REP (1) | APR (3) | V (3>1) | Substitui |
| 2 | APR (3) | MATR (2) | F (2<=3) | Mantem |
| 3 | MATR (2) | MATR (2) | F (2<=2) | Mantem |

**Testes:** whitebox linhas 198-250, blackbox P2-P3

## 4. Matriz de Rastreabilidade

| ID | Funcao | Requisito | Tecnica | Arquivo de teste | Teste(s) |
|---|---|---|---|---|---|
| T01 | isOptativa | Classificar materia como optativa/obrigatoria | EP, BVA, MC/DC | whitebox + blackbox | isOptativa — todos |
| T02 | extractSubjectCodes | Extrair codigos de materias de strings | EP, BVA | blackbox | extractSubjectCodes — P1-P5, VL |
| T03 | getCodigosEquivalentes | Obter codigos equivalentes com fallback | EP | whitebox + blackbox | getCodigosEquivalentes — P1-P3 |
| T04 | codigoContidoNaEquivalencia | Verificar se codigo pertence a equivalencia | EP | whitebox + blackbox | codigoContidoNaEquivalencia — P1-P4 |
| T05 | getStatusPriority | Determinar prioridade de status SIGAA | EP | whitebox + blackbox | getStatusPriority — P1-P3 |
| T06 | findSubjectMatch | Encontrar materia no banco (4 niveis fallback) | EP, BVA | whitebox + blackbox | findSubjectMatch — P1-P5, VL |
| T07 | processMatchedDiscipline | Processar match com resolucao de duplicatas | EP | whitebox + blackbox | processMatchedDiscipline — P1-P5 |
| T08 | checkEquivalencies | Verificar satisfacao de equivalencias | EP, MC/DC | whitebox + blackbox | checkEquivalencies — P1-P4 |
| T09 | mapPreRequisitosFromDb | Mapear pre-requisitos do banco | EP, BVA | whitebox + blackbox | mapPreRequisitosFromDb — P1-P4 |
| T10 | mapEquivalenciasFromDb | Mapear equivalencias (formato recursivo/legado) | EP, MC/DC | whitebox + blackbox | mapEquivalenciasFromDb — P1-P5 |
| T11 | GET /fluxograma | Buscar fluxograma por nome de curso | EP, Decisao | routes | fluxograma — P1-P3 |
| T12 | POST /casar_disciplinas | Casar disciplinas do historico com banco | EP, Decisao | routes | casar_disciplinas — P1-P3 |
| T13 | POST /integralizacao | Calcular integralizacao curricular | EP, BVA, Decisao | routes | integralizacao — P1-P5 |
| T14 | POST /upload-dados-fluxograma | Salvar fluxograma do usuario | EP, Decisao | routes | upload — P1-P3 |
| T15 | DELETE /delete-fluxograma | Remover fluxograma do usuario | EP, Decisao | routes | delete — P1-P4 |

**Legenda:** EP = Equivalence Partitioning, BVA = Boundary Value Analysis, MC/DC = Modified Condition/Decision Coverage

## 5. Como Executar

```bash
cd no_fluxo_backend

# Todos os testes do fluxograma_controller
npx jest tests-ts/fluxograma_controller --coverage

# Apenas caixa-branca
npx jest tests-ts/fluxograma_controller.whitebox.test.ts --coverage

# Apenas caixa-preta
npx jest tests-ts/fluxograma_controller.blackbox.test.ts --coverage

# Apenas rotas
npx jest tests-ts/fluxograma_controller.routes.test.ts --coverage

# Cobertura completa do projeto
npm run test:coverage
```

## 6. Integracao entre Abordagens

As mesmas funcoes sao testadas sob duas perspectivas complementares:

- **Caixa-preta** (blackbox): testa particionando os dominios de entrada com base na
  especificacao (o que a funcao *deve* fazer), identificando classes de equivalencia
  e valores limite.

- **Caixa-branca** (whitebox): testa exercitando caminhos do codigo (ramos, decisoes,
  MC/DC), garantindo que todas as ramificacoes sejam percorridas.

Exemplos de complementaridade:
- `isOptativa`: caixa-preta identifica as classes {0, 1, null, undefined, outros};
  caixa-branca garante que o ramo `tipo_natureza !== undefined && !== null` e exercitado
  com MC/DC.
- `checkEquivalencies`: caixa-preta testa cenarios funcionais (satisfeita/nao);
  caixa-branca garante o ramo `expressao_logica` vs fallback `expressao`.
- Rotas: caixa-preta valida respostas HTTP esperadas; caixa-branca cobre ramos de erro
  (Supabase falha, servico indisponivel, autorizacao negada).

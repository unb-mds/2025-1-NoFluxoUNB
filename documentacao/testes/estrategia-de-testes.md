# Estratégia de Testes — NoFluxoUNB

Este documento estabelece a base teórica, as técnicas de projeto de testes e a metodologia adotada pelo projeto **NoFluxoUNB**, em alinhamento com a disciplina **FGA0314 — Testes de Software**.

---

## 1. Princípios e Níveis de Teste

A estratégia adota a pirâmide de testes para garantir retorno rápido de feedback, facilidade de manutenção e máxima cobertura nos pontos críticos de negócio.

| Nível | Objetivo | Onde está implementado | Ferramental |
|---|---|---|---|
| **Unidade** | Validar funções puras, controladores isolados, cálculos de carga horária e stores | `no_fluxo_frontend_svelte` (`src/**/*.test.ts`), `no_fluxo_backend` (`tests-ts/`), `tests-python/` | Vitest, Jest, Pytest |
| **Integração** | Validar a comunicação entre múltiplos módulos (ex.: orquestrador com revisor de IA, resolução de dependências no grafo) | `no_fluxo_backend/tests-ts/orquestrador-*.test.ts`, `mcp_agent/test_tool_call_utils.py` | Jest, Pytest, Mocks de API |
| **Sistema / E2E** | Validar fluxos completos da perspectiva do estudante universitário | `no_fluxo_frontend_svelte/tests-e2e/*.spec.ts` | Playwright |

---

## 2. Técnicas de Projeto de Casos de Teste

### 2.1. Testes Baseados em Especificação (Caixa-Preta)
Focados no contrato da função ou componente, sem depender de detalhes internos de implementação:

- **Particionamento em Classes de Equivalência:**
  - *Exemplo (Carga Horária e Créditos):* Divisão entre créditos válidos ($[0, 32]$ créditos por semestre na UnB), créditos nulos e valores excedentes que violam a resolução acadêmica.
  - *Exemplo (Expressões de Pré-requisito):* Entradas simples (`"MAT0025"`), conjunções (`"A E B"`), disjunções (`"A OU B"`) e aninhamentos (`"(A OU B) E C"`).
- **Análise de Valor Limite (Boundary Value Analysis):**
  - Aplicação dos pontos *on point*, *off point* e limites de fronteira (ex.: mínimo de créditos para trancamento geral, limite máximo de slots de horário conflitantes por dia).

### 2.2. Testes Estruturais (Caixa-Branca)
Aplicados aos algoritmos complexos do projeto, em especial o **Motor 2 de Planejamento**, o **Montador Automático de Grade** e o **Parser de Expressões Lógicas**:

- **Cobertura de Decisão e Desvio:** Garantia de que todos os ramos condicionais de regras acadêmicas (ex.: matéria obrigatória vs. optativa, co-requisito atendido ou pendente) sejam percorridos.
- **Modified Condition / Decision Coverage (MC/DC):**
  - Utilizado na avaliação de expressões lógicas booleanas da UnB: cada condição deve demonstrar independência ao alterar individualmente o resultado final da expressão lógica (ex.: aprovação com base em equivalência disjuntiva).

### 2.3. Dublês de Teste (Test Doubles & Mocks)
Para manter a suíte determinística, rápida e independente de infraestrutura de rede:

- **Supabase Mocks:** No backend e frontend, operações de banco de dados são simuladas via interfaces mockadas, evitando chamadas de rede externas durante a execução do CI.
- **Mocks de LLM / IA:** As chamadas para APIs externas (OpenAI, Maritaca, Google Gemini) são interceptadas por fakes que retornam respostas controladas com schemas de JSON esperados.

---

## 3. Estado Atual das Suítes

- **Frontend SvelteKit (Vitest):** Suíte madura com **mais de 40 arquivos de teste**, cobrindo exaustivamente o algoritmo de montagem de grade (`grade.store.*`), seleção e pool de matérias recomendadas (`grade-pool.*`), verificação de pré-requisitos e conversão de bitmasks de horários.
- **Backend TypeScript (Jest):** Suíte sólida com **25 arquivos de teste**, cobrindo todos os controllers de API, motor de planejamento de formatura, atuadores de módulo livre e persistência de sessões de chat.
- **Módulos de Dados (Python / Pytest):** Testes unitários para parsers de expressões lógicas, validação de regex e sanitização de dados raspados do SIGAA.
- **E2E (Playwright):** Testes exploratórios automatizados para os fluxos mais sensíveis: upload e análise de histórico em PDF, autenticação e comportamento em dispositivos móveis.

---

## 4. Diretrizes para Novos Testes

Ao adicionar novas funcionalidades ao NoFluxoUNB:

1. **Determinismo:** Testes não devem depender de relógio local não-mockado, ordem de execução de arquivos ou chamadas reais a bancos na nuvem.
2. **Isolamento:** Cada caso de teste deve limpar seu estado em `beforeEach` / `afterEach`.
3. **Nomenclatura Clara:** Utilize o padrão `describe('Módulo / Função', () => { it('deve fazer X quando Y', ...)})`.
4. **Regressão:** Qualquer correção de bug deve ser acompanhada por um teste de unidade ou integração que reproduza o problema antes da correção.

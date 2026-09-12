# Estratégia de Testes — NoFluxoUNB

Documento de referência da disciplina **FGA0314 — Testes de Software** que descreve
como o projeto organiza seus testes, qual técnica/ nível cada suíte cobre e qual é o
plano de evolução. Ele complementa o **Relatório de Análise de Testes** produzido pela
equipe.

## Níveis de teste e a pirâmide

| Nível | O que verifica | Onde está no projeto | Ferramenta |
|-------|----------------|----------------------|------------|
| **Unidade** | Métodos/funções isolados | `no_fluxo_backend` (controllers, serviços, utilitários); `tests-python` (módulos de scraping/parse) | Jest, Pytest |
| **Integração** | Componentes interagindo (ex.: parsing → fluxograma, acesso ao Supabase real) | _Em construção (Fase 3)_ | Pytest/Jest + Supabase via Docker |
| **Sistema / E2E** | Fluxo completo do usuário (Home → curso → fluxograma) | _Em construção (Fase 3)_ | Playwright |

A base da pirâmide (unidade) é onde concentramos esforço primeiro, por ser mais barata
e rápida; integração e sistema vêm em seguida, em menor quantidade.

## Técnicas de projeto de casos de teste

As técnicas estudadas na disciplina orientam **como** escrevemos cada caso, em qualquer
nível:

- **Caixa-preta** (_specification-based_, Aniche cap. 2): Particionamento de
  Equivalência (classes válidas/inválidas) + Análise de Valor Limite (_on point_ /
  _off point_). Foco no comportamento especificado, sem olhar o código.
- **Caixa-branca** (_structural_, Aniche cap. 3): critérios estruturais, com destaque
  para **MC/DC** (condições → tabela-verdade → casos), usado para exercitar a lógica de
  decisão de funções complexas.
- **Dublês de teste / mocks** (Aniche cap. 6): isolam dependências externas (ex.:
  Supabase, HTTP, relógio) para testar a unidade de forma determinística.
- **TDD** (Aniche cap. 8): quando aplicável, escrever o teste antes da implementação.

## Estado atual (resumo do relatório)

- **Backend TS (Jest):** suíte funcional madura com 25 arquivos de teste cobrindo controllers, Motor 2, persistência de sessão e orquestrador de IA.
- **Frontend (Vitest & Playwright):** ampla cobertura com mais de 40 arquivos de teste cobrindo lojas de grade (`grade.store.*`), seleção e pool de matérias (`grade-pool.*`), serviços acadêmicos e testes ponta a ponta (E2E).
- **Backend de dados (Pytest):** os imports foram mapeados para `DBA` e cobrem parsers de expressões lógicas, scraping e ferramentas do agente.
- **Cobertura:** em constante monitoramento e expansão pelo Codecov.

## Plano de evolução

1. **Fase 1 — Correção e automação** _(Concluída)_: remapear imports Python, consolidar workflows no CI (`pipelineCI.yml`).
2. **Fase 2 — Cobertura**: elevar a cobertura com testes de unidade em controladores e lojas reativas do montador de grade.
3. **Fase 3 — Frontend e E2E** _(Concluída / Em Expansão)_: suítes Vitest de componentes e stores, e fluxo E2E com Playwright (upload de histórico, login e responsividade mobile).

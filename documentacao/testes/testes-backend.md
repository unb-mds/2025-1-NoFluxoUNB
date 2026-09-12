# Testes do Backend (Jest / TypeScript)

O backend do NoFluxoUNB (`no_fluxo_backend`) conta com uma suíte de **25 arquivos de teste** implementados em TypeScript com **Jest** e `ts-jest`.

---

## 📂 Organização dos Testes

Os arquivos residem em `no_fluxo_backend/tests-ts/` e cobrem os três pilares principais do backend: **Controllers da API**, **Motor 2 de Planejamento Acadêmico** e o **Orquestrador de Agentes de IA**.

```
no_fluxo_backend/
├── src/                    # Código-fonte
└── tests-ts/               # Suíte de testes Jest
    ├── controller_logger.test.ts
    ├── cursos_controller.test.ts
    ├── distribuir-slots-fix.test.ts
    ├── double-rounding-fix.test.ts
    ├── equivalencias-cumpridas.test.ts
    ├── fluxograma_controller.test.ts
    ├── grade-actuator.test.ts
    ├── horario-slots-backend.test.ts
    ├── maritaca-errors.test.ts
    ├── materias_controller.test.ts
    ├── modulo-livre-actuator.test.ts
    ├── motor2-v2.test.ts
    ├── oferta-por-equivalencia.test.ts
    ├── optativas-ja-cursadas.test.ts
    ├── orquestrador-fase2.test.ts
    ├── periodo-ativo.test.ts
    ├── planejador-agente.test.ts
    ├── planejamento-corequisitos.test.ts
    ├── planejamento-restricoes.test.ts
    ├── planejamento.test.ts
    ├── revisor-fase3.test.ts
    ├── session-persistence.test.ts
    ├── substitutos-equivalencia.test.ts
    ├── tool-registry.test.ts
    ├── users_controller.test.ts
    └── utils/
```

---

## 🔍 Catálogo das Suítes de Teste

### 1. Controladores da API REST
Testam endpoints HTTP, validação de payload com schemas Zod, headers de resposta e tratamento de status codes:

- `cursos_controller.test.ts`: Listagem de cursos, busca por ID de currículo e normalização de turnos (diurno/noturno).
- `fluxograma_controller.test.ts`: Geração e recuperação da árvore de matérias e matriz curricular por curso.
- `materias_controller.test.ts`: Busca de matérias, paginação, filtros por departamento e consulta de ementas.
- `users_controller.test.ts`: Consulta e salvamento de dados do usuário, histórico escolar e preferências de curso.
- `controller_logger.test.ts`: Auditoria e logs estruturados em requisições de controllers (Winston logger).

### 2. Motor 2 de Planejamento e Algoritmo de Grade
Conjunto mais denso de testes de regras de negócio, assegurando o cumprimento das resoluções acadêmicas da UnB:

- `motor2-v2.test.ts`: Lógica nuclear da cadeia de formatura personalizada, ordenação topológica e restrições de semestres.
- `planejamento.test.ts`: Cálculo de prazos estimados para colação de grau e projeção de disciplinas por período.
- `planejamento-corequisitos.test.ts`: Garantia de matrícula simultânea quando duas disciplinas possuem co-requisito estrito.
- `planejamento-restricoes.test.ts`: Respeito aos limites de créditos mínimos e máximos semestrais.
- `grade-actuator.test.ts` (44 KB): Validação exaustiva do atuador de alocação de horários, detecção de choques de grade e compatibilidade de turnos.
- `modulo-livre-actuator.test.ts`: Alocação correta de matérias de módulo livre (optativas fora da matriz de origem).
- `equivalencias-cumpridas.test.ts`: Dedução de matérias obrigatórias cumpridas através de disciplinas equivalentes cursadas.
- `optativas-ja-cursadas.test.ts`: Prevenção de recomendação redundante de disciplinas já aprovadas no histórico.
- `substitutos-equivalencia.test.ts`: Mapeamento de disciplinas equivalentes disponíveis para cursar no período letivo.
- `oferta-por-equivalencia.test.ts`: Cruzamento de turmas ofertadas em departamentos distintos que equivalem à matriz do curso.
- `horario-slots-backend.test.ts`: Operações bitmask para representação de blocos e horários no padrão UnB (ex.: 24T23).
- `distribuir-slots-fix.test.ts` e `double-rounding-fix.test.ts`: Testes de regressão cobrindo arredondamento de médias ponderadas e distribuição de slots.
- `periodo-ativo.test.ts`: Resolução do período letivo vigente no banco de dados.

### 3. Agente de IA, Orquestrador e Persistência
Validam a arquitetura multiagente de recomendação:

- `planejador-agente.test.ts`: Comportamento do agente de planejamento e geração de sugestões personalizadas.
- `orquestrador-fase2.test.ts`: Orquestração entre a intenção do usuário e a consulta de dados acadêmicos.
- `revisor-fase3.test.ts`: Verificação crítica de consistência do plano gerado pelo agente antes do retorno ao usuário.
- `session-persistence.test.ts`: Persistência de estado de conversas e planos entre sessões no banco de dados.
- `tool-registry.test.ts`: Registro, validação de schema e execução segura de tool calls disponíveis para as LLMs.
- `maritaca-errors.test.ts`: Tratamento de exceções, rate limits e fallbacks para a API da Maritaca AI.

---

## 🛠️ Como Executar os Testes do Backend

A partir da raiz do repositório ou de `no_fluxo_backend/`:

```bash
cd no_fluxo_backend

# 1. Executar todos os testes:
npm test

# 2. Executar em modo interativo/observador (watch mode):
npm run test:watch

# 3. Executar apenas uma suíte específica:
npx jest tests-ts/motor2-v2.test.ts

# 4. Executar testes com filtro por nome:
npx jest -t "deve respeitar os limites de créditos"

# 5. Gerar relatório de cobertura completo:
npm run test:coverage
```

### Relatório de Cobertura
O relatório é exportado em formato LCOV e HTML no diretório `no_fluxo_backend/coverage/`. Para visualizar no navegador:
- Abra `no_fluxo_backend/coverage/lcov-report/index.html`.

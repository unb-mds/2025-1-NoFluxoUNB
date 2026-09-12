# Testes do Frontend (Vitest & Playwright)

O frontend do NoFluxoUNB (`no_fluxo_frontend_svelte`), construído com **SvelteKit v2**, **Svelte 5** e **TypeScript**, conta com uma ampla suíte de testes de unidade e integração orientados por **Vitest** (com suporte aos novos runes `$state`) e testes de sistema ponta a ponta com **Playwright**.

---

## 📊 Panorama da Suíte

- **42 arquivos de testes de unidade e regras de negócio** via Vitest.
- **3 suítes E2E** via Playwright cobrindo jornadas críticas do usuário.
- Ambiente virtualizado de testes com DOM simulado (`jsdom`).
- Cobertura profunda do **Montador de Grade Horária** e da **Resolução de Grafo Curricular**.

---

## 🧩 Catálogo das Suítes Vitest

### 1. Núcleo do Montador de Grade (`grade.store.*`)
O montador de grade é uma das funcionalidades mais avançadas do produto. Ele utiliza bitmasks para representar horários e heurísticas de otimização combinatória:

- `grade.store.montarAutomatico.test.ts`: Algoritmo guloso de alocação de turmas evitando choques de horário.
- `grade.store.travar.test.ts`: Fixação de matérias selecionadas manualmente pelo aluno para não serem substituídas na auto-montagem.
- `grade.store.limiteCreditos.test.ts`: Controle rígido do teto de créditos semestrais permitidos.
- `grade.store.prioridadeNatureza.test.ts` e `pesoDaNatureza.test.ts`: Ordenação de prioridade (Obrigatórias > Optativas > Módulo Livre).
- `grade.store.freeMask.test.ts`: Operações binárias bitwise sobre máscaras de horários livres vs. ocupados.
- `grade.store.cursandoReal.test.ts` e `incluirCursando.test.ts`: Integração com o status das matérias que o aluno cursa atualmente.
- `grade.store.ajustarParaLimite.test.ts`: Podas e ajustes quando a seleção preliminar ultrapassa a carga horária alvo.
- `grade.store.montagemVazia.test.ts` e `limparTudo.test.ts`: Comportamento de reset e limpeza de estado da grade.

### 2. Seleção e Pool de Matérias (`grade-pool.*`)
Gerencia o catálogo de disciplinas elegíveis para o próximo semestre do aluno:

- `grade-pool.montarPoolRecomendado.test.ts`: Construção do conjunto de matérias recomendadas com base no progresso curricular.
- `grade-pool.candidatosDaMatriz.test.ts`: Filtro de matérias da matriz que ainda não foram cursadas nem trancadas.
- `grade-pool.pendenciaPreRequisito.test.ts`: Bloqueio de matérias cujos pré-requisitos não foram integralizados.
- `grade-pool.saldo.test.ts`: Cálculo do saldo remanescente de créditos obrigatórios e optativos para formatura.
- `grade-pool.moduloLivre.test.ts`: Regras de aproveitamento de carga horária para disciplinas eletivas de outros cursos.
- `grade-pool.escolherAteOLimite.test.ts`: Seleção combinatória ótima respeitando a janela de créditos definida.

### 3. Serviços de Domínio e Chat com IA
- `chat.service.test.ts`: Envio de mensagens, streaming e comunicação com o backend e agente IA.
- `auth.service.test.ts` e `authGuard.test.ts`: Proteção de rotas, interceptação de sessões e redirecionamento pós-login.
- `situacao-academica.test.ts`: Cálculo de índice de rendimento, percentual de conclusão e integralização curricular.
- `assistente-chat-store-montador.test.ts`: Interação entre o chat do assistente e as ações automáticas no montador de grade.
- `assistente-chat-store-erros.test.ts`: Fallbacks visuais e tratamento amigável de erros da IA para o usuário.

### 4. Utilitários e Formatação SIGAA
- `sigaa.test.ts`: Parser de códigos de horários padrão UnB (ex.: `24M12`, `35T34`, `6N12`).
- `horario-slots.test.ts` e `horario-slots.orcamento.test.ts`: Conversão de horários em bitmasks de 64 bits para colisão instantânea.
- `expressao-logica.test.ts`: Avaliação booleana no cliente de expressões de pré-requisito com operadores `E` e `OU`.
- `curriculum-graph.test.ts`: Algoritmo de ordenação e detecção de ciclos no grafo de dependências entre disciplinas.
- `SubjectSearch.test.ts`: Teste de componente Svelte validando busca instantânea, debounce e renderização de resultados.

---

## 🎭 Testes End-to-End (Playwright)

Localizados em `no_fluxo_frontend_svelte/tests-e2e/`:

1. `upload-historico.exploratorio.spec.ts`:
   - Realiza o fluxo completo de upload de PDF de histórico da UnB.
   - Valida a renderização correta do fluxograma preenchido com matérias cursadas, pendentes e aprovadas.
2. `login-auth.exploratorio.spec.ts`:
   - Valida os fluxos de login, recuperação de senha, mensagens de validação e redirecionamento para rotas protegidas.
3. `repro-limpar-grade-mobile.spec.ts`:
   - Teste de regressão para dispositivos móveis (viewport estreito) garantindo o funcionamento de botões de limpeza e modais.

---

## 🛠️ Como Executar os Testes do Frontend

A partir de `no_fluxo_frontend_svelte/`:

```bash
cd no_fluxo_frontend_svelte

# 1. Executar todos os testes de unidade (Vitest):
pnpm run test:unit       # ou: npm run test:unit

# 2. Executar em modo interativo (com interface gráfica Vitest no navegador):
npx vitest --ui

# 3. Executar arquivo específico com watch:
npx vitest src/lib/stores/grade.store.montarAutomatico.test.ts

# 4. Gerar relatório de cobertura:
pnpm run test:coverage

# 5. Executar os testes E2E do Playwright:
npx playwright test
```

> **Nota para o Playwright:** Os testes de sistema necessitam que o frontend esteja rodando previamente (`pnpm dev`) ou configurado no `playwright.config.ts`.

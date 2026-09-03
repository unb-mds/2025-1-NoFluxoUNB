# Métricas e Cobertura de Código

Este documento detalha como o **NoFluxoUNB** mede, monitora e reporta a cobertura de testes de código em suas diferentes frentes tecnológicas.

---

## 🎯 Metas e Políticas de Cobertura

As políticas de cobertura de testes do projeto são regidas pela configuração do **Codecov** ([`codecov.yml`](file:///c:/Users/Felipe%20Pedroza/Documents/UnB/nofluxo/2025-1-NoFluxoUNB/codecov.yml)) e pelos objetivos da disciplina:

- **Alvo do Projeto (Target):** `80%` de cobertura de linhas e ramos nas regras de negócio.
- **Tolerância (Threshold):** `5%` de variação aceitável em commits intermediários.
- **Branch Detection:** Ativada para desvios condicionais e loops.
- **Arquivos Ignorados:** Arquivos de setup (`jest.setup.js`), arquivos de configuração e os próprios arquivos de teste (`*.test.ts`, `*.spec.ts`) são excluídos da contagem de cobertura para não inflar as métricas artificialmente.

---

## 📊 Como Gerar Relatórios de Cobertura

### 1. Backend (TypeScript / Jest)

O Jest utiliza o instrumentador Istanbul para gerar métricas detalhadas de linhas, funções, instruções e ramos:

```bash
cd no_fluxo_backend
npm run test:coverage
```

- **Saída no Terminal:** Tabela resumida indicando percentual por arquivo em `src/`.
- **Relatório HTML Navegável:** Salvo em `no_fluxo_backend/coverage/lcov-report/index.html`.
- **Relatório LCOV:** Salvo em `no_fluxo_backend/coverage/lcov.info` (consumido pelo Codecov).

### 2. Frontend (SvelteKit / Vitest)

O Vitest utiliza o provedor `@vitest/coverage-v8` para mensuração de alta performance diretamente sobre a V8:

```bash
cd no_fluxo_frontend_svelte
pnpm run test:coverage
```

- **Saída no Terminal:** Cobertura de stores, componentes e utilitários.
- **Relatório HTML:** Gerado em `no_fluxo_frontend_svelte/coverage/index.html`.

### 3. Python (Pytest / pytest-cov)

O pytest-cov gera relatórios com suporte a branches e realce de linhas não visitadas:

```bash
cd tests-python
python -m pytest --cov=. --cov-report=html --cov-report=term-missing
```

- **Relatório HTML:** Gerado em `tests-python/htmlcov/index.html`.
- **Destaque de Falhas:** O argumento `--cov-report=term-missing` lista no próprio terminal as linhas exatas do arquivo que deixaram de ser exercitadas.

---

## 📈 Interpretação dos Indicadores

Ao analisar um relatório de cobertura, avaliamos quatro métricas fundamentais:

| Métrica | Significado | Meta Mínima Recomendada |
|---|---|---|
| **Statement Coverage** | Percentual de instruções de código executadas | $\ge 80\%$ |
| **Branch Coverage** | Percentual de ramificações (`if`, `else`, `switch`, ternários) testadas em ambos os caminhos | $\ge 75\%$ |
| **Function Coverage** | Percentual de funções e métodos chamados ao menos uma vez | $\ge 85\%$ |
| **Line Coverage** | Linhas de código executadas ao longo dos testes | $\ge 80\%$ |

---

## 🔍 Visualização Local dos Relatórios HTML

Para inspecionar detalhadamente quais linhas estão descobertas (marcadas em vermelho):

```bash
# No Windows:
start no_fluxo_backend/coverage/lcov-report/index.html
start no_fluxo_frontend_svelte/coverage/index.html
start tests-python/htmlcov/index.html

# No Linux:
xdg-open no_fluxo_backend/coverage/lcov-report/index.html

# No macOS:
open no_fluxo_backend/coverage/lcov-report/index.html
```

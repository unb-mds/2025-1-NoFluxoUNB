# Como Executar os Testes — NoFluxoUNB (PTOSS-2)

## Pre-requisitos

- Node.js >= 18
- Python >= 3.10 (para testes Python)
- npm instalado

## 1. Testes TypeScript (Backend)

```bash
cd backend
npm install

# Executar todos os testes
npm test

# Executar com cobertura
npm run test:coverage

# Executar arquivo especifico
npx jest tests-ts/fluxograma_controller.whitebox.test.ts
npx jest tests-ts/fluxograma_controller.blackbox.test.ts
npx jest tests-ts/fluxograma_controller.routes.test.ts
npx jest tests-ts/assistente_controller.test.ts
npx jest tests-ts/utils/

# Executar testes de um modulo com cobertura detalhada
npx jest tests-ts/fluxograma_controller --coverage --verbose
```

### Modulos testados (TypeScript)

| Modulo | Arquivo(s) de teste | Branch |
|---|---|---|
| `fluxograma_controller` | `fluxograma_controller.whitebox.test.ts`, `.blackbox.test.ts`, `.routes.test.ts` | `test/fluxograma-controller-coverage` |
| `assistente_controller` | `assistente_controller.test.ts` | `test/assistent-controller` |
| `utils/expressao_logica` | `utils/expressao_logica.test.ts` | `test/utils-test` |
| `utils/ranking.formatter` | `utils/ranking.formatter.test.ts` | `test/utils-test` |
| `utils/historico_sigaa` | `utils/historico_sigaa.test.ts` | `test/utils-test` |
| `utils/text.utils` | `utils/text.utils.test.ts` | `test/utils-test` |
| `services/ragflow.service` | `services/ragflow.service.test.ts` | `test/services-ragflow-sabia` |
| `services/sabia.service` | `services/sabia.service.test.ts` | `test/services-ragflow-sabia` |

## 2. Testes Python (Parser de Expressoes)

```bash
cd DBA/tests
pip install pytest pytest-cov

# Executar todos os testes
pytest -v

# Executar com cobertura
pytest --cov=../DBA/database --cov-report=term-missing -v

# Gerar relatorio HTML de cobertura
pytest --cov=../DBA/database --cov-report=html -v
```

### Modulos testados (Python)

| Modulo | Arquivo de teste | Branch |
|---|---|---|
| `expressao_parser` | `test_expressao_parser.py` | `test/fix--testes-python` |

## 3. Relatorios de Cobertura

Apos rodar com `--coverage` (TS) ou `--cov-report=html` (Python), os relatorios
ficam em:

- **TypeScript**: `backend/coverage/` (abrir `index.html`)
- **Python**: `DBA/tests/htmlcov/` (abrir `index.html`)

## 4. CI (GitHub Actions)

Os testes sao executados automaticamente no CI via GitHub Actions.
Veja `.github/workflows/` para configuracao.

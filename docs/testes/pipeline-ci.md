# Pipeline de Integração Contínua (CI)

O CI é a automação que **executa os testes do projeto a cada Pull Request e a cada push
para `main`/`dev`**. Ele não é uma técnica de teste em si: é o portão de qualidade que
faz a pirâmide de testes (unidade, integração, sistema) rodar continuamente e impede
que código com regressão seja integrado.

Implementa a **Fase 1** do Relatório de Análise de Testes ("configurar GitHub Actions
para rodar os testes automaticamente em cada PR").

## Workflow

Arquivo: [`.github/workflows/pipelineCI.yml`](https://github.com/unb-mds/2025-1-NoFluxoUNB/blob/main/.github/workflows/pipelineCI.yml)

```
on: pull_request + push (main, dev)
```

Cada job mapeia para uma parte da estratégia de testes:

| Job | Papel | Nível / técnica | Comando essencial |
|-----|-------|-----------------|-------------------|
| `qualidade-python` | Análise estática | Formatação (Black) + lint (Flake8) — não é teste funcional | `black --check .` / `flake8 .` |
| `testes-python` | Backend de dados | Unidade/integração (Pytest) | `cd tests-python && pytest` |
| `testes-backend` | Backend TS | Unidade (Jest) | `cd no_fluxo_backend && npm test` |
| `testes-frontend` | Frontend Svelte | Unidade (Vitest) | `cd no_fluxo_frontend_svelte && vitest run` |

Os jobs rodam em paralelo; o PR só fica verde se **todos** passarem.

## Decisões de projeto do pipeline

- **Versões fixadas de Black e Flake8.** O CI roda em Python 3.11 e o Black pode
  formatar de modo diferente entre versões/Python; fixar a versão (`black==25.11.0`,
  `flake8==7.3.0`) garante que "passa na minha máquina" = "passa no CI".
- **Consolidação.** Havia 4 workflows rodando testes sobrepostos (`pipelineCI`,
  `all-tests`, `python-tests`, `typescript-tests`). Foram unificados em um só, para
  evitar duplicação de execução e checks vermelhos confusos.
- **Actions atualizadas para v4/v5.** O GitHub passou a reprovar automaticamente
  workflows que usavam `actions/upload-artifact@v3` (descontinuado) — corrigido aqui e
  no `security-and-quality.yml`.
- **`tesseract-ocr` e `poppler-utils`** são instalados no job Python porque os módulos
  de parsing de PDF/OCR dependem deles.

## Estado dos testes Python

Os imports legados foram remapeados (`coleta_dados.scraping` → `DBA.scraping`,
`coleta_dados.parse_pdf` → `DBA.parse_pdf`) e um [`conftest.py`](https://github.com/unb-mds/2025-1-NoFluxoUNB/blob/main/tests-python/conftest.py)
garante que a raiz do repositório esteja no `sys.path`.

Resultado atual: **13 passam, 1 _skip_, 10 _xfail_**.

Os marcadores são **dívida técnica rastreável** (Fase 2), não testes escondidos:

- **`@unittest.expectedFailure` (xfail)** — o teste continua sendo coletado e executado,
  mas a falha é esperada porque o **módulo de produção divergiu** do que o teste assume.
  Exemplos: `formatar_turma` mudou o formato de saída; `salvar_por_departamento` ganhou
  o argumento `output_dir`; `executar_fluxo_dados_RAGFLOW` ainda usa o caminho legado
  `coleta_dados/dados`. Cada marcador tem um comentário com o motivo. Quando o módulo
  (ou o teste) for corrigido na Fase 2, o caso vira `xpass` e sinaliza a regularização.
- **`@unittest.skip`** — `test_upload_pdf` é um teste de **integração/sistema** que
  exige servidor rodando e um PDF de fixture; será reativado na Fase 3.

### Testes removidos

Foram removidos os testes de módulos que **não existem mais** no repositório (a
funcionalidade de IA migrou para o backend TypeScript, coberta pelo Jest):
`test_app.py`, `test_config.py`, `test_ragflow_agent_client.py`,
`test_visualizaJsonMateriasAssociadas.py` e `test_formatar_para_ragflow.py`.

## Cobertura (Python)

> ⚠️ Limitação conhecida: o `tests-python/pytest.ini` mede `--cov=.`, ou seja, a
> cobertura **dos próprios arquivos de teste**, não dos módulos de produção. O número
> exibido (~74%) por isso não reflete a cobertura real do código. Retargetar o `--cov`
> para os módulos de `DBA/` e elevar a cobertura real é tarefa da **Fase 2**.

## Como rodar localmente

```bash
# Qualidade Python
pip install black==25.11.0 flake8==7.3.0
black --check .
flake8 .

# Testes Python
pip install -r tests-python/requirements.txt pytest pytest-cov pytest-mock
cd tests-python && python -m pytest

# Testes backend (TS)
cd no_fluxo_backend && npm ci && npm test

# Testes frontend (Svelte)
cd no_fluxo_frontend_svelte && npm ci && npx vitest run --passWithNoTests
```

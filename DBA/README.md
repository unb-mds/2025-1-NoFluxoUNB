# DBA — camada de dados (Python)

Coleta, transformação e ingestão dos dados acadêmicos da UnB no Supabase.
É daqui que vêm cursos, matrizes, matérias, pré-requisitos, equivalências e turmas.

## Estrutura

- `database/` — pipeline numerado de ingestão (rodar em ordem):
  `01_insert_cursos_matrizes_materias.py` → `02_insert_pre_requisitos_equivalencias.py`
  → `03_insert_turmas.py` → `04_reconciliar_turmas.py` → `05_insert_calendario_academico.py`.
  Inclui `expressao_parser.py` (parser das expressões lógicas de pré-requisito — o
  módulo Python mais testado do repo). **As regras de negócio do banco (formato de
  `curriculo_completo`, `tipo_natureza`, política de insert/update) estão em
  `database/README.md` — leia antes de mexer.**
- `scraping/` — coleta do SIGAA (`scraping_turmas.py`, `scraping_ementa.py`,
  `scraping_equivalencias.py`, `scraping_calendario_academico.py`). Rodam agendados
  pelos workflows `scrape_*.yml` do GitHub Actions.
- `parse_pdf/` — `pdf_parser_final.py`, parser de histórico em PDF (atenção: existe uma
  cópia legada em `no_fluxo_backend/parse-pdf/`; a versão medida pelos testes é esta).
- `dados/` — datasets de apoio (`cursos-de-graduacao.json`, expressões lógicas).
- `turmas_2026_1/` — saída do scraping de turmas (JSON por departamento).
- `package.json` (`coleta-dados`) — só 2 scripts JS de migração pontual.

## Testes

A suíte fica em `tests-python/` na **raiz do repo** (importa `DBA.*` via conftest):

```bash
cd tests-python && python -m pytest
```

Cobertura medida sobre `expressao_parser` (~93%) e `DBA.parse_pdf.pdf_parser_final`
(~16%), com `--cov-fail-under=45`. Formatação/lint: `black --check .` e `flake8 .`
na raiz (versões fixadas no CI).

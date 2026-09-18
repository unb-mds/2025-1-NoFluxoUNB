# Testes em Python (Pytest e Análise Estática)

Os módulos em Python do NoFluxoUNB englobam o **pipeline de ingestão e scraping de dados (DBA)**, o **serviço de parsing de históricos escolares em PDF** e o **serviço de Agente de IA (MCP Agent)**.

---

## 📂 Organização das Suítes Python

```
2025-1-NoFluxoUNB/
├── DBA/tests/                           # Suíte central de dados e scraping
│   ├── conftest.py                         # Inclusão da raiz no sys.path
│   ├── pytest.ini                          # Configurações do Pytest e cobertura
│   ├── test_expressao_parser.py            # Parser de pré-requisitos lógicos
│   ├── test_scraping_equivalencias.py      # Scraping do SIGAA
│   └── test_upload_pdf.py                  # Integração de upload
├── DBA/parse_pdf/                          # Parser de históricos em PDF (coberto pela suíte)
└── mcp_agent/                              # Agente de IA
    └── test_tool_call_utils.py             # Validação de tool calling
```

---

## 🔍 Detalhamento das Suítes

### 1. `DBA/tests/` (Banco e Scraping)
- **`test_expressao_parser.py`**:
  - Testa a conversão de expressões em texto plano vindas do SIGAA para a árvore lógica em formato JSONB armazenada no Supabase.
  - Cobre:
    - Disciplinas isoladas: `"MAT0025"` $\rightarrow$ `{"operador": null, "condicoes": ["MAT0025"]}`
    - Conjunções (`E`): `"( MAT0025 E MAT0026 )"`
    - Disjunções (`OU`): `"( CCA0105 OU FUP0289 )"`
    - Expressões mistas com parênteses aninhados e tratamento de espaços irregulares.
- **`test_scraping_equivalencias.py`**:
  - Valida a extração de tabelas de equivalência a partir do HTML retornado pelo SIGAA.
  - Testa parsing de equivalências gerais vs. específicas por curso/currículo.
- **`test_upload_pdf.py`**:
  - Teste de integração que envia arquivos multipart/form-data para o endpoint de extração e valida o JSON estruturado resultante.

### 2. `DBA/parse_pdf/` (Parser de Históricos)
- O parser Python `pdf_parser_final.py` é coberto pela própria suíte `DBA/tests/`
  (`test_upload_pdf.py` e a métrica `--cov=DBA.parse_pdf.pdf_parser_final` no
  `pytest.ini`). O antigo serviço `parse-pdf/` do backend foi aposentado na fase 3
  da reorganização — o parse vivo do produto é client-side, no frontend
  (`pdfjs-dist`), validado pelo E2E `upload-historico.exploratorio.spec.ts`.

### 3. `mcp_agent/` (Agente de IA)
- **`test_tool_call_utils.py`**:
  - Testa as funções auxiliares que preparam o catálogo de ferramentas enviado para os modelos da OpenAI, Gemini e Maritaca.
  - Valida serialização de respostas, validação de tipos com Pydantic e captura de falhas em chamadas a APIs externas.

---

## 🧹 Análise Estática de Código

Além dos testes funcionais, o pipeline de qualidade do projeto exige aprovação em duas ferramentas de análise estática:

| Ferramenta | Papel | Comando | Versão Padronizada |
|---|---|---|---|
| **Black** | Formatação determinística de código | `black --check .` | `25.11.0` |
| **Flake8** | Linting, conformidade PEP 8 e detecção de imports não utilizados | `flake8 .` | `7.3.0` |

---

## 🛠️ Como Executar os Testes em Python

Certifique-se de ativar o ambiente virtual (`venv`) antes da execução:

```bash
# Ativar venv no Windows:
.\venv\Scripts\Activate.ps1
# Ou no Linux/macOS:
source venv/bin/activate

# 1. Executar suíte central DBA/tests:
cd DBA/tests
python -m pytest -v

# 2. Executar com cobertura:
python -m pytest --cov=. --cov-report=html --cov-report=term-missing

# 3. Executar testes do MCP Agent:
cd ../../mcp_agent
python -m pytest test_tool_call_utils.py

# 5. Executar linters de qualidade:
cd ..
black --check .
flake8 .
```

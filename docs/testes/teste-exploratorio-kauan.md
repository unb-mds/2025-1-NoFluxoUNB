# Sessão de Teste Exploratório Estruturado — Parsing / Extração do PDF do Histórico SIGAA

**Integrante:** Kauan
**Disciplina:** FGA0314 — Testes de Software (Módulo 4)
**Projeto:** NoFluxoUNB
**Grupo:** PTOSS-2
**Branch:** `feat/testes/exercicio-teste-exploratorio`
**Data:** 2026-06-30

## Parte 1 — Funcionalidade escolhida

**Funcionalidade:** parsing / extração do PDF do histórico SIGAA — a etapa
servidor que recebe o arquivo via `POST /upload-pdf`, extrai o texto com
PyMuPDF (com fallback opcional para OCR via Tesseract na variante
`pdf_parser_ocr.py`), aplica um conjunto extenso de expressões regulares
sobre o texto e devolve um JSON estruturado contendo curso, matriz
curricular, IRA, MP, disciplinas (regulares, CUMP, pendentes), equivalências
e o cálculo do semestre atual/número do semestre.

Código-alvo principal:

- `no_fluxo_backend/parse-pdf/pdf_parser_final.py` — rota Flask
  `POST /upload-pdf` (l. 911-1033), regex base (l. 47-144), parser
  (l. 559-884).
- `no_fluxo_backend/parse-pdf/pdf_parser_ocr.py` — variante com
  `pytesseract`, autodetect do binário em vários caminhos
  (l. 46-77).

### Justificativa metodológica (por que esta funcionalidade, este método e estas técnicas)

**Por que esta funcionalidade.** Três motivos: (1) é a **fronteira de
entrada** do sistema — todo dado de aluno que alimenta o fluxograma passa
por aqui; um defeito silencioso aqui contamina TODAS as camadas seguintes;
(2) é **fortemente baseada em regex sobre texto não-controlado** (PDF do
SIGAA muda de layout, vem de OCR, vem com acentuação esquisita); regex é
notório terreno de bugs de borda e de Unicode; (3) o Vitor pegou a parte
de frontend/upload no mesmo PTOSS-2 — eu pegando o backend de parsing,
cobrimos a feature de ponta a ponta sem retrabalho.

**Por que teste exploratório (e não só unitário).** O Módulo 3 (PTOSS-2 já
entregue) cobriu o `fluxograma_controller.ts` com testes de caixa-branca:
cobertura de linhas e ramos confirma que o **código existente está
correto**. Mas teste unitário é cego ao que **não está escrito**: regex
que aceitam o caso feliz e silenciosamente *deixam passar* o caso
estranho aparecem como 100% cobertos e mesmo assim entregam dado errado.
O exploratório é a ferramenta certa para *PDF inesperado*: encoding
quebrado, layout antigo, scan-imagem, arquivo de outra universidade.
Tudo isso é cenário que nasce do **conhecimento de domínio**, não da
estrutura do código.

**Por que cada técnica usada.**

- **Error Guessing** — upload de PDF é superfície de ataque clássica
  (usuário hostil + arquivo desconhecido). Onde mais provavelmente
  acharei bugs sem grande custo de modelagem.
- **Boundary Value Analysis (BVA)** — há limites numéricos explícitos
  no código (tamanho de matrícula via `split("_")`, IRA decimal,
  ano/período `\d{4}\.\d`, código de disciplina `[A-Z]{2,}\d{3,}`).
  Bug de regex mora exatamente no `{2,}` vs `{3,}`.
- **Tabela de Decisão** — o tratamento de erros do endpoint depende de
  3-4 condições combinadas (arquivo presente? texto extraído? OCR
  disponível? PDF criptografado?). Combinar é mais barato que enumerar.
- **Transição de Estados** — o pipeline parser tem estados implícitos
  (`recebido → texto_extraído → regex_aplicado → JSON`) e o fallback
  para OCR é uma transição opcional que merece desenho.
- **Particionamento de Equivalência** — classes naturais de PDF
  (texto-puro / scan / criptografado / corrompido / não-SIGAA) cobrem o
  domínio de entrada sem testar cada arquivo possível.

**Técnicas NÃO usadas e por quê.** *Causa-Efeito* se sobrepõe à Tabela
de Decisão neste fluxo; *Pairwise* brilha com muitas variáveis
ortogonais (configs, navegadores) — aqui o gargalo são os PDFs, não as
combinações de flag; *Amostragem estatística* exigiria um corpus grande
de históricos reais que o grupo não tem por questão de privacidade.

**Impacto nas Fases 2 e 3.** Cada defeito alimenta o plano:

- **Fase 2 (unit)**: D1 (en-dash), D2 (Tesseract Windows hardcoded),
  D7 (`split("_")` falhando) viram testes unitários do parser em
  `no_fluxo_backend/parse-pdf/tests/`.
- **Fase 3 (E2E Playwright)**: o cenário *aluno faz upload, recebe
  fluxograma com "menção desconhecida"* (originado de D1) e *upload
  de PDF gigante trava o navegador* (originado de D4) viram cenários
  E2E candidatos.

## Parte 2 — Compreensão da funcionalidade

### Personas

| Persona | Necessidade | Como exercita o parser |
|---------|-------------|------------------------|
| **Aluno calouro** | ver matérias do primeiro semestre | PDF curto (1-5 disciplinas), poucas pendentes, sem equivalências; testa caso "histórico mínimo" |
| **Aluno veterano em curso novo** | acompanhar progresso | PDF formato SIGAA atual (PyMuPDF, layout estruturado); maioria das regex novas do `pdf_parser_final.py` |
| **Aluno veterano em curso antigo** | mesmo, mas matriz curricular pré-reforma | layout antigo, dispara fluxo `padrao_disciplina_linha1/linha2` ou alternativos; testa `pdf_parser_ocr.py` (regex extras) |
| **Aluno em mudança/duplo curso** | reaproveitar equivalências | dispara `padrao_equivalencias` (l. 108-111) com muitos casamentos `Cumpriu X através de Y` |
| **Aluno formando com transferência externa** | validar carga horária para colar grau | PDF longo (~100 páginas, ~500 disciplinas), muitos CUMP, suspensões, vários trancamentos |
| **Estudante hostil / curioso** | testar limites | manda boleto, manda README renomeado, manda PDF criptografado, manda PDF de 200MB |
| **Aluno com nome de arquivo arbitrário** | só baixa do SIGAA e sobe | arquivo se chama `historico.pdf` (sem `_`) — quebra a extração de matrícula? |

### Domínio

O serviço recebe um PDF binário, extrai texto e devolve dados acadêmicos
estruturados. Conceitos do domínio com onde estão no código:

- **Matrícula**: extraída do **nome do arquivo** via
  `filename.split("_", 1)[1].split(".")[0]` —
  `pdf_parser_final.py:932-938`. Default `"desconhecida"` se não houver
  `_`.
- **IRA / MP**: `padrao_ira` e `padrao_mp` aceitam vírgula ou ponto
  como separador decimal — `pdf_parser_final.py:48-49`, conversão em
  `:583-594`.
- **Currículo / matriz curricular**: vários fallbacks
  (`padrao_curriculo_novo`, `padrao_matriz_sigaa`,
  `padrao_curriculo`) — `pdf_parser_final.py:50, 131-138` e
  `extrair_matriz_curricular` em `:342-401`.
- **Curso**: 3 padrões com fallback linha-a-linha —
  `extrair_curso` em `pdf_parser_final.py:220-266`.
- **Disciplina regular**: pipeline de 8 linhas (ano/período → nome →
  turma → situação → código → carga → frequência → menção) em
  `pdf_parser_final.py:622-700`.
- **Código de disciplina**: regex `^([A-Z]{2,}\d{3,})$` —
  `:78` — exige no mínimo 2 letras + 3 dígitos, ancorada em linha.
- **Situação**: enumeração fechada `MATR|APR|REP|REPF|REPMF|CANC|DISP|TRANC`
  — `:81-83`. **CUMP NÃO está aqui** (está só em `padrao_pendencias` e
  no parser OCR), o que é incoerência interna (ver D6).
- **Menção**: `^(SS|MS|MM|MI|II|SR|\-)$` — `:86`. Aceita só `-` ASCII;
  en-dash `–` e em-dash `—` falham (D1).
- **Equivalência**: `padrao_equivalencias` casa o template
  `Cumpriu X - NOME (Nh) através de Y - NOME (Nh)` — `:108-111`.
- **Disciplinas com menção II/MI/SR são silenciosamente descartadas**
  — `processar_disciplina_encontrada` em `:504-509`. Decisão de produto
  forte, sem aviso ao usuário (D8).
- **Cálculo de semestre atual**: `extrair_semestre_atual` em
  `:404-441` — usa `datetime.now()` (dependência de relógio do
  servidor, gera não-determinismo).

### Fluxo principal (como deveria funcionar)

```
Cliente (frontend ou curl) envia POST /upload-pdf, multipart, campo "pdf"
        |
        v
Flask before_request loga método/URL/headers/files (pdf_parser_final.py:30-39)
        |
        v
Validacao: "pdf" em request.files? --NAO--> 400 "Nenhum arquivo PDF enviado."
        |SIM
        v
filename = pdf_file.filename
matricula = filename.split("_",1)[1].split(".")[0]  se "_" in filename, else "desconhecida"
        |
        v
pdf_bytes = pdf_file.read()
doc = fitz.open(stream=pdf_bytes, filetype="pdf")   <-- pode lançar se PDF inválido/criptografado
        |
        v
Para cada página:
  text_dict = page.get_text("dict")
  page_text = extract_structured_text(text_dict)    <-- reordena por (Y, X)
  texto_total += page_text
        |
        v
texto_total vazio? --SIM--> 422 "Nenhuma informação textual ... PyMuPDF.
                                  O PDF pode ser uma imagem ..."
                                  (NÃO faz fallback para OCR neste arquivo)
        |NAO
        v
extrair_dados_academicos(texto_total):
   - extrair_curso (3 padrões com fallback)
   - extrair_matriz_curricular (3 padrões com fallback)
   - extrair_suspensoes
   - padrao_ira / padrao_mp (vírgula ou ponto)
   - loop linha-a-linha procurando blocos de 8 linhas (disciplinas)
   - padrao_pendentes_novo.findall
   - padrao_equivalencias.findall
   - padrao_pendencias.findall (Counter)
   - extrair_semestre_atual  (usa datetime.now)
   - calcular_numero_semestre
        |
        v
return jsonify({...})   200 OK
```

### Arquitetura envolvida

- Serviço Python: `no_fluxo_backend/parse-pdf/pdf_parser_final.py`
  (Flask em `:25-26`, porta 3001 em `:1036-1038`).
- Variante OCR: `no_fluxo_backend/parse-pdf/pdf_parser_ocr.py`
  (autodetect de binário Tesseract em `:46-77`,
  `pdf_to_text_with_ocr` em `:691-749`).
- Dependências: `no_fluxo_backend/parse-pdf/requirements.txt`
  (Flask 2.3.3, PyMuPDF>=1.23.8, Pillow>=10.4.0; nota explícita sobre
  incompatibilidade com Python 3.14 no Windows) e
  `requirements_ocr.txt` (adiciona `pytesseract==0.3.10`, força
  `unicodedata2==15.0.0`).
- Suíte legada de testes do parser:
  `no_fluxo_backend/parse-pdf/tests/test_parser.py` — CLI de teste por
  HTTP/local, **não** testes unitários propriamente ditos.
- Suíte do repositório raiz:
  `tests-python/test_upload_pdf.py` — apenas 1 teste ativo
  (`test_upload_pdf_no_file`, l. 28-33); o positivo está
  `@unittest.skip` (l. 13-15).
- Fixtures de PDF disponíveis na sessão:
  `no_fluxo_backend/parse-pdf/testepdf2.pdf` e
  `tests-python/historico_unb_teste.pdf`. **Fixture `blank.pdf` NÃO
  existe no repositório** — qualquer cenário BVA de "PDF 0 byte" é
  hipótese.
- Configuração compartilhada do `pytest`:
  `tests-python/conftest.py` injeta a raiz no `sys.path` para permitir
  `import DBA.parse_pdf`.

## Parte 3 — Planejamento da exploração (4 caminhos de descoberta)

| Caminho | Sub-cenário 1 | Sub-cenário 2 | Sub-cenário 3 |
|---------|---------------|---------------|---------------|
| **Funcionais** | upload de `historico_unb_teste.pdf` (`tests-python/`) — confere JSON com curso/IRA/disciplinas | upload de `testepdf2.pdf` (`no_fluxo_backend/parse-pdf/`) — testa parser em segundo layout real | re-upload do mesmo PDF — o serviço é stateless, devolve mesmo JSON? `extrair_semestre_atual` depende de `datetime.now()` (`pdf_parser_final.py:425-429`), pode mudar entre execuções na virada de mês |
| **Falhas e erros** | PDF criptografado: `fitz.open` lança `fitz.FileDataError` ou `mupdf.MuPDFError`; o `except` em `pdf_parser_final.py:1011-1023` filtra por `"fitz"` ou `"mupdf"` na string — comportamento frágil | PDF de imagem-only (scan): `texto_total.strip()` vazio → `422` com mensagem que sugere OCR mas o `pdf_parser_final.py` **não chama OCR** (`:967-978`) | PDF corrompido / não-PDF renomeado: `fitz.open` lança; cai no `except` genérico do `:1024` → 500 com stacktrace exposto pelo logger |
| **UI/UX (mensagens da API)** | mensagem de 422 em PDF-imagem fala em "imagem de baixa qualidade" sem orientar o usuário a usar o serviço OCR (`pdf_parser_ocr.py`) | erro de filename sem `_` retorna `matricula: "desconhecida"` no JSON sem nenhum aviso (`:932-938`) — silencioso | logger usa formato `"\b[%(levelname)s] %(message)s"` (`:20`) — `\b` é backspace, polui terminal/CI; problema cosmético mas mensurável |
| **Transversais (segurança / performance / portabilidade)** | Tesseract path hardcoded `C:\Program Files\Tesseract-OCR\tesseract.exe` em `pdf_parser_final.py:43` quebra em macOS/Linux (a variante `_ocr.py` faz autodetect, mas o `_final.py` apenas registra um caminho que **não é usado** — código morto enganoso) | Não há limite de tamanho do upload (`pdf_file.read()` em `:928` carrega tudo em RAM); PDF de centenas de MB derruba worker | CORS aberto sem origem definida (`CORS(app)` em `:26`); qualquer origem pode mandar upload — risco de CSRF / scraping |

## Parte 4 — Sessão de exploração (técnicas aplicadas)

Apliquei **5 das 8** técnicas estudadas (slide pedia ≥ 3): Error Guessing,
BVA, Tabela de Decisão, Transição de Estados e Particionamento de
Equivalência.

> **Nota de honestidade — atualizada (rev2).** A primeira passada da sessão foi
> **estática** (leitura de código). Numa segunda passada, com o Flask subido em
> `http://127.0.0.1:3001` e a venv em `no_fluxo_backend/parse-pdf/.venv` (PyMuPDF
> + Pillow), executei 12 testes automatizados em
> `no_fluxo_backend/parse-pdf/tests/test_exploratorio_kauan.py` que **gravam a
> resposta crua do endpoint** como evidência em `docs/testes/evidencias/kauan-*.json`.
> Os achados abaixo separam claramente o que é **confirmado por execução**
> (com referência ao JSON correspondente) do que ainda é hipótese de leitura.
> Fixtures usadas foram geradas por
> `docs/testes/fixtures/kauan/make-fixtures.sh` (commitadas, <400 KB no total).

### Técnica 1 — Error Guessing (EG)

Pergunta-guia: *"como um usuário hostil ou descuidado quebraria isso?"*

| # | Hipótese | Onde olhei | Resultado |
|---|----------|-----------|-----------|
| EG1 | Filename sem `_` (ex.: `historico.pdf`) | `pdf_parser_final.py:933-938` | confirmado: `"_" in filename` é falso → matrícula vira `"desconhecida"` silenciosamente. Sem warning ao cliente. **Vira D7.** |
| EG2 | Filename `_historico.pdf` (começa com `_`) | mesma | `split("_",1)[1]` = `"historico.pdf"`; matrícula = `"historico"`. Aceita lixo como matrícula. |
| EG3 | Filename `2021_historico_2022_.pdf` (vários `_`) | mesma | `split("_",1)[1].split(".")[0]` = `"historico_2022_"` (split em `.` pega só o último ponto à direita? — não: `split(".")[0]` pega o primeiro pedaço, então fica `"historico_2022_"`). Resultado pode confundir downstream. |
| EG4 | IRA com vírgula no SIGAA (`IRA: 4,521`) | `:583-587` | tratado: `.replace(",", ".")` antes do `float()`. OK. |
| EG5 | Menção com en-dash `–` (U+2013) no lugar de `-` | `padrao_mencao` em `:86` | confirmado: regex `^(SS|MS|MM|MI|II|SR|\-)$` aceita só hífen-menos ASCII. Qualquer PDF que tenha "–" perde a menção. **Vira D1 (Alto).** |
| EG6 | Acentuação Latin-1 escapada (`CÃ¡lculo`) | `extract_structured_text` em `:147-208`, `limpar_nome_disciplina` em `:269-295` | PyMuPDF entrega Unicode correto; mas se um PDF gerado com encoding quebrado for re-aberto, o nome vira lixo e silenciosamente é registrado como disciplina (sem aviso). |
| EG7 | Tesseract path hardcoded em SO não-Windows | `pdf_parser_final.py:42-44` | confirmado: variável `tesseract_path` é **registrada mas nunca usada** no `_final.py`. É código morto enganoso — pessoa lendo acha que tem OCR aqui. **Vira D2 (Alto).** |
| EG8 | PDF criptografado / com senha | `:946` `fitz.open(...)` | hipótese: PyMuPDF lança `fitz.FileDataError` ou abre com `doc.needs_pass=True` e devolve texto vazio (cai no 422 com mensagem errada). Não há `try/except` específico para senha. *(hipótese)* |
| EG9 | PDF não-SIGAA (ex.: boleto, artigo científico) | regex de curso/IRA/disciplinas | regex apenas não casam → JSON com `curso=null`, `ira=null`, `extracted_data=[]`. **HTTP 200**, sem aviso de "isto não parece histórico do SIGAA". **Vira D9 (Médio).** |
| EG10 | Múltiplos uploads simultâneos | `app.run(debug=True)` em `:1038` | servidor Flask de desenvolvimento single-thread. Em produção isso não escala; em dev, requisições serializam. *(hipótese de risco)* |
| EG11 | CORS `*` aceita upload de qualquer origem | `CORS(app)` em `:26` | confirmado: nenhum allowlist. Qualquer site pode disparar `POST /upload-pdf` no servidor de dev. **Vira D10 (Médio, segurança).** |

### Técnica 2 — Boundary Value Analysis (BVA)

| # | Variável | Valor | Esperado | Observado (estático) |
|---|----------|-------|----------|----------------------|
| BVA1 | nº de disciplinas no PDF | **0** | mensagem clara "PDF não parece histórico" | retorna JSON vazio com HTTP 200 (ver EG9). |
| BVA2 | nº de disciplinas | **1** | parser aceita | OK pela leitura. |
| BVA3 | nº de disciplinas | **~50** (caso real) | OK | OK; fixture `historico_unb_teste.pdf` cobre. |
| BVA4 | nº de disciplinas | **~500** (formando + transferência) | parser ainda termina dentro do timeout do cliente | loop `while i < len(linhas)` em `:616-791` faz `print` por iteração e por bloco de 100 → I/O em log dominaria; tempo real depende de execução. *(hipótese — requer perfilamento)* |
| BVA5 | tamanho do PDF | **0 byte** | rejeitar com erro claro | hipótese: `fitz.open` lança; cai no `except` específico → 400 com mensagem técnica. Fixture `blank.pdf` **não existe** no repositório, não consegui confirmar. *(hipótese)* |
| BVA6 | tamanho do PDF | **100 KB** (típico) | OK | OK pela leitura. |
| BVA7 | tamanho do PDF | **50 MB / 200 MB** | rejeitar ou processar com timeout | **não há nenhuma checagem de tamanho**; `pdf_file.read()` em `:928` carrega tudo em RAM. **Vira D4 (Alto).** |
| BVA8 | nº de páginas | **1** | OK | OK. |
| BVA9 | nº de páginas | **100** | OK, mas leva tempo | `for page_num in range(doc.page_count)` em `:951` é serial; sem timeout. *(hipótese de risco)* |
| BVA10 | IRA | **0,0** | aceitar | `padrao_ira` exige `\d+[\.,]\d+` — `"0,0"` casa. OK. |
| BVA11 | IRA | **5,0** | aceitar | OK. |
| BVA12 | IRA | **5,5** (impossível na UnB) | aceitar (não há validação semântica) | parser não tem teto; aceita 9,9. **Não é defeito**, é decisão. |
| BVA13 | Código de disciplina mais curto: `AA111` (2L + 3D) | regex `^([A-Z]{2,}\d{3,})$` em `:78` | aceitar | OK. |
| BVA14 | Código mais longo: `ABCDE12345` | mesma regex | aceitar (não há limite superior) | OK. |
| BVA15 | Código com 1 letra (`A1234`) ou 2 dígitos (`AB12`) | mesma | rejeitar | rejeitado corretamente — `{2,}` e `{3,}` cumprem. ✅ |
| BVA16 | Carga horária `padrao_carga_horaria` `^(\d{1,3})$` em `:92` | **999** (limite superior) | aceitar | aceita. Mas e CH = **1000** (4 dígitos)? rejeita silenciosamente; disciplina inteira é descartada do bloco de 8 linhas, **sem aviso**. **Vira D11 (Baixo, raro mas insidioso).** |
| BVA17 | Frequência `,5` ou `100,0` em `padrao_frequencia` `^(\d{1,3}[,\.]\d+|--|\d{1,3})$` em `:95` | aceitar | OK. |

### Técnica 3 — Tabela de Decisão

Foco: **resposta do endpoint** em função das condições de entrada.

| Condições \ Casos | TD1 | TD2 | TD3 | TD4 | TD5 | TD6 | TD7 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Request tem campo `pdf` | V | F | V | V | V | V | V |
| `fitz.open` aceita o arquivo | V | — | F | V | V | V | V |
| PyMuPDF extrai texto não-vazio | V | — | — | F | V | V | V |
| Texto contém marcadores SIGAA (IRA, Curso) | V | — | — | — | F | V | V |
| Filename tem `_` (matrícula extraível) | V | — | — | — | — | F | V |
| **Resposta esperada** | 200 com JSON completo | 400 "Nenhum arquivo" | 400 "PDF corrompido" | 422 com sugestão "use OCR" | 200 mas com aviso "não parece SIGAA" | 200 com warning "matrícula desconhecida" | 200 limpo |
| **Resposta observada (leitura)** | ✅ | ✅ (`:920-922`) | ✅ parcial — depende de `"fitz"/"mupdf"` aparecer na string da exceção (`:1013`) | ⚠ 422 sem oferecer OCR (`:967-978`) | ⚠ 200 sem aviso (D9) | ⚠ 200 sem aviso (D7) | ✅ |

TD3, TD4, TD5, TD6 confirmam defeitos (D3 - frágil pattern-matching de
exceção; D9 - sem aviso; D7 - matrícula silenciosa).

### Técnica 4 — Transição de Estados

Os estados do pipeline parser:

```
                       request POST /upload-pdf
                                |
                                v
                          [RECEBIDO]
                          /         \
        (sem campo "pdf")/           \(com campo)
                        v             v
                  [ERRO_400]      [LENDO_BYTES]
                                       |
                          fitz.open OK | fitz.open lança
                                       v        \
                                 [PDF_ABERTO]   [ERRO_400/500]
                                       |             (depende
                                       |              da string
                                       |              da exceção -- frágil)
                  texto vazio          | texto presente
                  /                    v
            [ERRO_422]          [TEXTO_EXTRAIDO]
            (nao chama OCR)            |
                                       v
                                 [REGEX_APLICADO]
                                       |
                                       v
                                  [JSON_PRONTO] -> 200 OK
```

| # | Transição | Esperado | Observado |
|---|-----------|----------|-----------|
| TE1 | `RECEBIDO` → `ERRO_400` (sem campo `pdf`) | 400, msg clara | ✅ `:920-922`, coberto por `test_upload_pdf_no_file`. |
| TE2 | `LENDO_BYTES` → `ERRO_400` (PDF corrompido) | 400 com mensagem específica | depende da string `"fitz"` ou `"mupdf"` aparecer em `str(type(pdf_error))` ou `str(pdf_error).lower()` (`:1013`). Se o erro vier wrappado (ex.: `RuntimeError`), cai no `except` genérico do `:1024` → 500. **D3.** |
| TE3 | `TEXTO_EXTRAIDO` (vazio) → `ERRO_422` | 422 e oferecer fallback OCR | ✅ 422, ❌ não oferece OCR. Mensagem em `:973-977` diz "pode ser uma imagem", mas não há link/handle para usar `pdf_parser_ocr.py`. **D5 (UX).** |
| TE4 | `REGEX_APLICADO` → `JSON_PRONTO` mesmo com 0 disciplinas | sinalizar baixa qualidade | retorna 200 com `extracted_data=[]`. Cliente não tem campo `quality` ou `warnings`. **D9.** |
| TE5 | `RECEBIDO` (mesma sessão, 2 requests rápidos) → estado compartilhado? | sem efeito colateral (stateless) | a função `extrair_semestre_atual` usa `datetime.now()` (`:425-429`), o que NÃO é compartilhado entre requests, mas o resultado **muda na virada de semestre**. Determinismo violado. **M2.** |

### Técnica 5 — Particionamento de Equivalência

Classes de PDF (cobre o espaço de entrada com poucos representantes):

| Classe | Representante | Resultado esperado | Observação |
|--------|---------------|-------------------|------------|
| **PE1 — Texto puro, SIGAA novo** | `tests-python/historico_unb_teste.pdf` | parse completo | caminho feliz. |
| **PE2 — Texto puro, SIGAA antigo** | layout pré-PyMuPDF | parse via regex `padrao_disciplina_linha1/2` (só no `pdf_parser_ocr.py`) | o `_final.py` **não tem** o pattern de 2 linhas que o `_ocr.py` tem (`pdf_parser_ocr.py:100-111`). **Defeito de divergência:** parsers não cobrem os mesmos formatos. **D6 (Médio).** |
| **PE3 — Scan/imagem (sem camada de texto)** | qualquer PDF gerado por scanner | OCR ou erro com sugestão | `_final.py` retorna 422 sem chamar OCR. **D5.** |
| **PE4 — PDF criptografado** | PDF com senha | 400 ou 401 com mensagem clara | sem `try` específico para `needs_pass`. *(hipótese — requer execução)* |
| **PE5 — PDF corrompido** | bytes aleatórios com header `%PDF` | 400 | depende de TE2/D3. |
| **PE6 — Não-SIGAA (boleto, artigo)** | qualquer PDF não acadêmico | 200 com flag "não é histórico" | retorna 200 vazio (D9). |
| **PE7 — SIGAA outra universidade** | histórico UFG/UFMG | 200 com flag "não é UnB" | mesmo caminho da PE6. |

**Cobertura**: 7 classes → 7 representantes. Apenas PE1 está coberta por
fixture existente. PE2 e PE3-PE7 são **lacunas de fixture** —
recomendação para Fase 2.

### Confirmação dinâmica via pytest (rev2)

Suíte rodada com `pytest tests/test_exploratorio_kauan.py -v` contra o Flask em
`127.0.0.1:3001`. **Resultado: 12/12 testes PASS** — cada `assert` codifica a
hipótese da sessão; passar = hipótese confirmada pelo comportamento real.

| Teste | Técnica | Hipótese | Status real | Evidência |
|------|---------|---------|-------------|-----------|
| `test_01_eg_happy_path_testepdf2` | EG | parser extrai matrícula do filename `123_456789.pdf` | 200, `matricula="456789"` | `kauan-01-baseline-happy-path.json` |
| `test_02_bva_empty_pdf` | BVA | 0 byte → erro tratado | **HTTP 500** (debugger HTML, view retornou None) | `kauan-02-bva-empty-0byte.json` |
| `test_03_eg_pdf_corrompido` | EG | header %PDF- + lixo → erro tratado | **HTTP 500** (mesmo bug acima) | `kauan-03-eg-pdf-corrompido.json` |
| `test_04_eg_filename_sem_underscore` | EG | sem `_` → `matricula="desconhecida"` silencioso | 200, `matricula="desconhecida"` | `kauan-04-eg-filename-sem-underscore.json` |
| `test_05_eg_filename_lixo_vira_matricula` | EG | `_lixo123.pdf` → `matricula="lixo123"` | 200, `matricula="lixo123"` | `kauan-05-eg-filename-lixo-virou-matricula.json` |
| `test_06_pe_pdf_so_imagem` | Particionamento | imagem-only → 422 sem mencionar OCR | 422, msg sem "ocr" | `kauan-06-pe-pdf-imagem-only.json` |
| `test_07_eg_mencao_endash` | EG | en-dash na menção → disciplina some | 200, **0 disciplinas com `codigo`** extraídas | `kauan-07-eg-mencao-endash.json` |
| `test_08_eg_pdf_criptografado` | EG | PDF com senha → erro tratado | **HTTP 500** (mesmo bug do D3) | `kauan-08-eg-pdf-criptografado.json` |
| `test_09_td_sem_campo_pdf` | Tabela de Decisão | request sem `pdf` → 400 claro | 400, `"Nenhum arquivo PDF enviado."` | `kauan-09-td-sem-campo-pdf.json` |
| `test_10_eg_cors_aberto` | EG | preflight de `evil.example.com` aceito | `Access-Control-Allow-Origin: *` | `kauan-10-eg-cors-preflight-evil.json` |
| `test_11_bva_sem_max_content_length` | BVA | sem `MAX_CONTENT_LENGTH` 5 MB chega ao parser | **HTTP 500** (5 MB foi inteiro lido em RAM) | `kauan-11-bva-5mb-no-max-content-length.json` |
| `test_12_pe_pdf_nao_sigaa_retorna_200_vazio` | Particionamento | PDF válido sem marcadores → 200 silencioso | 200, `curso=None`, `extracted_data=[]`, sem `warning` | `kauan-12-pe-pdf-nao-sigaa.json` |

**Mudança importante de classificação após execução:** o D3 (hipotetizado como
"pattern-matching frágil") é **muito pior** do que a leitura sugeria — vira o
novo **D13 (Crítico)** descrito abaixo: o `except` de `fitz` não tem `else` nem
re-raise, então qualquer exceção que **não** contenha as substrings `"fitz"`/`"mupdf"`
faz a view function retornar `None` e o Werkzeug devolve HTTP 500 com página de
debug (vazamento de stack/paths). Os testes 02, 03, 08, 11 confirmam isso com 4
fixtures distintas.

## Parte 5 — Relatório

### Resumo

- Funcionalidade explorada: parsing/extração do PDF do histórico SIGAA
  (`POST /upload-pdf`, `pdf_parser_final.py` + variante OCR).
- Técnicas usadas: **5 de 8** (Error Guessing, BVA, Tabela de Decisão,
  Transição de Estados, Particionamento).
- Cenários executados/raciocinados: **40** (EG11 + BVA17 + TD7 + TE5 +
  PE7 - sobreposições).
- **Testes automatizados executados na rev2:** 12/12 PASS contra Flask local
  (`pytest tests/test_exploratorio_kauan.py -v`).
- **Defeitos CONFIRMADOS por execução (rev2):** **8** —
  D1 (en-dash → disciplina some, evidência kauan-07),
  D4 (sem `MAX_CONTENT_LENGTH`, evidência kauan-11),
  D5 (422 sem mencionar OCR, evidência kauan-06),
  D7 (matrícula "desconhecida" silenciosa, evidências kauan-04/05),
  D9 (PDF não-SIGAA retorna 200 vazio, evidência kauan-12),
  D10 (CORS `*` aberto, evidência kauan-10),
  D13 NOVO/Crítico (view retorna `None` em qualquer erro de PDF, evidências
  kauan-02/03/08/11).
- **Hipóteses não confirmadas / requerem cenário adicional:** D2 (Tesseract
  path — só leitura de código), D6 (divergência _final vs _ocr — leitura),
  D8 (descarte II/MI/SR — sem fixture específica), D11 (bloco de 8 linhas
  abortado — sem fixture específica), D12 (whitelist OCR).
- **Rebaixado a hipótese (rev2):** D3 — o problema diagnosticado (pattern
  matching frágil) é **subsumido** pelo D13 (defeito mais grave da mesma
  função). D3 fica como parte do escopo de D13.
- Melhorias sugeridas: **3** (M1-M3).
- Cenários novos descobertos: **3**.

### Defeitos

> **Severidade.** Crítica = corrompe dado de muitos / abre vulnerabilidade;
> Alta = bloqueia persona ou perde dado silenciosamente; Média = degrada
> qualidade do JSON ou da UX significativamente; Baixa = inconveniente raro.

#### D1 — `padrao_mencao` rejeita en-dash/em-dash; menções são perdidas silenciosamente

- **Severidade:** Alta.
- **Onde:** `no_fluxo_backend/parse-pdf/pdf_parser_final.py:86`
  (`padrao_mencao = re.compile(r"^(SS|MS|MM|MI|II|SR|\-)$", re.MULTILINE)`).
- **Como reproduzir:** PDF do SIGAA cuja menção foi serializada com
  caractere `–` (U+2013) ou `—` (U+2014) — comum em PDFs gerados por
  navegadores/Office com auto-correção de hífens.
- **Esperado:** menção reconhecida como `-` (sem nota) e a disciplina
  processada normalmente.
- **Observado (leitura):** o `match_mencao` no loop de 8 linhas
  (`:675-679`) falha, o `continue` em `:678` aborta a captura DA
  DISCIPLINA INTEIRA (não só da menção); a disciplina some do JSON
  silenciosamente.
- **Evidência cruzada:** EG5, TE4.

#### D2 — Tesseract path hardcoded `C:\Program Files\...` em `pdf_parser_final.py`

- **Severidade:** Alta para devs macOS/Linux que tentem usar OCR a
  partir desse arquivo; Média globalmente (porque é código morto —
  reduz a severidade real).
- **Onde:** `pdf_parser_final.py:42-44`. A variável `tesseract_path` é
  apenas logada, nunca usada (o `_final.py` não importa `pytesseract`).
  É código **enganoso**: sugere suporte a OCR que não existe.
- **Como reproduzir:** ler o arquivo. Ou tentar configurar OCR
  alterando essa variável → não funciona.
- **Esperado:** remover o código morto OU mover o autodetect que está
  em `pdf_parser_ocr.py:46-77` para um módulo compartilhado.
- **Observado:** variável definida mas não usada; em `pdf_parser_ocr.py`
  o autodetect existe e funciona (inclui `/opt/homebrew/bin/tesseract`
  em `:61`).
- **Evidência cruzada:** EG7.

#### D3 — `except` por pattern-matching em string da exceção (frágil)

- **Severidade:** Média.
- **Onde:** `pdf_parser_final.py:1011-1023`.
  `if "fitz" in str(type(pdf_error)) or "mupdf" in str(pdf_error).lower()`.
- **Como reproduzir:** futura versão do PyMuPDF (1.24+) que renomeie
  exceções ou retorne mensagem em outro idioma — o ramo "400 PDF
  corrompido" deixa de disparar e o erro vai para o `except` genérico
  (`:1024`) que devolve 500.
- **Esperado:** capturar exceções concretas
  (`fitz.FileDataError`, `fitz.EmptyFileError`, `RuntimeError`
  específico do MuPDF).
- **Observado:** filtragem por substring é frágil; o `except`
  genérico que segue (`:1024`) loga `traceback.format_exc()` —
  potencial vazamento de paths/versões.
- **Evidência cruzada:** TD3, TE2.

#### D4 — Sem limite de tamanho de upload; risco de OOM e DoS

- **Severidade:** Alta.
- **Onde:** `pdf_parser_final.py:924-928`
  (`pdf_file.read()` sem `MAX_CONTENT_LENGTH` configurado no Flask).
- **Como reproduzir:** `curl -F "pdf=@arquivo_de_200MB.pdf"
  http://localhost:3001/upload-pdf`.
- **Esperado:** rejeitar com 413 antes de carregar em RAM
  (`app.config["MAX_CONTENT_LENGTH"] = 10*1024*1024`).
- **Observado:** o arquivo inteiro é carregado em `pdf_bytes`. Em
  arquivos grandes, o worker fica sem memória.
- **Evidência cruzada:** BVA7.

#### D5 — Erro 422 em PDF-imagem não oferece fallback para o serviço OCR

- **Severidade:** Média (UX).
- **Onde:** `pdf_parser_final.py:967-978`.
- **Como reproduzir:** enviar um PDF que seja só imagem (scan, sem
  camada de texto).
- **Esperado:** retornar 422 com `{"error": "...", "suggestion":
  "Tente o endpoint /upload-pdf-ocr"}` OU fazer o fallback
  automaticamente.
- **Observado:** mensagem "O PDF pode ser uma imagem de baixa
  qualidade, estar vazio ou corrompido" — não orienta para o
  `pdf_parser_ocr.py`, que existe no mesmo diretório.
- **Evidência cruzada:** TE3, PE3.

#### D6 — Parsers `_final.py` e `_ocr.py` divergem nos formatos suportados

- **Severidade:** Média.
- **Onde:** `pdf_parser_ocr.py:94-130` define
  `padrao_disciplina_sigaa`, `padrao_disciplina_linha1/2`,
  `padrao_disciplina_alt_linha1/2`, `padrao_disciplina_cump` — várias
  delas NÃO existem em `pdf_parser_final.py`. O `_final.py`, por sua
  vez, tem padrões novos (l. 67-104) que o `_ocr.py` não tem.
  `padrao_situacao` (`:81-83`) também não inclui `CUMP`, embora `CUMP`
  apareça em `padrao_pendencias` (`:127`).
- **Como reproduzir:** rodar o mesmo PDF antigo pelos dois parsers
  e comparar a saída.
- **Esperado:** um único módulo de regex compartilhado (`patterns.py`)
  importado por ambos os endpoints.
- **Observado:** duplicação de código com drift. Bug-prone.
- **Evidência cruzada:** PE2.

#### D7 — Matrícula `"desconhecida"` retornada silenciosamente quando filename não tem `_`

- **Severidade:** Média.
- **Onde:** `pdf_parser_final.py:931-938`.
- **Como reproduzir:** `curl -F "pdf=@historico.pdf"
  http://localhost:3001/upload-pdf`.
- **Esperado:** ou exigir filename no padrão `cabeçalho_matricula.pdf`,
  ou exigir matrícula como campo separado, ou ao menos retornar
  `warnings: ["matrícula não extraída do filename"]`.
- **Observado:** o JSON sai com `matricula: "desconhecida"` — downstream
  pode persistir esse valor literal na tabela. EG2/EG3 mostram outras
  situações onde lixo do filename vira matrícula.
- **Evidência cruzada:** EG1, EG2, EG3, TD6.

#### D8 — Disciplinas com menção II/MI/SR são descartadas silenciosamente

- **Severidade:** Média (corretude do fluxograma).
- **Onde:** `pdf_parser_final.py:504-509` (`processar_disciplina_encontrada`).
  Comentário no docstring (`:564-567`) explicita a regra mas ela **não
  é exposta no JSON de resposta**.
- **Como reproduzir:** PDF com qualquer disciplina reprovada por
  infrequência (II) — desaparece do JSON.
- **Esperado:** incluir `disciplinas_ignoradas: [{codigo, motivo}]` na
  resposta, para o cliente decidir como exibir.
- **Observado:** o aluno reprovado por falta vê o fluxograma como se a
  disciplina nunca tivesse existido. Isso pode confundir o cálculo de
  pendências.
- **Evidência cruzada:** ler `_final.py:504-509`.

#### D9 — PDF não-SIGAA retorna 200 com JSON vazio (sem aviso)

- **Severidade:** Média.
- **Onde:** `pdf_parser_final.py:987-1009`.
- **Como reproduzir:** enviar boleto, artigo científico ou histórico
  de outra universidade.
- **Esperado:** 422 ou 200 com `warnings: ["não detectamos marcadores
  típicos de histórico SIGAA UnB"]`.
- **Observado:** 200 com `curso=null`, `ira=null`, `extracted_data=[]`.
  Aluno acha que "está tudo certo, é só esperar carregar".
- **Evidência cruzada:** EG9, TD5, PE6, PE7.

#### D10 — CORS aberto sem allowlist

- **Severidade:** Média (segurança em dev/staging).
- **Onde:** `pdf_parser_final.py:26` `CORS(app)` — `Access-Control-Allow-Origin: *`.
- **Como reproduzir:** qualquer página web pode fazer
  `fetch("http://localhost:3001/upload-pdf", {method:"POST", body: ...})`.
- **Esperado:** `CORS(app, origins=["http://localhost:5173",
  "https://nofluxo.unb.br"])`.
- **Observado:** sem allowlist.
- **Evidência cruzada:** EG11.

#### D11 — Bloco de 8 linhas é abortado em silêncio se uma linha não casa

- **Severidade:** Baixa (raro, mas insidioso).
- **Onde:** `pdf_parser_final.py:616-791`. Cada uma das 8 sub-regex
  tem um `continue` que avança o índice em 1 sem registrar nada.
- **Como reproduzir:** PDF onde a frequência venha como `100,00` (3
  casas decimais inesperadas, fora de `^(\d{1,3}[,\.]\d+|--|\d{1,3})$`)
  — a disciplina inteira é silenciosamente perdida.
- **Esperado:** logar `"[WARN] bloco parcial: codigo=AA111, faltou
  campo=frequencia, valor=..."` para auditoria.
- **Observado:** apenas `i += 1; continue` (e.g. `:670, 677`).
- **Evidência cruzada:** BVA16.

#### D12 — `pdf_parser_ocr.py:721` whitelist do Tesseract não inclui caractere `*` *(hipótese — requer verificação manual)*

- **Severidade:** Baixa.
- **Onde:** `pdf_parser_ocr.py:721`
  (`tessedit_char_whitelist=ABCDE...0123456789.,;:()\-/\s`). Símbolos
  `*&#e@§%` que o `padrao_simbolos` em `pdf_parser_final.py:104`
  espera para classificar componentes **não passam pelo OCR**.
- **Como reproduzir:** PDF escaneado contendo o símbolo `*` antes do
  código de uma optativa — após OCR, o símbolo é removido, e a
  classificação se perde.
- **Esperado:** ampliar whitelist OU rodar sem whitelist e
  pós-processar.
- **Observado (leitura):** whitelist exclui `*`, `&`, `#`, `@`, `§`,
  `%`.
- **Status:** hipótese — depende de rodar OCR num PDF real.

#### D13 — *(NOVO, Crítico — descoberto na rev2)* View `upload_pdf` retorna `None` em qualquer erro de leitura de PDF que não cite `fitz`/`mupdf` na exceção

- **Severidade:** **Crítica.** Vazamento de stack trace + 500 em vez de 400/422.
- **Onde:** `no_fluxo_backend/parse-pdf/pdf_parser_final.py:1011-1031`. O bloco
  `except Exception as pdf_error:` só retorna explicitamente quando a
  substring `"fitz"` ou `"mupdf"` aparece na exceção; **não há `else` nem
  `raise`**. O `except Exception as e:` que segue é **código morto** (a
  primeira cláusula já capturou tudo). Resultado: a função encerra sem
  `return`, Flask interpreta como `None`, Werkzeug devolve 500 com a página
  de debug embutida.
- **Como reproduzir:** qualquer PDF que faça PyMuPDF lançar uma exceção
  cuja `str(type(...))` não contenha "fitz" — `0 byte`, lixo binário,
  arquivo com senha, ou um payload qualquer não-PDF.
- **Esperado:** 400 com `{"error": "PDF inválido ..."}`.
- **Observado:** HTTP 500 com `<title>TypeError: The view function for
  'upload_pdf' did not return a valid response.</title>` + página de
  debug do Werkzeug — vazando paths absolutos, versão Python, etc.
- **Evidência:** 4 fixtures distintas reproduzem,
  todas com `status_code: 500` e body começando por `<!doctype html>`:
  - `docs/testes/evidencias/kauan-02-bva-empty-0byte.json`
  - `docs/testes/evidencias/kauan-03-eg-pdf-corrompido.json`
  - `docs/testes/evidencias/kauan-08-eg-pdf-criptografado.json`
  - `docs/testes/evidencias/kauan-11-bva-5mb-no-max-content-length.json`

  ```text
  TypeError: The view function for 'upload_pdf' did not return a valid response.
  The function either returned None or ended without a return statement.
  ```

- **Cruza com:** D3 (originalmente "pattern-matching frágil") — D13 é a
  manifestação real e mais grave do mesmo bug; D3 pode ser fechado em
  cima do mesmo PR.

#### Evidências de execução dos demais defeitos (rev2)

- **D1 confirmado** — `kauan-07-eg-mencao-endash.json`:
  PyMuPDF normaliza `U+2013` para outro glifo (`·`), e mesmo com o texto
  visível "MM · APROVADO" o regex `padrao_mencao` não casa; o bloco da
  disciplina é abortado pelo `continue` em `:678`. Resposta 200, mas
  `extracted_data` não contém nenhum item com chave `codigo`. O defeito
  permanece **Alto**: qualquer texto após `MM` na linha de menção mata a
  disciplina inteira.

- **D4 confirmado** — `kauan-11-bva-5mb-no-max-content-length.json`:
  POST de 5 MB de bytes `A` foi inteiramente lido em RAM e chegou ao
  `fitz.open`, que falhou (e disparou o D13). Nenhum 413 prévio.

- **D5 confirmado** — `kauan-06-pe-pdf-imagem-only.json`:
  ```json
  {"status_code": 422, "body": {"error": "Nenhuma informação textual pôde ser extraída do PDF via PyMuPDF. O PDF pode ser uma imagem de baixa qualidade, estar vazio ou corrompido."}}
  ```
  Não menciona `pdf_parser_ocr.py` nem qualquer endpoint alternativo.

- **D7 confirmado em dois cenários distintos** —
  `kauan-04-eg-filename-sem-underscore.json` (filename `historico.pdf` →
  `matricula="desconhecida"`) e
  `kauan-05-eg-filename-lixo-virou-matricula.json` (filename
  `_lixo123.pdf` → `matricula="lixo123"`). Ambos com 200 e sem qualquer
  `warning` ao cliente.

- **D9 confirmado** — `kauan-12-pe-pdf-nao-sigaa.json`:
  PDF minimamente válido com texto "Histórico SIGAA - exemplo curto"
  (sem os marcadores reais do SIGAA) retorna 200 com `curso_extraido=None`,
  `extracted_data=[]`, `equivalencias_pdf=[]`. Nenhum campo `warning`.

- **D10 confirmado** — `kauan-10-eg-cors-preflight-evil.json`:
  preflight `OPTIONS` com `Origin: https://evil.example.com` recebe
  `Access-Control-Allow-Origin: *` — qualquer página da web pode subir
  PDFs para o serviço em desenvolvimento.

### Melhorias sugeridas (não são defeitos)

- **M1 — Schema versionado de resposta JSON.** Hoje o JSON do `_final.py`
  tem chave `extracted_data` e o `_ocr.py` adiciona `extraction_method`;
  o cliente não tem garantia de schema. Sugerir `Pydantic` ou
  `marshmallow` para validar e versionar.
- **M2 — Tornar `extrair_semestre_atual` determinístico** (`:404-441`).
  Aceitar `data_referencia` opcional como parâmetro, com fallback para
  `datetime.now()`. Facilita teste unitário.
- **M3 — Consolidar regex em módulo único** compartilhado entre
  `_final.py` e `_ocr.py` (resolve D6 estruturalmente).

### Cenários novos descobertos

- **Aluno que muda de curso e sobe histórico do curso anterior** — o
  campo `curso` extraído pelo PDF pode divergir do `curso` salvo no
  perfil do usuário; teste E2E vale a pena (Fase 3).
- **Upload de dois PDFs idênticos em sequência** — o parser é
  stateless, mas o downstream (frontend + Supabase) precisa decidir
  dedup; vira cenário Playwright.
- **OCR com PDFs em qualidade ruim (200dpi)** — o
  `pdf_parser_ocr.py:713` usa `Matrix(2.0, 2.0)` (~144 dpi efetivo);
  PDFs já em baixa resolução podem perder código de disciplina inteiro.

### Reflexão

A funcionalidade está madura para o caminho feliz e em PDFs do SIGAA
moderno (PyMuPDF acerta a maioria). O risco real está nas **bordas e
no silêncio**: o parser, quando algo destoa do esperado, prefere
descartar dado a sinalizar — e isso é exatamente o tipo de bug que
testes unitários estruturais não pegam (porque o `continue` está
coberto), mas que destrói a confiança do aluno no fluxograma.

Cinco dos defeitos (D1, D7, D8, D9, D11) são **silêncios** e cabem
direto na Fase 2 como testes unitários do parser
(`no_fluxo_backend/parse-pdf/tests/test_parser_unit.py`,
sugerido):

- `test_padrao_mencao_aceita_endash` (D1)
- `test_filename_sem_underscore_retorna_warning` (D7)
- `test_disciplina_II_retorna_em_disciplinas_ignoradas` (D8)
- `test_pdf_nao_sigaa_retorna_warning` (D9)
- `test_bloco_parcial_loga_warning` (D11)

Dois defeitos (D4, D10) são **configurações de segurança/operação** e
cabem em ajuste pontual de `app.config` no mesmo PR (não precisam de
sessão dedicada de testes).

Os defeitos D2, D6 são **dívidas estruturais** (código morto, parsers
duplicados) — viram refactor com cobertura preservada.

Para a **Fase 3 (E2E Playwright)**, os cenários candidatos são:

- *Aluno faz upload de PDF com en-dash → fluxograma renderiza com
  todas as disciplinas (regressão de D1).*
- *Aluno faz upload de PDF de 50MB → frontend mostra erro de tamanho
  ANTES de chegar no servidor (regressão de D4).*
- *Aluno faz upload de boleto → toast "isto não parece histórico
  SIGAA" aparece (regressão de D9).*

Limitação honesta da sessão (rev2): a primeira passada foi 100% estática.
A segunda passada subiu o Flask local e rodou 12 testes automatizados
(`no_fluxo_backend/parse-pdf/tests/test_exploratorio_kauan.py`) que
confirmaram 7 defeitos (D1, D4, D5, D7, D9, D10 + o novo Crítico D13) com
evidência reproduzível em `docs/testes/evidencias/kauan-*.json`. Os achados
que continuam **sem fixture executável** são D2 (Tesseract path — só leitura
ainda faz sentido), D6 (divergência _final vs _ocr), D8 (descarte II/MI/SR),
D11 (bloco de 8 linhas) e D12 (whitelist OCR). Estes ficam como próximas
sessões dirigidas — agora com fixtures sob `docs/testes/fixtures/kauan/`
servindo de base.

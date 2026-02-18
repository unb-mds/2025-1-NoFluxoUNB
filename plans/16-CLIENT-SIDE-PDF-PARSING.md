# Plan 16 — Client-Side PDF Parsing: Backend → Svelte Migration

> Move PDF parsing from the Python Flask microservice to the SvelteKit frontend so the browser handles transcript extraction directly, eliminating the backend dependency for this feature.

---

## Migration Status Overview

| Component | Current (Backend) | Target (Frontend) | Status |
|---|---|---|---|
| PDF text extraction | PyMuPDF (Python) | PDF.js (`pdfjs-dist`) | Not started |
| Regex data extraction | Python `re` module | TypeScript RegExp | Not started |
| Upload endpoint | `POST /fluxograma/read_pdf` | Removed (client-side) | Not started |
| Discipline matching | `POST /fluxograma/casar_disciplinas` | Direct Supabase / SvelteKit server route | Not started |
| Upload service | Calls backend API | Calls local parser module | Not started |
| Upload store | Manages API-based flow | Manages local parsing flow | Not started |
| OCR fallback | `pytesseract` (not used in prod) | Deferred (Tesseract.js if needed) | Deferred |

---

## Current Architecture

```
Browser → POST /fluxograma/read_pdf → Express (port 3000) → Python Flask (port 3001)
                                                                  ↓
                                                          PyMuPDF extracts text
                                                          Regex extracts data
                                                                  ↓
Browser ← JSON response ← Express ← Flask returns JSON
```

### Backend Files Involved

| File | Role |
|---|---|
| `no_fluxo_backend/parse-pdf/pdf_parser_final.py` | Flask server + parsing logic (~600 lines) |
| `no_fluxo_backend/parse-pdf/pdf_parser_ocr.py` | OCR variant (not used in prod) |
| `no_fluxo_backend/src/index.ts` | Spawns Python process on startup |
| `no_fluxo_backend/src/controllers/fluxograma_controller.ts` | `read_pdf` endpoint proxies to Flask; `casar_disciplinas` does discipline matching |

### Frontend Files Involved

| File | Role |
|---|---|
| `src/lib/services/upload.service.ts` | `uploadPdf(file)` → calls backend; `casarDisciplinas(data)` → calls backend |
| `src/lib/stores/uploadStore.ts` | Manages upload lifecycle (states, progress, results) |
| `src/routes/upload-historico/+page.svelte` | Upload page UI |
| `src/lib/components/upload/*.svelte` | FileDropzone, UploadProgress, UploadSuccess, etc. |

---

## Target Architecture

```
Browser → PDF.js extracts text (Web Worker)
             ↓
       TypeScript regex engine extracts structured data
             ↓
       Discipline matching via SvelteKit server route or direct Supabase
             ↓
       Results displayed, saved to Supabase
```

No Python process. No backend proxy. The entire PDF → structured data pipeline runs in the browser.

---

## Phase 1: PDF Text Extraction with PDF.js

### 1.1 Install `pdfjs-dist`

```bash
pnpm add pdfjs-dist
```

- [ ] Add `pdfjs-dist` to `no_fluxo_frontend_svelte/package.json`
- [ ] Configure the PDF.js worker (copy `pdf.worker.min.mjs` to `static/` or use CDN)
- [ ] Add `/static/pdf.worker.min.mjs` to `.gitignore` if copying from node_modules via a build script

### 1.2 Create PDF text extraction module

**File: `src/lib/services/pdf/pdfExtractor.ts`**

Port the `extract_structured_text()` logic from `pdf_parser_final.py` to TypeScript using PDF.js.

Key mapping:

| Python (PyMuPDF) | TypeScript (PDF.js) |
|---|---|
| `fitz.open(stream)` | `pdfjsLib.getDocument({ data: arrayBuffer })` |
| `page.get_text("dict")` → blocks → lines → spans | `page.getTextContent()` → items with `str` + `transform` |
| `span["bbox"][0]` (X position) | `item.transform[4]` (X position) |
| `span["bbox"][1]` (Y position) | `item.transform[5]` (Y position) |
| Sort spans by X, group by Y proximity | Same logic, adapted to PDF.js transform matrix |
| Space insertion based on `(x - prev_end) > threshold` | Same logic with `item.width` from PDF.js |

Implementation tasks:

- [ ] Create `src/lib/services/pdf/pdfExtractor.ts`
- [ ] Implement `extractTextFromPdf(file: File): Promise<string>` that:
  1. Reads the File as `ArrayBuffer`
  2. Loads document with `pdfjsLib.getDocument()`
  3. Iterates pages, calls `page.getTextContent()`
  4. Reconstructs lines by sorting items by Y position (descending), then X position
  5. Inserts spaces between items based on positional gaps (mirrors Python's threshold logic)
  6. Returns the full reconstructed text
- [ ] Handle edge cases: empty pages, rotated text, multi-column layouts
- [ ] Ensure Unicode normalization matches Python behavior (`NFKD`)

### 1.3 Web Worker for PDF.js (optional but recommended)

PDF.js already uses a worker for parsing. Ensure the worker is properly configured:

- [ ] Verify `pdfjsLib.GlobalWorkerOptions.workerSrc` is set correctly
- [ ] Test that parsing doesn't block the main thread
- [ ] If extraction is slow (>2s), move the full pipeline to a dedicated Web Worker

---

## Phase 2: Regex Data Extraction in TypeScript

### 2.1 Create the data extraction module

**File: `src/lib/services/pdf/pdfDataExtractor.ts`**

Port `extrair_dados_academicos()` from `pdf_parser_final.py`. This is ~500 lines of pure text processing.

#### Regex porting guide

| Python Pattern | TypeScript Equivalent |
|---|---|
| `re.compile(r"...", re.IGNORECASE)` | `new RegExp("...", "i")` |
| `re.compile(r"...", re.MULTILINE)` | `new RegExp("...", "m")` |
| `re.DOTALL` | `new RegExp("...", "s")` |
| `(?P<name>...)` named groups | `(?<name>...)` named groups |
| `match.group("name")` | `match.groups.name` |
| `re.findall(pattern, text)` | `[...text.matchAll(new RegExp(pattern, "g"))]` |
| `re.search(pattern, text)` | `text.match(pattern)` |
| `unicodedata.normalize('NFKD', s)` | `s.normalize('NFKD')` |
| `texto.splitlines()` | `texto.split('\n')` |

Implementation tasks:

- [ ] Create `src/lib/services/pdf/pdfDataExtractor.ts`
- [ ] Define TypeScript types for extracted data:

```typescript
export interface DisciplinaExtraida {
  tipo_dado: string;
  nome: string;
  status: string;
  mencao: string;
  creditos: number | null;
  codigo: string;
  carga_horaria: number | null;
  ano_periodo: string;
  turma: string;
  frequencia: string;
}

export interface EquivalenciaExtraida {
  cumpriu: string;
  nome_cumpriu: string;
  atraves_de: string;
  nome_atraves_de: string;
}

export interface DadosExtraidos {
  curso_extraido: string;
  matriz_curricular: string;
  ira: number | null;
  media_ponderada: number | null;
  extracted_data: DisciplinaExtraida[];
  equivalencias_pdf: EquivalenciaExtraida[];
  semestre_atual: string;
  numero_semestre: number;
  suspensoes: string[];
}
```

- [ ] Port `extrair_dados_academicos()` → `extractAcademicData(text: string): DadosExtraidos`
  - [ ] Course name extraction (3 regex patterns + fallback)
  - [ ] Matriz curricular extraction
  - [ ] IRA extraction
  - [ ] MP (média ponderada) extraction
  - [ ] Suspensões extraction
  - [ ] Discipline extraction (8-line structured pattern):
    - ano_periodo, nome, turma, situação, código, carga_horária, frequência, menção
    - Filter out II/MI/SR grades
  - [ ] Disciplinas pendentes extraction
  - [ ] Equivalências extraction ("Cumpriu X através de Y")
  - [ ] Semestre atual derivation (from MATR-status disciplines)
  - [ ] Número do semestre calculation (unique semesters with APR/REP/CUMP)
- [ ] Port matrícula extraction from filename

### 2.2 Create the main parser entry point

**File: `src/lib/services/pdf/pdfParser.ts`**

```typescript
export interface ParsedPdfResult {
  filename: string;
  matricula: string;
  curso_extraido: string;
  matriz_curricular: string;
  media_ponderada: number | null;
  full_text: string;
  extracted_data: DisciplinaExtraida[];
  equivalencias_pdf: EquivalenciaExtraida[];
  semestre_atual: string;
  numero_semestre: number;
  suspensoes: string[];
}

export async function parsePdf(file: File): Promise<ParsedPdfResult>;
```

- [ ] Create `src/lib/services/pdf/pdfParser.ts` that orchestrates extraction + data parsing
- [ ] Extract matrícula from filename (same regex as Python)
- [ ] Combine text extraction + data extraction into a single async function
- [ ] Return the same JSON structure currently returned by the Flask endpoint

---

## Phase 3: Discipline Matching (casar_disciplinas)

The `casar_disciplinas` endpoint in `fluxograma_controller.ts` is ~500 lines that:
1. Receives extracted PDF data + course ID
2. Queries Supabase for the course's discipline catalog
3. Matches extracted disciplines against catalog by code
4. Handles equivalencies
5. Returns `disciplinas_casadas` (matched disciplines array)

### Options

**Option A: SvelteKit Server Route (recommended)**
Move the matching logic to a SvelteKit `+server.ts` route that runs server-side. This keeps Supabase queries server-side (no RLS exposure for catalog data) and avoids duplicating database query logic.

**Option B: Direct Supabase from Client**
Query the course catalog from the browser and do matching client-side. Simpler but exposes more Supabase queries to the client.

### Implementation (Option A)

- [ ] Create `src/routes/api/casar-disciplinas/+server.ts`
  - [ ] Port matching logic from `fluxograma_controller.ts`
  - [ ] Accept POST with `{ extracted_data, curso, matriz_curricular, equivalencias_pdf }`
  - [ ] Query Supabase using the server-side client (from `event.locals.supabase`)
  - [ ] Return `{ disciplinas_casadas, dados_validacao, materias_optativas }`
- [ ] Define TypeScript types for request/response in `src/lib/types/upload.ts`

---

## Phase 4: Update Frontend Integration

### 4.1 Update upload service

**File: `src/lib/services/upload.service.ts`**

Replace backend API calls with local parser + server route:

- [ ] Remove `uploadPdf(file)` method (no longer calls backend)
- [ ] Add `parsePdfLocally(file: File): Promise<ParsedPdfResult>` that uses `pdfParser.ts`
- [ ] Update `casarDisciplinas()` to call `/api/casar-disciplinas` (SvelteKit server route) instead of the Express backend
- [ ] Keep `saveFluxogramaToDB()` unchanged (already uses direct Supabase)

### 4.2 Update upload store

**File: `src/lib/stores/uploadStore.ts`**

- [ ] Replace the `upload()` method:
  - Before: `uploadService.uploadPdf(file)` → HTTP to Express → HTTP to Flask
  - After: `parsePdfLocally(file)` → runs in browser
- [ ] Update progress simulation:
  - Before: 0-50% upload, 50-90% matching
  - After: 0-40% text extraction, 40-70% data extraction, 70-90% discipline matching
- [ ] Update error handling for client-side parsing errors (more descriptive messages)
- [ ] Keep the rest of the flow (course selection, save, navigate) unchanged

### 4.3 Update upload page (if needed)

- [ ] Verify `FileDropzone.svelte` still works (it should — it just passes a `File` object)
- [ ] Verify `UploadProgress.svelte` still works with updated progress states
- [ ] Verify no component references the backend URL directly
- [ ] Test the full flow: drag PDF → parse → match → display results → save

---

## Phase 5: Testing & Validation

### 5.1 Unit tests for the parser

**File: `src/lib/services/pdf/__tests__/pdfParser.test.ts`**

- [ ] Port test assertions from `tests/test_parser.py`
- [ ] Copy test PDFs to a test fixtures directory: `src/lib/services/pdf/__tests__/fixtures/`
  - `historico_190012579.pdf`
  - `historico_211029503-5.pdf`
  - `historico_222006202.pdf`
  - `historico_222037700.pdf`
  - `historico_232021516.pdf`
- [ ] Test: course name extraction for each PDF
- [ ] Test: matriz curricular extraction
- [ ] Test: IRA / MP extraction
- [ ] Test: discipline count and details
- [ ] Test: pending disciplines
- [ ] Test: equivalencies
- [ ] Test: semestre atual and número do semestre

### 5.2 Cross-validation with Python parser

- [ ] Run both parsers (Python + TypeScript) on all 5 test PDFs
- [ ] Compare JSON outputs field by field
- [ ] Document any differences and decide if they're acceptable
- [ ] Pay special attention to text extraction differences between PyMuPDF and PDF.js:
  - Character encoding edge cases (accented characters in Portuguese)
  - Span positioning and line reconstruction
  - Whitespace handling

### 5.3 Integration testing

- [ ] Test full upload flow in the browser with each test PDF
- [ ] Test discipline matching with `casar_disciplinas` server route
- [ ] Test course selection modal flow (when auto-match fails)
- [ ] Test save to Supabase flow
- [ ] Test error states: invalid PDF, corrupt file, non-SIGAA transcript

---

## Phase 6: Cleanup

### 6.1 Remove backend PDF parsing dependencies

- [ ] Remove Python process spawn from `no_fluxo_backend/src/index.ts`
- [ ] Remove `read_pdf` endpoint from `fluxograma_controller.ts`
- [ ] Optionally remove `casar_disciplinas` endpoint if fully migrated to SvelteKit server route
- [ ] Remove `pdf_parser_port.json`
- [ ] Update `docker-compose.yml` if it references the Python parser
- [ ] Update any CI/CD that installs Python PDF parser dependencies

### 6.2 Update documentation

- [ ] Update `no_fluxo_backend/README.md` to note PDF parsing moved to frontend
- [ ] Update `DOCKER_README.md` if applicable
- [ ] Update this plan with final status

---

## Dependency Summary

### New Frontend Dependencies

| Package | Size (gzipped) | Purpose |
|---|---|---|
| `pdfjs-dist` | ~400KB + worker | PDF text extraction in browser |

### Removed Backend Dependencies

| Package | Purpose |
|---|---|
| `PyMuPDF` | PDF text extraction (Python) |
| `Flask` | PDF parser HTTP server |
| `flask-cors` | CORS for Flask |
| `Pillow` | Image processing (unused in prod) |
| `pdf2image` | PDF to image (unused in prod) |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| PDF.js text extraction differs from PyMuPDF | Medium | High | Cross-validate with all 5 test PDFs; tune positional reconstruction |
| Regex edge cases in JS vs Python | Low | Medium | Port tests 1:1; run both parsers in parallel during transition |
| Performance on large PDFs | Low | Low | PDF.js worker runs off main thread; transcripts are typically 2-5 pages |
| Bundle size increase (~400KB) | Low | Low | Lazy-load `pdfjs-dist` only on upload page via dynamic import |
| SIGAA format changes | Low | High | Same risk exists with Python parser; keep regex patterns maintainable |

---

## Implementation Order

1. **Phase 1** (PDF.js text extraction) — Foundation, can be tested independently
2. **Phase 2** (Regex extraction) — Pure TypeScript, easiest to port and test
3. **Phase 5.1-5.2** (Unit tests + cross-validation) — Validate before integrating
4. **Phase 3** (Discipline matching server route) — Server-side, independent of Phase 1-2
5. **Phase 4** (Frontend integration) — Wire everything together
6. **Phase 5.3** (Integration testing) — End-to-end validation
7. **Phase 6** (Cleanup) — Remove backend code after frontend is fully validated

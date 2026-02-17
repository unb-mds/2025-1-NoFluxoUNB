# Plan 16: PDF Parser Algorithm Rewrite

## Status: Ready for Implementation

## Problem

The current `pdfDataExtractor.ts` in the Svelte frontend **cannot extract any disciplines** from real SIGAA histórico PDFs. It uses an 8-consecutive-lines pattern matching approach that assumes each discipline field (period, name, turma, situação, código, carga_horária, frequência, menção) appears on its **own separate line**. However, pdfjs-dist extracts the text with all discipline data on **1-3 lines**, not 8.

### Evidence

Testing with 6 real histórico PDFs from `test_historicos/`:

| Metric | Old Parser | New Parser |
|--------|-----------|-----------|
| Regular disciplines found | **0** | **171** |
| Pending disciplines found | **0** | **99** |
| Equivalências found | **1** | **2** |
| Pass rate on 55 tests | ~0% | **100%** |

The old parser finds **zero** disciplines because its pattern never matches.

## Root Cause

pdfjs-dist reconstructs text with positional sorting. Each discipline appears in one of **4 formats**:

### Format A: "Name-above" (3 lines)
```
ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES        ← name (separate line)
2019.1  * CIC0004          90    AA   92,0  MM   APR   ← data (one line)
Dr. FABRICIO ATAIDES BRAZ (90h)                  ← professor (optional)
```

### Format B: "Single-line" (1 line)
```
2021.1  * CIC0004ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES  90  AA  100,0  SS  APR
```
Name is concatenated with the code, no separate name or professor line.

### Format C: "Professor-embedded" (2 lines)
```
ALGORITMOS E PROGRAMAÇÃO DECOMPUTADORES         ← name (may have concatenated words)
2022.2  & CIC0004Dr. GIOVANNI ALMEIDA SANTOS(90h)  90  08  --  -  TRANC
```
Professor appears between code and CH on the data line.

### Format D: "Detailed transcript" (many lines)
```
ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES  90  APROVADO(A)   ← header
EMENTA: ...                                               ← ementa section
OBJETIVOS: ...                                            ← objectives
PROGRAMA: ...                                             ← program
2021.1*CIC0004                                            ← hidden period+code
REFERÊNCIAS: ...                                          ← references
```
Uses long status text (APROVADO(A)) instead of short codes (APR).

### Special: CUMP with "--" period
```
--   * FGA0221INTELIGÊNCIA ARTIFICIAL  60  --  --  -  CUMP
```

## Solution: New Algorithm

File: `test_historicos/pdfDataExtractor.mjs` — fully tested and working.

### Architecture

```
extrairDadosAcademicos(text)
├── Metadata extraction (curso, IRA, MP, matriz, suspensões)
├── Format detection (isDetailed?)
├── if DETAILED format:
│   └── extrairDisciplinasDetalhado() — pattern matching for FORMAT D
│       - Regex: "NAME    CH    APROVADO(A)"
│       - Forward search for "YYYY.S[symbols]CODE" line
│       - Maps long status → short code (APROVADO(A) → APR)
├── if SIMPLE format:
│   └── extrairDisciplinasDaLinha() — single-regex approach for A/B/C
│       - One main regex captures: period, symbols, code, middle, CH, turma, freq, nota, situação
│       - Middle text analysis determines if name is inline or on previous line
│       - Professor detection (embedded or on next line)
├── extrairDisciplinasPendentes() — "Componentes Curriculares Obrigatórios Pendentes" section
├── extrairEquivalencias() — "Cumpriu X através de Y" patterns
├── Status counts (Pendencias)
└── Semester calculation
```

### Key Design Decisions

1. **Single main regex** instead of 8 separate line checks — the data line has consistent structure: `PERIOD  [SYMBOLS]  CODE  [MIDDLE]  CH  TURMA  FREQ  NOTA  SITUACAO`
2. **Middle text analysis** — the variable part between code and CH can be: empty (name above), discipline name (single-line), or professor (embedded format)
3. **No skipping MI/II/SR** — the old algorithm silently dropped disciplines with these grades. The new algorithm keeps all, letting the frontend decide what to display
4. **Format auto-detection** — presence of "EMENTA:" + "APROVADO(A)" triggers detailed parser

## Implementation Steps

### Step 1: Replace `pdfDataExtractor.ts` (HIGH PRIORITY)
- [ ] Convert `test_historicos/pdfDataExtractor.mjs` to TypeScript
- [ ] Replace `no_fluxo_frontend_svelte/src/lib/services/pdf/pdfDataExtractor.ts`
- [ ] Keep all existing interfaces (`DisciplinaExtraida`, `EquivalenciaExtraida`, `DadosAcademicos`)
- [ ] Keep all existing exports

### Step 2: Update `pdfParser.ts` if needed
- [ ] Verify `parsePdf()` orchestrator still works with new extractor
- [ ] No changes expected — the interface is the same

### Step 3: No changes to `pdfExtractor.ts`
- The text extraction layer works correctly. The bug is only in the data extraction (regex parsing) layer.

### Step 4: Handle name quality edge case
- [ ] Add word-boundary fixup for Format C concatenated names (e.g., "DECOMPUTADORES" → "DE COMPUTADORES")
- [ ] This is a known limitation of the PDF text extraction when fonts lack proper spacing metadata
- [ ] Consider adding a dictionary-based word splitter if needed

### Step 5: Testing
- [ ] Copy test PDFs to Svelte project test infrastructure
- [ ] Create Vitest unit tests using the extracted text files
- [ ] Test the full pipeline: PDF file → pdfExtractor → pdfDataExtractor → result
- [ ] Verify browser compatibility (the algorithm is pure regex, no Node-specific code)

### Step 6: MI/II/SR Discipline Handling
- [ ] Decide on policy: skip (current) vs include (new algorithm)
- [ ] If including, add `excluded: boolean` flag or filter in the UI layer
- [ ] Update fluxograma matching logic if disciplines with these grades should appear

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `src/lib/services/pdf/pdfDataExtractor.ts` | **REWRITE** | New algorithm replacing 8-line matching with single-line regex |
| `src/lib/services/pdf/pdfParser.ts` | No change | Interface is preserved |
| `src/lib/services/pdf/pdfExtractor.ts` | No change | Text extraction works correctly |

## Testing Artifacts

The `test_historicos/` folder contains:
- `extract_text.mjs` — PDF text extraction using pdfjs-dist (same lib as Svelte)
- `analyze_patterns.mjs` — Pattern classification analysis
- `pdfDataExtractor.mjs` — **The new algorithm** (JavaScript, ready to port to TS)
- `old_parser.mjs` — Port of the current algorithm for comparison
- `test_parser.mjs` — Test suite with 55 assertions across 6 PDFs (100% pass rate)
- `compare_old_new.mjs` — Side-by-side comparison script
- `extracted_texts/` — Raw and numbered text extractions from all 6 test PDFs

## Risk Assessment

- **Low risk**: The new algorithm outputs the exact same data structures as the old one
- **Low risk**: Text extraction (`pdfExtractor.ts`) is unchanged
- **Medium risk**: Edge cases from other UnB courses/campuses not yet tested (only FGA/FCTE PDFs in test set)
- **Mitigation**: The new algorithm is more permissive and detects format automatically, so it should handle variations better than the rigid 8-line approach

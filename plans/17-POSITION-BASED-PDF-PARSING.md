# Plan 17: Position-Based PDF Parsing

## Status: Implemented

## Motivation

The current regex-based PDF parser (Plan 16) works well for ~90% of disciplines but fundamentally struggles when PDF.js reconstructs text in unexpected ways. The root problem is that **we throw away the positional data** and then try to reconstruct structure from flat text using increasingly complex regexes.

### Known Failures in the Current Regex Approach

**1. Multi-line professor wrapping** — When a professor's name is too long, PDF.js splits it across two lines. The data (CH, turma, freq, nota, status) ends up on a third line instead of the second. The regex can't match because it expects data on the line immediately after the name.

Example (DSC0172 in semester 2024.2):
```
Line 1:  2024.2  # DSC0172  VIGILÂNCIA EPIDEMIOLÓGICA PARTICIPATIVA  
Line 2:  Dra. LIGIA MARIA CANTARINO DA COSTA (30h), Dr. JONAS LOTUFO BRANT DE CARVALHO  
Line 3:  (30h)  30 01 100,0  SS APR
```

The main `reDataLine` regex doesn't match line 1 (no data fields), `reNameLine` matches line 1 but then line 2 doesn't match `reProfessorDataLine` (data is on line 3). Result: **discipline is silently dropped**. This causes 2 of 3 DSC0172 entries to disappear.

**2. Professor name cleanup** — The `limparNomeProfessor` function doesn't strip the trailing `(Xh)` pattern, leaving every professor with artifacts like `"JONAS LOTUFO BRANT DE CARVALHO (30h"`.

**3. Long discipline names wrapping** — Similar to professors, long discipline names can wrap across lines (e.g., FGA0412 "MONITORIA EM PROBABILIDADE E ESTATÍSTICA APLICADO A ENGENHARIA" wraps).

**4. Edge-case format proliferation** — Every new PDF variant requires a new regex branch (we already have Formats A, B, C, D, E). This is unsustainable.

### Impact

For the test file `historico_222037700.pdf`:
- **Expected**: ~31 unique disciplines across 6 semesters
- **Extracted**: 29 (missing 2+ due to multi-line professor wrap)
- **Professor data**: all 28 have leftover `(Xh` artifacts

## Proposed Approach: Position-Based Parsing

Instead of converting PDF → flat text → regex, we keep the **x, y coordinates** from PDF.js and use them to build a structured table directly.

### Why This Is Better

The SIGAA histórico is fundamentally a **table**. Each discipline's data is laid out in **columns**:

```
Column:   Period    Symbols  Code      Name                          CH   Turma  Freq   Nota  Status
X range:  ~30-70    ~75-85   ~90-140   ~145-400                     ~410  ~430   ~450   ~480  ~510
```

Text items that share the same **Y coordinate** belong to the same row. Text items in specific **X ranges** belong to specific columns. This is how the PDF was originally generated, and PDF.js gives us this information for free — we just discard it today.

### How It Works

```
PDF file
  │
  ▼
PDF.js getTextContent()
  │  gives us: { str, transform[4]=x, transform[5]=y, width }
  │
  ▼
Step 1: Group items by Y coordinate (same as today's groupItemsIntoLines)
  │  items within 3pt of each other → same row
  │
  ▼
Step 2: Identify column boundaries
  │  Scan the first few discipline rows to detect column X-ranges
  │  OR use known SIGAA column positions (they're consistent)
  │
  ▼
Step 3: For each row, slot items into columns by X position
  │  Row = { period, symbols, code, name, ch, turma, freq, nota, status, professor }
  │
  ▼
Step 4: Handle multi-row items
  │  If a name or professor spans two Y-rows, merge them (same X range)
  │  The professor line has a distinct X start (indented) and lacks period/code
  │
  ▼
Step 5: Build DisciplinaExtraida[] from structured rows
```

### Key Advantages

| Aspect | Regex Approach | Position-Based Approach |
|--------|---------------|------------------------|
| Multi-line professors | Breaks (needs special-case regex per format) | Natural: items at same X, adjacent Y → merge |
| Multi-line names | Breaks (same reason) | Natural: merge by X range |
| Column identification | Fragile regex with `\s{2,}` gaps | Robust: X coordinate ranges |
| New PDF variants | Need new regex branch | Same column layout → works automatically |
| Concatenated text (e.g., `CIC0004ALGORITMOS`) | Regex hack to split | X position shows code ends before name starts |
| Maintenance | Complex, brittle | Simple column-mapping logic |

### The Data Is Already There

In `pdfExtractor.ts`, we already extract positioned items:
```ts
items.push({
    text,
    x: textItem.transform[4],  // ← horizontal position
    y: textItem.transform[5],  // ← vertical position  
    width: textItem.width
});
```

But then `reconstructLine()` flattens everything to plain text, losing the positional meaning. The proposal is to **keep the structured items** and parse from them directly.

## Architecture

### Option A: Replace Data Extractor Only (Lower Risk)

Keep `pdfExtractor.ts` as-is (it returns flat text). Add a **new extractor** that receives the raw positioned items and returns `DisciplinaExtraida[]`.

```
pdfParser.ts (orchestrator)
├── pdfExtractor.ts → extractTextFromPdf()        [unchanged, for metadata/fallback]
├── pdfExtractor.ts → extractPositionedItems()     [NEW: returns PositionedTextItem[][]]
└── pdfPositionExtractor.ts                        [NEW: position-based discipline extraction]
    ├── detectColumnBoundaries(items)
    ├── buildTableRows(items, columns)
    ├── mergeContinuationRows(rows)
    └── toDisciplinaExtraida(rows) → DisciplinaExtraida[]
```

Metadata extraction (curso, IRA, matriz, etc.) can still use regex on flat text — those are simple single-line patterns.

### Option B: Full Pipeline Rewrite (Higher Risk, Cleaner)

Replace the entire pipeline. The `pdfExtractor.ts` returns positioned items per page, and a single new module handles all extraction.

### Recommendation: **Option A**

Lower risk, incremental, can be tested side-by-side with the regex approach.

## Implementation Steps

### Phase 1: Expose Positioned Items (Low Risk)

- [ ] Add `extractPositionedItems(file: File): Promise<PositionedTextItem[][]>` to `pdfExtractor.ts`
  - Returns array of pages, each page is array of `PositionedTextItem`
  - Reuses existing PDF.js loading code
- [ ] Keep `extractTextFromPdf()` working as-is (for metadata extraction)

### Phase 2: Column Detection

- [ ] Create `pdfPositionExtractor.ts`
- [ ] Implement `detectColumnBoundaries(items: PositionedTextItem[][]): ColumnLayout`
  - Scan items looking for the header row ("Ano/Período", "Componente", "CH", "Turma", etc.)
  - If header found → use its X positions as column boundaries
  - If not found → use hardcoded SIGAA defaults (the layout is remarkably consistent):
    ```
    period:  x < 80
    code:    80 ≤ x < 150
    name:    150 ≤ x < 400
    ch:      400 ≤ x < 430
    turma:   430 ≤ x < 460
    freq:    460 ≤ x < 490
    nota:    490 ≤ x < 520
    status:  x ≥ 520
    ```
  - Validate by checking that several rows have items in most column ranges

### Phase 3: Row Building

- [ ] Implement `buildTableRows(items, columns): RawRow[]`
  - Group items by Y (same as existing `groupItemsIntoLines`)
  - For each Y-group, classify items into columns by X position
  - A row is "discipline data" if it has items in the period and/or code columns
  - A row is "professor" if it starts with `Dr./Dra./MSc./Prof.` and has no period
  - A row is "continuation" if it has items only in the name or professor X-range

### Phase 4: Row Merging

- [ ] Implement `mergeContinuationRows(rows: RawRow[]): MergedRow[]`
  - If a "continuation" row follows a discipline or professor row, merge its text
  - This naturally handles:
    - Multi-line professor names (DSC0172 case)
    - Multi-line discipline names (FGA0412 case)
    - Any text wrapping without needing special regex

### Phase 5: Conversion

- [ ] Implement `toDisciplinaExtraida(rows: MergedRow[]): DisciplinaExtraida[]`
  - Map each merged row to the existing `DisciplinaExtraida` interface
  - Clean professor names (strip `Dr./Dra./MSc.` prefix and `(Xh)` suffix)
  - Clean discipline names (same fixups as today)
  - Calculate créditos from CH

### Phase 6: Integration

- [ ] Update `pdfParser.ts` to use the position-based extractor
- [ ] Keep regex extractor as fallback (if position-based finds 0 disciplines, fall back to regex)
- [ ] Metadata (curso, IRA, matriz, suspensões) stays regex-based — they're simple patterns on flat text

### Phase 7: Testing

- [ ] Extract positioned items from all 6+ test PDFs, save as JSON fixtures
- [ ] Write unit tests comparing position-based vs regex-based results
- [ ] Position-based should find **equal or more** disciplines than regex
- [ ] Verify the DSC0172, FGA0412, and similar edge cases are resolved

### Phase 8: Cleanup

- [ ] Once position-based is stable, remove the regex-based discipline extractor
- [ ] Keep regex-based metadata extraction (it works fine for those)
- [ ] Update Plan 16 as superseded

## Quick Wins (Can Do Now, Before Full Position-Based Rewrite)

While the full position-based approach is the right long-term solution, these regex fixes address the immediate problems:

### QW-1: Fix multi-line professor + data (DSC0172 bug)
- [ ] In `extrairDisciplinasDaLinha()`, when `reNameLine` matches but `reProfessorDataLine` doesn't match the next line:
  - Check if next line starts with `Dr./Dra./MSc./Prof.` (professor start)
  - Join next 1-2 lines and re-try `reProfessorDataLine` on the joined text
  - This handles the 3-line case: name → professor_start → professor_end+data

### QW-2: Fix professor `(Xh)` cleanup
- [ ] In `limparNomeProfessor()`, also strip trailing `\(\d+h\)` and `\(\d+h$`
- [ ] Handle multi-professor strings: `"NOME1 (30h), Dr. NOME2 (30h)"` → `"NOME1, NOME2"`

### QW-3: Fix FGA0412-style zero-hour professor lines
- [ ] Pattern: `Dr. NAME (0h) 30 -- -- -- APR` — the `(0h)` makes the professor regex not match standard pattern
- [ ] Ensure `reProfessorDataLine` allows `0h` in the professor part

## File Map

| File | Change | Phase |
|------|--------|-------|
| `src/lib/services/pdf/pdfExtractor.ts` | Add `extractPositionedItems()` | 1 |
| `src/lib/services/pdf/pdfPositionExtractor.ts` | **NEW** — position-based discipline extraction | 2-5 |
| `src/lib/services/pdf/pdfParser.ts` | Use position extractor, regex fallback | 6 |
| `src/lib/services/pdf/pdfDataExtractor.ts` | Keep for metadata; discipline extraction becomes fallback | 6 |
| `test_historicos/pdfDataExtractor.mjs` | Quick wins (QW-1, QW-2, QW-3) | Now |

## Risk Assessment

- **Low risk**: Position data is already extracted by PDF.js — no new dependencies
- **Low risk**: Metadata extraction stays regex-based (proven working)
- **Medium risk**: Column boundaries might vary between SIGAA versions or campuses
  - Mitigation: auto-detect from header row, with hardcoded fallback
- **Medium risk**: The "Detailed" format (Format D with EMENTA) has different layout
  - Mitigation: detect format first (same as today), use position-based only for simple format
- **Low risk**: Incremental approach — regex fallback ensures no regression

## Comparison Summary

```
Current:  PDF → flat text → regex match 4+ formats → DisciplinaExtraida[]
                    ▲ loses position info
                    
Proposed: PDF → positioned items → column classification → table rows → DisciplinaExtraida[]
                    ▲ keeps position info ── the key insight
```

The SIGAA PDF is a table. Parse it as a table.

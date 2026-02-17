# Plan 14 — Meu Fluxograma: Flutter → Svelte Migration

> Comprehensive gap analysis and migration plan for the Meu Fluxograma page.

---

## Migration Status Overview

| Category | Flutter Features | Svelte Done | Svelte Missing |
|----------|-----------------|-------------|----------------|
| Routes & Navigation | 3 | 3 | 0 |
| Data Models & Types | 10+ | 10+ | 0 |
| API Services | 6 endpoints | 7 methods | 0 |
| Store / State | ~12 state fields | ~10 fields | 2 (optativas) |
| Core UI Components | 12 widgets | 10 components | 2 |
| Interactions | 12 interactions | 8 interactions | 4 |
| Dialogs & Modals | 6 dialogs | 2 dialogs | 4 |
| Advanced Features | 5 features | 2 features | 3 |

---

## 1. Already Migrated (Complete) ✅

These features are fully functional in Svelte and match or exceed the Flutter implementation:

### Routes
- [x] `/fluxogramas` — Course listing with search, type filter, pagination
- [x] `/meu-fluxograma` — Authenticated user's personalized flowchart
- [x] `/meu-fluxograma/[courseName]` — Anonymous/read-only course view

### Data Layer
- [x] `MateriaModel` type with all fields (ementa, credits, prerequisites, status, etc.)
- [x] `CursoModel` with subjects, prerequisites, co-requisites, equivalencies
- [x] `EquivalenciaModel` with full Boolean expression parser (AND/OR/parentheses)
- [x] `UserModel` with `DadosFluxogramaUser` and `DadosMateria`
- [x] `SubjectStatusEnum` (NOT_STARTED, IN_PROGRESS, COMPLETED, FAILED, AVAILABLE, LOCKED)
- [x] Status helper functions (`determineSubjectStatus`, `canBeTaken`, `getStatusColorClass`)
- [x] Type guards (`isDadosFluxogramaUser`, `hasFluxogramaData`)
- [x] Zod validation schemas
- [x] JSON ↔ Model factories for all types

### Services
- [x] `getAllCursos()` — List all courses (minimal)
- [x] `getCourseData(courseName)` — Full course with subjects, prereqs, coreqs, equivalencias
- [x] `getMateriaData(idMateria)` — Single subject details
- [x] `getMateriasByCode(codes)` — Subject names by code
- [x] `getMateriasFromCodigos(codes, idCurso)` — Full subject data for code list
- [x] `deleteFluxograma(userId)` — Delete user flowchart data
- [x] `saveFluxograma(userId, data, semestre)` — Save user flowchart data

### Store (Svelte 5 Runes)
- [x] `FluxogramaState` with courseData, loading, error, zoomLevel, showConnections, isAnonymous
- [x] `subjectsBySemester` derived grouping
- [x] `completedCodes`, `currentCodes`, `failedCodes` derived sets
- [x] `getSubjectStatus()` and `getSubjectUserData()`
- [x] `loadCourseData(courseName, anonymous)`
- [x] Zoom controls: `setZoom()`, `zoomIn()`, `zoomOut()`, `resetZoom()` (0.3–2.0)
- [x] `toggleConnections()`, `setHoveredSubject()`, `setSelectedSubject()`
- [x] `saveScreenshot()` via html2canvas
- [x] `reset()` — clears all state

### UI Components
- [x] **FluxogramaHeader** — Back button, course name, matrix display, screenshot button
- [x] **FluxogramaLegendControls** — Status legend, connections toggle, zoom slider/buttons/reset
- [x] **FluxogramContainer** — Scrollable container, mouse-drag panning, ctrl+wheel zoom, semester columns
- [x] **SemesterColumn** — Semester header + subject cards list
- [x] **SubjectCard** — Status gradient colors, hover highlighting (prereqs purple, dependents teal), dimming
- [x] **PrerequisiteConnections** — SVG bezier curves, hover mode + "show all" toggle, arrow markers
- [x] **SubjectDetailsModal** — 3-tab dialog (Info, Pré-requisitos, Equivalências)
- [x] **ProgressSummarySection** — Credits circle, completion bar, current semester + IRA
- [x] **OptativasModal** — Searchable browse of semester-0 electives (read-only)
- [x] **CourseCard** — For course listing page

### Interactions
- [x] Click subject card → opens detail modal
- [x] Hover subject → highlights prerequisite/dependent chain
- [x] Zoom +/- buttons and slider
- [x] Ctrl+wheel zoom
- [x] Mouse drag to pan
- [x] Toggle connections view
- [x] Screenshot/save as PNG
- [x] Search and filter on course listing page

---

## 2. Missing Features — Migration Tasks

### Phase 1: Optativas Management (Priority: HIGH)

The optativas workflow is the biggest functional gap. Flutter has a complete add/remove/track flow.

#### 1.1 Store: Add Optativa State & Methods
**Flutter reference**: `_MeuFluxogramaScreenState` tracks `optativasAdicionadas: List<OptativaAdicionada>`

**Task**: Add optativa management to `fluxograma.store.svelte.ts`

```typescript
// Add to FluxogramaState interface
interface OptativaAdicionada {
  materia: MateriaModel;
  semestre: number;
}

// Add state
optativasAdicionadas: OptativaAdicionada[];

// Add methods
addOptativa(materia: MateriaModel, semestre: number): void;
removeOptativa(codigoMateria: string): void;
```

- [ ] Define `OptativaAdicionada` type in `src/lib/types/materia.ts`
- [ ] Add `optativasAdicionadas` state field to store
- [ ] Implement `addOptativa()` — checks for duplicates, adds to list
- [ ] Implement `removeOptativa()` — removes by code
- [ ] Add derived `optativasBySemester` grouping

#### 1.2 OptativasModal: Add-to-Semester Functionality
**Flutter reference**: `optativas_modal.dart` — semester dropdown (1-10), search filter, select subjects from table, confirm button

**Current Svelte state**: `OptativasModal.svelte` exists but is **read-only** (browse only, no add action)

- [ ] Add semester selector dropdown (1–10) to OptativasModal
- [ ] Add select/deselect checkboxes on each optativa row
- [ ] Add "Confirmar" / "Adicionar" action button
- [ ] Wire confirm action to `fluxogramaStore.addOptativa()`
- [ ] Close modal after successful add

#### 1.3 OptativasAdicionadasSection Component
**Flutter reference**: `optativas_adicionadas_section.dart` — displays added optativas as cards, clickable for details/remove

**Current Svelte state**: Does not exist

- [ ] Create `src/lib/components/fluxograma/OptativasAdicionadasSection.svelte`
- [ ] Display list of added optativas grouped by assigned semester
- [ ] Each card shows: code, name, credits, assigned semester
- [ ] Click card → opens detail dialog with "Remover" button
- [ ] Wire remove action to `fluxogramaStore.removeOptativa()`
- [ ] Add this component to the main fluxograma page layout (below FluxogramContainer)

#### 1.4 "Adicionar ao Próximo Semestre" Button in SubjectDetailsModal
**Flutter reference**: `materia_data_dialog_content.dart` — footer button for future/available subjects to quick-add to next semester

- [ ] Add conditional footer button to `SubjectDetailsModal.svelte`
- [ ] Show only for subjects with status AVAILABLE or NOT_STARTED (not completed/in_progress)
- [ ] Hide for anonymous users
- [ ] On click: determine next available semester, add subject as optativa, show confirmation toast

---

### Phase 2: Advanced Interactions (Priority: MEDIUM)

#### 2.1 Long-Press → Prerequisite Chain Dialog
**Flutter reference**: `prerequisite_chain_dialog.dart` — long-press on a card opens a dialog showing full prerequisite chain visualization with levels, can-take status, and dependent count

**Current Svelte state**: Not implemented — no long-press behavior, no chain dialog

- [ ] Create `src/lib/components/fluxograma/PrerequisiteChainDialog.svelte`
- [ ] Content: Can-take status indicator, prerequisite levels (tree view), dependent subjects list
- [ ] Each level shows subjects with completion status (✓/✗)
- [ ] Add `contextmenu` or long-press (pointer down + timer) event to `SubjectCard.svelte`
- [ ] Wire long-press to open PrerequisiteChainDialog
- [ ] Disable for anonymous users

#### 2.2 Prerequisite Indicator Badge on Cards
**Flutter reference**: `prerequisite_indicator_widget.dart` — small badge on each card showing prerequisite status (flag/check/warning icon + dependent count)

**Current Svelte state**: Not implemented

- [ ] Create indicator badge element in `SubjectCard.svelte`
- [ ] Show icon based on status: ✓ (all prereqs done), ⚠ (some missing), 🏳 (no prereqs)
- [ ] Show dependent count number
- [ ] Hide for anonymous users
- [ ] Position in top-right corner of card

#### 2.3 Co-Requisite Connection Lines
**Flutter reference**: `prerequisite_connections_widget.dart` draws green lines for co-requisites alongside purple/teal prerequisite lines

**Current Svelte state**: Co-requisites show in the detail modal text but are **not drawn as SVG lines**

- [ ] Extend `PrerequisiteConnections.svelte` to also draw co-requisite lines
- [ ] Use green color (#10B981) for co-requisite connections
- [ ] Use dashed stroke style to differentiate from prerequisite lines
- [ ] Add co-requisite entry to the legend in `FluxogramaLegendControls.svelte`

#### 2.4 Touch Support for Mobile
**Flutter reference**: Flutter natively handles touch events (tap, long-press, drag)

**Current Svelte state**: `FluxogramContainer.svelte` only has mouse events (`mousedown`, `mousemove`, `mouseup`), no touch events

- [ ] Add `touchstart`, `touchmove`, `touchend` events to FluxogramContainer for panning
- [ ] Add touch-based long-press detection for SubjectCard (300ms hold = long-press)
- [ ] Add pinch-to-zoom on FluxogramContainer
- [ ] Test on mobile viewport sizes

---

### Phase 3: Tool Modals (Priority: LOW — Currently Disabled/Placeholder in Flutter)

All four tool modals are marked "Em breve" (coming soon) in Flutter. They show mock/placeholder UIs.

#### 3.1 ProgressToolsSection Component
**Flutter reference**: `progress_tools_section.dart` — 4 tool cards (all disabled): Calculadora de IRA, Progresso do Curso, Integralização, Mudança de Curso

**Current Svelte state**: Does not exist

- [ ] Create `src/lib/components/fluxograma/ProgressToolsSection.svelte`
- [ ] Render 4 tool cards in a grid
- [ ] All cards show "Em breve" badge / disabled state
- [ ] Add this section below ProgressSummarySection on the page

#### 3.2 Tool Modal Dialogs (Placeholder UIs)
**Flutter reference**: `tool_modals.dart` — 4 modal dialogs with mock content

Since these are all placeholder/"coming soon" UIs, they are low priority:

- [ ] Create `src/lib/components/fluxograma/ToolModals.svelte` (or individual modal components)
- [ ] **IRA Calculator Modal** — fields for adding disciplines/grades/credits, calculate button
- [ ] **Course Progress Modal** — progress bars with credit breakdown by type
- [ ] **Integralização Modal** — graduation requirements checklist
- [ ] **Course Change Modal** — transfer simulation UI
- [ ] Wire card clicks to open respective modals
- [ ] Block with toast/snackbar for anonymous users

---

### Phase 4: UX Polish & Advanced Features (Priority: LOW)

#### 4.1 "Enviar Fluxograma Novamente" Button
**Flutter reference**: Button on main page calls `deleteFluxogramaUser()` API then navigates to `/upload-historico`

**Current Svelte state**: Not visible on the page (service method exists)

- [ ] Add "ENVIAR FLUXOGRAMA NOVAMENTE" button to FluxogramaHeader or below it
- [ ] Show only for authenticated (non-anonymous) users
- [ ] Add confirmation dialog before deleting
- [ ] On confirm: call `fluxogramaService.deleteFluxograma(userId)`, then `goto('/upload-historico')`

#### 4.2 Multiple Curriculum Matrices
**Flutter reference**: `_MeuFluxogramaScreenState.matrizesCurriculares` stores multiple `CursoModel` for courses with different matrices; the header shows matrix info

**Current Svelte state**: Only loads single CursoModel

- [ ] Add `matrizesCurriculares` state to store
- [ ] Add matrix selector UI in FluxogramaHeader (dropdown or tabs)
- [ ] When user switches matrix, reload subject grid with new matrix data

#### 4.3 Optimal Screenshot Zoom Calculation
**Flutter reference**: `_calculateOptimalScreenshotZoom()` uses actual rendered widget dimensions to calculate best zoom level for full capture

**Current Svelte state**: Captures at current zoom level

- [ ] Before capture, calculate optimal zoom from container scroll dimensions
- [ ] Set optimal zoom, wait for render, capture, then restore original zoom
- [ ] Ensure full fluxogram fits in the exported image

#### 4.4 "Falar com Assistente" CTA
**Flutter reference**: Button in ProgressSummarySection navigates to `/assistente`

**Current Svelte state**: ProgressSummarySection exists but may not have this button

- [ ] Add "FALAR COM ASSISTENTE" button to ProgressSummarySection
- [ ] On click: navigate to `/assistente` route

#### 4.5 Anonymous vs Authenticated Feature Gating
**Flutter reference**: Many features are conditionally hidden/disabled based on `isAnonymous`

**Current Svelte state**: Basic `isAnonymous` flag exists in store, some gating in place

- [ ] Audit all components for proper anonymous gating:

| Feature | Authenticated | Anonymous |
|---------|:------------:|:---------:|
| Subject status colors (completed, current, ready) | ✅ | Only future + completed |
| Progress summary section | ✅ | Hidden |
| Progress tools section | ✅ | Hidden |
| "Enviar novamente" button | ✅ | Hidden |
| "Adicionar optativa" button | ✅ | Hidden |
| Long-press chain dialog | ✅ | Disabled |
| Prerequisite indicator badges | ✅ | Hidden |
| Tool modals | ✅ | Blocked with toast |
| Menção display on cards | ✅ | Hidden |
| "Adicionar ao próximo semestre" button | ✅ | Hidden |

---

## 3. Status Color Reference

Both Flutter and Svelte use the same 6-status color system:

| Status | Flutter Gradient | Svelte Class | Hex Range |
|--------|-----------------|--------------|-----------|
| Completed | Green | `bg-gradient-completed` | #2DC063 → #0B7D35 |
| In Progress | Purple | `bg-gradient-in_progress` | #A78BFA → #8B5CF6 |
| Available (Can Take) | Amber | `bg-gradient-available` | #F59E0B → #D97706 |
| Failed | Red | `bg-gradient-failed` | #EF4444 → #DC2626 |
| Locked | Gray | `bg-gradient-locked` | #6B7280 → #4B5563 |
| Not Started | Light Gray | `bg-gradient-not_started` | #9CA3AF → #6B7280 |

### Menção Color Chips (for SubjectDetailsModal)
| Menção | Color |
|--------|-------|
| SS | Green (#10B981) |
| MS | Blue (#3B82F6) |
| MM | Amber (#F59E0B) |
| MI | Red (#EF4444) |
| II | Gray (#6B7280) |
| SR | Gray (#6B7280) |

---

## 4. Implementation Order & Estimates

| # | Task | Priority | Effort | Dependencies |
|---|------|----------|--------|-------------|
| 1 | Optativa store methods (`addOptativa`, `removeOptativa`) | HIGH | S | None |
| 2 | OptativasModal add-to-semester flow | HIGH | M | Task 1 |
| 3 | OptativasAdicionadasSection component | HIGH | M | Task 1 |
| 4 | "Adicionar ao próximo semestre" in detail modal | HIGH | S | Task 1 |
| 5 | "Enviar Fluxograma Novamente" button + flow | MEDIUM | S | None |
| 6 | Co-requisite SVG connection lines | MEDIUM | M | None |
| 7 | Long-press + PrerequisiteChainDialog | MEDIUM | L | None |
| 8 | Prerequisite indicator badges on cards | MEDIUM | S | None |
| 9 | Touch support (pan, pinch-zoom, long-press) | MEDIUM | M | Task 7 |
| 10 | "Falar com Assistente" CTA button | LOW | XS | None |
| 11 | Anonymous feature gating audit | LOW | S | Tasks 1-9 |
| 12 | ProgressToolsSection + tool modals (placeholders) | LOW | M | None |
| 13 | Multiple curriculum matrices support | LOW | L | None |
| 14 | Optimal screenshot zoom calculation | LOW | S | None |

**Effort Key**: XS = < 30min, S = 30min–1h, M = 1–3h, L = 3–6h

---

## 5. File Map (New Files to Create)

```
src/lib/
├── components/fluxograma/
│   ├── OptativasAdicionadasSection.svelte    ← NEW
│   ├── PrerequisiteChainDialog.svelte        ← NEW
│   └── ProgressToolsSection.svelte           ← NEW (placeholder)
├── stores/
│   └── fluxograma.store.svelte.ts            ← MODIFY (add optativa methods)
└── types/
    └── materia.ts                            ← MODIFY (add OptativaAdicionada type)

src/routes/meu-fluxograma/
    └── +page.svelte                          ← MODIFY (add new sections to layout)
```

## 6. Files to Modify

| File | Changes |
|------|---------|
| `src/lib/stores/fluxograma.store.svelte.ts` | Add `optativasAdicionadas` state, `addOptativa()`, `removeOptativa()`, derived `optativasBySemester` |
| `src/lib/types/materia.ts` | Add `OptativaAdicionada` interface |
| `src/lib/components/fluxograma/OptativasModal.svelte` | Add semester selector, checkboxes, confirm button |
| `src/lib/components/fluxograma/SubjectCard.svelte` | Add long-press event, prerequisite indicator badge |
| `src/lib/components/fluxograma/SubjectDetailsModal.svelte` | Add "Adicionar ao próximo semestre" footer button |
| `src/lib/components/fluxograma/PrerequisiteConnections.svelte` | Add co-requisite green dashed lines |
| `src/lib/components/fluxograma/FluxogramaLegendControls.svelte` | Add co-requisite legend entry |
| `src/lib/components/fluxograma/FluxogramaHeader.svelte` | Add "Enviar novamente" button |
| `src/lib/components/fluxograma/FluxogramContainer.svelte` | Add touch events (touchstart/move/end, pinch-zoom) |
| `src/lib/components/fluxograma/ProgressSummarySection.svelte` | Add "Falar com Assistente" button |
| `src/routes/meu-fluxograma/+page.svelte` | Add OptativasAdicionadasSection, ProgressToolsSection to layout |

---

## 7. Checklist

### Phase 1 — Optativas Management
- [ ] `OptativaAdicionada` type definition
- [ ] Store: `optativasAdicionadas` state + methods
- [ ] OptativasModal: semester dropdown + select + confirm
- [ ] OptativasAdicionadasSection component
- [ ] SubjectDetailsModal: "Adicionar ao próximo semestre" button
- [ ] Integration: wire everything into main page

### Phase 2 — Advanced Interactions
- [ ] PrerequisiteChainDialog component
- [ ] SubjectCard: long-press event handler
- [ ] SubjectCard: prerequisite indicator badge
- [ ] PrerequisiteConnections: co-requisite green lines
- [ ] FluxogramaLegendControls: co-requisite legend entry
- [ ] FluxogramContainer: touch events + pinch-zoom
- [ ] FluxogramaHeader: "Enviar novamente" button + confirmation

### Phase 3 — Tool Modals (Placeholder)
- [ ] ProgressToolsSection component (4 disabled cards)
- [ ] IRA Calculator modal (placeholder)
- [ ] Course Progress modal (placeholder)
- [ ] Integralização modal (placeholder)
- [ ] Course Change modal (placeholder)

### Phase 4 — Polish
- [ ] "Falar com Assistente" CTA
- [ ] Anonymous feature gating audit
- [ ] Multiple curriculum matrices
- [ ] Optimal screenshot zoom calculation
- [ ] Mobile responsive testing

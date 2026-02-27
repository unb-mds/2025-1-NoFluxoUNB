# 21 — Export Visual Parity: Match Svelte Screenshot to Flutter Output

## Goal

Make the "Export" (screenshot/save) feature on the Svelte **Meu Fluxograma** page produce a PNG image that looks identical to what the Flutter app produces. This covers the capture library, the captured content, the visual styling of the output, the button UX/label, and the filename format.

---

## Current State Comparison

### Button / Trigger

| Aspect | Flutter | Svelte (current) | Match? |
|--------|---------|-------------------|--------|
| Button label | **"SALVAR FLUXOGRAMA"** | "Screenshot" | ❌ |
| Button icon | `Icons.save` (floppy disk) | `Camera` (lucide) | ❌ |
| Button style | Green gradient (`#22C55E` → `#16A34A`), rounded 8px, bold Poppins, shadow | Glass pill (black/40%, border white/10, backdrop-blur) | ❌ |
| Button position | Right side of header row (desktop), full-width row (mobile) | Right side of header, always same style | ❌ |

### Capture Mechanism

| Aspect | Flutter | Svelte (current) | Match? |
|--------|---------|-------------------|--------|
| Library | `screenshot` (Flutter package) — native widget capture | SVG `foreignObject` fallback (broken) | ❌ |
| Pixel ratio | 3.0 | 2.0 | ❌ |
| Pre-capture zoom | Calculates optimal zoom to fit all content | Uses current user zoom level | ❌ |
| Pre-capture scroll | Centers scroll, waits 400ms | None | ❌ |
| Loading indicator | Fullscreen `SplashWidget` dialog | None | ❌ |
| Post-capture restore | Restores original zoom | None (no zoom change) | ❌ |

### Captured Content (What's in the Image)

| Element | Flutter | Svelte | Match? |
|---------|---------|--------|--------|
| Outer container background | `black @ 40%` opacity | Inherited (unclear with SVG fallback) | ❌ |
| Container border radius | 24px | 12px (`rounded-xl`) | ❌ |
| Container padding | 32px all sides | 16px (`p-4`) | ❌ |
| Semester header style | White pill (`white @10%`), 8px radius, Poppins bold 16px | Black/60% pill with border white/10, 12px radius, uppercase tracking | ❌ |
| Semester header text | `"Xº Semestre"` | `"Semestre X"` | ❌ |
| Column spacing | 32px margin-right | `3rem` gap (≈48px) / `6rem` in connection mode | ⚠️ |
| Card width | 192px fixed | `min-w-[160px]` (flexible) | ❌ |
| Card border radius | 8px | 12px (`rounded-xl`) | ❌ |
| Card padding | 12px all sides | 12px (`p-3`) | ✅ |
| Card shadow | black @30%, blur 8, offset(0,4) | None (border-based) | ❌ |
| Card gradient direction | topLeft → bottomRight | topLeft → bottomRight | ✅ |

### Card Content Layout

| Element | Flutter | Svelte | Match? |
|---------|---------|--------|--------|
| Subject code | Poppins, bold, 14px, white, top-left | 10px, semibold, uppercase, tracking-wider, top-left | ❌ |
| Subject name | Poppins, 12px, white, max 2 lines | 12px (xs), medium, line-clamp-2 | ⚠️ |
| Credits badge | Pill (`black @20%`, 4px radius), "X créditos", 10px | Inline text "Xcr", 10px, top-right | ❌ |
| Menção badge | Pill (`black @20%`, 4px radius), menção text, 10px | Not shown on card | ❌ |
| Bottom row | Credits pill + Menção pill side by side | No bottom row | ❌ |

### Status Colors

| Status | Flutter | Svelte | Match? |
|--------|---------|--------|--------|
| Completed | `#2DC063` → `#0B7D35` | `green-500` → `green-700` (`#22C55E` → `#15803D`) | ⚠️ close |
| In Progress | `#A78BFA` → `#8B5CF6` | `purple-400` → `purple-600` (`#A78BFA` → `#9333EA`) | ⚠️ close |
| Available/Ready | `#F59E0B` → `#D97706` | `amber-500` → `amber-700` (`#F59E0B` → `#B45309`) | ⚠️ close |
| Locked/Future | `white @10%` → `white @10%` | `white/10` → `white/5` | ⚠️ close |
| Failed | `#FB7185` → `#E11D48` (selected) | `red-500` → `red-700` (`#EF4444` → `#B91C1C`) | ❌ |
| Optative | `#3B82F6` → `#1D4ED8` | N/A (not rendered in main grid) | — |

### Output File

| Aspect | Flutter | Svelte | Match? |
|--------|---------|--------|--------|
| Format | PNG | PNG | ✅ |
| Filename | `fluxograma_{courseName}_{timestamp}.png` | `{courseName}.png` | ❌ |
| Resolution | 3x pixel ratio | 2x pixel ratio | ❌ |

---

## Implementation Plan

### Phase 1 — Fix the Capture Library (Critical)

The SVG `foreignObject` fallback is fundamentally broken for Tailwind CSS — external stylesheets, utility classes, pseudo-elements, gradients, and backdrop-blur are not rendered. The image output is visually wrong.

#### Task 1.1: Install `html-to-image`

Use `html-to-image` (lighter, more modern, and more reliable than `html2canvas`) for DOM-to-canvas conversion.

**Why `html-to-image` over `html2canvas`:**
- Smaller bundle size
- Better CSS support (gradients, transforms, SVG)
- Active maintenance
- Works well with Tailwind utility classes

```bash
cd no_fluxo_frontend_svelte
pnpm add html-to-image
```

#### Task 1.2: Rewrite `screenshot.ts`

**File:** `src/lib/utils/screenshot.ts`

Replace the current implementation with `html-to-image`:

```typescript
import { toPng } from 'html-to-image';

export interface ScreenshotOptions {
  pixelRatio?: number;
  backgroundColor?: string;
  filename?: string;
}

export async function captureScreenshot(
  element: HTMLElement,
  filename = 'fluxograma.png',
  options: ScreenshotOptions = {}
): Promise<void> {
  const { pixelRatio = 3, backgroundColor = '#0a0a0a' } = options;

  const dataUrl = await toPng(element, {
    pixelRatio,
    backgroundColor,
    cacheBust: true,
    // Skip interactive-only elements
    filter: (node: HTMLElement) => {
      // Skip any tooltip/popover/modal elements that might be in the tree
      if (node.classList?.contains('tooltip') || node.classList?.contains('popover')) {
        return false;
      }
      return true;
    },
  });

  const link = document.createElement('a');
  link.download = filename;
  link.href = dataUrl;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}
```

---

### Phase 2 — Pre-Capture Zoom & Scroll (Match Flutter Behavior)

The Flutter app calculates an "optimal zoom" before capturing, so the entire fluxograma fits nicely in the image regardless of the user's current zoom/scroll position. The Svelte version should do the same.

#### Task 2.1: Add `saveScreenshot` Logic in Store

**File:** `src/lib/stores/fluxograma.store.svelte.ts`

Update `saveScreenshot()` to:

1. Show a loading toast or overlay.
2. Save the current zoom level.
3. Calculate optimal zoom: measure the inner content dimensions vs the container, pick the zoom that fits everything with a safety margin (×0.45 like Flutter, clamped to 0.1–2.0).
4. Set the new zoom, wait for layout (≈500ms via `requestAnimationFrame` + `setTimeout`).
5. Capture at `pixelRatio: 3`.
6. Restore original zoom.
7. Show success/error toast.

```typescript
async saveScreenshot(container: HTMLElement | null, outerContainer: HTMLElement | null) {
    if (!container) {
        toast.error('Elemento do fluxograma não encontrado.');
        return;
    }

    const loadingToastId = toast.loading('Capturando fluxograma...');

    const originalZoom = state.zoomLevel;
    try {
        // Calculate optimal zoom to fit content
        const optimalZoom = calculateOptimalZoom(container, outerContainer);
        state.zoomLevel = optimalZoom;

        // Wait for layout to settle
        await new Promise((r) => setTimeout(r, 600));

        const courseName = state.courseData?.nomeCurso ?? 'fluxograma';
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
        const filename = `fluxograma_${courseName.replace(/\s+/g, '_')}_${timestamp}.png`;

        await captureScreenshot(container, filename, { pixelRatio: 3 });
        toast.dismiss(loadingToastId);
        toast.success('Fluxograma salvo com sucesso!');
    } catch {
        toast.dismiss(loadingToastId);
        toast.error('Não foi possível capturar a imagem.');
    } finally {
        state.zoomLevel = originalZoom;
    }
}
```

#### Task 2.2: Implement `calculateOptimalZoom` Helper

**File:** `src/lib/utils/screenshot.ts` (or new file `src/lib/utils/zoom.ts`)

```typescript
export function calculateOptimalZoom(
    content: HTMLElement,
    container: HTMLElement | null
): number {
    const PADDING = 64; // 32px each side
    const SAFETY_FACTOR = 0.45;

    if (!container) return 0.5;

    const containerRect = container.getBoundingClientRect();
    const contentRect = content.getBoundingClientRect();

    const availableW = containerRect.width - PADDING;
    const availableH = containerRect.height - PADDING;
    const contentW = contentRect.width;
    const contentH = contentRect.height;

    if (contentW <= 0 || contentH <= 0) return 0.5;

    const scaleX = availableW / contentW;
    const scaleY = availableH / contentH;
    const zoom = Math.min(scaleX, scaleY) * SAFETY_FACTOR;

    return Math.min(2.0, Math.max(0.1, zoom));
}
```

#### Task 2.3: Pass `outerContainer` Ref to Store

**File:** `src/routes/meu-fluxograma/+page.svelte`

Update the page to also pass the outer container ref (the scrollable div) to the store's `saveScreenshot` call.

**File:** `src/lib/components/fluxograma/FluxogramaHeader.svelte`

Add an `outerContainerRef` prop and pass it through.

---

### Phase 3 — Visual Parity of Captured Content

These changes affect the visual styling of the fluxogram grid so the exported PNG looks like the Flutter output.

#### Task 3.1: Match Container Styling

**File:** `src/lib/components/fluxograma/FluxogramContainer.svelte`

Update the outer container div class:

| Property | Current | Target |
|----------|---------|--------|
| Background | `bg-black/30` | `bg-black/40` |
| Border radius | `rounded-xl` (12px) | `rounded-3xl` (24px) |
| Padding on inner | `p-4` (16px) | `p-8` (32px) |
| Border | `border border-white/10` | Keep (Flutter has none, but border looks fine) |

Change the inner div from `class="relative inline-flex p-4"` to `class="relative inline-flex p-8"`.

#### Task 3.2: Match Semester Header

**File:** `src/lib/components/fluxograma/SemesterColumn.svelte`

| Property | Current | Target |
|----------|---------|--------|
| Text | `"Semestre X"` | `"Xº Semestre"` |
| Background | `bg-black/60` | `bg-white/10` |
| Border | `border border-white/10` | Remove border |
| Border radius | `rounded-lg` (8px) | `rounded-lg` (8px) ✅ |
| Font | `text-xs font-bold uppercase tracking-wider text-white/70` | `text-base font-bold text-white` (Poppins 16px) |
| Backdrop blur | `backdrop-blur-md` | Remove |

Replace:
```svelte
<span class="text-xs font-bold uppercase tracking-wider text-white/70">
    {semester === 0 ? 'Optativas' : `Semestre ${semester}`}
</span>
```
With:
```svelte
<span class="text-base font-bold text-white">
    {semester === 0 ? 'Optativas' : `${semester}º Semestre`}
</span>
```

And update the header container classes from:
```
bg-black/60 border border-white/10 backdrop-blur-md
```
To:
```
bg-white/10
```

#### Task 3.3: Match Card Dimensions & Styling

**File:** `src/lib/components/fluxograma/SubjectCard.svelte`

| Property | Current | Target |
|----------|---------|--------|
| Width | `min-w-[160px]` (flexible) on parent | Fixed `w-48` (192px) on card |
| Border radius | `rounded-xl` (12px) | `rounded-lg` (8px) |
| Shadow | None (uses border) | `shadow-md` or custom `shadow-[0_4px_8px_rgba(0,0,0,0.3)]` |
| Border | `border border-white/10` etc. | Remove border, rely on shadow |

Update `cardClasses` computed:
- Change `rounded-xl border` → `rounded-lg`
- Add `shadow-[0_4px_8px_rgba(0,0,0,0.3)]`
- Change `border-white/10` etc. → keep border for hover/selection states but make default borderless

Also set card width on the semester column level: change `min-w-[160px]` to `w-48` (192px).

#### Task 3.4: Match Card Content Layout

**File:** `src/lib/components/fluxograma/SubjectCard.svelte`

Current card body:
```svelte
<div class="mb-1 flex items-center justify-between gap-1">
    <span class="text-[10px] font-semibold uppercase tracking-wider">{materia.codigoMateria}</span>
    <span class="text-[10px] opacity-60">{materia.creditos}cr</span>
</div>
<p class="line-clamp-2 text-xs font-medium leading-tight">{materia.nomeMateria}</p>
```

Target (matching Flutter):
```svelte
<div>
    <span class="text-sm font-bold text-white">{materia.codigoMateria}</span>
</div>
<p class="mt-1 line-clamp-2 text-xs text-white">{materia.nomeMateria}</p>
<div class="mt-2 flex items-center gap-1">
    <span class="rounded bg-black/20 px-2 py-0.5 text-[10px] text-white">
        {materia.creditos} créditos
    </span>
    {#if userData?.mencao && userData.mencao !== '-'}
        <span class="ml-auto rounded bg-black/20 px-2 py-0.5 text-[10px] text-white">
            {userData.mencao}
        </span>
    {/if}
</div>
```

Key changes:
- Subject code: `text-sm font-bold` (14px bold) instead of `text-[10px] uppercase`
- Subject name: `text-xs text-white` (12px) — similar, keep
- Credits: move to bottom row, pill style (`bg-black/20 rounded px-2 py-0.5`), show "X créditos" not "Xcr"
- Menção: add menção badge in same bottom row (pill style)
- Remove the top-right credits inline

#### Task 3.5: Exact Color Matching

**File:** `src/lib/components/fluxograma/SubjectCard.svelte`

Update the `gradientMap` to use exact Flutter hex colors via Tailwind arbitrary values:

```typescript
const gradientMap: Record<SubjectStatusValue, string> = {
    [SubjectStatusEnum.COMPLETED]: 'from-[#2DC063] to-[#0B7D35]',
    [SubjectStatusEnum.IN_PROGRESS]: 'from-[#A78BFA] to-[#8B5CF6]',
    [SubjectStatusEnum.AVAILABLE]: 'from-[#F59E0B] to-[#D97706]',
    [SubjectStatusEnum.FAILED]: 'from-[#FB7185] to-[#E11D48]',
    [SubjectStatusEnum.LOCKED]: 'from-white/10 to-white/10',
    [SubjectStatusEnum.NOT_STARTED]: 'from-white/10 to-white/10',
};
```

#### Task 3.6: Match Column Spacing

**File:** `src/lib/components/fluxograma/FluxogramContainer.svelte`

Change the gap from `3rem` to `2rem` (32px, matching Flutter's `EdgeInsets.only(right: 32)`) when connections are off:

```svelte
style="gap: {store.state.connectionMode === 'all' ? '6rem' : '2rem'};"
```

**File:** `src/lib/components/fluxograma/SemesterColumn.svelte`

Change `BASE_GAP_REM` from `0.5` to `1` (16px, matching Flutter's `margin-bottom: 16` on each card).

---

### Phase 4 — Button UX Parity

#### Task 4.1: Rename & Restyle the Export Button

**File:** `src/lib/components/fluxograma/FluxogramaHeader.svelte`

Replace:
```svelte
<button onclick={handleScreenshot}
    class="inline-flex items-center gap-2 rounded-full border border-white/10
           bg-black/40 px-4 py-2 text-sm font-medium text-white/80
           backdrop-blur-md transition-colors hover:bg-white/10 hover:text-white">
    <Camera class="h-4 w-4" />
    Screenshot
</button>
```

With a green gradient button matching Flutter:
```svelte
<button onclick={handleScreenshot}
    class="inline-flex items-center gap-2 rounded-lg bg-gradient-to-r
           from-green-500 to-green-600 px-4 py-2.5 text-sm font-bold
           text-white shadow-md transition-all hover:from-green-400
           hover:to-green-500 hover:shadow-lg">
    <Save class="h-4 w-4" />
    Salvar Fluxograma
</button>
```

Import `Save` from `lucide-svelte` instead of `Camera`.

#### Task 4.2: Responsive Button Layout

Match Flutter's responsive behavior:
- **Desktop (≥900px):** "SALVAR FLUXOGRAMA" button on the right
- **Tablet (600–899px):** Same but slightly smaller padding
- **Mobile (<600px):** Full-width row with stacked buttons

This requires updating FluxogramaHeader to use responsive breakpoint classes.

---

### Phase 5 — Filename & Output Format

#### Task 5.1: Match Filename Format

**File:** `src/lib/stores/fluxograma.store.svelte.ts`

Change filename from `{courseName}.png` to `fluxograma_{courseName}_{timestamp}.png`:

```typescript
const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
const filename = `fluxograma_${courseName.replace(/\s+/g, '_')}_${timestamp}.png`;
```

#### Task 5.2: Use 3x Pixel Ratio

Already covered in Task 1.2 and 2.1 — pass `pixelRatio: 3` to `html-to-image`.

---

## Phase Summary & Dependencies

```
Phase 1 (Capture Library)     ← MUST be done first; everything depends on reliable capture
  └─ Task 1.1: Install html-to-image
  └─ Task 1.2: Rewrite screenshot.ts

Phase 2 (Pre-capture Zoom)    ← Can be done right after Phase 1
  └─ Task 2.1: Store saveScreenshot logic
  └─ Task 2.2: calculateOptimalZoom helper
  └─ Task 2.3: Pass outerContainer ref

Phase 3 (Visual Styling)      ← Independent of Phase 2; can be done in parallel
  └─ Task 3.1: Container styling
  └─ Task 3.2: Semester header
  └─ Task 3.3: Card dimensions
  └─ Task 3.4: Card content layout
  └─ Task 3.5: Exact colors
  └─ Task 3.6: Column spacing

Phase 4 (Button UX)           ← Independent; can be done anytime
  └─ Task 4.1: Rename & restyle button
  └─ Task 4.2: Responsive layout

Phase 5 (Output Format)       ← Depends on Phase 1
  └─ Task 5.1: Filename format
  └─ Task 5.2: Pixel ratio
```

---

## Files Modified

| File | Phases |
|------|--------|
| `package.json` | 1 |
| `src/lib/utils/screenshot.ts` | 1, 2 |
| `src/lib/stores/fluxograma.store.svelte.ts` | 2, 5 |
| `src/lib/components/fluxograma/FluxogramaHeader.svelte` | 2, 4 |
| `src/lib/components/fluxograma/FluxogramContainer.svelte` | 3 |
| `src/lib/components/fluxograma/SemesterColumn.svelte` | 3 |
| `src/lib/components/fluxograma/SubjectCard.svelte` | 3 |
| `src/routes/meu-fluxograma/+page.svelte` | 2 |

---

## Testing Checklist

- [ ] `html-to-image` installs without errors
- [ ] Screenshot captures all semester columns with correct gradients
- [ ] Screenshot background is dark (`#0a0a0a` or `black/40`)
- [ ] Cards display subject code (14px bold), name (12px), credits pill, and menção pill
- [ ] Semester headers read "Xº Semestre" with `bg-white/10` pill
- [ ] Cards are 192px wide with 8px border radius and shadow
- [ ] Column gap is 32px (2rem)
- [ ] Exported filename follows `fluxograma_{name}_{timestamp}.png` format
- [ ] Image resolution is 3x (high-DPI / retina quality)
- [ ] Pre-capture zoom fits entire fluxograma, then restores user zoom
- [ ] Loading toast shown during capture
- [ ] Button shows "Salvar Fluxograma" with green gradient and save icon
- [ ] Mobile layout has full-width button row
- [ ] Status colors match Flutter hex values exactly
- [ ] The exported image visually matches a Flutter export side-by-side

---

## Important Notes

1. **Phase 3 changes affect the on-screen appearance too**, not just the export. This is intentional — the in-app grid should also match Flutter's design. If the team wants to keep the current Svelte on-screen look and only change the export, an alternative approach would be to render a hidden "export-only" version of the grid styled like Flutter. This is significantly more complex and not recommended.

2. **`html-to-image` inlines computed styles**, so Tailwind utility classes will be properly captured — unlike the current SVG foreignObject approach.

3. **The Flutter app does NOT include the header, legend, or progress sections** in the export. The Svelte version should maintain this behavior (only capture the grid container).

# Plan 19 — Conexões Behavior Rework

## Goal

Change the "Conexões" toggle from a simple on/off to a tri-state system with a dropdown, and decouple hover highlighting from connection lines.

## Current Behavior

| `showConnections` | Card hovered? | SVG Lines | Card Visual Effect |
|:-:|:-:|---|---|
| OFF | No | None | All cards full opacity |
| OFF | Yes | Prereqs (purple) + dependents (teal) lines drawn | Hovered + related = bright; others = 40%; colored dots on related cards |
| ON | No | **All** prereq lines + **all** co-req lines | All cards full opacity |
| ON | Yes | Only hovered card's prereqs + dependents (overrides showAll) | Hovered + related = bright; others = 40% |

## Desired Behavior

| `connectionMode` | Card hovered? | SVG Lines | Card Visual Effect |
|:-:|:-:|---|---|
| `'off'` | No | None | All cards full opacity |
| `'off'` | Yes | **None** | **Only** a light highlight on the hovered card (e.g. brighter border/glow). **No dimming** of other cards. No colored dots. |
| `'direct'` | No | None | All cards full opacity |
| `'direct'` | Yes | Prereqs (purple) + dependents (teal) of hovered card | Hovered + related = bright; others = 40%; colored dots on related cards |
| `'all'` | No | **All** prereq + co-req lines | All cards full opacity |
| `'all'` | Yes | Only hovered card's prereqs + dependents (overrides showAll) | Hovered + related = bright; others = 40% |

**Summary of changes:**
- Default OFF: hovering does nothing except lightly highlight the hovered card itself — no lines, no dimming, no relationship highlighting.
- "Conexões diretas": the current hover behavior (show direct prereqs + dependents on hover).
- "Todas as conexões": the current `showConnections = true` behavior (show all lines, hover overrides to show focused view).

---

## Files to Modify

### 1. `src/lib/stores/fluxograma.store.svelte.ts`

**Changes:**
- Replace `showConnections: boolean` with `connectionMode: ConnectionMode` where:
  ```typescript
  type ConnectionMode = 'off' | 'direct' | 'all';
  ```
- Add the type export.
- Replace `toggleConnections()` with `setConnectionMode(mode: ConnectionMode)`.
- Add a convenience getter: `get showConnections()` → `this.state.connectionMode !== 'off'` (for backward compat in legend).
- Update `reset()` to set `connectionMode: 'off'`.

### 2. `src/lib/components/fluxograma/FluxogramaLegendControls.svelte`

**Changes:**
- Replace the single "Conexões" toggle button with a button + dropdown group:
  - When `connectionMode === 'off'`: button appears in the default (inactive) style.
  - Clicking the button cycles to `'direct'` (enabling connections).
  - When `connectionMode !== 'off'`: the button appears active (purple), and a **dropdown** appears next to it with two options:
    - `Conexões diretas` (selected when mode is `'direct'`)
    - `Todas as conexões` (selected when mode is `'all'`)
  - Clicking the button again when active turns connections off.
- The connection-type legend (prereq/dependent/co-req line samples) should still only show when `connectionMode !== 'off'`.
- Co-req legend line should only show when `connectionMode === 'all'`.

**UI approach — dropdown design:**
- Use a small inline segmented control or a `<select>`-style dropdown that appears to the right of the Conexões button when active.
- Recommended: a pair of small pills/tabs that appear inline, e.g.:
  ```
  [🔗 Conexões ▾] [ Diretas | Todas ]
  ```
- Or a popover dropdown that appears below the button on click.
- Either approach works — pills/tabs inline is simpler and avoids click-outside handling.

### 3. `src/lib/components/fluxograma/PrerequisiteConnections.svelte`

**Changes in `calculateConnections()`:**
- Replace references from `showAll` (derived from `showConnections`) to use `connectionMode`:
  - `connectionMode === 'off'`: 
    - **No lines at all**, even on hover. Return empty `lines = []`.
  - `connectionMode === 'direct'`:
    - No lines when nothing is hovered.
    - On hover: draw prerequisite + dependent lines for the hovered card only (current hover behavior).
  - `connectionMode === 'all'`:
    - When nothing is hovered: draw all prerequisite + co-requisite lines (current `showAll` behavior).
    - On hover: draw only hovered card's prereqs + dependents (current hover-overrides-showAll behavior).

### 4. `src/lib/components/fluxograma/SubjectCard.svelte`

**Changes:**
- Modify hover/highlight logic based on `connectionMode`:
  - When `connectionMode === 'off'`:
    - `onmouseenter` still sets `hoveredSubjectCode` (for the light highlight).
    - `isHighlighted` = only `isHovered` (not prereqs/dependents).
    - `dimmed` logic: **no dimming** — all other cards stay at full opacity.
    - No colored dots (purple/teal) on related cards.
    - The hovered card gets a subtle visual boost (e.g. `border-white/30` or a soft glow), distinct from the connection-mode highlight.
  - When `connectionMode === 'direct'` or `'all'`:
    - Keep current behavior: `isHighlighted = isHovered || isPrereqOfHovered || isDependentOfHovered`, dimming at 40%, colored dots.

**Implementation detail — derived value changes:**
```typescript
// Current
const dimmed = store.state.hoveredSubjectCode && !isHighlighted ? 'opacity-40' : 'opacity-100';

// New
const connectionsEnabled = store.state.connectionMode !== 'off';
const dimmed = connectionsEnabled && store.state.hoveredSubjectCode && !isHighlighted
  ? 'opacity-40'
  : 'opacity-100';
```

For the light highlight in `off` mode:
```typescript
const lightHighlight = !connectionsEnabled && isHovered ? 'ring-1 ring-white/20' : '';
```

### 5. `src/lib/components/fluxograma/FluxogramContainer.svelte`

**Changes:**
- The `PrerequisiteConnections` component is conditionally rendered or always present — either way, the logic inside it handles the mode. No major changes needed here, but verify it passes the right reactive props.

---

## Implementation Steps

### Step 1: Update the Store
1. Add `ConnectionMode` type.
2. Replace `showConnections: boolean` with `connectionMode: ConnectionMode` (default `'off'`).
3. Replace `toggleConnections()` with `setConnectionMode(mode: ConnectionMode)`.
4. Add a convenience computed/getter `showConnections` that returns `connectionMode !== 'off'` for gradual migration.
5. Update `reset()`.

### Step 2: Update SubjectCard Hover Logic
1. Import `ConnectionMode` or read `connectionMode` from store.
2. Adjust `isHighlighted` derivation: when `connectionMode === 'off'`, only `isHovered` matters.
3. Adjust `dimmed` derivation: no dimming when `connectionMode === 'off'`.
4. Suppress colored dots when `connectionMode === 'off'`.
5. Add light highlight styling for `off` mode hover.

### Step 3: Update PrerequisiteConnections
1. Read `connectionMode` instead of `showConnections`.
2. Adjust `calculateConnections()`:
   - `'off'` → always return `[]`.
   - `'direct'` → lines only on hover (current hover logic).
   - `'all'` → all lines when idle, focused lines on hover.

### Step 4: Update FluxogramaLegendControls
1. Replace single toggle with button + inline dropdown.
2. Button click toggles between `'off'` and `'direct'`.
3. When active, show dropdown/pills to switch between `'direct'` and `'all'`.
4. Update connection legend visibility:
   - Show prereq/dependent legend when mode is `'direct'` or `'all'`.
   - Show co-req legend only when mode is `'all'`.

### Step 5: Test & Polish
1. Verify hover in `off` mode: only light highlight, no lines, no dimming.
2. Verify hover in `direct` mode: lines + dimming + dots as before.
3. Verify `all` mode idle: all lines visible.
4. Verify `all` mode hover: focused lines replace all lines.
5. Mobile: long-press should respect the active mode.
6. Verify legend updates correctly per mode.

---

## Edge Cases

- **Mobile long-press**: should work the same way — if `connectionMode === 'off'`, long-press highlights but doesn't show lines.
- **URL/state persistence**: if connection mode is persisted anywhere, update the serialization.
- **Anonymous mode**: verify `isAnonymous` state doesn't conflict with new connection modes.
- **Transition animations**: existing line transitions should still work regardless of mode.

## Risk Assessment

- **Low risk**: The change is UI-only, no backend changes.
- **Store change**: renaming `showConnections` → `connectionMode` may break references. Use grep to find all usages.
- **Backward compat**: the convenience `showConnections` getter eases migration, but long-term all references should use `connectionMode`.

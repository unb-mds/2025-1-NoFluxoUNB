# Plan 20 — Connection Line Routing Improvements

## Problem

In "Todas as conexões" mode, lines between non-sequential semesters (e.g., semester 1 → semester 4) overlap with subject blocks in intermediate semesters. Additionally, multiple lines sharing the same vertical gap between columns stack on top of each other, making the diagram unreadable.

### Root Causes

1. **Single midpoint routing**: The current `getRoutedPath` places the vertical segment at `midX = (x1 + x2) / 2`, which for non-adjacent semesters (e.g., sem 1 → sem 4) lands right in the middle of semester 2–3 columns, overlapping their cards.

2. **No gap awareness**: The routing scans for "clear channels" but searches the entire `x1..x2` range, not knowing where the actual gaps between columns are. It can pick an X that's inside a column.

3. **No line separation**: Multiple lines that route through the same gap use the same X position, causing them to overlap each other.

---

## Solution: Gap-Based Multi-Segment Routing with Lane Assignment

### Core Idea

Instead of routing through a single midpoint, detect where the **actual gaps** between semester columns are, and route lines through those gaps — stepping through intermediate gaps when spanning multiple semesters. Within each gap, assign **lanes** so parallel vertical segments don't overlap.

### Architecture

```
Semester 1  │ GAP │ Semester 2  │ GAP │ Semester 3  │ GAP │ Semester 4
            │     │             │     │             │     │
   [Card]───┤  │  │             │     │             │  │  ├───[Card]
            │  │  │             │     │             │  │  │
            │  └──┼─────────────┼─────┼─────────────┼──┘  │
```

For a connection from Semester 1 → Semester 4:
- Exit right edge of source card
- Enter Gap 1 (between sem 1-2), go vertical to a transit Y
- Cross through Gap 2 (between sem 2-3) horizontally at transit Y
- Cross through Gap 3 (between sem 3-4) horizontally at transit Y
- Enter left edge of target card from Gap 3

---

## Implementation Steps

### Step 1: Detect Column Gaps

Collect the bounding boxes of semester columns (`.semester-column` elements) and compute the gaps between them.

```typescript
interface ColumnGap {
  index: number;      // gap index (0 = before first gap after col 1)
  leftX: number;      // right edge of left column
  rightX: number;     // left edge of right column
  centerX: number;    // midpoint of gap
  width: number;      // gap width
}

function collectColumnGaps(containerEl, containerRect, zoom): ColumnGap[] {
  const columns = containerEl.querySelectorAll('.semester-column');
  // Sort by X position
  // For each consecutive pair, compute the gap
}
```

### Step 2: Determine Which Gaps a Line Must Cross

For a connection from source card (in column A) to target card (in column B):
- Find which column each card belongs to (by checking which column's bounding box contains the card)
- The line must route through all gaps between column A and column B
- The vertical segment should be in the **first gap** (right after the source column) — this keeps lines close to their origin and avoids crossing intermediate columns

### Step 3: Lane Assignment Within Gaps

Multiple lines may need to use the same gap for their vertical segment. Assign each line a **lane** (an X offset within the gap) so they don't overlap.

```typescript
interface GapLaneAssignment {
  gapIndex: number;
  laneX: number;      // actual X position within the gap
}
```

**Algorithm:**
1. Group all lines by which gap they use for their vertical segment
2. Within each gap, sort lines by their Y-span (or by source Y)
3. Distribute lanes evenly across the gap width with padding:
   - `laneWidth = gapWidth / (numLanes + 1)`
   - `laneX[i] = gap.leftX + laneWidth * (i + 1)`
4. Minimum padding between lanes: ~6px

### Step 4: Multi-Segment Path Building

For a line from (x1,y1) in column A to (x2,y2) in column B:

**Case 1: Adjacent columns (A+1 = B)**
Same as current routing but use the gap's lane X instead of midpoint:
```
(x1,y1) → horizontal → (laneX, y1) → vertical → (laneX, y2) → horizontal → (x2, y2)
```

**Case 2: Non-adjacent columns (B > A+1)**
Choose a transit Y that's outside the card area (above all cards or below all cards):
```
(x1,y1) → horizontal → (gap1.laneX, y1) → vertical → (gap1.laneX, transitY)
→ horizontal across all intermediate gaps at transitY →
(gapN.laneX, transitY) → vertical → (gapN.laneX, y2) → horizontal → (x2,y2)
```

Where `gapN` is the last gap before the target column.

**Transit Y selection:**
- For lines going downward: route above both cards (`transitY = min(y1, y2) - offset`)
- For lines going upward: route below both cards (`transitY = max(y1, y2) + offset`)
- Apply lane-based offset to transit Y too if multiple lines share the same horizontal corridor
- Clamp transitY to stay within the SVG bounds (add padding to SVG height if needed)

### Step 5: Horizontal Lane Separation

Multiple lines crossing the same intermediate columns at the same transit Y need vertical separation:

1. Group lines by their horizontal corridor (same set of intermediate gaps)
2. Offset each line's transit Y by `lineIndex * LANE_SPACING` (e.g., 8px)
3. This ensures parallel horizontal cables don't stack on top of each other

### Step 6: Rounded Corners

Keep the existing `Q` (quadratic Bezier) corners at each turn, with radius capped at half the available space.

---

## Data Flow

```
calculateConnections()
  ├── collectColumnGaps()          → ColumnGap[]
  ├── For each connection line:
  │     ├── findSourceColumn()
  │     ├── findTargetColumn()
  │     ├── Determine gap path (which gaps to cross)
  │     └── Store gap routing info on the line
  ├── assignLanes(lines, gaps)     → Each line gets lane assignments
  └── Store lines with routing metadata

getPath(line)
  ├── If adjacent columns: single-gap routed path
  └── If non-adjacent: multi-segment path through gaps
```

---

## Modified Interfaces

```typescript
interface ConnectionLine {
  x1: number; y1: number;
  x2: number; y2: number;
  type: 'prerequisite' | 'dependent' | 'corequisite';
  isAllMode?: boolean;
  fromCode: string;
  toCode: string;
  // New routing metadata (populated for all-mode lines):
  routing?: {
    verticalGapIndex: number;   // which gap has the vertical segment
    laneX: number;              // X position within that gap
    transitY?: number;          // Y for horizontal crossing (non-adjacent only)
    entryGapIndex?: number;     // gap before target column (non-adjacent)
    entryLaneX?: number;        // X in entry gap
  };
}
```

---

## Files to Modify

### `PrerequisiteConnections.svelte`
- Add `collectColumnGaps()` function
- Add `assignLanes()` function  
- Modify `calculateConnections()` to compute routing metadata after collecting all lines
- Replace `getRoutedPath()` with gap-aware multi-segment routing
- Add `buildMultiGapPath()` for non-adjacent connections

### `FluxogramContainer.svelte`
- Potentially increase gap further if lane count exceeds available width (dynamic gap sizing based on max lines per gap)

### `SemesterColumn.svelte`
- No changes needed (`.semester-column` class is already queryable)

---

## Edge Cases

- **Same-column connections** (co-requisites within same semester): Route outside the column (left or right) with a U-shaped path
- **Very large Y differences**: Ensure transit Y stays within SVG bounds; expand SVG height if needed
- **Reverse connections** (target is left of source): Handle by routing left instead of right
- **Single line in a gap**: Center it in the gap
- **Many lines in one gap**: If lanes would be < 4px apart, increase gap width dynamically or cap the distribution

## Performance

- Gap detection and lane assignment add O(lines × gaps) work, but gap count is typically ≤15 (number of semesters) and line count is typically ≤100, so this is negligible
- No DOM queries beyond what's already done (column querySelector is fast)

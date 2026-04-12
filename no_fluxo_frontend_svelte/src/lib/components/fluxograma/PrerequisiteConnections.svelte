<script lang="ts">
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { browser } from '$app/environment';
	import {
		CHAIN_VISUAL,
		classifyChainPrereqStroke,
		getSubjectChain
	} from '$lib/utils/curriculum-graph';

	const store = fluxogramaStore;

	function normSubjectCode(code: string): string {
		return (code || '').trim().toUpperCase();
	}

	/** Evita falha de querySelector por casing ou caracteres especiais no código. */
	function findCardBySubjectCode(containerEl: HTMLElement, code: string): HTMLElement | null {
		const needle = normSubjectCode(code);
		if (!needle) return null;
		for (const el of containerEl.querySelectorAll('[data-subject-code]')) {
			const attr = el.getAttribute('data-subject-code');
			if (attr != null && normSubjectCode(attr) === needle) return el as HTMLElement;
		}
		return null;
	}

	/** Distância horizontal máxima (px, coords SVG) para tratar como mesma coluna / mesmo semestre. */
	const SAME_COLUMN_DX_PX = 42;

	interface ConnectionLine {
		x1: number;
		y1: number;
		x2: number;
		y2: number;
		type: 'prerequisite' | 'dependent' | 'corequisite';
		/** Modo diretas + cadeia transitiva no hover */
		chainStroke?: 'pre' | 'desc' | 'core';
		isAllMode?: boolean;
		fromCode: string;
		toCode: string;
		/** Pré-req e dependente empilhados na mesma coluna (seta “por fora”, mais legível). */
		sameColumnStack?: boolean;
		// Routing metadata for gap-based routing (populated in all-mode)
		routing?: RoutingInfo;
	}

	interface RoutingInfo {
		exitGapIndex: number;       // gap right after source column
		entryGapIndex: number;      // gap right before target column
		exitLaneX: number;          // X for vertical segment in exit gap
		entryLaneX: number;         // X for vertical segment in entry gap
		transitY: number;           // Y for horizontal crossing (non-adjacent)
		isAdjacent: boolean;        // whether source and target columns are adjacent
	}

	interface ColumnGap {
		index: number;
		leftX: number;    // right edge of left column
		rightX: number;   // left edge of right column
		centerX: number;
		width: number;
	}

	interface ColumnRect {
		index: number;
		left: number;
		right: number;
		top: number;
		bottom: number;
	}

	let lines = $state<ConnectionLine[]>([]);
	let svgWidth = $state(0);
	let svgHeight = $state(0);

	interface Props {
		container?: HTMLElement | null;
	}

	let { container = null }: Props = $props();

	let columnGaps = $state<ColumnGap[]>([]);
	let columnRects = $state<ColumnRect[]>([]);

	/** Invalida follow-ups agendados quando um novo cálculo “principal” roda (evita corridas). */
	let followUpGeneration = 0;
	let followUpRaf1 = 0;
	let followUpRaf2 = 0;
	let followUpTimeout: ReturnType<typeof setTimeout> | null = null;

	function cancelScheduledFollowUps() {
		if (followUpRaf1) cancelAnimationFrame(followUpRaf1);
		if (followUpRaf2) cancelAnimationFrame(followUpRaf2);
		if (followUpTimeout) clearTimeout(followUpTimeout);
		followUpRaf1 = 0;
		followUpRaf2 = 0;
		followUpTimeout = null;
	}

	/**
	 * No modo "todas", `computeAndSetDensity` e as transições de `gap` (flex entre colunas e entre
	 * cards) mudam o layout depois do primeiro paint. Um único rAF mede cedo demais; precisamos
	 * remediar após reflow e após ~300ms (fim da transição CSS).
	 */
	function scheduleFollowUpsAfterDensity() {
		cancelScheduledFollowUps();
		const gen = ++followUpGeneration;
		followUpRaf1 = requestAnimationFrame(() => {
			followUpRaf1 = 0;
			followUpRaf2 = requestAnimationFrame(() => {
				followUpRaf2 = 0;
				if (gen !== followUpGeneration) return;
				calculateConnections(false);
			});
		});
		followUpTimeout = setTimeout(() => {
			followUpTimeout = null;
			if (gen !== followUpGeneration) return;
			calculateConnections(false);
		}, 360);
	}

	// ─── Gap & Column Detection ───────────────────────────────────────

	function collectColumnsAndGaps(containerEl: HTMLElement, containerRect: DOMRect, zoom: number) {
		const columns = Array.from(containerEl.querySelectorAll('.semester-column'));
		const rects: ColumnRect[] = columns.map((col, i) => {
			const r = col.getBoundingClientRect();
			return {
				index: i,
				left: (r.left - containerRect.left) / zoom,
				right: (r.right - containerRect.left) / zoom,
				top: (r.top - containerRect.top) / zoom,
				bottom: (r.bottom - containerRect.top) / zoom
			};
		}).sort((a, b) => a.left - b.left);

		const gaps: ColumnGap[] = [];
		for (let i = 0; i < rects.length - 1; i++) {
			const leftX = rects[i].right;
			const rightX = rects[i + 1].left;
			gaps.push({
				index: i,
				leftX,
				rightX,
				centerX: (leftX + rightX) / 2,
				width: rightX - leftX
			});
		}

		columnRects = rects;
		columnGaps = gaps;
	}

	/**
	 * Find which column a card belongs to by its X center position.
	 */
	function findColumnIndex(cardCenterX: number): number {
		for (let i = 0; i < columnRects.length; i++) {
			if (cardCenterX >= columnRects[i].left && cardCenterX <= columnRects[i].right) {
				return i;
			}
		}
		// Fallback: find closest column
		let best = 0;
		let bestDist = Infinity;
		for (let i = 0; i < columnRects.length; i++) {
			const center = (columnRects[i].left + columnRects[i].right) / 2;
			const dist = Math.abs(cardCenterX - center);
			if (dist < bestDist) {
				bestDist = dist;
				best = i;
			}
		}
		return best;
	}

	// ─── Lane Assignment ──────────────────────────────────────────────

	const LANE_PADDING = 6; // minimum px between parallel lines in a gap
	const TRANSIT_Y_PADDING = 8; // px between parallel horizontal transit lines

	/**
	 * Assign lanes to all lines that use a given gap for their vertical segment.
	 * Returns a Map from line index to lane X position.
	 */
	function assignLanesForGap(
		linesInGap: { lineIndex: number; y1: number; y2: number }[],
		gap: ColumnGap
	): Map<number, number> {
		const result = new Map<number, number>();
		if (linesInGap.length === 0) return result;

		// Sort by midpoint Y so nearby lines get nearby lanes
		const sorted = [...linesInGap].sort((a, b) => {
			const midA = (a.y1 + a.y2) / 2;
			const midB = (b.y1 + b.y2) / 2;
			return midA - midB;
		});

		const usableWidth = gap.width - LANE_PADDING * 2;
		const count = sorted.length;

		if (count === 1) {
			result.set(sorted[0].lineIndex, gap.centerX);
		} else {
			const spacing = Math.max(usableWidth / (count - 1), LANE_PADDING);
			const startX = gap.centerX - (spacing * (count - 1)) / 2;
			for (let i = 0; i < count; i++) {
				result.set(sorted[i].lineIndex, startX + spacing * i);
			}
		}

		return result;
	}

	/**
	 * Assign transit Y offsets for non-adjacent lines sharing the same corridor.
	 * Groups lines by their gap range and separates their transit Y values.
	 */
	function assignTransitYValues(
		allLines: ConnectionLine[],
		lineRoutingData: Map<number, { sourceCol: number; targetCol: number }>
	): Map<number, number> {
		const result = new Map<number, number>();

		// Group non-adjacent lines by their corridor (exitGap..entryGap range)
		const corridors = new Map<string, { lineIndex: number; y1: number; y2: number }[]>();

		for (const [lineIdx, data] of lineRoutingData) {
			if (data.targetCol - data.sourceCol <= 1) continue; // adjacent, no transit needed

			const line = allLines[lineIdx];
			const key = `${data.sourceCol}-${data.targetCol}`;
			if (!corridors.has(key)) corridors.set(key, []);
			corridors.get(key)!.push({ lineIndex: lineIdx, y1: line.y1, y2: line.y2 });
		}

		for (const [, linesInCorridor] of corridors) {
			// Sort by average Y
			const sorted = [...linesInCorridor].sort((a, b) => {
				const avgA = (a.y1 + a.y2) / 2;
				const avgB = (b.y1 + b.y2) / 2;
				return avgA - avgB;
			});

			// Find the topmost card Y across all these lines to place transit above it
			const allY = sorted.flatMap(l => [l.y1, l.y2]);
			const minY = Math.min(...allY);
			const maxY = Math.max(...allY);

			// Decide: route above if most lines go downward, below if most go upward
			// Simple heuristic: use above (negative Y offset from minY)
			const baseTransitY = minY - 30; // 30px above the topmost card center

			for (let i = 0; i < sorted.length; i++) {
				result.set(sorted[i].lineIndex, baseTransitY - i * TRANSIT_Y_PADDING);
			}
		}

		return result;
	}

	// ─── Main Calculation ─────────────────────────────────────────────

	function calculateConnections(allowFollowUp = true) {
		if (!browser || !container) {
			lines = [];
			return;
		}

		const hoveredCode =
			store.state.hoverPreviewSubjectCode ?? store.state.hoveredSubjectCode;
		const connectionMode = store.state.connectionMode;
		const courseData = store.state.courseData;

		if (connectionMode === 'off' || !courseData) {
			lines = [];
			if (allowFollowUp) {
				followUpGeneration++;
				cancelScheduledFollowUps();
			}
			return;
		}

		if (connectionMode === 'direct' && !hoveredCode) {
			lines = [];
			if (allowFollowUp) {
				followUpGeneration++;
				cancelScheduledFollowUps();
			}
			return;
		}

		const containerRect = container.getBoundingClientRect();
		svgWidth = container.scrollWidth;
		svgHeight = container.scrollHeight;

		const zoom = store.state.zoomLevel || 1;
		const isAllMode = connectionMode === 'all';

		if (isAllMode) {
			collectColumnsAndGaps(container, containerRect, zoom);
		} else {
			columnGaps = [];
			columnRects = [];
		}

		const newLines: ConnectionLine[] = [];

		if (hoveredCode && connectionMode === 'direct') {
			const chain = getSubjectChain(courseData, hoveredCode);
			if (!chain) {
				lines = [];
				if (allowFollowUp) {
					followUpGeneration++;
					cancelScheduledFollowUps();
				}
				return;
			}

			const S = chain.chainNodeSet;
			const M = chain.focusCode;
			const P = chain.precursors;
			const D = chain.descendants;

			for (const materia of courseData.materias) {
				const v = normSubjectCode(materia.codigoMateria);
				if (!S.has(v)) continue;
				for (const prereq of materia.preRequisitos ?? []) {
					const u = normSubjectCode(prereq.codigoMateria);
					if (!S.has(u)) continue;
					const stroke = classifyChainPrereqStroke(u, v, M, P, D);
					const line = getLineBetweenCards(
						prereq.codigoMateria,
						materia.codigoMateria,
						container,
						containerRect,
						stroke === 'desc' ? 'dependent' : 'prerequisite',
						false
					);
					if (line) {
						line.chainStroke = stroke;
						newLines.push(line);
					}
				}
			}

			if (courseData.coRequisitos?.length) {
				const materiaMap = new Map(courseData.materias.map((m) => [m.idMateria, m]));
				const drawnPairs = new Set<string>();
				for (const coReq of courseData.coRequisitos) {
					const fromMateria = materiaMap.get(coReq.idMateria);
					if (!fromMateria) continue;
					const a = normSubjectCode(fromMateria.codigoMateria);
					const b = coReq.codigoMateriaCoRequisito
						? normSubjectCode(coReq.codigoMateriaCoRequisito)
						: '';
					if (!b || !S.has(a) || !S.has(b)) continue;
					const pairKey = [a, b].sort().join('\0');
					if (drawnPairs.has(pairKey)) continue;
					drawnPairs.add(pairKey);
					const line = getLineBetweenCards(
						fromMateria.codigoMateria,
						coReq.codigoMateriaCoRequisito,
						container,
						containerRect,
						'corequisite',
						false
					);
					if (line) {
						line.chainStroke = 'core';
						newLines.push(line);
					}
				}
			}
		} else if (connectionMode === 'all') {
			for (const materia of courseData.materias) {
				if (materia.preRequisitos) {
					for (const prereq of materia.preRequisitos) {
						const line = getLineBetweenCards(
							prereq.codigoMateria, materia.codigoMateria,
							container, containerRect, 'prerequisite', true
						);
						if (line) newLines.push(line);
					}
				}
			}

			if (courseData.coRequisitos) {
				const materiaMap = new Map(courseData.materias.map((m) => [m.idMateria, m]));
				const drawnPairs = new Set<string>();
				for (const coReq of courseData.coRequisitos) {
					const fromMateria = materiaMap.get(coReq.idMateria);
					if (!fromMateria) continue;
					const pairKey = [fromMateria.codigoMateria, coReq.codigoMateriaCoRequisito].sort().join('-');
					if (drawnPairs.has(pairKey)) continue;
					drawnPairs.add(pairKey);
					const line = getLineBetweenCards(
						fromMateria.codigoMateria, coReq.codigoMateriaCoRequisito,
						container, containerRect, 'corequisite', true
					);
					if (line) newLines.push(line);
				}
			}

			// Assign routing metadata for all-mode lines
			if (columnGaps.length > 0) {
				assignRoutingToLines(newLines);
			}
		}

		lines = newLines;

		// Compute per-semester connection density and push to store
		if (connectionMode === 'all' && courseData) {
			computeAndSetDensity(newLines, courseData);
			if (allowFollowUp) {
				scheduleFollowUpsAfterDensity();
			}
		} else {
			store.setConnectionDensity(new Map());
			if (allowFollowUp) {
				followUpGeneration++;
				cancelScheduledFollowUps();
			}
		}
	}

	/**
	 * Count connections per semester and push to the store.
	 * For each line, increment count for both the source and target subject's semester.
	 */
	function computeAndSetDensity(allLines: ConnectionLine[], courseData: { materias: { codigoMateria: string }[] }) {
		// code → semestre exibido (optativa planejada sobrepõe nivel 0 da matriz no mapa)
		const codeToSemester = new Map<string, number>();
		const plannedSem = store.optativaPlanejadaSemestrePorCodigo;
		for (const [sem, subjects] of store.subjectsBySemester) {
			for (const s of subjects) {
				const u = s.codigoMateria.trim().toUpperCase();
				const displaySem = plannedSem.get(u) ?? sem;
				codeToSemester.set(u, displaySem);
			}
		}

		const density = new Map<number, number>();
		for (const line of allLines) {
			const fromSem = codeToSemester.get(line.fromCode.trim().toUpperCase());
			const toSem = codeToSemester.get(line.toCode.trim().toUpperCase());
			if (fromSem !== undefined) {
				density.set(fromSem, (density.get(fromSem) ?? 0) + 1);
			}
			if (toSem !== undefined) {
				density.set(toSem, (density.get(toSem) ?? 0) + 1);
			}
		}

		store.setConnectionDensity(density);
	}

	/**
	 * Compute routing metadata for all lines in 'all' mode.
	 * Detects which gaps each line crosses, assigns lanes, and transit Y values.
	 */
	function assignRoutingToLines(allLines: ConnectionLine[]) {
		// Step 1: Determine source/target column for each line
		const lineColData = new Map<number, { sourceCol: number; targetCol: number }>();

		for (let i = 0; i < allLines.length; i++) {
			const line = allLines[i];
			if (!line.isAllMode) continue;

			const sourceCol = findColumnIndex(line.x1 - 10); // x1 is right edge, shift left
			const targetCol = findColumnIndex(line.x2 + 10); // x2 is left edge, shift right

			// Ensure source < target for consistent routing
			const sCol = Math.min(sourceCol, targetCol);
			const tCol = Math.max(sourceCol, targetCol);

			lineColData.set(i, { sourceCol: sCol, targetCol: tCol });
		}

		// Step 2: Group lines by their exit gap (gap right after source column)
		const exitGapLines = new Map<number, { lineIndex: number; y1: number; y2: number }[]>();
		const entryGapLines = new Map<number, { lineIndex: number; y1: number; y2: number }[]>();

		for (const [lineIdx, data] of lineColData) {
			const line = allLines[lineIdx];
			const exitGapIdx = Math.min(data.sourceCol, columnGaps.length - 1);
			let entryGapIdx = Math.min(data.targetCol - 1, columnGaps.length - 1);
			// Mesma coluna ou alvo na 1ª coluna: o vão útil é o à direita da coluna (evita índice -1).
			if (data.sourceCol === data.targetCol || entryGapIdx < 0) {
				entryGapIdx = exitGapIdx;
			}

			if (exitGapIdx < 0 || entryGapIdx < 0) continue;

			if (data.targetCol - data.sourceCol <= 1) {
				// Adjacent: single gap, use exit gap for the vertical segment
				if (!exitGapLines.has(exitGapIdx)) exitGapLines.set(exitGapIdx, []);
				exitGapLines.get(exitGapIdx)!.push({ lineIndex: lineIdx, y1: line.y1, y2: line.y2 });
			} else {
				// Non-adjacent: separate exit and entry gaps
				if (!exitGapLines.has(exitGapIdx)) exitGapLines.set(exitGapIdx, []);
				exitGapLines.get(exitGapIdx)!.push({ lineIndex: lineIdx, y1: line.y1, y2: line.y2 });

				if (!entryGapLines.has(entryGapIdx)) entryGapLines.set(entryGapIdx, []);
				entryGapLines.get(entryGapIdx)!.push({ lineIndex: lineIdx, y1: line.y1, y2: line.y2 });
			}
		}

		// Step 3: Assign lanes within each gap
		const exitLanes = new Map<number, number>(); // lineIndex → laneX
		const entryLanes = new Map<number, number>();

		for (const [gapIdx, linesInGap] of exitGapLines) {
			if (gapIdx >= columnGaps.length) continue;
			const lanes = assignLanesForGap(linesInGap, columnGaps[gapIdx]);
			for (const [lineIdx, laneX] of lanes) {
				exitLanes.set(lineIdx, laneX);
			}
		}

		for (const [gapIdx, linesInGap] of entryGapLines) {
			if (gapIdx >= columnGaps.length) continue;
			const lanes = assignLanesForGap(linesInGap, columnGaps[gapIdx]);
			for (const [lineIdx, laneX] of lanes) {
				entryLanes.set(lineIdx, laneX);
			}
		}

		// Step 4: Assign transit Y values for non-adjacent lines
		const transitYValues = assignTransitYValues(allLines, lineColData);

		// Step 5: Attach routing info to each line
		for (const [lineIdx, data] of lineColData) {
			const line = allLines[lineIdx];
			const exitGapIdx = Math.min(data.sourceCol, columnGaps.length - 1);
			let entryGapIdx = Math.min(data.targetCol - 1, columnGaps.length - 1);
			if (data.sourceCol === data.targetCol || entryGapIdx < 0) {
				entryGapIdx = exitGapIdx;
			}
			const isAdjacent = data.targetCol - data.sourceCol <= 1;

			if (exitGapIdx < 0 || entryGapIdx < 0) continue;

			const exitLaneX = exitLanes.get(lineIdx) ?? columnGaps[exitGapIdx]?.centerX ?? (line.x1 + line.x2) / 2;
			const entryLaneX = isAdjacent
				? exitLaneX
				: (entryLanes.get(lineIdx) ?? columnGaps[entryGapIdx]?.centerX ?? (line.x1 + line.x2) / 2);

			const transitY = transitYValues.get(lineIdx) ?? Math.min(line.y1, line.y2) - 30;

			line.routing = {
				exitGapIndex: exitGapIdx,
				entryGapIndex: entryGapIdx,
				exitLaneX,
				entryLaneX,
				transitY,
				isAdjacent
			};
		}
	}

	// ─── Card Lookup ──────────────────────────────────────────────────

	function getLineBetweenCards(
		fromCode: string,
		toCode: string,
		containerEl: HTMLElement,
		containerRect: DOMRect,
		type: 'prerequisite' | 'dependent' | 'corequisite',
		isAllMode: boolean = false
	): ConnectionLine | null {
		const fromCard = findCardBySubjectCode(containerEl, fromCode);
		const toCard = findCardBySubjectCode(containerEl, toCode);

		if (!fromCard || !toCard) return null;

		const fromRect = fromCard.getBoundingClientRect();
		const toRect = toCard.getBoundingClientRect();
		const zoom = store.state.zoomLevel || 1;

		const x1 = (fromRect.right - containerRect.left) / zoom;
		const y1 = (fromRect.top + fromRect.height / 2 - containerRect.top) / zoom;
		const x2 = (toRect.left - containerRect.left) / zoom;
		const y2 = (toRect.top + toRect.height / 2 - containerRect.top) / zoom;

		const dx = Math.abs(x2 - x1);
		const dy = Math.abs(y2 - y1);
		const sameColumnStack = dx < SAME_COLUMN_DX_PX && dy > 10;

		return { x1, y1, x2, y2, type, isAllMode, fromCode, toCode, sameColumnStack };
	}

	// ─── Path Generation ──────────────────────────────────────────────

	/**
	 * Mesmo semestre / mesma coluna: “U” à direita dos cards para não sobrepor o texto e manter a seta visível.
	 */
	function buildSameColumnStackPath(x1: number, y1: number, x2: number, y2: number): string {
		const outward = 36;
		const midX = Math.max(x1, x2) + outward;
		const r = 14;
		const dir = y2 >= y1 ? 1 : -1;
		// Desce (ou sobe) pelo corredor vertical à direita da coluna
		return [
			`M ${x1} ${y1}`,
			`L ${midX - r} ${y1}`,
			`Q ${midX} ${y1} ${midX} ${y1 + r * dir}`,
			`L ${midX} ${y2 - r * dir}`,
			`Q ${midX} ${y2} ${midX - r} ${y2}`,
			`L ${x2} ${y2}`
		].join(' ');
	}

	function getPath(line: ConnectionLine): string {
		const { x1, y1, x2, y2, sameColumnStack } = line;
		if (sameColumnStack) {
			return buildSameColumnStackPath(x1, y1, x2, y2);
		}
		// Bézier: pontos de controle devem ir “em direção” ao outro extremo. Com optativa em
		// semestre à esquerda do pré-requisito, x2 < x1; offsets fixos para a direita quebram a curva.
		const dx = Math.abs(x2 - x1);
		const controlOffset = Math.max(dx * 0.4, 40);
		if (x2 >= x1) {
			return `M ${x1} ${y1} C ${x1 + controlOffset} ${y1}, ${x2 - controlOffset} ${y2}, ${x2} ${y2}`;
		}
		return `M ${x1} ${y1} C ${x1 - controlOffset} ${y1}, ${x2 + controlOffset} ${y2}, ${x2} ${y2}`;
	}

	/** Modo direto: bezier; modo todas: vão entre colunas quando há `routing`. */
	function pathForLine(line: ConnectionLine): string {
		if (line.routing) {
			if (line.sameColumnStack) {
				return buildSameColumnStackPath(line.x1, line.y1, line.x2, line.y2);
			}
			return getGapRoutedPath(line);
		}
		return getPath(line);
	}

	/**
	 * Generate a gap-routed path with proper lane assignments.
	 */
	function getGapRoutedPath(line: ConnectionLine): string {
		const r = line.routing!;
		const { x1, y1, x2, y2 } = line;

		if (r.isAdjacent) {
			return buildAdjacentPath(x1, y1, x2, y2, r.exitLaneX);
		} else {
			return buildNonAdjacentPath(x1, y1, x2, y2, r.exitLaneX, r.entryLaneX, r.transitY);
		}
	}

	/**
	 * Adjacent columns: simple L-path through the gap with rounded corners.
	 * (x1,y1) → (laneX,y1) → (laneX,y2) → (x2,y2)
	 */
	function buildAdjacentPath(
		x1: number, y1: number,
		x2: number, y2: number,
		laneX: number
	): string {
		const dy = y2 - y1;
		const dx = Math.abs(x2 - x1);
		// Mesma coluna no modo “todas”: afasta o corredor do meio dos cards
		let lane = laneX;
		if (dx < SAME_COLUMN_DX_PX && Math.abs(dy) > 8) {
			lane = Math.max(lane, Math.max(x1, x2) + 28);
		}

		// If roughly same Y, use a straight line through the gap
		if (Math.abs(dy) < 5) {
			return `M ${x1} ${y1} L ${x2} ${y2}`;
		}

		const dirY = dy > 0 ? 1 : -1;
		const maxR = 10;
		const r = Math.min(maxR, Math.abs(dy) / 2, Math.abs(lane - x1) / 2, Math.abs(x2 - lane) / 2);

		if (r < 2) {
			// Too tight for rounded corners, use straight segments
			return `M ${x1} ${y1} L ${lane} ${y1} L ${lane} ${y2} L ${x2} ${y2}`;
		}

		return [
			`M ${x1} ${y1}`,
			`L ${lane - r} ${y1}`,
			`Q ${lane} ${y1}, ${lane} ${y1 + r * dirY}`,
			`L ${lane} ${y2 - r * dirY}`,
			`Q ${lane} ${y2}, ${lane + r} ${y2}`,
			`L ${x2} ${y2}`
		].join(' ');
	}

	/**
	 * Non-adjacent columns: Z-path through exit gap, horizontal transit, entry gap.
	 * (x1,y1) → (exitLaneX,y1) → (exitLaneX,transitY) → (entryLaneX,transitY) → (entryLaneX,y2) → (x2,y2)
	 */
	function buildNonAdjacentPath(
		x1: number, y1: number,
		x2: number, y2: number,
		exitLaneX: number, entryLaneX: number,
		transitY: number
	): string {
		const maxR = 8;
		const points: string[] = [];

		// Segment 1: horizontal from source to exit lane
		points.push(`M ${x1} ${y1}`);

		// Corner 1: turn from horizontal to vertical at (exitLaneX, y1) going toward transitY
		const dir1Y = transitY < y1 ? -1 : 1;
		const r1 = Math.min(maxR, Math.abs(transitY - y1) / 2, Math.abs(exitLaneX - x1) / 2);

		if (r1 >= 2) {
			points.push(`L ${exitLaneX - r1} ${y1}`);
			points.push(`Q ${exitLaneX} ${y1}, ${exitLaneX} ${y1 + r1 * dir1Y}`);
		} else {
			points.push(`L ${exitLaneX} ${y1}`);
		}

		// Segment 2: vertical in exit gap from y1 to transitY
		// Corner 2: turn from vertical to horizontal at (exitLaneX, transitY)
		const dir2X = entryLaneX > exitLaneX ? 1 : -1;
		const r2 = Math.min(maxR, Math.abs(transitY - y1) / 2, Math.abs(entryLaneX - exitLaneX) / 2);

		if (r2 >= 2) {
			points.push(`L ${exitLaneX} ${transitY - r2 * dir1Y}`);
			points.push(`Q ${exitLaneX} ${transitY}, ${exitLaneX + r2 * dir2X} ${transitY}`);
		} else {
			points.push(`L ${exitLaneX} ${transitY}`);
		}

		// Segment 3: horizontal transit from exit lane to entry lane
		// Corner 3: turn from horizontal to vertical at (entryLaneX, transitY)
		const dir3Y = y2 > transitY ? 1 : -1;
		const r3 = Math.min(maxR, Math.abs(entryLaneX - exitLaneX) / 2, Math.abs(y2 - transitY) / 2);

		if (r3 >= 2) {
			points.push(`L ${entryLaneX - r3 * dir2X} ${transitY}`);
			points.push(`Q ${entryLaneX} ${transitY}, ${entryLaneX} ${transitY + r3 * dir3Y}`);
		} else {
			points.push(`L ${entryLaneX} ${transitY}`);
		}

		// Segment 4: vertical in entry gap from transitY to y2
		// Corner 4: turn from vertical to horizontal at (entryLaneX, y2)
		const r4 = Math.min(maxR, Math.abs(y2 - transitY) / 2, Math.abs(x2 - entryLaneX) / 2);

		if (r4 >= 2) {
			points.push(`L ${entryLaneX} ${y2 - r4 * dir3Y}`);
			points.push(`Q ${entryLaneX} ${y2}, ${entryLaneX + r4} ${y2}`);
		} else {
			points.push(`L ${entryLaneX} ${y2}`);
		}

		// Segment 5: horizontal from entry lane to target
		points.push(`L ${x2} ${y2}`);

		return points.join(' ');
	}

	// ─── Helpers ──────────────────────────────────────────────────────

	function isLineRelatedToHovered(line: ConnectionLine, hoveredCode: string): boolean {
		const h = normSubjectCode(hoveredCode);
		return normSubjectCode(line.fromCode) === h || normSubjectCode(line.toCode) === h;
	}

	function getStrokeColor(type: 'prerequisite' | 'dependent' | 'corequisite'): string {
		switch (type) {
			case 'prerequisite': return '#a78bfa';  // violeta
			case 'dependent': return '#2dd4bf';     // teal
			case 'corequisite': return '#10b981';   // verde
			default: return '#a78bfa';
		}
	}

	function chainStrokeColor(st: 'pre' | 'desc' | 'core'): string {
		switch (st) {
			case 'pre':
				return CHAIN_VISUAL.precursor;
			case 'desc':
				return CHAIN_VISUAL.descendant;
			case 'core':
				return CHAIN_VISUAL.corequisite;
		}
	}

	/** Paleta harmônica (círculo cromático): 12 cores distribuídas no HSL para pré-requisitos no modo "todas". */
	const PALETTE_PREREQ = [
		'#a78bfa', // violeta
		'#38bdf8', // azul claro
		'#2dd4bf', // teal
		'#34d399', // esmeralda
		'#a3e635', // lima
		'#facc15', // amarelo
		'#fb923c', // laranja
		'#f87171', // vermelho claro
		'#f472b6', // rosa
		'#c084fc', // violeta claro
		'#818cf8', // índigo
		'#22d3ee'  // ciano
	];

	// ─── Reactivity ──────────────────────────────────────────────────

	$effect(() => {
		const _hovered = store.state.hoveredSubjectCode;
		void store.state.hoverPreviewSubjectCode;
		const _mode = store.state.connectionMode;
		const _data = store.state.courseData;
		const el = container;
		const _zoom = store.state.zoomLevel;
		void store.diagramLayoutRevision;

		if (!browser) return;

		let resizeDebounce: ReturnType<typeof setTimeout> | null = null;
		const ro =
			el &&
			new ResizeObserver(() => {
				if (resizeDebounce) clearTimeout(resizeDebounce);
				resizeDebounce = setTimeout(() => {
					resizeDebounce = null;
					calculateConnections(true);
				}, 50);
			});

		if (el && ro) ro.observe(el);

		// Dois frames: aguarda commit de layout do Svelte e primeiras transições de gap/zoom.
		requestAnimationFrame(() => {
			requestAnimationFrame(() => {
				calculateConnections(true);
			});
		});

		return () => {
			ro?.disconnect();
			if (resizeDebounce) clearTimeout(resizeDebounce);
		};
	});
</script>

{#if lines.length > 0}
	<svg
		class="pointer-events-none absolute left-0 top-0"
		width={svgWidth}
		height={svgHeight}
		style="z-index: 5;"
	>
		<defs>
			<!-- Marcadores por tipo (modo diretas) -->
			<marker
				id="arrow-prereq"
				markerUnits="userSpaceOnUse"
				markerWidth="10"
				markerHeight="8"
				refX="9"
				refY="4"
				orient="auto"
			>
				<polygon points="0 0, 9 4, 0 8" fill="#a78bfa" />
			</marker>
			<marker
				id="arrow-dep"
				markerUnits="userSpaceOnUse"
				markerWidth="10"
				markerHeight="8"
				refX="9"
				refY="4"
				orient="auto"
			>
				<polygon points="0 0, 9 4, 0 8" fill="#2dd4bf" />
			</marker>
			<marker
				id="arrow-coreq"
				markerUnits="userSpaceOnUse"
				markerWidth="10"
				markerHeight="8"
				refX="9"
				refY="4"
				orient="auto"
			>
				<polygon points="0 0, 9 4, 0 8" fill="#10b981" />
			</marker>
			<!-- Modo diretas: cadeia transitiva (cores alinhadas ao painel de referência) -->
			<marker
				id="arrow-chain-pre"
				markerUnits="userSpaceOnUse"
				markerWidth="10"
				markerHeight="8"
				refX="9"
				refY="4"
				orient="auto"
			>
				<polygon points="0 0, 9 4, 0 8" fill={CHAIN_VISUAL.precursor} />
			</marker>
			<marker
				id="arrow-chain-desc"
				markerUnits="userSpaceOnUse"
				markerWidth="10"
				markerHeight="8"
				refX="9"
				refY="4"
				orient="auto"
			>
				<polygon points="0 0, 9 4, 0 8" fill={CHAIN_VISUAL.descendant} />
			</marker>
			<marker
				id="arrow-chain-core"
				markerUnits="userSpaceOnUse"
				markerWidth="10"
				markerHeight="8"
				refX="9"
				refY="4"
				orient="auto"
			>
				<polygon points="0 0, 9 4, 0 8" fill={CHAIN_VISUAL.corequisite} />
			</marker>
			<!-- Paleta para pré-requisitos (modo "todas") — uma cor por seta -->
			{#each PALETTE_PREREQ as paletteColor, j}
				<marker
					id="arrow-palette-{j}"
					markerUnits="userSpaceOnUse"
					markerWidth="10"
					markerHeight="8"
					refX="9"
					refY="4"
					orient="auto"
				>
					<polygon points="0 0, 9 4, 0 8" fill={paletteColor} fill-opacity="0.5" />
				</marker>
			{/each}
		</defs>

		{#each lines as line, i}
			{@const hoveredCode =
				store.state.hoverPreviewSubjectCode ?? store.state.hoveredSubjectCode}
			{@const isAllMode = store.state.connectionMode === 'all'}
			{@const isDirectChain = !isAllMode && line.chainStroke}
			{@const isAllWithHover = isAllMode && !!hoveredCode}
			{@const isRelated = isAllWithHover && isLineRelatedToHovered(line, hoveredCode)}
			{@const isDimmed = isAllWithHover && !isRelated}
			{@const strokeColor = isDirectChain && line.chainStroke
				? chainStrokeColor(line.chainStroke)
				: isAllMode && line.type === 'prerequisite'
					? PALETTE_PREREQ[i % PALETTE_PREREQ.length]
					: getStrokeColor(line.type)}
			{@const markerUrl = isDirectChain && line.chainStroke
				? line.chainStroke === 'pre'
					? 'url(#arrow-chain-pre)'
					: line.chainStroke === 'desc'
						? 'url(#arrow-chain-desc)'
						: 'url(#arrow-chain-core)'
				: isAllMode && line.type === 'prerequisite'
					? `url(#arrow-palette-${i % PALETTE_PREREQ.length})`
					: line.type === 'prerequisite'
						? 'url(#arrow-prereq)'
						: line.type === 'dependent'
							? 'url(#arrow-dep)'
							: 'url(#arrow-coreq)'}
			<path
				d={pathForLine(line)}
				fill="none"
				stroke={strokeColor}
				stroke-width={isRelated ? '3' : isAllMode ? '2.5' : '2'}
				stroke-opacity={isDimmed ? '0.2' : isAllMode ? '0.5' : '0.85'}
				stroke-dasharray={line.type === 'corequisite' ? '8,5' : 'none'}
				marker-end={markerUrl}
				style="transition: stroke-opacity 0.2s, stroke-width 0.2s;"
			/>
		{/each}
	</svg>
{/if}

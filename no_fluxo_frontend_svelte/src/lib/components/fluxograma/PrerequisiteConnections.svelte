<script lang="ts">
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { browser } from '$app/environment';

	const store = fluxogramaStore;

	interface ConnectionLine {
		x1: number;
		y1: number;
		x2: number;
		y2: number;
		type: 'prerequisite' | 'dependent' | 'corequisite';
		isAllMode?: boolean;
		fromCode: string;
		toCode: string;
	}

	let lines = $state<ConnectionLine[]>([]);
	let svgWidth = $state(0);
	let svgHeight = $state(0);

	interface Props {
		container?: HTMLElement | null;
	}

	let { container = null }: Props = $props();

	// ─── Main Calculation ─────────────────────────────────────────────

	function calculateConnections() {
		if (!browser || !container) {
			lines = [];
			return;
		}

		const hoveredCode = store.state.hoveredSubjectCode;
		const connectionMode = store.state.connectionMode;
		const courseData = store.state.courseData;

		if (connectionMode === 'off' || !courseData) {
			lines = [];
			return;
		}

		if (connectionMode === 'direct' && !hoveredCode) {
			lines = [];
			return;
		}

		const containerRect = container.getBoundingClientRect();
		svgWidth = container.scrollWidth;
		svgHeight = container.scrollHeight;

		const zoom = store.state.zoomLevel || 1;

		const newLines: ConnectionLine[] = [];

		if (hoveredCode && connectionMode === 'direct') {
			const hoveredMateria = courseData.materias.find(
				(m) => m.codigoMateria === hoveredCode
			);
			if (!hoveredMateria) {
				lines = [];
				return;
			}

			if (hoveredMateria.preRequisitos) {
				for (const prereq of hoveredMateria.preRequisitos) {
					const line = getLineBetweenCards(
						prereq.codigoMateria, hoveredCode,
						container, containerRect, 'prerequisite', false
					);
					if (line) newLines.push(line);
				}
			}

			for (const materia of courseData.materias) {
				if (materia.preRequisitos?.some((p) => p.codigoMateria === hoveredCode)) {
					const line = getLineBetweenCards(
						hoveredCode, materia.codigoMateria,
						container, containerRect, 'dependent', false
					);
					if (line) newLines.push(line);
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

		}

		lines = newLines;

		// Compute per-semester connection density and push to store
		if (connectionMode === 'all' && courseData) {
			computeAndSetDensity(newLines, courseData);
		} else {
			store.setConnectionDensity(new Map());
		}
	}

	/**
	 * Count connections per semester and push to the store.
	 * For each line, increment count for both the source and target subject's semester.
	 */
	function computeAndSetDensity(allLines: ConnectionLine[], courseData: { materias: { codigoMateria: string }[] }) {
		// Build code → semester map from the store's subjectsBySemester
		const codeToSemester = new Map<string, number>();
		for (const [sem, subjects] of store.subjectsBySemester) {
			for (const s of subjects) {
				codeToSemester.set(s.codigoMateria, sem);
			}
		}

		const density = new Map<number, number>();
		for (const line of allLines) {
			const fromSem = codeToSemester.get(line.fromCode);
			const toSem = codeToSemester.get(line.toCode);
			if (fromSem !== undefined) {
				density.set(fromSem, (density.get(fromSem) ?? 0) + 1);
			}
			if (toSem !== undefined) {
				density.set(toSem, (density.get(toSem) ?? 0) + 1);
			}
		}

		store.setConnectionDensity(density);
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
		const fromCard = containerEl.querySelector(
			`[data-subject-code="${fromCode}"]`
		) as HTMLElement | null;
		const toCard = containerEl.querySelector(
			`[data-subject-code="${toCode}"]`
		) as HTMLElement | null;

		if (!fromCard || !toCard) return null;

		const fromRect = fromCard.getBoundingClientRect();
		const toRect = toCard.getBoundingClientRect();
		const zoom = store.state.zoomLevel || 1;

		// Origem do SVG = padding edge do container (position absolute usa content box)
		const style = getComputedStyle(containerEl);
		const padL = parseFloat(style.paddingLeft) || 0;
		const padT = parseFloat(style.paddingTop) || 0;
		const originX = containerRect.left + padL;
		const originY = containerRect.top + padT;

		// Meio da direita do pré-requisito → meio da esquerda do destino
		const x1 = (fromRect.right - originX) / zoom;
		const y1 = (fromRect.top + fromRect.height / 2 - originY) / zoom;
		const x2 = (toRect.left - originX) / zoom;
		const y2 = (toRect.top + toRect.height / 2 - originY) / zoom;

		return { x1, y1, x2, y2, type, isAllMode, fromCode, toCode };
	}

	// ─── Path Generation (estilo Flutter: Bezier curva acima) ───────────

	function getPath(line: ConnectionLine): string {
		const { x1, y1, x2, y2 } = line;
		const zoom = store.state.zoomLevel || 1;
		const curveOffset = 50 * zoom;

		// Control points acima da linha (como no Flutter)
		const cp1x = x1 + (x2 - x1) * 0.3;
		const cp1y = y1 - curveOffset;
		const cp2x = x1 + (x2 - x1) * 0.7;
		const cp2y = y2 - curveOffset;

		return `M ${x1} ${y1} C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${x2} ${y2}`;
	}

	// ─── Helpers ──────────────────────────────────────────────────────

	function isLineRelatedToHovered(line: ConnectionLine, hoveredCode: string): boolean {
		return line.fromCode === hoveredCode || line.toCode === hoveredCode;
	}

	function getStrokeColor(type: 'prerequisite' | 'dependent' | 'corequisite'): string {
		if (type === 'corequisite') return '#34d399';
		return type === 'prerequisite' ? '#c4b5fd' : '#5eead4';
	}

	// ─── Reactivity ──────────────────────────────────────────────────

	$effect(() => {
		const _hovered = store.state.hoveredSubjectCode;
		const _mode = store.state.connectionMode;
		const _data = store.state.courseData;
		const _container = container;
		const _zoom = store.state.zoomLevel;

		if (browser) {
			requestAnimationFrame(() => {
				calculateConnections();
			});
		}
	});
</script>

{#if lines.length > 0}
	<svg
		class="pointer-events-none absolute left-0 top-0"
		width={svgWidth}
		height={svgHeight}
		style="z-index: 5; shape-rendering: geometricPrecision;"
	>
		<defs>
			<!-- Setas maiores e mais limpas -->
			<marker
				id="arrow-prereq"
				markerUnits="userSpaceOnUse"
				markerWidth="16"
				markerHeight="12"
				refX="14"
				refY="6"
				orient="auto"
			>
				<polygon points="0 0, 14 6, 0 12" fill="#c4b5fd" />
			</marker>
			<marker
				id="arrow-dep"
				markerUnits="userSpaceOnUse"
				markerWidth="16"
				markerHeight="12"
				refX="14"
				refY="6"
				orient="auto"
			>
				<polygon points="0 0, 14 6, 0 12" fill="#5eead4" />
			</marker>
			<marker
				id="arrow-coreq"
				markerUnits="userSpaceOnUse"
				markerWidth="16"
				markerHeight="12"
				refX="14"
				refY="6"
				orient="auto"
			>
				<polygon points="0 0, 14 6, 0 12" fill="#34d399" />
			</marker>
		</defs>

		{#each lines as line, i}
			{@const hoveredCode = store.state.hoveredSubjectCode}
			{@const isAllWithHover = store.state.connectionMode === 'all' && !!hoveredCode}
			{@const isRelated = isAllWithHover && isLineRelatedToHovered(line, hoveredCode)}
			{@const isDimmed = isAllWithHover && !isRelated}
			<path
				d={getPath(line)}
				fill="none"
				stroke={getStrokeColor(line.type)}
				stroke-width={isRelated ? '3' : '2.5'}
				stroke-opacity={isDimmed ? '0.2' : '0.9'}
				stroke-linecap="round"
				stroke-linejoin="round"
				stroke-dasharray={line.type === 'corequisite' ? '8,6' : 'none'}
				marker-end={line.type === 'prerequisite' ? 'url(#arrow-prereq)' : line.type === 'dependent' ? 'url(#arrow-dep)' : 'url(#arrow-coreq)'}
				style="transition: stroke-opacity 0.2s, stroke-width 0.2s;"
			/>
		{/each}
	</svg>
{/if}

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
	}

	let lines = $state<ConnectionLine[]>([]);
	let svgWidth = $state(0);
	let svgHeight = $state(0);

	let containerEl: HTMLElement | null = $state(null);

	interface Props {
		container?: HTMLElement | null;
	}

	let { container = null }: Props = $props();

	function calculateConnections() {
		if (!browser || !container) {
			lines = [];
			return;
		}

		const hoveredCode = store.state.hoveredSubjectCode;
		const showAll = store.state.showConnections;
		const courseData = store.state.courseData;

		if ((!hoveredCode && !showAll) || !courseData) {
			lines = [];
			return;
		}

		const containerRect = container.getBoundingClientRect();
		svgWidth = container.scrollWidth;
		svgHeight = container.scrollHeight;

		console.log('[Connections] Calculating:', {
			hoveredCode,
			showAll,
			svgWidth,
			svgHeight,
			zoom: store.state.zoomLevel,
			materias: courseData.materias.length,
			materiasWithPrereqs: courseData.materias.filter((m) => (m.preRequisitos?.length ?? 0) > 0).length
		});

		const newLines: ConnectionLine[] = [];

		if (hoveredCode) {
			// Find the hovered subject
			const hoveredMateria = courseData.materias.find(
				(m) => m.codigoMateria === hoveredCode
			);
			if (!hoveredMateria) {
				lines = [];
				return;
			}

			// Draw lines from prerequisites TO this subject
			if (hoveredMateria.preRequisitos) {
				for (const prereq of hoveredMateria.preRequisitos) {
					const line = getLineBetweenCards(
						prereq.codigoMateria,
						hoveredCode,
						container,
						containerRect,
						'prerequisite'
					);
					if (line) newLines.push(line);
				}
			}

			// Draw lines from this subject TO its dependents
			for (const materia of courseData.materias) {
				if (materia.preRequisitos?.some((p) => p.codigoMateria === hoveredCode)) {
					const line = getLineBetweenCards(
						hoveredCode,
						materia.codigoMateria,
						container,
						containerRect,
						'dependent'
					);
					if (line) newLines.push(line);
				}
			}
		} else if (showAll) {
			// Show all prerequisite connections
			for (const materia of courseData.materias) {
				if (materia.preRequisitos) {
					for (const prereq of materia.preRequisitos) {
						const line = getLineBetweenCards(
							prereq.codigoMateria,
							materia.codigoMateria,
							container,
							containerRect,
							'prerequisite'
						);
						if (line) newLines.push(line);
					}
				}
			}

			// Show co-requisite connections
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
						fromMateria.codigoMateria,
						coReq.codigoMateriaCoRequisito,
						container,
						containerRect,
						'corequisite'
					);
					if (line) newLines.push(line);
				}
			}
		}

		console.log('[Connections] Lines generated:', newLines.length);
		lines = newLines;
	}

	function getLineBetweenCards(
		fromCode: string,
		toCode: string,
		containerEl: HTMLElement,
		containerRect: DOMRect,
		type: 'prerequisite' | 'dependent' | 'corequisite'
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

		// getBoundingClientRect() returns viewport coordinates (post-transform/scale).
		// The SVG lives inside the scaled container, so we need local (pre-scale) coords.
		const zoom = store.state.zoomLevel || 1;

		const x1 = (fromRect.right - containerRect.left) / zoom;
		const y1 = (fromRect.top + fromRect.height / 2 - containerRect.top) / zoom;
		const x2 = (toRect.left - containerRect.left) / zoom;
		const y2 = (toRect.top + toRect.height / 2 - containerRect.top) / zoom;

		return { x1, y1, x2, y2, type };
	}

	function getPath(line: ConnectionLine): string {
		const dx = Math.abs(line.x2 - line.x1);
		const controlOffset = Math.max(dx * 0.4, 40);

		return `M ${line.x1} ${line.y1} C ${line.x1 + controlOffset} ${line.y1}, ${line.x2 - controlOffset} ${line.y2}, ${line.x2} ${line.y2}`;
	}

	function getStrokeColor(type: 'prerequisite' | 'dependent' | 'corequisite'): string {
		if (type === 'corequisite') return '#10b981';
		return type === 'prerequisite' ? '#a78bfa' : '#2dd4bf';
	}

	// Recalculate connections when hovered subject, showConnections, or zoom changes
	$effect(() => {
		// Access reactive dependencies
		const _hovered = store.state.hoveredSubjectCode;
		const _show = store.state.showConnections;
		const _data = store.state.courseData;
		const _container = container;
		const _zoom = store.state.zoomLevel;

		// Use requestAnimationFrame for smooth recalculation
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
		style="z-index: 5;"
	>
		<defs>
			<marker
				id="arrow-prereq"
				markerWidth="8"
				markerHeight="6"
				refX="8"
				refY="3"
				orient="auto"
			>
				<polygon points="0 0, 8 3, 0 6" fill="#a78bfa" />
			</marker>
			<marker
				id="arrow-dep"
				markerWidth="8"
				markerHeight="6"
				refX="8"
				refY="3"
				orient="auto"
			>
				<polygon points="0 0, 8 3, 0 6" fill="#2dd4bf" />
			</marker>
			<marker
				id="arrow-coreq"
				markerWidth="8"
				markerHeight="6"
				refX="8"
				refY="3"
				orient="auto"
			>
				<polygon points="0 0, 8 3, 0 6" fill="#10b981" />
			</marker>
		</defs>

		{#each lines as line, i}
			<path
				d={getPath(line)}
				fill="none"
				stroke={getStrokeColor(line.type)}
				stroke-width="2"
				stroke-opacity="0.7"
				stroke-dasharray={line.type === 'corequisite' ? '6,4' : 'none'}
				marker-end={line.type === 'prerequisite' ? 'url(#arrow-prereq)' : line.type === 'dependent' ? 'url(#arrow-dep)' : 'url(#arrow-coreq)'}
			/>
		{/each}
	</svg>
{/if}

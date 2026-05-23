<script lang="ts">
	import { browser } from '$app/environment';
	import type { CursoModel } from '$lib/types/curso';
	import type { PlanoFormatura } from '$lib/types/plano-formatura';
	import { getDirectPrerequisites } from '$lib/types/curso';

	export interface Props {
		plano: PlanoFormatura;
		curso: CursoModel | null;
	}

	let { plano, curso }: Props = $props();

	let scrollContainer: HTMLElement | null = null;
	let contentWrapper: HTMLElement | null = null;
	let svgWidth = 0;
	let svgHeight = 0;
	let lines: { path: string; key: string }[] = [];
	let resizeObserver: ResizeObserver | null = null;

	function normalizeCode(code: string) {
		return code?.trim().toUpperCase() ?? '';
	}

	function updateLines() {
		if (!browser) {
			console.log('[PlannerPrerequisiteConnections] Not in browser');
			lines = [];
			return;
		}
		if (!scrollContainer) console.log('[PlannerPrerequisiteConnections] No scrollContainer');
		if (!contentWrapper) console.log('[PlannerPrerequisiteConnections] No contentWrapper');
		if (!curso) {
			console.log('[PlannerPrerequisiteConnections] No curso data');
		} else {
			console.log('[PlannerPrerequisiteConnections] curso loaded:', { materias: curso.materias.length, preRequisitos: curso.preRequisitos?.length || 0 });
		}
		if (!plano?.plano?.length) console.log('[PlannerPrerequisiteConnections] No plano data', { planoExists: !!plano, planoPlano: !!plano?.plano, length: plano?.plano?.length });

		if (!browser || !scrollContainer || !contentWrapper || !curso || !plano?.plano?.length) {
			lines = [];
			return;
		}

		const containerRect = scrollContainer.getBoundingClientRect();
		const scrollLeft = scrollContainer.scrollLeft;
		const scrollTop = scrollContainer.scrollTop;

		const cardEls = Array.from(contentWrapper.querySelectorAll<HTMLElement>('[data-subject-code]'));
		console.log(`[PlannerPrerequisiteConnections] Found ${cardEls.length} cards with data-subject-code`);
		const cardMap = new Map<string, HTMLElement>();
		for (const card of cardEls) {
			const rawCode = card.dataset.subjectCode ?? '';
			const code = normalizeCode(rawCode);
			if (code) {
				cardMap.set(code, card);
				console.log(`[PlannerPrerequisiteConnections] Card: ${rawCode} → ${code}`);
			}
		}
		console.log(`[PlannerPrerequisiteConnections] Card map has ${cardMap.size} entries: ${Array.from(cardMap.keys()).join(', ')}`);

		const width = Math.max(contentWrapper.scrollWidth, contentWrapper.clientWidth);
		const height = Math.max(contentWrapper.scrollHeight, contentWrapper.clientHeight);
		svgWidth = width;
		svgHeight = height;

		const newLines: { path: string; key: string }[] = [];
		const seen = new Set<string>();

		for (const semestre of plano.plano) {
			for (const item of semestre.materias) {
				if (!('codigo' in item)) continue;
				const subjectCode = normalizeCode(item.codigo);
				const targetEl = cardMap.get(subjectCode);
				if (!targetEl) {
					console.log(`[PlannerPrerequisiteConnections] Card not found for ${subjectCode}`);
					continue;
				}

				const prereqs = getDirectPrerequisites(curso, subjectCode);
				console.log(`[PlannerPrerequisiteConnections] Looking up ${subjectCode} in curso.materias...`);
				const materiaInCurso = curso.materias.find(m => normalizeCode(m.codigoMateria) === subjectCode);
				console.log(`[PlannerPrerequisiteConnections] ${subjectCode}: found in curso = ${!!materiaInCurso}, prerequisitos = ${prereqs.length}`);
				if (prereqs.length > 0) {
					console.log(`[PlannerPrerequisiteConnections] ${subjectCode} has ${prereqs.length} prerequisites`, prereqs.map(p => `${p.codigoMateria}(${p.idMateria})`));
				}
				for (const prereq of prereqs) {
					const sourceCode = normalizeCode(prereq.codigoMateria);
					const sourceEl = cardMap.get(sourceCode);
					if (!sourceEl) {
						console.log(`[PlannerPrerequisiteConnections] Prerequisite ${prereq.codigoMateria} (normalized: ${sourceCode}) not in cardMap`);
						continue;
					}
					console.log(`[PlannerPrerequisiteConnections] Drawing arrow: ${sourceCode} → ${subjectCode}`);

					const key = `${sourceCode}->${subjectCode}`;
					if (seen.has(key)) continue;
					seen.add(key);

					const sourceRect = sourceEl.getBoundingClientRect();
					const targetRect = targetEl.getBoundingClientRect();

					const sourceY = sourceRect.top - containerRect.top + scrollTop + sourceRect.height / 2;
					const targetY = targetRect.top - containerRect.top + scrollTop + targetRect.height / 2;
					const sourceX = sourceRect.right - containerRect.left + scrollLeft;
					const targetX = targetRect.left - containerRect.left + scrollLeft;

					const isForward = sourceX <= targetX;
					const controlX = isForward
						? sourceX + Math.max((targetX - sourceX) * 0.5, 32)
						: targetX - Math.max((sourceX - targetX) * 0.5, 32);

					const endX = isForward ? Math.max(targetX - 8, sourceX + 16) : Math.min(targetX + 8, sourceX - 16);
					const startX = isForward ? sourceX + 4 : sourceX - 4;

					const path = `M ${startX} ${sourceY} C ${controlX} ${sourceY} ${controlX} ${targetY} ${endX} ${targetY}`;
					newLines.push({ path, key });
				}
			}
		}

		console.log(`[PlannerPrerequisiteConnections] Drew ${newLines.length} prerequisite arrows`);
		lines = newLines;
	}

	function scheduleUpdate() {
		requestAnimationFrame(updateLines);
	}

	function observeContentWrapper(node: HTMLElement) {
		contentWrapper = node;
	
		if (browser && resizeObserver) {
			resizeObserver.observe(node);
		}
	
		scheduleUpdate();
	
		return {
			destroy() {
				if (resizeObserver) {
					resizeObserver.unobserve(node);
				}
			}
		};
	}

	function plannerLines(node: HTMLElement, plan?: unknown) {
		scrollContainer = node;

		if (browser) {
			resizeObserver = new ResizeObserver(scheduleUpdate);
			resizeObserver.observe(node);
			window.addEventListener('resize', scheduleUpdate);
		}

		scheduleUpdate();

		return {
			update() {
				scheduleUpdate();
			},
			destroy() {
				if (resizeObserver) {
					resizeObserver.disconnect();
			}
				if (browser) {
					window.removeEventListener('resize', scheduleUpdate);
				}
			}
		};
	}


</script>

<div class="relative flex flex-1 overflow-x-auto pb-4" use:plannerLines={plano}>
	<div class="relative" style="width: {svgWidth}px; min-width: 100%; height: auto;">
		<svg class="absolute inset-0 pointer-events-none" width={svgWidth} height={svgHeight} viewBox={`0 0 ${svgWidth} ${svgHeight}`}>
			<defs>
				<marker
					id="planner-arrowhead"
					viewBox="0 0 8 8"
					refX="7"
					refY="4"
					markerWidth="6"
					markerHeight="6"
					orient="auto"
				>
					<path d="M 0 0 L 8 4 L 0 8 Z" fill="rgba(96, 165, 250, 0.95)" />
				</marker>
			</defs>
			{#each lines as line}
				<path d={line.path} fill="none" stroke="rgba(96, 165, 250, 0.95)" stroke-width="2" marker-end="url(#planner-arrowhead)" />
			{/each}
		</svg>

		<div class="relative flex gap-4" bind:this={contentWrapper} use:observeContentWrapper>
			<slot />
		</div>
	</div>
</div>

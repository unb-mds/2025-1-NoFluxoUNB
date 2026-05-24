<script lang="ts">
	import { browser } from '$app/environment';
	import type { CursoModel } from '$lib/types/curso';
	import type { PlanoFormatura } from '$lib/types/plano-formatura';
	import { getDirectPrerequisites } from '$lib/types/curso';

	export interface Props {
		plano: PlanoFormatura;
		curso: CursoModel | null;
		hoveredCode?: string | null;
	}

	let { plano, curso, hoveredCode }: Props = $props();

	let scrollContainer: HTMLElement | null = null;
	let contentWrapper: HTMLElement | null = null;
	let svgWidth = 0;
	let svgHeight = 0;
	let lines: { path: string; key: string }[] = [];
	let resizeObserver: ResizeObserver | null = null;

	/** Linhas filtradas que devem ser exibidas (apenas as que envolvem hoveredCode, ou todas se nenhum hover). */
	const visibleLines = $derived.by(() => {
		if (!hoveredCode) return lines;
		return lines.filter(line => {
			const from = line.key.split('->')[0];
			const to = line.key.split('->')[1];
			return from === hoveredCode || to === hoveredCode;
		});
	});

	function normalizeCode(code: string) {
		return code?.trim().toUpperCase() ?? '';
	}

	function updateLines() {
		if (!browser || !scrollContainer || !contentWrapper || !curso || !plano?.plano?.length) {
			lines = [];
			return;
		}

		const containerRect = scrollContainer.getBoundingClientRect();
		const scrollLeft = scrollContainer.scrollLeft;
		const scrollTop = scrollContainer.scrollTop;

		const cardEls = Array.from(contentWrapper.querySelectorAll<HTMLElement>('[data-subject-code]'));
		const cardMap = new Map<string, HTMLElement>();
		for (const card of cardEls) {
			const code = normalizeCode(card.dataset.subjectCode ?? '');
			if (code) cardMap.set(code, card);
		}

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
				for (const prereq of prereqs) {
					const sourceCode = normalizeCode(prereq.codigoMateria);
					const sourceEl = cardMap.get(sourceCode);
					if (!sourceEl) continue;

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
			{#each visibleLines as line}
				<path d={line.path} fill="none" stroke="rgba(96, 165, 250, 0.95)" stroke-width="2" marker-end="url(#planner-arrowhead)" />
			{/each}
		</svg>

		<div class="relative flex gap-4" bind:this={contentWrapper} use:observeContentWrapper>
			<slot />
		</div>
	</div>
</div>

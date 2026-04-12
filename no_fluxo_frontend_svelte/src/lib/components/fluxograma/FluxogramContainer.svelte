<script lang="ts">
	import { onDestroy } from 'svelte';
	import { browser } from '$app/environment';
	import type { MateriaModel } from '$lib/types/materia';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import { matchesFluxogramCompactTouchMode } from '$lib/utils/fluxogram-viewport';
	import SemesterColumn from './SemesterColumn.svelte';
	import PrerequisiteConnections from './PrerequisiteConnections.svelte';

	interface Props {
		onSubjectClick?: (materia: MateriaModel) => void;
		onSubjectOpenChain?: (materia: MateriaModel) => void;
		onSubjectLongPress?: (materia: MateriaModel) => void;
		bind_container?: HTMLElement | null;
	}

	let { onSubjectClick, onSubjectOpenChain, onSubjectLongPress, bind_container = $bindable(null) }: Props =
		$props();

	const store = fluxogramaStore;

	let containerRef: HTMLElement | null = $state(null);
	let innerRef: HTMLElement | null = $state(null);

	// Scroll offset for sticky semester headers (compensates for transform: scale)
	let headerOffsetY = $state(0);

	function handleScroll() {
		if (!containerRef) return;
		headerOffsetY = containerRef.scrollTop / store.state.zoomLevel;
	}

	// Pan/drag state
	let isDragging = $state(false);
	let dragStartX = $state(0);
	let dragStartY = $state(0);
	let scrollStartX = $state(0);
	let scrollStartY = $state(0);

	// Touch state
	let lastTouchX = $state(0);
	let lastTouchY = $state(0);
	let initialPinchDistance = $state(0);
	let initialPinchZoom = $state(0);
	/** Mobile: toque iniciou em um card — atrasa scroll para permitir tap/long-press */
	let touchStartedOnCard = $state(false);

	/**
	 * Em telas estreitas, rolagem com 1 dedo fica nativa (overflow) para encadear com a página
	 * e não “prender” o gesto no diagrama. Desktop mantém pan customizado no fundo.
	 */
	let useNativeTouchScroll = $state(false);

	$effect(() => {
		if (!browser) return;
		const apply = () => {
			useNativeTouchScroll = matchesFluxogramCompactTouchMode();
		};
		apply();
		const mqNarrow = window.matchMedia('(max-width: 768px)');
		const mqLand = window.matchMedia('(orientation: landscape) and (max-height: 560px)');
		mqNarrow.addEventListener('change', apply);
		mqLand.addEventListener('change', apply);
		window.addEventListener('resize', apply);
		return () => {
			mqNarrow.removeEventListener('change', apply);
			mqLand.removeEventListener('change', apply);
			window.removeEventListener('resize', apply);
		};
	});

	// Semestres: apenas colunas nivel >= 1 da matriz + semestres onde há optativa planejada (sem coluna “pool” nivel 0).
	let sortedSemesters = $derived.by(() => {
		const keys = new Set<number>();
		for (const k of store.subjectsBySemester.keys()) {
			if (k > 0) keys.add(k);
		}
		for (const k of store.optativasBySemester.keys()) {
			if (k > 0) keys.add(k);
		}
		return Array.from(keys).sort((a, b) => a - b);
	});

	/** Só arrasta pelo “fundo” — não rouba clique dos cards nem de controles. */
	function isPanStartTarget(target: EventTarget | null): boolean {
		const el = target as HTMLElement | null;
		if (!el) return false;
		if (el.closest('.subject-card')) return false;
		if (el.closest('button, a, input, select, textarea, [role="button"]')) return false;
		return true;
	}

	function endWindowPan() {
		window.removeEventListener('mousemove', handleWindowMouseMove);
		window.removeEventListener('mouseup', handleWindowMouseUp);
		isDragging = false;
		if (containerRef) containerRef.style.cursor = 'grab';
	}

	function handleWindowMouseMove(e: MouseEvent) {
		if (!isDragging || !containerRef) return;
		e.preventDefault();
		const dx = e.clientX - dragStartX;
		const dy = e.clientY - dragStartY;
		containerRef.scrollLeft = scrollStartX - dx;
		containerRef.scrollTop = scrollStartY - dy;
	}

	function handleWindowMouseUp() {
		endWindowPan();
	}

	function handleMouseDown(e: MouseEvent) {
		if (e.button !== 0 || !containerRef || !isPanStartTarget(e.target)) return;
		// Modo "Todas": arrastar pelo fundo limpa o foco (como toque fora do card no mobile)
		if (store.state.connectionMode === 'all') {
			store.setHoveredSubject(null);
		}
		e.preventDefault();
		isDragging = true;
		dragStartX = e.clientX;
		dragStartY = e.clientY;
		scrollStartX = containerRef.scrollLeft;
		scrollStartY = containerRef.scrollTop;
		containerRef.style.cursor = 'grabbing';
		window.addEventListener('mousemove', handleWindowMouseMove);
		window.addEventListener('mouseup', handleWindowMouseUp);
	}

	function handleMouseUp() {
		endWindowPan();
	}

	function handleWheel(e: WheelEvent) {
		if (e.ctrlKey || e.metaKey) {
			e.preventDefault();
			const delta = e.deltaY > 0 ? -0.05 : 0.05;
			store.setZoom(store.state.zoomLevel + delta);
		}
	}

	function handleTouchStart(e: TouchEvent) {
		if (e.touches.length === 1) {
			const target = e.target as HTMLElement;
			touchStartedOnCard = !!target.closest('.subject-card');
			if (!useNativeTouchScroll) {
				// Se toque em card, não inicia scroll — permite tap/long-press
				isDragging = !touchStartedOnCard;
			} else {
				isDragging = false;
			}
			lastTouchX = e.touches[0].clientX;
			lastTouchY = e.touches[0].clientY;
			if (containerRef) {
				scrollStartX = containerRef.scrollLeft;
				scrollStartY = containerRef.scrollTop;
			}
		} else if (e.touches.length === 2) {
			isDragging = false;
			const dx = e.touches[0].clientX - e.touches[1].clientX;
			const dy = e.touches[0].clientY - e.touches[1].clientY;
			initialPinchDistance = Math.sqrt(dx * dx + dy * dy);
			initialPinchZoom = store.state.zoomLevel;
		}
	}

	function handleTouchMove(e: TouchEvent) {
		if (useNativeTouchScroll && e.touches.length === 1) {
			return;
		}
		if (e.touches.length === 1) {
			// Se toque começou em card e usuário moveu, habilita scroll (só desktop / pan customizado)
			if (touchStartedOnCard) {
				const dx = Math.abs(e.touches[0].clientX - lastTouchX);
				const dy = Math.abs(e.touches[0].clientY - lastTouchY);
				if (dx > 8 || dy > 8) {
					touchStartedOnCard = false;
					isDragging = true;
					if (containerRef) {
						scrollStartX = containerRef.scrollLeft;
						scrollStartY = containerRef.scrollTop;
					}
				}
			}
			if (isDragging && containerRef) {
				// Importante: em alguns navegadores esse handler pode ser considerado `passive`,
				// então `preventDefault()` dispara warning no console. O `touch-action: none`
				// no container já evita a rolagem nativa para o gesto de arrasto/pan.
				const ddx = lastTouchX - e.touches[0].clientX;
				const ddy = lastTouchY - e.touches[0].clientY;
				containerRef.scrollLeft += ddx;
				containerRef.scrollTop += ddy;
				lastTouchX = e.touches[0].clientX;
				lastTouchY = e.touches[0].clientY;
			}
		} else if (e.touches.length === 2) {
			// Pinch: em mobile com rolagem nativa, pinch-zoom do SO pode competir; zoom fino continua no painel FAB.
			const dx = e.touches[0].clientX - e.touches[1].clientX;
			const dy = e.touches[0].clientY - e.touches[1].clientY;
			const distance = Math.sqrt(dx * dx + dy * dy);
			const scale = distance / initialPinchDistance;
			store.setZoom(initialPinchZoom * scale);
		}
	}

	function handleTouchEnd(e: TouchEvent) {
		isDragging = false;
		touchStartedOnCard = false;

		// Se toque terminou fora de um card, esconde conexões
		const target = e.target as HTMLElement;
		if (!target.closest('.subject-card')) {
			store.setHoveredSubject(null);
		}
	}

	// Sync bind_container
	$effect(() => {
		bind_container = innerRef;
	});

	onDestroy(() => {
		endWindowPan();
	});
</script>

<!-- Pan/zoom/toque no wrapper: sem elemento nativo equivalente. -->
<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div
	bind:this={containerRef}
	class="fluxogram-container relative h-full min-h-0 w-full flex-1 select-none overflow-auto rounded-xl border border-white/10 bg-black/30 backdrop-blur-sm [overflow-anchor:none] {useNativeTouchScroll ? 'overscroll-y-auto' : ''}"
	style:cursor="grab"
	style:touch-action={useNativeTouchScroll ? 'pan-x pan-y pinch-zoom' : 'none'}
	style:-webkit-overflow-scrolling={useNativeTouchScroll ? 'touch' : undefined}
	role="application"
	aria-label="Fluxograma interativo — arraste o fundo para mover"
	onmousedown={handleMouseDown}
	onmouseup={handleMouseUp}
	onwheel={handleWheel}
	ontouchstart={handleTouchStart}
	ontouchmove={handleTouchMove}
	ontouchend={handleTouchEnd}
	onscroll={handleScroll}
>
	<div
		bind:this={innerRef}
		class="relative inline-flex p-4 pb-[5.75rem] pt-4 md:pb-14"
		style="gap: {store.state.connectionMode === 'all' ? '6rem' : '3rem'}; transform: scale({store.state.zoomLevel}); transform-origin: top left; transition: gap 0.3s ease;"
	>
		<!-- Prerequisite connection lines -->
		<PrerequisiteConnections container={innerRef} />

		<!-- Semester columns -->
		{#each sortedSemesters as semester (semester)}
			{@const subjects = store.subjectsBySemester.get(semester) ?? []}
			{@const optRaw = store.optativasBySemester.get(semester) ?? []}
			{@const codesInCol = new Set(
				subjects.map((m) => m.codigoMateria.trim().toUpperCase())
			)}
			{@const optPlanned = optRaw.filter((o) =>
				!codesInCol.has(o.materia.codigoMateria.trim().toUpperCase())
			)}
			<SemesterColumn
				{semester}
				{subjects}
				optPlanned={optPlanned}
				{onSubjectClick}
				{onSubjectOpenChain}
				{onSubjectLongPress}
				{headerOffsetY}
			/>
		{/each}
	</div>
</div>

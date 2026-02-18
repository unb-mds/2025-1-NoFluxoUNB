<script lang="ts">
	import type { MateriaModel } from '$lib/types/materia';
	import { fluxogramaStore } from '$lib/stores/fluxograma.store.svelte';
	import SemesterColumn from './SemesterColumn.svelte';
	import PrerequisiteConnections from './PrerequisiteConnections.svelte';

	interface Props {
		onSubjectClick?: (materia: MateriaModel) => void;
		onSubjectLongPress?: (materia: MateriaModel) => void;
		bind_container?: HTMLElement | null;
	}

	let { onSubjectClick, onSubjectLongPress, bind_container = $bindable(null) }: Props = $props();

	const store = fluxogramaStore;

	let containerRef: HTMLElement | null = $state(null);
	let innerRef: HTMLElement | null = $state(null);

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

	// Sorted semesters (excluding 0 = optativas)
	let sortedSemesters = $derived.by(() => {
		const map = store.subjectsBySemester;
		return Array.from(map.keys())
			.filter((k) => k > 0)
			.sort((a, b) => a - b);
	});

	function handleMouseDown(e: MouseEvent) {
		if (e.button !== 0 || !containerRef) return;
		isDragging = true;
		dragStartX = e.clientX;
		dragStartY = e.clientY;
		scrollStartX = containerRef.scrollLeft;
		scrollStartY = containerRef.scrollTop;
		containerRef.style.cursor = 'grabbing';
	}

	function handleMouseMove(e: MouseEvent) {
		if (!isDragging || !containerRef) return;
		e.preventDefault();
		const dx = e.clientX - dragStartX;
		const dy = e.clientY - dragStartY;
		containerRef.scrollLeft = scrollStartX - dx;
		containerRef.scrollTop = scrollStartY - dy;
	}

	function handleMouseUp() {
		isDragging = false;
		if (containerRef) containerRef.style.cursor = 'grab';
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
			isDragging = true;
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
		if (e.touches.length === 1 && isDragging && containerRef) {
			e.preventDefault();
			const dx = lastTouchX - e.touches[0].clientX;
			const dy = lastTouchY - e.touches[0].clientY;
			containerRef.scrollLeft += dx;
			containerRef.scrollTop += dy;
			lastTouchX = e.touches[0].clientX;
			lastTouchY = e.touches[0].clientY;
		} else if (e.touches.length === 2) {
			e.preventDefault();
			const dx = e.touches[0].clientX - e.touches[1].clientX;
			const dy = e.touches[0].clientY - e.touches[1].clientY;
			const distance = Math.sqrt(dx * dx + dy * dy);
			const scale = distance / initialPinchDistance;
			store.setZoom(initialPinchZoom * scale);
		}
	}

	function handleTouchEnd(e: TouchEvent) {
		isDragging = false;
		
		// If touch ended on the container background (not a SubjectCard),
		// clear the hover state to hide connections
		const target = e.target as HTMLElement;
		if (!target.closest('.subject-card')) {
			store.setHoveredSubject(null);
		}
	}

	// Sync bind_container
	$effect(() => {
		bind_container = innerRef;
	});
</script>

<div
	bind:this={containerRef}
	class="fluxogram-container relative overflow-auto rounded-xl border border-white/10 bg-black/30 backdrop-blur-sm"
	style="max-height: calc(100vh - 280px); cursor: grab;"
	role="application"
	aria-label="Fluxograma interativo"
	onmousedown={handleMouseDown}
	onmousemove={handleMouseMove}
	onmouseup={handleMouseUp}
	onmouseleave={handleMouseUp}
	onwheel={handleWheel}
	ontouchstart={handleTouchStart}
	ontouchmove={handleTouchMove}
	ontouchend={handleTouchEnd}
>
	<div
		bind:this={innerRef}
		class="relative inline-flex p-4"
		style="gap: 3rem; transform: scale({store.state.zoomLevel}); transform-origin: top left;"
	>
		<!-- Prerequisite connection lines -->
		<PrerequisiteConnections container={innerRef} />

		<!-- Semester columns -->
		{#each sortedSemesters as semester (semester)}
			{@const subjects = store.subjectsBySemester.get(semester) ?? []}
			<SemesterColumn
				{semester}
				{subjects}
				{onSubjectClick}
				{onSubjectLongPress}
			/>
		{/each}
	</div>
</div>
